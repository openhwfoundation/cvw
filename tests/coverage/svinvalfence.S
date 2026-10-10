///////////////////////////////////////////
// svinvalfence.S
//
// Written David_Harris@hmc.edu 10/5/26
//
// Purpose: sfence.inval.ir must order an earlier sinval.vma before the fetch of the next instruction
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
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

// Sv39, 4 KiB pages.  VA page Q (0xC0000000) ends with sfence.w.inval; sinval.vma; sfence.inval.ir and
// falls through into VA page P (0xC0001000).  Page tables A and B (same ASID) map Q identically, but
// map P to physical code page c1page (a0 = 1) or c2page (a0 = 2) respectively.  Both are written before
// an sfence.vma.  With P's translation from A still in the ITLB, S mode switches satp to B and runs
// sinval.vma x0, x0; sfence.inval.ir: the instruction after sfence.inval.ir must come from c2page.

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

main:
    # page tables A and B: VPN2=2 identity gigapage, VPN2=3 (0xC0000000) -> l1 -> l0 -> {Q, P}
    la t0, qpage
    srli t0, t0, 12
    slli t0, t0, 10
    ori t0, t0, 0x4B          # V R X A
    la t1, c1page
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, 0x4B
    la t2, pt_l0a
    sd t0, 0(t2)              # A: VA Q -> qpage
    sd t1, 8(t2)              # A: VA P -> c1page
    la t1, c2page
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, 0x4B
    la t2, pt_l0b
    sd t0, 0(t2)              # B: VA Q -> qpage
    sd t1, 8(t2)              # B: VA P -> c2page
    la t0, pt_l0a
    srli t0, t0, 12
    slli t0, t0, 10
    ori t0, t0, 1
    la t1, pt_l1a
    sd t0, 0(t1)              # A: VPN1=0 -> pt_l0a
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, 1
    la t2, pt_roota
    sd t1, 24(t2)             # A: VPN2=3 -> pt_l1a
    la t0, pt_l0b
    srli t0, t0, 12
    slli t0, t0, 10
    ori t0, t0, 1
    la t1, pt_l1b
    sd t0, 0(t1)              # B: VPN1=0 -> pt_l0b
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, 1
    la t2, pt_rootb
    sd t1, 24(t2)             # B: VPN2=3 -> pt_l1b
    li t0, 8
    slli t0, t0, 60           # Sv39, ASID 0
    la s7, pt_roota
    srli s7, s7, 12
    or s7, s7, t0             # s7 = satp for A
    la s8, pt_rootb
    srli s8, s8, 12
    or s8, s8, t0             # s8 = satp for B
    csrw satp, s7
    sfence.vma                # orders all the page-table stores above

    li s2, 0xC0001000         # VA P
    li s3, 0xC0000FF4         # sfence.w.inval; sinval.vma; sfence.inval.ir; fall into P
    li s4, 0xC0000FF8         # sinval.vma; sfence.inval.ir; fall into P
    li a0, 1
    ecall                     # to S mode

    # warm up the I$ with the sequence and c1page, then leave P -> c1page in the ITLB
    # (each Svinval instruction flushes the TLBs on Wally, so P must be executed last)
    jalr ra, 0(s4)
    li s6, 1
    SC_CHECK_EQ a0, s6, 1
    jalr ra, 0(s2)
    SC_CHECK_EQ a0, s6, 2

    # switch to B without invalidating: the ITLB may still use A's P -> c1page until the sequence
    csrw satp, s8
    jalr ra, 0(s4)            # sinval.vma; sfence.inval.ir
    li s6, 2
    SC_CHECK_EQ a0, s6, 3
    jalr ra, 0(s2)            # ITLB now holds P -> c2page
    SC_CHECK_EQ a0, s6, 4

    # back to A, then the full sequence (on Wally sfence.w.inval also flushes the TLBs)
    csrw satp, s7
    jalr ra, 0(s3)            # sfence.w.inval; sinval.vma; sfence.inval.ir
    li s6, 1
    SC_CHECK_EQ a0, s6, 5

    SC_PASS
    j done

.option push
.option norvc
.align 12
qpage:                        # mapped at VA Q = 0xC0000000
    .skip 4096-12
    sfence.w.inval            # VA 0xC0000FF4
    sinval.vma zero, zero     # VA 0xC0000FF8
    sfence.inval.ir           # VA 0xC0000FFC; next instruction is VA 0xC0001000 in page P
.align 12
c1page:
    addi a0, zero, 1
    jalr zero, 0(ra)
.align 12
c2page:
    addi a0, zero, 2
    jalr zero, 0(ra)
.option pop

.data
.align 12
pt_roota:
    .dword 0, 0
    .dword 0x200000CF         # VPN2=2: identity gigapage at 0x80000000, V R W X A D
    .dword 0                  # VPN2=3 (0xC0000000): filled in at run time
    .fill 508, 8, 0
pt_l1a:
    .fill 512, 8, 0
pt_l0a:
    .fill 512, 8, 0
pt_rootb:
    .dword 0, 0
    .dword 0x200000CF         # VPN2=2: identity gigapage at 0x80000000, V R W X A D
    .dword 0                  # VPN2=3 (0xC0000000): filled in at run time
    .fill 508, 8, 0
pt_l1b:
    .fill 512, 8, 0
pt_l0b:
    .fill 512, 8, 0
