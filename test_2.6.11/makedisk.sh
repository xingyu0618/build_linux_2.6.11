#!/usr/bin/bash

mkdir -p tmp/empty

virt-make-fs --format=qcow2 --type=ext2 --size=+200M tmp/empty ext2.qcow2
