#!/bin/bash

# Uncomment when debugging the testcase script
#set -x
#set -v


# Update the affinity of the internal kernel threads
./misc/update-affinity.sh

# Set "max locked memory" to unlimited
ulimit -l unlimited
ulimit


FS_SPECIFIC_SETUP=./fs-specific/$FS_TEST/setup.sh
FS_SPECIFIC_DIR=./fs-specific/$FS_TEST/
if [ -x "$FS_SPECIFIC_SETUP" ] 
then
	echo "Executing the test specific setup.sh"
	pushd $FS_SPECIFIC_DIR
	./setup.sh
	popd
else
	echo "ERROR: Unable to find the test specific :"
fi

echo "** Current directories mounted:"
mount

echo "** Dump the last 20 lines of dmesg:"
dmesg | tail -n 20 

echo "** lsmod:"
lsmod

echo "** /proc/modules:"
cat /proc/modules


