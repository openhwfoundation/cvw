#!/bin/bash
###########################################
## flash-sd.sh
##
## Written: Jacob Pease jacobpease@protonmail.com
## Created: August 22, 2023
##
## Purpose: A script to flash an sd card with a bootable linux image.
##
## A component of the CORE-V-WALLY configurable RISC-V project.
## https://github.com/openhwgroup/cvw
##
## Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
##
## SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
## Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
## except in compliance with the License, or, at your option, the Apache License version 2.0. You
## may obtain a copy of the License at
##
## https:##solderpad.org/licenses/SHL-2.1/
##
## Unless required by applicable law or agreed to in writing, any work distributed under the
## License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
## either express or implied. See the License for the specific language governing permissions
## and limitations under the License.
################################################################################################

# Exit on any error (return code != 0)
# set -e

usage() { echo "Usage: $0 [-zh] [-b <path/to/buildroot>] <device>" 1>&2; exit 1; }

help() {
    echo "Usage: $0 [OPTIONS] <device>"
    echo "  -z                          wipes card with zeros"
    echo "  -b <path/to/buildroot>      get images from given buildroot"
    echo "  -d <device tree name>       specify device tree to use"
    exit 0;
}

abort() {
    echo -e "$NAME $ERRORTEXT $*" >&2
    exit 1
}

# Output colors
GREEN="\e[32m"
RED="\e[31m"
BOLDRED="\e[1;91m"
BOLDGREEN="\e[1;32m"
BOLDYELLOW="\e[1;33m"
NC="\e[0m"
NAME="$BOLDGREEN"${0:2}:"$NC"
ERRORTEXT="$BOLDRED"ERROR:"$NC"
WARNINGTEXT="$BOLDYELLOW"Warning:"$NC"

# Default values for buildroot and device tree
BUILDROOT=$RISCV/buildroot
DEVICE_TREE=wally-vcu108.dtb
MNT_DIR=wallyimg

# Process options and arguments. The following code grabs the single
# sdcard device argument no matter where it is in the positional
# parameters list.
ARGS=()
while [ $OPTIND -le "$#" ] ; do
    if getopts "hzb:d:" arg ; then
        case "${arg}" in
            h) help
               ;;
            z) WIPECARD=y
               ;;
            b) BUILDROOT=${OPTARG}
               ;;
            d) DEVICE_TREE=${OPTARG}
               ;;
        esac
    else
        ARGS+=("${!OPTIND}")
        ((OPTIND++))
    fi
done

# File location variables
IMAGES=$BUILDROOT/output/images
FW_JUMP=$IMAGES/fw_jump.bin
LINUX_KERNEL=$IMAGES/Image
#DEVICE_TREE=$IMAGES/$DEVICE_TREE

SDCARD=${ARGS[0]}

# User Error Checks ===================================================

if [ "$#" -eq "0" ] ; then
    usage
fi

# Check to make sure sd card device exists
if [ ! -e "$SDCARD" ] ; then
    echo -e "$NAME $ERRORTEXT SD card device does not exist."
    exit 1
fi

# Prefix partition with "p" for non-SCSI disks (mmcblk, nvme)
if [[ $SDCARD == "/dev/sd"* ]]; then
    PART_PREFIX=""
else
    PART_PREFIX="p"
fi

# If no images directory, images have not been built
if [ ! -d $IMAGES ] ; then
    echo -e "$ERRORTEXT Buildroot images directory does not exist"
    echo '       Make sure you have built the images before'
    echo '       running this script.'
    exit 1
else
    # If images are not built, exit
    if [ ! -e $FW_JUMP ] || [ ! -e $LINUX_KERNEL ] ; then
        echo -e "$ERRORTEXT Missing images in buildroot output directory."
        echo '       Build images before running this script.'
        exit 1
    fi
fi

# Ensure device tree binaries exist
if [ ! -e $DEVICE_TREE ] ; then
    echo -e "$NAME $ERRORTEXT Missing device tree files"
    echo -e "$NAME generating all device tree files into buildroot"
    make -C ../ generate BUILDROOT=$BUILDROOT
fi

# Calculate partition information =====================================

# Size of OpenSBI and the Kernel in 512B blocks
DST_SIZE=$(ls -la --block-size=512 $DEVICE_TREE | cut -d' ' -f 5 )
FW_JUMP_SIZE=$(ls -la --block-size=512 $FW_JUMP | cut -d' ' -f 5 )
KERNEL_SIZE=$(ls -la --block-size=512 $LINUX_KERNEL | cut -d' ' -f 5 )

# Start sectors of OpenSBI and Kernel Partitions
FW_JUMP_START=$(( 34 + $DST_SIZE ))
KERNEL_START=$(( $FW_JUMP_START + $FW_JUMP_SIZE ))
FS_START=$(( $KERNEL_START + $KERNEL_SIZE ))

# Print out the sizes of the binaries in 512B blocks
echo -e "$NAME Device tree block size:     $DST_SIZE"
echo -e "$NAME OpenSBI FW_JUMP block size: $FW_JUMP_SIZE"
echo -e "$NAME Kernel block size:          $KERNEL_SIZE"

read -p $'\e[1;33mWarning:\e[0m Doing this will replace all data on this card. Continue? y/n: ' -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]] ; then
    # We need to make sure that the file system partition of the card
    # is not mounted before re-flashing it.
    DEVBASENAME=$(basename $SDCARD)
    CHECKMOUNT=$(lsblk | grep "$DEVBASENAME"4 | tr -s ' ' | cut -d' ' -f 7)

    if [ ! -z $CHECKMOUNT ] ; then
        sudo umount -v $CHECKMOUNT || abort "Could not unmount $CHECKMOUNT. Aborting."
    fi

    #Make empty image
    if [ ! -z $WIPECARD ] ; then
        echo -e "$NAME Wiping SD card. This could take a while."
        sudo dd if=/dev/zero of=$SDCARD bs=64k status=progress || abort "Failed to wipe card"
        sync
    fi

    # GUID Partition Tables (GPT)
    # ===============================================
    # -g Converts any existing mbr record to a gpt record
    # --clear clears any GPT partition table that already exists.
    # --set-alignment=1 that we want to align partition starting sectors
    # to 1 sector boundaries I think? This would normally be set to 2048
    # apparently.

    sudo sgdisk -z $SDCARD || abort "Failed to zap partition table."

    sleep 1

    echo -e "$NAME Creating GUID Partition Table"
    sudo sgdisk -g --clear --set-alignment=1 \
         --new=1:34:+$DST_SIZE --change-name=1:'fdt' \
         --new=2:$FW_JUMP_START:+$FW_JUMP_SIZE --change-name=2:'opensbi' --typecode=2:2E54B353-1271-4842-806F-E436D6AF6985 \
         --new=3:$KERNEL_START:+$KERNEL_SIZE --change-name=3:'kernel' \
         --new=4:$FS_START:-0 --change-name=4:'filesystem' \
         $SDCARD || abort "Failed to create partition table on $SDCARD."

    # Inform OS about the partition table change
    sudo partprobe $SDCARD
    sleep 3

    echo -e "$NAME Copying binaries into their partitions."
    DD_FLAGS="bs=4k iflag=direct,fullblock oflag=dsync conv=fsync status=progress"

    echo -e "$NAME Copying device tree"
    sudo dd if=$DEVICE_TREE of="$SDCARD""$PART_PREFIX"1 $DD_FLAGS && sync || \
            abort "Failed to write device tree to ${SDCARD}${PART_PREFIX}1"

    echo -e "$NAME Copying OpenSBI"
    sudo dd if=$FW_JUMP of="$SDCARD""$PART_PREFIX"2 $DD_FLAGS && sync || \
            abort "Failed to write OpenSBI to ${SDCARD}${PART_PREFIX}2"

    echo -e "$NAME Copying Kernel"
    sudo dd if=$LINUX_KERNEL of="$SDCARD""$PART_PREFIX"3 $DD_FLAGS && sync || \
            abort "Failed to write the Linux Kernel to ${SDCARD}${PART_PREFIX}3"

    # Initialize all inodes immediately. This avoids the case where
    # the Kernel on the FPGA thinks the filesystem is corrupted.
    sudo mkfs.ext4 -E lazy_itable_init=0,lazy_journal_init=0 "$SDCARD""$PART_PREFIX"4 || \
        abort "Failed to initialize the filesystem on ${SDCARD}${PART_PREFIX}4."

    # Fix any potential errors in the file system.
    sudo fsck -fv "$SDCARD""$PART_PREFIX"4 || true

    sudo mkdir /mnt/$MNT_DIR
    sudo mount -o init_itable=0 -v "$SDCARD""$PART_PREFIX"4 /mnt/$MNT_DIR
    sudo umount -v /mnt/$MNT_DIR

    sudo rmdir /mnt/$MNT_DIR
    #sudo losetup -d $LOOPDEVICE
fi

echo
echo "GPT Information for $SDCARD ==================================="
sudo sgdisk -p $SDCARD
