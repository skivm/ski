#!/bin/bash


##################################################################################
############                     CREATE SNAPSHOT                       ###########
##################################################################################

## Default directories values: update or override them ##
SKI_TMP=${SKI_TMP-"/dev/shm/ski-user/tmp/"}
SKI_DIR=${SKI_DIR-"$HOME/ski/"}


error_msg(){
	echo "[RUN-SKI-CREATE-SNAPSHOT.SH] ERROR: $1"
	echo "[RUN-SKI-CREATE-SNAPSHOT.SH] ERROR: Exiting!!"
	exit 1
}

log_msg(){
	echo "[RUN-SKI-CREATE-SNAPSHOT.SH] $1"
}

# Used by the load-testsuit.sh to ssh into the client
export SKI_VMM_SSH_LOCAL_PORT=10001

VMM_BINARY=$SKI_DIR/vmm-install/bin/qemu-system-i386
VMM_RAM_MB=512
VMM_CPUS=4
VMM_BOOTLOADER_LINUX_APPEND="root=/dev/hda1 rootfstype=ext4 rw -verbose console=tty0 console=ttyS0"
VMM_MISC_OPTIONS="-rtc base=utc,clock=vm -qmp tcp:localhost:10000,server,nowait -net nic -net user,hostfwd=tcp::$SKI_VMM_SSH_LOCAL_PORT-:22 -vnc :1"
VMM_SKI_ARGS="-ski 0,input_number=210:210,preemptions=119:97"
LOADTESTSUIT_SCRIPT=$SKI_DIR/scripts/load-testsuit.sh

RUN_SCRIPT=ski-testcase-run.sh
PACK_SCRIPT=ski-testcase-pack.sh
TESTCASE_PACKAGE_BASEDIR="`basename $SKI_TESTCASE_DIR`"
TESTCASE_PACKAGE_FILENAME=$TESTCASE_PACKAGE_BASEDIR.tgz
TESTCASE_PACKAGE_RESULT_FILENAME=${TESTCASE_PACKAGE_BASEDIR}_result.tgz

if ! [ -x $VMM_BINARY ] ; then error_msg "Unable to find the binary at $VMM_BINARY. Make sure that SKI_DIR is correctly defined (SKI_DIR=$SKI_DIR)."; fi
if [ -z "$SKI_VM_FILENAME" ] || ! [ -f "$SKI_VM_FILENAME" ] ; then  error_msg "Need to set SKI_VM_FILENAME to a valid VM image (SKI_VM_FILENAME=$SKI_VM_FILENAME)"; fi
if ! [ -d "$SKI_OUTPUT_DIR" ] ; then  mkdir $SKI_OUTPUT_DIR || error_msg "Need create the output directory (SKI_OUTPUT_DIR=$SKI_OUTPUT_DIR)."; fi
if ! [ -d "$SKI_TESTCASE_DIR" ] ; then error_msg "Unable to read the testcase directory (SKI_TESTCASE_DIR = $SKI_TESTCASE_DIR)."; fi
if ! [ -x "$SKI_TESTCASE_DIR/$RUN_SCRIPT" ] ; then error_msg "Unable to find the executable run script in the testcase directory ($SKI_TESTCASE_DIR/$RUN_SCRIPT)."; fi
if ! [ -x "$SKI_TESTCASE_DIR/$PACK_SCRIPT" ] ; then error_msg "Unable to find the executable pack script in the testcase directory ($SKI_TESTCASE_DIR/$PACK_SCRIPT)."; fi
if [ -z $TESTCASE_PACKAGE_BASEDIR ] || [[ "$TESTCASE_PACKAGE_BASEDIR" == *"/"* ]] ; then error_msg "Invalid package filename  ($TESTCASE_PACKAGE_BASEDIR)."; fi
if ! [ -x $LOADTESTSUIT_SCRIPT ] ; then error_msg "Unable to find load-testsuit.sh ($LOADTESTSUIT_SCRIPT)" ; fi


log_msg "Running the testcase packing script ($SKI_TESTCASE_DIR/$PACK_SCRIPT)..." > /dev/null
pushd $SKI_TESTCASE_DIR/ > /dev/null
./$PACK_SCRIPT
PACK_RESULT=$?
if [ $PACK_RESULT -ne 0 ]; then error_msg "Unable to sucessfully run the pack script ($SKI_TESTCASE_DIR/$PACK_SCRIPT)"; fi
popd > /dev/null

log_msg "Creating the testcase package..."
pushd $SKI_TESTCASE_DIR/.. > /dev/null
if [ -f $TESTCASE_PACKAGE_FILENAME ] ; then rm $TESTCASE_PACKAGE_FILENAME; log_msg "Deleted the existing testcase package file";  fi
log_msg "Packing directory $TESTCASE_PACKAGE_BASEDIR into archive $TESTCASE_PACKAGE_FILENAME..."
tar --totals -czf $TESTCASE_PACKAGE_FILENAME $TESTCASE_PACKAGE_BASEDIR > /dev/null
TAR_RESULT=$?
if [ $TAR_RESULT -ne 0 ]; then error_msg "Unable to create the testcase package tar file"; fi
ls -l $TESTCASE_PACKAGE_FILENAME
TESTCASE_PACKAGE_PATH=`pwd`/$TESTCASE_PACKAGE_FILENAME
popd > /dev/null
echo_log " -> Created the testcase package: $TESTCASE_PACKAGE_PATH "




log_msg "Checking if there are other QEMU instances running..."
ps -All -f | grep qemu
log_msg "Killing other instances of SKI..."
killall -9 qemu-system-i386
export
log_msg "Sleeping for a few seconds..."
sleep 3


# TODO: Misc: Ensure that this is sufficient to get the coredumps, 
# Enable core dumps
ulimit -c unlimited
ulimit -a
# Note that coredumps can be extremely large, specially if not filtered because of the large address space
# echo 21 > /proc/self/coredump_filter


VMM_HDA_FILENAME=$SKI_TMP/tmp.$$.img
VMM_SERIAL_FILENAME=file:$SKI_OUTPUT_DIR/console.txt

mkdir -p $SKI_TMP
log_msg "Copying the VM image to tmp" 
cp $SKI_VM_FILENAME $VMM_HDA_FILENAME || error_msg "Unable to copy the VM image to the temporary directory (SKI_TMP=$SKI_TMP)!"


# Parameters that are expected to be provided by the user to SKI (e.g., when calling ./run-ski.sh)
# SKI_TRACE_INSTRUCTIONS_ENABLED=1 
# SKI_TRACE_MEMORY_ACCESSES_ENABLED=1
# SKI_KERNEL_FILENAME=/dev/shm/ski-user/kernels/3.13.5-fs-static2_bzImage 
# SKI_VM_FILENAME=/dev/shm/ski-user/snapshots/test40-ext4/vm-image.img
# SKI_OUTPUT_DIR=/local/ski-user/ski/results/test40-ext4/

# Other SKI parameters
export SKI_INPUT1_RANGE=1-1 
export SKI_INPUT2_RANGE=1-1 
export SKI_INTERLEAVING_RANGE=1-200 
export SKI_FORKALL_CONCURRENCY=1 
export SKI_RACE_DETECTOR_ENABLED=0
export SKI_RESCHEDULE_POINTS=1
export SKI_RESCHEDULE_K=1
export SKI_FORKALL_ENABLED=0
export SKI_WATCHDOG_SECONDS=300
export SKI_QUIT_HYPERCALL_THRESHOLD=1
export SKI_OUTPUT_DIR_PER_INPUT_ENABLED=1
export SKI_DEBUG_START_SLEEP_ENABLED=0
export SKI_DEBUG_CHILD_START_SLEEP_SECONDS=1
export SKI_DEBUG_CHILD_WAIT_START_SECONDS=0
export SKI_DEBUG_PARENT_EXECUTES_ENABLED=0
export SKI_DEBUG_EXIT_AFTER_HYPERCALL_ENABLED=0
export SKI_MEMFS_ENABLED=0
export SKI_MEMFS_TEST_MODE_ENABLED=0
export SKI_MEMFS_LOG_LEVEL=1
export SKI_PRIORITIES_FILENAME=$SKI_DIR/config/fsstress.priorities
#export SKI_IPFILTER_FILENAME=

# XXX: This applies for linux case; for other OSs QEMU is not so convenient so need to modify the VM image to change kernel options
export SKI_APPEND_COMMAND=root="/dev/hda1 rootfstype=ext4 rw -verbose console=tty0 console=ttyS0"


log_msg "Running SKI process in the background"
#gdb -ex "set follow-fork-mode child" --args 
$VMM_BINARY -m "$VMM_RAM_MB" -smp "$VMM_CPUS" -kernel "$SKI_KERNEL_FILENAME" -append "$SKI_APPEND_COMMAND" -hda "$VMM_HDA_FILENAME" -serial "$VMM_SERIAL_FILENAME" $VMM_MISC_OPTIONS $VMM_SKI_ARGS & 
# Save the QEMU PID for the testsuit loader
export SKI_VMM_PID=$!

# Lunch the testsuit loader
log_msg "Spawning in the background the testsuit loader..."
$LOADTESTSUIT_SCRIPT & 

# Wait for QEMU to finish
log_msg "Waiting for QEMU to finish"
wait $SKI_VMM_PID
# TODO: Implement a return signal for sucessful snapshot production
# TODO: Figure out if it was a sucess here 

log_msg "Copying the final VM image..."
cp $VMM_HDA_FILENAME $SKI_OUTPUT_DIR/vm-image.img
log_msg "*********************************************************************************************************"
log_msg "** If message \"[SKI] Successfully wrote snapshot!!\" was displayed then snapshot was created successfuly"
log_msg "** and the VM image with the snapshot is stored in $SKI_OUTPUT_DIR/vm-image.img"
log_msg "*********************************************************************************************************"

# TODO:
log_msg "Removing the VM image in tmp.."
rm $VMM_HDA_FILENAME

