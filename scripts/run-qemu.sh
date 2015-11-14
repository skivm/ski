#!/bin/bash


##################################################################################
############                     CREATE SNAPSHOT                       ###########
##################################################################################

SKI_DIR=${SKI_DIR-"$HOME/ski/"}

error_msg(){
	echo "[RUN-QEMU.SH] ERROR: $1"
	echo "[RUN-QEMU.SH] ERROR: Exiting!!"
	exit 1
}

log_msg(){
	echo "[RUN-QEMU.SH] $1"
}

SKI_VMM_SSH_LOCAL_PORT=10001
VMM_BINARY=$SKI_DIR/vmm-install/bin/qemu-system-i386
VMM_RAM_MB=512
VMM_CPUS=4
VMM_MISC_OPTIONS="-rtc base=utc,clock=vm -qmp tcp:localhost:10000,server,nowait -net nic -net user,hostfwd=tcp::$SKI_VMM_SSH_LOCAL_PORT-:22 -vnc :1"
VMM_SKI_ARGS="-ski 0,input_number=210:210,preemptions=119:97"

if ! [ -x $VMM_BINARY ] ; then error_msg "Unable to find the binary at $VMM_BINARY. Make sure that SKI_DIR is correctly defined (SKI_DIR=$SKI_DIR)."; fi
if [ -z "$SKI_VM_FILENAME" ] || ! [ -f "$SKI_VM_FILENAME" ] ; then  error_msg "Need to set SKI_VM_FILENAME to a valid VM image (SKI_VM_FILENAME=$SKI_VM_FILENAME)"; fi
if ! [ -d "$SKI_OUTPUT_DIR" ] ; then  mkdir $SKI_OUTPUT_DIR || error_msg "Need create the output directory (SKI_OUTPUT_DIR=$SKI_OUTPUT_DIR)."; fi



log_msg "Checking if there are other QEMU instances running..."
ps -All -f | grep qemu
log_msg "Killing other instances of QEMU..."
killall -9 qemu-system-i386
export
log_msg "==============================================================="
log_msg "Going to modify $SKI_VM_FILENAME. Waiting for a few seconds..."
sleep 10


# TODO: Misc: Ensure that this is sufficient to get the coredumps, 
# Enable core dumps
ulimit -c unlimited
ulimit -a
# Note that coredumps can be extremely large, specially if not filtered because of the large address space
# echo 21 > /proc/self/coredump_filter


VMM_SERIAL_FILENAME=file:$SKI_OUTPUT_DIR/console.txt

log_msg "Operating on VM image $SKI_VM_FILENAME" 
VMM_HDA_FILENAME=$SKI_VM_FILENAME 


# Parameters that are expected to be provided by the user to SKI (e.g., when calling ./run-qemu.sh)
# SKI_KERNEL_FILENAME=/dev/shm/ski-user/kernels/3.13.5-fs-static2_bzImage 
# SKI_VM_FILENAME=/dev/shm/ski-user/snapshots/test40-ext4/vm-image.img
# SKI_OUTPUT_DIR=/local/ski-user/ski/results/test40-ext4/

# Other SKI parameters
export SKI_TRACE_INSTRUCTIONS_ENABLED=0
export SKI_TRACE_MEMORY_ACCESSES_ENABLED=0
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
export SKI_PRIORITIES_FILENAME=${SKI_DIR}/config/fsstress.priorities
#export SKI_IPFILTER_FILENAME=

# XXX: This applies for linux case; for other OSs QEMU is not so convenient so need to modify the VM image to change kernel options
export SKI_APPEND_COMMAND=root="/dev/hda1 rootfstype=ext4 rw -verbose console=tty0 console=ttyS0"

log_msg "==============================================================="
log_msg "Waiting for VM to boot..."
log_msg " ...to get booting information run: tail -f $VMM_SERIAL_FILENAME"
log_msg " ...or use VNC: vncviewer :1"
log_msg "==============================================================="


log_msg "Running QEMU process in the foreground"
#gdb -ex "set follow-fork-mode child" --args 
$VMM_BINARY -m "$VMM_RAM_MB" -smp "$VMM_CPUS" -kernel "$SKI_KERNEL_FILENAME" -append "$SKI_APPEND_COMMAND" -hda "$VMM_HDA_FILENAME" -serial "$VMM_SERIAL_FILENAME" $VMM_MISC_OPTIONS $VMM_SKI_ARGS 

log_msg "Modified image: $VMM_HDA_FILENAME"

