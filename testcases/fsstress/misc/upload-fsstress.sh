#!/bin/bash

SKI_DIR=${SKI_DIR-"$HOME/ski/"}

if ! [ -f "$SKI_DIR/config/id_dsa_vm" ] ; then error_msg "Unable to read the SSH private key for the VM ($SKI_DIR/config/id_dsa_vm)."; fi

scp -P $1 -i ${SKI_DIR}/config/id_dsa_vm -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null fsstress  empty root@localhost:/root/fsstress


