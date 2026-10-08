///////////////////////////////////////////
// cboADPermission.S
//
// Written David_Harris@hmc.edu 10/5/26
//
// Purpose: With menvcfg.ADUE=1, a CBO that misses the DTLB must not have the page table walker set A/D
//          in a PTE whose permissions make the CBO fault: cbo.zero needs W, cbo.clean/flush/inval need R
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
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

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

// Each gigapage VPN2=3..8 maps PA 0x80000000 with different permissions (see pt_root).  A CBO from S mode
// through each mapping walks the page table.  cbotrap records mcause in s10 and mtval in s11.
// CBOCASE vpn2, instr, block, cause, pte, index: run instr on block through gigapage vpn2, then check
// mcause = cause (0 = no trap), mtval = the VA when it faulted, and the PTE afterwards = pte.
.macro CBOCASE vpn2, instr, block, cause, pte, index
    la a1, \block
    li a2, \vpn2 - 2
    slli a2, a2, 30
    add a1, a1, a2              // VA of block through gigapage vpn2
    li s10, 0
    li s11, 0
    li a0, 1
    ecall                       // to S mode
    \instr (a1)
    li a0, 3
    ecall                       // back to M mode
    li a3, \cause
    SC_CHECK_EQ s10, a3, \index
    beqz a3, 1f
    SC_CHECK_EQ s11, a1, \index+1
1:  la a2, pt_root
    ld a4, 8*\vpn2(a2)
    li a3, \pte
    SC_CHECK_EQ a4, a3, \index+2
.endm

main:
    li t0, 1
    slli t0, t0, 61
    ori t0, t0, 0xF0
    csrs menvcfg, t0            // menvcfg.ADUE = 1; CBZE, CBCFE, CBIE = 11 so cbo.* run in S mode
    la t0, cbotrap
    csrw mtvec, t0
    la t0, pt_root
    srli t0, t0, 12
    li t1, 8
    slli t1, t1, 60
    or t0, t0, t1
    csrw satp, t0               // Sv39
    sfence.vma

    // read-only page, A=D=0: cbo.zero needs W, so it faults and must leave the PTE and the block unchanged
    CBOCASE 3, cbo.zero, blk0, 15, 0x20000003, 1
    la a1, blk0
    ld a4, 0(a1)
    li a3, 0x1111111111111111
    SC_CHECK_EQ a4, a3, 4
    // execute-only page, A=0: cbo.clean/flush/inval need R (MXR=0), so they fault and must leave A=0
    CBOCASE 4, cbo.clean, blk1, 15, 0x20000009, 5
    CBOCASE 5, cbo.flush, blk1, 15, 0x20000009, 8
    CBOCASE 6, cbo.inval, blk1, 15, 0x20000009, 11
    // writable page, A=D=0: cbo.zero sets A and D and zeroes the block
    CBOCASE 7, cbo.zero, blk2, 0, 0x200000C7, 14
    la a1, blk2
    ld a4, 0(a1)
    SC_CHECK_EQ a4, zero, 17
    // writable page, A=D=0: cbo.flush sets A but not D
    CBOCASE 8, cbo.flush, blk1, 0, 0x20000047, 18

    SC_PASS
    j done

// Store page faults: record mcause/mtval and skip the CBO.  Everything else goes to sc_trap_handler,
// which passes ecalls to the WALLY-init-lib.h handler and fails the test on any other trap.
.align 4
cbotrap:
    csrr s9, mcause
    addi s9, s9, -15
    bnez s9, sc_trap_handler
    li s10, 15
    csrr s11, mtval
    csrr s9, mepc
    addi s9, s9, 4
    csrw mepc, s9
    mret

.data
.align 12
pt_root:
    .dword 0, 0
    .dword 0x200000CF           // VPN2=2: identity gigapage at 0x80000000, V R W X A D
    .dword 0x20000003           // VPN2=3: V R (read-only, A=D=0)
    .dword 0x20000009           // VPN2=4: V X (execute-only, A=0)
    .dword 0x20000009           // VPN2=5: V X (execute-only, A=0)
    .dword 0x20000009           // VPN2=6: V X (execute-only, A=0)
    .dword 0x20000007           // VPN2=7: V R W (A=D=0)
    .dword 0x20000007           // VPN2=8: V R W (A=D=0)
    .fill 503, 8, 0
.align 6
blk0:
    .rept 8
    .dword 0x1111111111111111
    .endr
blk1:
    .rept 8
    .dword 0x2222222222222222
    .endr
blk2:
    .rept 8
    .dword 0x3333333333333333
    .endr
