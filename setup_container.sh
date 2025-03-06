#!/usr/bin/bash

if which podman; then
  hash=`podman run --arch=i386 --personality=LINUX32 --detach --tty \
    --mount=type=bind,src=`pwd`,dst=/root/build_linux_2.6.11 \
    docker.io/library/debian:bookworm`
  
  podman exec $hash apt update
  podman exec $hash apt install bear make

fi