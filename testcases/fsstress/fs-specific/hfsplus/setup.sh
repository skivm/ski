#!/bin/bash

set -x
set -v

echo "Executing the setup specific to hfsplus"

#  Install/download packages to mkfs (dpkg -i ... or apt-get install)
apt-get install hfsprogs

MOUNT_DIR=/mnt/dir

######################
## For loop device
######################

RAMDISK_FILENAME=/mnt/tmp/ramdisk.image
LOOP_DEVICE=/dev/loop0

RAMFS_DIR=/mnt/tmp


# Mount ramfs
mkdir -p ${RAMFS_DIR}
mount -t ramfs -o size=350m ramfs ${RAMFS_DIR}

# For loop device on ramdisk (for bigger)
touch ${RAMDISK_FILENAME}
dd if=/dev/zero of=${RAMDISK_FILENAME} count=600k
losetup ${LOOP_DEVICE} ${RAMDISK_FILENAME}
mkfs.hfsplus ${LOOP_DEVICE}

mkdir $MOUNT_DIR
mount -t hfsplus ${LOOP_DEVICE} $MOUNT_DIR
mount


######################
## For physical HD
######################

#PHY_DEVICE="/dev/hda5"
#swapoff ${PHY_DEVICE}
#mkfs.hfplus --non-interactive ${PHY_DEVICE}

#mkdir $MOUNT_DIR
#mount -t hfsplus ${PHY_DEVICE} $MOUNT_DIR
#mount
~                   
