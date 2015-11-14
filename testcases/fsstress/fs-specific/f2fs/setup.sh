#!/bin/bash

set -x
set -v

echo "Executing the setup specific to f2fs"

# https://packages.debian.org/sid/f2fs-tools
dpkg -i f2fs-tools_1.2.0-1_i386.deb f2fs-tools-dbg_1.2.0-1_i386.deb

export LD_LIBRARY_PATH="/usr/lib/i386-linux-gnu/"

MOUNT_DIR=/mnt/dir
RAMDISK_FILENAME=/mnt/tmp/ramdisk.image
LOOP_DEVICE=/dev/loop0

RAMFS_DIR=/mnt/tmp


## Mount ramfs
mkdir -p ${RAMFS_DIR}
mount -t ramfs -o size=350m ramfs ${RAMFS_DIR}

## For loop device on ramdisk (for bigger)
touch ${RAMDISK_FILENAME}
dd if=/dev/zero of=${RAMDISK_FILENAME} count=600k
losetup ${LOOP_DEVICE} ${RAMDISK_FILENAME}
mkfs.f2fs ${LOOP_DEVICE}

mkdir $MOUNT_DIR
mount -t f2fs ${LOOP_DEVICE} $MOUNT_DIR
mount
