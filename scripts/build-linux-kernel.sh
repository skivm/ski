#!/bin/bash

#!/bin/bash

#set -x
#set -v

error_msg(){
    echo "[BUILD-LINUX-KERNEL.SH] ERROR: $1"
    echo "[BUILD-LINUX-KERNEL.SH] ERROR: Exiting!!"
    exit 1
}

log_msg(){
    echo "[BUILD-LINUX-KERNEL.SH] $1"
}



SKI_DIR=${SKI_DIR-"$HOME/ski/"}


# SKI_KERNEL_PACKAGE_URL=
# SKI_KERNEL_PACKAGE_FILENAME=
# SKI_KERNEL_PATCH_FILENAME=
# SKI_KERNEL_CONFIG_FILENAME=
# SKI_KERNEL_TAGNAME=


MAKE_PARALLEL=16

if ! [[ $SKI_KERNEL_PACKAGE_URL =~ https?://.* ]] && ! [ -f "$SKI_KERNEL_PACKAGE_FILENAME" ]; then error_msg "SKI_KERNEL_PACKAGE_URL ($SKI_KERNEL_PACKAGE_URL) not a valid URL and SKI_KERNEL_PACKAGE_FILENAME ($SKI_KERNEL_PACKAGE_FILENAME) not a valid package filename" ; fi
if [ "$SKI_KERNEL_PATCH_FILENAME" != "" ] && ! [ -f $SKI_KERNEL_PATCH_FILENAME ]; then error_msg "SKI_KERNEL_PATCH_FILENAME should be empty (no patch applied) or a valid file. (SKI_KERNEL_PATCH_FILENAME = $SKI_KERNEL_PATCH_FILENAME)" ; fi
if [ "$SKI_KERNEL_CONFIG_FILENAME" != "" ] && ! [ -f $SKI_KERNEL_CONFIG_FILENAME ]; then error_msg "SKI_KERNEL_CONFIG_FILENAME should be empty (no patch applied) or a valid file. (SKI_KERNEL_CONFIG_FILENAME = $SKI_KERNEL_CONFIG_FILENAME)" ; fi
if [ "$SKI_KERNEL_TAGNAME" == "" ] ; then error_msg "Provide a tagname with SKI_KERNEL_TAGNAME"; fi
if [ "$SKI_KERNEL_OUTPUT_DIR" == "" ] ; then error_msg "Provide the output dir with SKI_KERNEL_OUTPUT_DIR"; fi



mkdir -p $SKI_KERNEL_OUTPUT_DIR
if ! [ -d $SKI_KERNEL_OUTPUT_DIR ] ; then error_msg "Unable to create the kernel output directory."; fi


TMP_DIRECTORY=$(mktemp -d --suffix=-${SKI_KERNEL_TAGNAME})
log_msg "Created temporary directory ($TMP_DIRECTORY)"
pushd $TMP_DIRECTORY

if [[ $SKI_KERNEL_PACKAGE_URL =~ https?://.* ]]
then
	################################
	# DOWNLOADING
	################################

	DOWNLOAD_DIR=${TMP_DIRECTORY}/download
	SKI_KERNEL_PACKAGE_FILENAME=${TMP_DIRECTORY}/download/$(basename $SKI_KERNEL_PACKAGE_URL)
	log_msg "Trying to download linux package from $SKI_KERNEL_PACKAGE_URL (to $SKI_KERNEL_PACKAGE_FILENAME)..."

	mkdir $DOWNLOAD_DIR || true
	pushd $DOWNLOAD_DIR


	wget $SKI_KERNEL_PACKAGE_URL
	RES=$?
	if [ $RES -ne 0 ]; then error_msg "WGET failed ($RES). Exiting..." ;  fi
	if ! [ -f $SKI_KERNEL_PACKAGE_FILENAME ] ; then error_msg "Unable to find downloaded file?!" ; fi  
	popd
else
	################################
	# USING FILE ON FS
	################################

	log_msg "Using package provided ($SKI_KERNEL_PACKAGE_FILENAME)"
fi



################################
# EXTRACTING KERNEL TAR
################################

EXTRACT_DIR=${TMP_DIRECTORY}/extract/
mkdir $EXTRACT_DIR || true 
log_msg "Trying to extract $SKI_KERNEL_PACKAGE_FILENAME to $EXTRACT_DIR"
pushd $EXTRACT_DIR


tar -xvf $SKI_KERNEL_PACKAGE_FILENAME
RES=$?
if [ $RES -ne 0 ]; then error_msg "Tar failed ($RES)" ; fi

pushd linux*
SOURCE_DIR=$(pwd)
popd
popd












################################
# PATCHING THE KERNEL MAKEFILE
################################

if [ -f ${SKI_KERNEL_PATCH_FILENAME} ]
then
	pushd $SOURCE_DIR

	# Patch created with:
	#  diff -u linux-2.6.28/Makefile linux-2.6.28-patched/Makefile  > optimization.patch
	patch --forward Makefile < ${SKI_KERNEL_PATCH_FILENAME}
	RES=$?
	#if [ $RES -ne 0 ]; then echo "ERROR: Makefile patch (to remove optimizations) failed ($RES). Exiting..." ; exit; fi

	popd
fi















################################
# CONFIG KERNEL
################################

INSTALL_STATIC_DIR_NAME="linux-${SKI_KERNEL_TAGNAME}-install-static"
INSTALL_STATIC_DIR=$TMP_DIRECTORY/$INSTALL_STATIC_DIR_NAME

mkdir ${INSTALL_DIR} || true
log_msg "Configuring the kernel"


pushd $SOURCE_DIR

if [ -f $SKI_KERNEL_CONFIG_FILENAME ]
then
	log_msg "Using oldconfig based on existing $SKI_KERNEL_CONFIG_FILENAME kernel config"    
    cp ${SKI_KERNEL_CONFIG_FILENAME} ./.config
    ls -l ./.config
	yes "" | make O=${INSTALL_STATIC_DIR} oldconfig ARCH=i386 | tee -a .oldconfig.output
    mv .config .config.used
else
	log_msg "Using default kernel config"    
	yes "" | make O=${INSTALL_STATIC_DIR} config ARCH=i386 | tee -a .newconfig.output
fi

popd








################################
# COMPILE THE KERNEL AND THE MODULES
################################

INSTALL_STATIC_MODULES_DIR_NAME="linux-${SKI_KERNEL_TAGNAME}-install-static_modules"
INSTALL_STATIC_MODULES_DIR="$TMP_DIRECTORY/$INSTALL_STATIC_MODULES_DIR_NAME"

LOG_STATIC_FILENAME="${TMP_DIRECTORY}/log/${SKI_KERNEL_TAGNAME}.log"
LOG_STATIC_MODULES_FILENAME="${TMP_DIRECTORY}/log/${SKI_KERNEL_TAGNAME}.modules.log"
mkdir ${TMP_DIRECTORY}/log || true


pushd $SOURCE_DIR

make -j ${MAKE_PARALLEL} O=${INSTALL_STATIC_DIR} ARCH=i386  2>&1 | tee  $LOG_STATIC_FILENAME
MAKE_RET=${PIPESTATUS[0]}
if [ ${MAKE_RET} -ne 0 ]; then error_msg "Kernel make failed ($MAKE_RET)"; fi


mkdir ${INSTALL_STATIC_MODULES_DIR} || true
make -j ${MAKE_PARALLEL} O=${INSTALL_STATIC_DIR} ARCH=i386 INSTALL_MOD_PATH=${INSTALL_STATIC_MODULES_DIR} modules_install  2>&1 | tee  ${LOG_STATIC_MODULES_FILENAME}
MAKE_RET=${PIPESTATUS[0]}
if [ ${MAKE_RET} -ne 0 ]; then error_msg "ERROR: Modules make failed ($MAKE_RET)"; fi


INSTALL_KERNEL_FILENAME=${INSTALL_STATIC_DIR}/arch/i386/boot/bzImage

popd



################################
# PREPARE TO TRANSFER MODULES
################################

FINAL_LIB_FILENAME="${SKI_KERNEL_OUTPUT_DIR}/${SKI_KERNEL_TAGNAME}_lib.tar.bz2"
cd ${INSTALL_STATIC_MODULES_DIR}
tar -cjvf ${FINAL_LIB_FILENAME} lib

FINAL_KERNEL_FILENAME="${SKI_KERNEL_OUTPUT_DIR}/${SKI_KERNEL_TAGNAME}_bzImage"

cp $INSTALL_KERNEL_FILENAME $FINAL_KERNEL_FILENAME
#XXX: Cp the config file too for the records

log_msg "*****************************************"
log_msg "FINAL_LIB_FILENAME = $FINAL_LIB_FILENAME"
log_msg "FINAL_KERNEL_FILENAME = $FINAL_KERNEL_FILENAME"
log_msg "*****************************************"
log_msg "Temporary files left in ${TMP_DIRECTORY}"
log_msg "*****************************************"







