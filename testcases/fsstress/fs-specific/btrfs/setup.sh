#!/bin/bash

set -x
set -v


apt-get install btrfs-tools

MOUNT_DIR=/mnt/dir
RAMDISK_FILENAME=/mnt/tmp/ramdisk.image
LOOP_DEVICE=/dev/loop0

SECONDARY_RAMDISK_FILENAME=/mnt/tmp/ramdisk1.image
SECONDARY_LOOP_DEVICE=/dev/loop1

RAMFS_DIR=/mnt/tmp


## Mount ramfs
mkdir -p ${RAMFS_DIR}
mount -t ramfs -o size=350m ramfs ${RAMFS_DIR}

## For loop device on ramdisk (for bigger)
touch ${RAMDISK_FILENAME}
dd if=/dev/zero of=${RAMDISK_FILENAME} count=600k
#dd if=/dev/zero of=${RAMDISK_FILENAME} count=512k
losetup ${LOOP_DEVICE} ${RAMDISK_FILENAME}
#mke2fs -b 1024 ${LOOP_DEVICE}
mkfs.btrfs -m single ${LOOP_DEVICE}
btrfs filesystem show ${LOOP_DEVICE}

mkdir $MOUNT_DIR
mount ${LOOP_DEVICE} $MOUNT_DIR


echo "** Creating the secondary device:"
touch ${SECONDARY_RAMDISK_FILENAME}
dd if=/dev/zero of=${SECONDARY_RAMDISK_FILENAME} count=50k
losetup ${SECONDARY_LOOP_DEVICE} ${SECONDARY_RAMDISK_FILENAME}


#/root/usermode/simple-app/debug "Waiting for user intervention (kill the read process insed the VM)!!"
#sleep 1000000
#/root/usermode/simple-app/debug "Finished waiting"
