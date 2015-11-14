#!/bin/bash

LOOP_DEVICE=/dev/loop0
RAMFS_DIR=/mnt/tmp

umount ${LOOP_DEVICE} 
losetup -d ${LOOP_DEVICE} 
umount ${RAMFS_DIR}

