#!/bin/bash
# Copyright (c) 2022, XMOS Ltd, All rights reserved
set -e # exit on first error
set -x # echo on

# help text
help()
{
   echo "XCORE-VOICE Device Firmware Update (DFU) Test"
   echo
   echo "Syntax: check_dfu.sh [-h] adapterID"
   echo 
   echo "Options:"
   echo "   h     Print this Help."
}

# flag arguments
while getopts h option
do
    case "${option}" in
        h) help
           exit;;
    esac
done

# assign vars
FIRMWARE="dist/test_ffva_dfu.xe"
DATA_PARTITION="dist/example_ffva_ua_adec_altarch_data_partition.bin"
OUTPUT_DIR=test/device_firmware_update/test_output
if [ ! -z "${@:$OPTIND:1}" ]
then
    ADAPTER_ID="--adapter-id ${@:$OPTIND:1}"
fi

# discern repository root
SLN_VOICE_ROOT=$(git rev-parse --show-toplevel)
source "${SLN_VOICE_ROOT}"/tools/ci/helper_functions.sh

# xflash erase
xflash ${ADAPTER_ID} --erase-all --target-file "${SLN_VOICE_ROOT}"/examples/ffd/bsp_config/XK_VOICE_L71/XK_VOICE_L71.xn

# reset board
xgdb -batch -ex "connect ${ADAPTER_ID} --reset-to-mode-pins" -ex detach

# flash the data partition
# build_tests.sh creates example_ffva_ua_adec_data_partition.bin used here
xflash ${ADAPTER_ID} --quad-spi-clock 50MHz --factory ${FIRMWARE} --boot-partition-size 0x100000 --data ${DATA_PARTITION}

# wait for device to reset (may not be necessary)
sleep 3

# strip path and .xe from firmware
FIRMWARE_NAME="${FIRMWARE#*dist/}"
FIRMWARE_NAME="${FIRMWARE_NAME%%.*}"
echo "${FIRMWARE_NAME}"

# remove any previous images
rm -rf "${OUTPUT_DIR}"
mkdir "${OUTPUT_DIR}"

# get the tools version numbers for xflash
export_tools_version

# create the upgrade firmware
xflash ${ADAPTER_ID} --factory-version ${XTC_VERSION_MAJOR}.${XTC_VERSION_MINOR} --upgrade 0 ${FIRMWARE} -o ${OUTPUT_DIR}/${FIRMWARE_NAME}_upgrade.bin

# write the upgrade image
dfu-util -e -d ,20b1:4001 -a 1 -D ${OUTPUT_DIR}/${FIRMWARE_NAME}_upgrade.bin

# reset board
xgdb -batch -ex "connect ${ADAPTER_ID} --reset-to-mode-pins" -ex detach

# wait for dust to gather
sleep 5

# get readback upgrade image
dfu-util -e -d ,20b1:4001 -a 1 -U ${OUTPUT_DIR}/readback_upgrade.bin
