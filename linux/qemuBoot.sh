#!/bin/bash
###########################################
## Boot linux on QEMU configured to match Wally
##
## Written: Jordan Carlin, jcarlin@hmc.edu
## Created: 20 January 2025
## Modified:
##
## A component of the CORE-V-WALLY configurable RISC-V project.
## https://github.com/openhwfoundation/cvw
##
## Copyright (C) 2021-25 Harvey Mudd College & Oklahoma State University
##
## SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
################################################################################################

BUILDROOT="${BUILDROOT:-$RISCV/buildroot}"
IMAGES="$BUILDROOT"/output/images

if [[ "$1" == "--gdb" && -n "$2" ]]; then
    GDB_FLAG="-gdb tcp::$2 -S"
fi

qemu-system-riscv64 \
  -M virt -m 256M -nographic \
  -bios "$IMAGES"/fw_jump.bin \
  -kernel "$IMAGES"/Image \
  -initrd "$IMAGES"/rootfs.cpio \
  -dtb "$IMAGES"/wally-virt.dtb \
  -cpu rva22s64,zicond=true,zfa=true,zfh=true,zcb=true,zbc=true,zkn=true,sstc=true,svadu=true,svnapot=true,pmp=on,debug=off \
  $GDB_FLAG
