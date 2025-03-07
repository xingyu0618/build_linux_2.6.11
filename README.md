A script used to build Linux kernel 2.6.11.

### Why bother building such an old kernel?

Kernel 2.6.11 is used in the book UTLK, Understanding the Linux Kernel 2rd edition. 

I find it easier to read when using the same version as the author.

Kernel 2.6.11 was released in 2005, though two decades old,
in fact a quite full-fledge kernel, and it's easier to understand
than newer kernel.

### How to built it

Kernel 2.6.11 was released in 2005. So we need to find a Linux Distro
that released in that year.
What I found was Debian Sarge(Debian 3.1) which released in 2005-06-06. 
And luckily there's a Docker image of it.

https://hub.docker.com/layers/debian/eol/sarge/images/sha256-1eb2cc32d515e6292ef3c0d37006cdba1004c7c3d4633946fe9fe9e6bc6bb4ad

```
# Run in container, docker or podman, I use podman.
# Because this old distro does not support https,
# download linux-2.6.11.tar.gz in host machine, then copy it into then container
# https://www.kernel.org/pub/linux/kernel/v2.6/linux-2.6.11.tar.gz
apt-get update
apt-get install gcc binutils make libc6-dev
cd /root
tar zxvf linux-2.6.11.tar.gz
cd linux-2.6.11
make ARCH=i386 defconfig
make ARCH=i386 -j$number_of_cpus
```

It's quite fast to build this old kernel in modern hardwares.

### generate compile_commands.json

Though successfully built it, our goal is to read the code, understand the code.
I find clangd+vscode are awesome tools to read large project written in C.

To use clangd to index source code, you have to generate compile_commands.json,
a file containing compiler flags like -D, -I, 
which is crucial for tools like clangd to correctly index the whole project.

Modern build tools like CMake can generate it with -DCMAKE_COMPILE_COMMANDS. 
But kernel usea GNU Make. Luckily there's tool like bear,
which can intercept calls to cc1 and generate compile_commands.json.

But there's no package of bear in old distros like Debian Sarge.
Old 32-bit softwares can run in modern Linux Distro, 
because Linux kernel supports 32-bit emulation, which is provided by most of Linux Distros, 
but you need install a 32-bit glibc first, which is also provided by most distros, 
in Arch Linux, it's lib32-glibc.

So we need detour to a bit to see how to run old 32-bit gcc in modern
64-bit machine.

### tweak old gcc to work in modern Linux

In the previous successed built, the toolchain used is
```
gcc 3.3.5
binutils 2.15
```

You can download them manually via archive.debian.org

```
https://archive.debian.org/debian/pool/main/g/gcc-3.3/gcc-3.3_3.3.5-13_i386.deb
https://archive.debian.org/debian/pool/main/g/gcc-3.3/cpp-3.3_3.3.5-13_i386.deb
https://archive.debian.org/debian/pool/main/b/binutils/binutils_2.15-6_i386.deb
```

Then install them into a folder, like gcc33

```
dpkg-deb -x gcc-3.3_3.3.5-13_i386.deb gcc33
```

Try to call `gcc33/usr/bin/gcc --help` to see whether it works.
gcc-3.3 will execute successful because it uses no external shlibs but
libc6.so.

But binutils, like ld, does not work out of box, because it uses shlib called `libbfd-2.15.so`,
which can be found in gcc33/usr/lib.

A quick fix is to call it like `LD_LIBRARY_PATH=gcc33/usr/lib gcc33/usr/bin/ld`.

But a more elegant fix is to use patchelf to add rpath into executable.

`patchelf --add-rpath $(realpath gcc33/usr/lib) gcc33/usr/bin/ld`.

GCC in fact isn't a compiler, but a driver, which coordinates
cpp, cc1, as and ld.

By default gcc uses as and ld from known path, such as
/usr/bin/as, /usr/bin/ld.

Newer version of binutils cannot compile kernel 2.6.11.

Specifically because newer GNU assembler fails to compile some inline
assembly code in kernel 2.6.11, which fixed in later kernel version.
See https://www.kernel.org/pub/linux/kernel/people/akpm/patches/2.6/2.6.12-rc1/2.6.12-rc1-mm4/broken-out/i386-x86_64-segment-register-access-update.patch

Luckily gcc has an option -B which forces gcc to use binutils in other
folder first.

So we can create a file called ccwrap

```
#!/bin/bash
exec gcc33/usr/bin/gcc-3.3 -B gcc33/usr/bin/ "$@"
```

then `make ARCH=i386 CC=./ccwrap`

### use bear to generate compile_commands.json

bear works by using PRELOAD provided by glibc.
By using PRELOAD, you can run a shlib even before glibc
being loaded by dynamic linker.
So you can hook execve(3).

bear provided by distro works for 64-bit only.
So it cannot intercept execve(3) of 32-bit programs,
because they use 32-bit libc.

So we need a newer 32-bit Linux Distro which provides
32-bit bear. I use 32-bit Debian Bookworm here.

Also I use podman here. By using bind-mount, we can use
what we have done by now.

```
podman run -it --arch i386 --personality=LINUX32 \
--mount=type=bind,src=$srcpath,dst=/root/$dstpath \
docker.io/debian/bookworm

apt update
apt install gcc bear make

cd /root/build_linux_2.6.11/linux-2.6.11
make ARCH=i386 CC=./ccwrap
```

### How to build a super-mini kernel
Already implemented. Documentation TODO.

### How to disable compile optimization
Already implemented. Documentation TODO.