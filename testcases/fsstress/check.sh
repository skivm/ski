#!/bin/bash

set -v
set -x

MY_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

FS_SPECIFIC_CHECK=${MY_DIR}/./fs-specific/$FS_TEST/check.sh
FS_SPECIFIC_DIR=${MY_DIR}/./fs-specific/$FS_TEST/

if [ -x "$FS_SPECIFIC_CHECK" ]
then
    echo "Executing the test specific check.sh"
    pushd $FS_SPECIFIC_DIR
    ./check.sh
    popd
else
    echo "ERROR: Unable to find the test specific check.sh"
fi



