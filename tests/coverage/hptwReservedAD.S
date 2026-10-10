///////////////////////////////////////////
// hptwReservedAD.S
//
// Written David_Harris@hmc.edu 10/6/26
//
// Purpose: With menvcfg.ADUE=1, a store through a leaf PTE with a reserved encoding (PBMT=3, PBMT!=0 while
//          menvcfg.PBMTE=0, N=1 with a reserved napot encoding, or a nonzero bit in 60:54) must raise a store
//          page fault without the page table walker setting A/D: the translation algorithm stops at step 3,
//          before the A/D update in step 9.  Legal PTEs (including PBMT=NC with PBMTE=1) still get A and D.
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

// Each gigapage VPN2=3..8 maps PA 0x80000000 through a leaf PTE (see pt_root).  sttrap records mcause in s10
// and mtval in s11.  STCASE vpn2, cause, pte, index: from S mode store s3 to blk through gigapage vpn2, then
// check mcause = cause (0 = no trap), mtval = the VA when it faulted, and the PTE afterwards = pte.
.macro STCASE vpn2, cause, pte, index
    la a1, blk
    li a2, \vpn2 - 2
    slli a2, a2, 30
    add a1, a1, a2              // VA of blk through gigapage vpn2
    li s10, 0
    li s11, 0
    li a0, 1
    ecall                       // to S mode
    sd s3, 0(a1)
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
    csrs menvcfg, t0            // menvcfg.ADUE = 1
    la t0, sttrap
    csrw mtvec, t0
    la t0, pt_root
    srli t0, t0, 12
    li t1, 8
    slli t1, t1, 60
    or t0, t0, t1
    csrw satp, t0               // Sv39
    sfence.vma
    li s3, 0x5555555555555555

    // menvcfg.PBMTE = 0: PBMT=NC is reserved
    STCASE 5, 15, 0x2000000020000007, 1
    li t0, 1
    slli t0, t0, 62
    csrs menvcfg, t0            // menvcfg.PBMTE = 1
    STCASE 3, 15, 0x6000000020000007, 4     // PBMT=3 is reserved
    STCASE 4, 15, 0x0040000020000007, 7     // bit 54 is reserved
    STCASE 6, 15, 0x8000000020000007, 10    // N=1 with ppn[3:0]=0000 is a reserved napot encoding
    STCASE 7, 0, 0x20000000200000C7, 13     // PBMT=NC with PBMTE=1 is legal: A and D are set
    STCASE 8, 0, 0x00000000200000C7, 16     // ordinary PTE: A and D are set
    la a1, blk
    ld a4, 0(a1)
    SC_CHECK_EQ a4, s3, 19                  // the legal stores were performed

    SC_PASS
    j done

// Store page faults: record mcause/mtval and skip the store.  Everything else goes to sc_trap_handler,
// which passes ecalls to the WALLY-init-lib.h handler and fails the test on any other trap.
.align 4
sttrap:
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
    .dword 0x6000000020000007   // VPN2=3: V R W, PBMT=3 (reserved)
    .dword 0x0040000020000007   // VPN2=4: V R W, bit 54 set (reserved)
    .dword 0x2000000020000007   // VPN2=5: V R W, PBMT=NC (reserved while PBMTE=0)
    .dword 0x8000000020000007   // VPN2=6: V R W, N=1 with ppn[3:0]=0000 (reserved)
    .dword 0x2000000020000007   // VPN2=7: V R W, PBMT=NC
    .dword 0x0000000020000007   // VPN2=8: V R W
    .fill 503, 8, 0
.align 6
blk:
    .fill 8, 8, 0
