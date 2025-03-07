#!/usr/bin/bash

set -o errexit  # set -e
set -o errtrace # set -E
set -o nounset  # set -u
set -o pipefail
set -o functrace

on_error() {
  local lieno=$1
  local msg=$2
  echo "[E] Failed at $lineno: $msg"
}

trap_error() {
  trap 'on_error $LINENO "$BASH_COMMAND"' ERR
}

setup_git_if_needed() {
  if ! test -d .git; then
    git config --global --add safe.directory `realpath .`
    git init
    git add -A
    git commit -m 'first'
    cat - > .gitignore <<END
.gitignore
cleanbuild
END
  fi
}

check_in_source_tree() {
  if ! test -f arch/$arch/Makefile; then
    echo "not in source tree"
    exit 1
  fi
  echo "[ok] in source tree"
}

patch_fix_wrong_makefile() {
  if grep -q '+ =' $linux/drivers/media/dvb/b2c2/Makefile; then
    sed -i 's/+ =/+=/' $linux/drivers/media/dvb/b2c2/Makefile
  fi
  echo "[*] patch fix drivers/media/dvb/b2c2/Makefile..done"
}

patch_change_HZ_100() {
  file="$linux/include/asm-i386/param.h"
  perl -i -pe 's/HZ\s+1000/HZ 100/' $file
  if ! grep -q '# define HZ 100' $file; then
    echo "[E] fail to change hz 100"
    exit 1
  fi
  echo "[*] change hz 100...done"
}

create_gccwraps() {
  local gcc33_bin=`realpath gcc33/usr/bin`

  cat > $ccwrap <<END
#!/bin/bash

exec $gcc33_bin/gcc-3.3 \
-B $gcc33_bin/ \
"\$@" -O0 -D__OPTIMIZEXX__
END

  cat > $hostccwrap <<END
#!/bin/bash

exec gcc -std=gnu89 -w -g -O0 "\$@"
END
  
  chmod +x $ccwrap
  chmod +x $hostccwrap

  echo "[*] create gccwraps...done"
}

clean_kernel_source() {
  cd $linux

  printf "[*] clean kernel source\n"
  if test -d .git; then
    # git clean -dn | grep --quiet --invert-match cleanbuild/
    git clean -df > /dev/null
    echo "    git clean -dn"
  else
    $domake mrproper &> /dev/null
    echo "    make mrproper"
  fi

  cd ..
}

__create_makehelpers() {
  local outfile="$1"
  local logfile="$2"

  local bear_code=

  if echo "$outfile" | grep -q bear; then
    bear_code='bear --'
  fi

  cat > $outfile <<END
#!/bin/bash
set -eEu -o pipefail

makeflags="$makeflags"

user_args="\$@"

main() {
  echo -e "[*] user_args=\"\$user_args\"\n"
  echo -e "[*] makeflags=\"\$makeflags\"\n"

  echo -e "\n==== CLEAN START ====\n"

  make \$makeflags clean
  
  echo -e "\n==== CLEAN DONE ====\n"

  $bear_code make \$makeflags "\$user_args"
}

main 2>&1 | tee $logfile
END
}

create_makehelpers() {
  makeflags=
  makeflags+=" ARCH=$arch"
  makeflags+=" CROSS_COMPILE=$cross_compile/"
  makeflags+=" CC=$ccwrap"
  makeflags+=" HOSTCC=$hostccwrap"

  __create_makehelpers $domake $domake_log
  __create_makehelpers $domake_bear $domake_bear_log

  chmod +x $domake
  chmod +x $domake_bear

  if ! grep -q '/ CC=' $domake; then
    echo "[E] don't forget add trailing slash to CROSS_COMPILE"
    exit 1
  fi

  echo "[*] create makehelpers...done"
}

do_tiny_config() {
  cp config_tiny $linux/.config
  
  ruby tools/oldnoconfig.rb $domake $linux `realpath logs/oldnoconfig.log` &> logs/oldnoconfig.stdout

  if grep -q CONFIG_KALLSYMS=y $linux/.config; then
    echo "[E] CONFIG_KALLSYMS is found"
    exit 1
  fi
  echo "[*] do config...done"
}

patch_disable_optimization() {
  target_file=$linux/include/linux/byteorder/generic.h
  target_text='#if defined(__GNUC__) && (__GNUC__ >= 2) && defined(__OPTIMIZE__)'
  target_line=155
  replace_text=$(cat <<END
#if defined(__OPTIMIZE__)
#error "optimization is enabled"
#endif
#if defined(__GNUC__) && (__GNUC__ >= 2) // && defined(__OPTIMIZE__)
END
)

  code=$(cat <<END
replace_text=<<EOF
$replace_text
EOF
target_text='$target_text'

if \$.==$target_line and \$_.strip == target_text
 print replace_text
else
  print
end
END
)
  echo "$code" > tmp/disable_optimization.rb
  ruby -i -n tmp/disable_optimization.rb $target_file

  echo "[*] disable optimization...done"
}

download() {
  local url=$1
  local sha256=$2

  basename=`basename $url`
  destfile=download/`basename $url`

  printf "[*] download $basename..."
  if test -f $destfile && sha256sum $destfile | grep -q $sha256; then
    echo skip
    return
  fi

  wget -q --output-document=$destfile $url
  if ! sha256sum download/`basename $url` | grep -q $sha256; then
    echo "[E] fail to checksum $destfile"
    exit 1
  fi

  echo done
}

download_files() {
  download https://www.kernel.org/pub/linux/kernel/v2.6/linux-2.6.11.tar.xz \
  31b5cb6fcbdc079e635d9b93195375d0b836d503a15285fa406152e3f8366851

  download https://archive.debian.org/debian/pool/main/g/gcc-3.3/gcc-3.3_3.3.5-13_i386.deb \
  88799d7e6221c323a5131639f9505780d779946ea44e3a1172833b71d47aea87

  download https://archive.debian.org/debian/pool/main/g/gcc-3.3/cpp-3.3_3.3.5-13_i386.deb \
  4e73b2009535996ab3db4f335bafc03f581a2ef493956da7a5455940ae301598

  download https://archive.debian.org/debian/pool/main/b/binutils/binutils_2.15-6_i386.deb \
  f4a73c5ad1cba4c61b38bd83e6b0e493cc6a1a41d30bc010ae4969617d12bc9b

  download https://archive.debian.org/debian/pool/main/b/busybox/busybox-static_0.60.5-2.2_i386.deb \
  abf3d486b3106c4f4d93aa850e95e32d1d010976eb4bf3af6a20f2b2a755bfd3
}

install_debfiles() {
  printf "[*] install deb files..."
  if gcc33/usr/bin/gcc-3.3 --help &> /dev/null && \
     gcc33/usr/bin/cpp-3.3 --help &> /dev/null && \
     test -f gcc33/usr/bin/ld; then
    # echo skip; return
    # The installation isn't time-consuming and we will
    # add more deb files in the future.
    true
  fi
  
  for debfile in `echo download/*.deb`; do
    dpkg-deb -x $debfile gcc33
  done
  
  echo done
}

patchelf_add_rpath() {
  printf "[*] patchelf binutils..."
  if gcc33/usr/bin/ld -v &> /dev/null; then
    echo skip
    return
  fi

  for x in as ld ar nm strip objcopy objdump; do
    patchelf --add-rpath `realpath gcc33/usr/lib` gcc33/usr/bin/$x
    if ! gcc33/usr/bin/$x --help &> /dev/null; then
      echo "[E] fail to patchelf"
      exit 1
    fi
  done

  echo done
}

unpack_kernel_source() {
  printf "[*] unpack kernel source..."
  if test -f linux-2.6.11/Makefile; then
    echo skip
    return
  fi
  tar axf download/linux-2.6.11.tar.xz
  echo done
}

trap_error

mkdir -p download gcc33 gccwraps logs tmp

download_files
install_debfiles
patchelf_add_rpath
unpack_kernel_source

ccwrap=`realpath gccwraps/ccwrap`
hostccwrap=`realpath gccwraps/hostccwrap`
cross_compile=`realpath gcc33/usr/bin`

domake=`realpath gccwraps/domake`
domake_bear=`realpath gccwraps/domake_bear`
domake_log=`realpath logs/domake`
domake_bear_log=`realpath logs/domake_bear`
linux=`realpath linux-2.6.11`

arch=${1:-i386}

create_gccwraps
create_makehelpers
# exit 0

echo
echo "==== do_tinyconfig ===="
echo "[*] arch=$arch"

# fix drivers/media/dvb/b2c2/Makefile before `make mrproper`
patch_fix_wrong_makefile
patch_change_HZ_100
patch_disable_optimization

# make mrproper or git clean -df if Git was setup.
clean_kernel_source
do_tiny_config

for x in `grep =y config_tiny`; do
  if ! grep -q $x $linux/.config; then
    echo "[E] $x is not set in .config"
  fi
done

echo "========================"
# make $makeflags oldconfig
# bear -- make $makeflags
