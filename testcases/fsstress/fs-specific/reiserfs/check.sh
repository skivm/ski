#!/bin/bash

set -v
set -x


df 2>&1 | tr -t '\n' '\0' | xargs -0  -I '{}' -s 100000  /root/usermode/simple-app/debug " df: {}"

umount /dev/loop0
losetup -d /dev/loop0



# Run the checker
/root/usermode/simple-app/debug "Running the FS checker"
fsck.reiserfs -f -y /mnt/tmp/ramdisk.image 2>&1 | tr -t '\n' '\0' | xargs -0  -I '{}' -s 100000  /root/usermode/simple-app/debug " fsck: {}"

/root/usermode/simple-app/debug "Running uname"
UNAME="Uname: $(uname -a)"
/root/usermode/simple-app/debug "${UNAME}"

# Checksum of the disk
#/root/usermode/simple-app/debug "Calculating the checksums"
#CHECKSUM="MD5 Checksum: $(md5sum /mnt/tmp/ramdisk.image)"
#/root/usermode/simple-app/debug "${CHECKSUM}" 


