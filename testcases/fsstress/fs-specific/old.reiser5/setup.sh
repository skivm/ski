#!/bin/bash

set -x
set -v

echo "Executing the setup specific to reiser4"

# Install/download packages to mkfs (dpkg -i ... or apt-get install)
apt-get install reiser4progs

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
mkfs.reiser4 ${LOOP_DEVICE}

mkdir $MOUNT_DIR
mount -t reiser4 ${LOOP_DEVICE} $MOUNT_DIR
mount
