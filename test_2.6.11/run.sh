#!/usr/bin/bash

set -eu -o pipefail

# compile setsid.c in Debian Sarge
__compile_setsid_sarge() {
  podman cp utils/setsid.c sarge:/root
  podman exec -w /root sarge gcc-3.3 -static -o setsid setsid.c
  podman cp sarge:/root/setsid $initramfs/binx/setsid_sarge
}

__compile_setsid() {
  podman exec -w /trykernel/test_2.6.11 bookworm \
    musl-gcc -static -o $initramfs/binx/setsid_musl \
    setsid.c
}

make_initramfs() {
  rm -rf $initramfs
  mkdir -p $initramfs/bin
  mkdir -p $initramfs/binx

  __compile_setsid

  podman cp sarge:/bin/busybox $initramfs/binx/busybox_sarge           # v0.60.5

  ln -s /binx/busybox_sarge $initramfs/bin/sh
  __make_busybox_initrc

  # pack folder initrf into initrf.cpio
  cd $initramfs
  find | cpio -v -o -H newc > $initramfs_cpio
  cd -

  # unpack initramfs.cpio to check whether we've done right.
  rm -rf $initramfs_unpack
  mkdir $initramfs_unpack
  cd $initramfs_unpack
  cpio -i -v < $initramfs_cpio
  cd -
}

__make_busybox_initrc() {
  cat > $initramfs/init <<END
#!/bin/sh

echo "=== init ==="
mkdir -p /dev

mknod /dev/ttyS0 c 4 64

# /binx/setsid_sarge
/binx/setsid_musl
END

  chmod +x $initramfs/init

  cat > $initramfs/initrc <<END
echo "=== initrc of busybox ==="

mkdir -p /proc /dev

mount -t proc proc /proc
mount -t devfs dev /dev

mknod /dev/hda b 3 0
# mkdir /ext2
# mount -t ext2 /dev/hda /ext2
END
}

initramfs=initramfs.d
initramfs_unpack=initramfs.unpack
initramfs_cpio=tmp/initramfs.cpio
bzImage=/trykernel/cleanbuild/linux-2.6.11/arch/i386/boot/bzImage

mkdir tmp

make_initramfs

# exit 0

#dd if=/dev/zero of=imgx bs=10M count=1
#loopdev=`sudo losetup -f --show imgx`
#sudo mke2fs -t ext3 $loopdev

diskdrive="-drive if=ide,file=ext2.qcow2"
debug="-s"

debug=
diskdrive=

qemu-system-i386 -m 4G -accel kvm \
-kernel $bzImage -initrd $initramfs_cpio \
-append 'console=ttyS0 norandmaps' \
-nographic \
$diskdrive \
$debug
