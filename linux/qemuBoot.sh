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
## Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
## except in compliance with the License, or, at your option, the Apache License version 2.0. You
## may obtain a copy of the License at
##
## https://solderpad.org/licenses/SHL-2.1/
##
## Unless required by applicable law or agreed to in writing, any work distributed under the
## License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
## either express or implied. See the License for the specific language governing permissions
## and limitations under the License.
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
