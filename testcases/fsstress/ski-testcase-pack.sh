#!/bin/bash


# Script executed on the host before packing and sending the testcase to the VM
# Should return 0 if sucessfull, otherwise the run-create-snapshot.sh aborts

pushd git-btrfs-progs/btrfs-progs
make
MAKE_RESULT=$?
if [ $MAKE_RESULT -ne 0 ] ; then exit $MAKE_RESULT; fi 
popd

make
MAKE_RESULT=$?
exit $MAKE_RESULT

