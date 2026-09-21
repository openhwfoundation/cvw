///////////////////////////////////////////
// vm64check.S
//
// Written: David_Harris@hmc.edu 7 April 2023
//
// Purpose: vm64check coverage
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

// Cover IMMU vm64check block by jumping to illegal virtual addresses
// Need a nonstandard trap handler to deal with returns from these jumps
//    assign eq_46_38 = &(VAdr[46:38]) | ~|(VAdr[46:38]);
 //   assign eq_63_47 = &(VAdr[63:47]) | ~|(VAdr[63:47]);
 //   assign UpperBitsUnequal = SV39Mode ? ~(eq_63_47 & eq_46_38) : ~eq_63_47;

.section .text.init
.global rvtest_entry_point

rvtest_entry_point:
    la sp, topofstack       # Initialize stack pointer (not used)

    # Set up interrupts
    la t0, trap_handler
    csrw mtvec, t0      # Initialize MTVEC to trap_handler
    # set up PMP so user and supervisor mode can access full address space
    csrw pmpcfg0, 0xF   # configure PMP0 to TOR RWX
    li t0, 0xFFFFFFFF
    csrw pmpaddr0, t0   # configure PMP0 top of range to 0xFFFFFFFF to allow all 32-bit addresses

    # SATP in non-39 mode
    csrw satp, zero

    // vm64check coverage
check1:
    // check virtual addresses with bits 63:47 and/or 46:38 being equal or unequal
    li t0, 0x00000001800F0000   # unimplemented memory with upper and lower all zero
    la ra, check2
    jalr t0

check2:
    li t0, 0xFFFFFFF1800F0000   # unimplemented memory with upper and lower all one
    la ra, check3
    jalr t0

check3:
    li t0, 0xFFF81001800F0000   # unimplemented memory with upper all one, lower mixed
    la ra, check4
    jalr t0

check4:
    li t0, 0x03001001800F0000   # unimplemented memory with upper mixed, lower mixed
    la ra, check5
    jalr t0

check5:
    li t0, 0x00001001800F0000   # unimplemented memory with upper all zero, lower mixed
    la ra, check11
    jalr t0

check11:
    # SATP in SV39 mode
    li t0, 0x8000000000000000
    csrw satp, t0

    // check virtual addresses with bits 63:47 and/or 46:38 being equal or unequal
    li t0, 0x00000001800F0000   # unimplemented memory with upper and lower all zero
    la ra, check12
    jalr t0

check12:
    li t0, 0xFFFFFFF1800F0000   # unimplemented memory with upper and lower all one
    la ra, check13
    jalr t0

check13:
    li t0, 0xFFF81001800F0000   # unimplemented memory with upper all one, lower mixed
    la ra, check14
    jalr t0

check14:
    li t0, 0x03001001800F0000   # unimplemented memory with upper mixed, lower mixed
    la ra, check15
    jalr t0

check15:
    li t0, 0x00001001800F0000   # unimplemented memory with upper all zero, lower mixed
    la ra, check15a
    jalr t0

    # The checks above leave three SV39 FEC terms in vm64check uncovered because no
    # VA exercises these exact upper-bit field patterns.  Add them explicitly:
check15a:                       # all0_55_47_0: bits[63:56]=0, bits[55:47]!=0 (bit47), bits[46:38]=0
    li t0, 0x00008000800F0000
    la ra, check15b
    jalr t0

check15b:                       # all1_46_38_0: bits[63:47]=all1, bits[46:38]!=all1 (=0)
    li t0, 0xFFFF8000800F0000
    la ra, check15c
    jalr t0

check15c:                       # all1_55_47_0: bits[63:56]=all1, bits[55:47]!=all1 (=0), bits[46:38]=all1
    li t0, 0xFF007FC0800F0000
    la ra, check16
    jalr t0

check16:

write_tohost:
    la t1, tohost
    li t0, 1            # 1 for success, 3 for failure
    sd t0, 0(t1)        # send success code

self_loop:
    j self_loop         # wait

.align 4                # trap handlers must be aligned to multiple of 4
trap_handler:
    csrw mepc, ra       # return to address in ra
    mret

.section .tohost
tohost:                 # write to HTIF
    .dword 0
fromhost:
    .dword 0


# Initialize stack with room for 512 bytes
.bss
    .space 512
topofstack:





    j done

    lw t1, 0(t0)
    li t0, 0xFFFFFFFF80000000
    lw t1, 0(t0)
    li t1, 0xFFF8000080000000
    lw t1, 0(t0)
    li t1, 0x1000000080000000
    lw t1, 0(t0)
    li t1, 0x0000010080000000
    lw t1, 0(t0)
   li t0, 0x8000000000000000
   csrw satp, t0   # SV39 mode
    li t0, 0x0000000080000000
    lw t1, 0(t0)
    li t0, 0xFFFFFFFF80000000
    lw t1, 0(t0)
    li t1, 0xFFF8000080000000
    lw t1, 0(t0)
    li t1, 0x1000000080000000
    lw t1, 0(t0)
    li t1, 0x0000010080000000
    lw t1, 0(t0)
   li t0, 0x9000000000000000
   csrw satp, t0   # SV48 mode
    li t0, 0x0000000080000000
    lw t1, 0(t0)
    li t0, 0xFFFFFFFF80000000
    lw t1, 0(t0)
    li t1, 0xFFF8000080000000
    lw t1, 0(t0)
    li t1, 0x1000000080000000
    lw t1, 0(t0)
    li t1, 0x0000010080000000
    lw t1, 0(t0)
   li t0, 0x0000000000000000
   csrw satp, t0   # disable virtual memory
