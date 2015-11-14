#!/bin/bash


## PROBABLY NOT SUPPORTED BY THE KERNEL... (i.e. MOUNT WILL FAIL)
set -x
set -v

echo "Executing the setup specific to exFAT"

# wget http://backports.debian.org/debian-backports/pool/main/e/exfat-utils/exfat-utils_0.9.7-1~bpo60+1_i386.deb
dpkg -i exfat-utils_0.9.7-1~bpo60+1_i386.deb

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

mkfs.exfat -n LABEL ${LOOP_DEVICE}

mkdir $MOUNT_DIR
mount -t exfat ${LOOP_DEVICE} $MOUNT_DIR

