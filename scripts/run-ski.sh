#!/bin/bash


## Default directories values: update or override them ##
SKI_TMP=${SKI_TMP-"/dev/shm/ski-user/tmp/"}
SKI_DIR=${SKI_DIR-"$HOME/ski/"}


VMM_BINARY=$SKI_DIR/vmm-install/bin/qemu-system-i386
VMM_RAM_MB=512
VMM_CPUS=4
VMM_BOOTLOADER_LINUX_APPEND="root=/dev/hda1 rootfstype=ext4 rw -verbose console=tty0 console=ttyS0"
VMM_MISC_OPTIONS="-rtc base=utc,clock=vm -qmp tcp:localhost:10000,server,nowait -net nic -net user,hostfwd=tcp::10001-:22 -vnc :1"

VMM_SKI_ARGS="-ski 0,input_number=210:210,preemptions=119:97"


error_msg(){
	echo [RUN-SKI.SH] ERROR: $1
	echo [RUN-SKI.SH] ERROR: exiting!
	exit 1
}

log_msg(){
	echo [RUN-SKI.SH] $1
}

if ! [ -x $VMM_BINARY ] ; then error_msg "Unable to find the binary at $VMM_BINARY. Make sure that SKI_DIR is correctly defined."; fi
if [ -z "$SKI_VM_FILENAME" ] || ! [ -f "$SKI_VM_FILENAME" ] ; then  error_msg "Need to set SKI_VM_FILENAME to a valid snapshot"; fi
if ! [ -d "$SKI_OUTPUT_DIR" ] ; then  mkdir $SKI_OUTPUT_DIR || error_msg "Need create the output directory (SKI_OUTPUT_DIR=$SKI_OUTPUT_DIR)."; fi

log_msg "Checking if there are other qemu instances running..."
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


# Running concurrent test by resuming from a snapshot

VMM_SNAPSHOT=ski-vm-XXX 
VMM_HDA_FILENAME=$SKI_TMP/tmp.$$.img
VMM_SERIAL_FILENAME=file:$SKI_OUTPUT_DIR/console.txt

mkdir -p $SKI_TMP
log_msg "Copying the VM image to tmp" 
cp $SKI_VM_FILENAME $VMM_HDA_FILENAME || error_msg "Unable to copy the VM image to the temporary directory (SKI_TMP=$SKI_TMP)!"


# Parameters that are expected to be provided by the user to SKI (e.g., when calling ./run-ski.sh)
# SKI_INPUT1_RANGE=1-25 
# SKI_INPUT2_RANGE=+0-1 
# SKI_INTERLEAVING_RANGE=1-200 
# SKI_FORKALL_CONCURRENCY=1 
# SKI_RACE_DETECTOR_ENABLED=1
# SKI_TRACE_INSTRUCTIONS_ENABLED=1 
# SKI_TRACE_MEMORY_ACCESSES_ENABLED=1
# SKI_KERNEL_FILENAME=/dev/shm/ski-user/kernels/3.13.5-fs-static2_bzImage 
# SKI_VM_FILENAME=/dev/shm/ski-user/snapshots/test40-ext4/vm-image.img
# SKI_OUTPUT_DIR=/local/ski-user/ski/results/test40-ext4/

# Other SKI parameters
export SKI_RESCHEDULE_POINTS=1
export SKI_RESCHEDULE_K=1
export SKI_FORKALL_ENABLED=1
export SKI_WATCHDOG_SECONDS=300
export SKI_QUIT_HYPERCALL_THRESHOLD=1
export SKI_OUTPUT_DIR_PER_INPUT_ENABLED=1
export SKI_DEBUG_START_SLEEP_ENABLED=0
export SKI_DEBUG_CHILD_START_SLEEP_SECONDS=1
export SKI_DEBUG_CHILD_WAIT_START_SECONDS=0
export SKI_DEBUG_PARENT_EXECUTES_ENABLED=0
export SKI_DEBUG_EXIT_AFTER_HYPERCALL_ENABLED=0
export SKI_MEMFS_ENABLED=1
export SKI_MEMFS_TEST_MODE_ENABLED=0
export SKI_MEMFS_LOG_LEVEL=1
export SKI_PRIORITIES_FILENAME=${SKI_DIR}/config/fsstress.priorities
#export SKI_IPFILTER_FILENAME=

log_msg "Running command"
#gdb -ex "set follow-fork-mode child" --args 
$VMM_BINARY -m $VMM_RAM_MB -smp $VMM_CPUS -loadvm $VMM_SNAPSHOT -kernel $SKI_KERNEL_FILENAME -hda $VMM_HDA_FILENAME -serial $VMM_SERIAL_FILENAME $VMM_MISC_OPTIONS $VMM_SKI_ARGS 


log_msg "Removing the VM image in tmp.."
rm $VMM_HDA_FILENAME

