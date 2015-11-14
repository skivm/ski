#!/bin/bash


SKI_DIR=${SKI_DIR-"$HOME/ski/"}


error_msg(){
    echo [SSH-VM.SH] ERROR: $1
    echo [SSH-VM.SH] ERROR: Exiting!!
    exit 1
}

log_msg(){
    echo [SSH-VM.SH] $1
}


if ! [ -f "$SKI_DIR/config/id_dsa_vm" ] ; then error_msg "Unable to read the SSH private key for the VM ($SKI_DIR/config/id_dsa_vm)."; fi


SSH_OPTIONS="-i $SKI_DIR/config/id_dsa_vm -o StrictHostKeyChecking=no  -o UserKnownHostsFile=/dev/null"
SSH_DESTINATION="root@localhost"
VMM_SSH_LOCAL_PORT=10001


ssh -p ${VMM_SSH_LOCAL_PORT} ${SSH_OPTIONS} ${SSH_DESTINATION}



