///////////////////////////////////////////
// tlbMultiMatch.S
//
// Written David_Harris@hmc.edu 10/6/26
//
// Purpose: A TLB write must not leave two different entries matching one address
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

// Each part caches a translation for VA X = 0xC0000000 in the DTLB, changes the page tables without
// sfence.vma, and makes a second access that misses and caches an entry that also covers X.  A load from X
// may then use either translation (privileged spec, SFENCE.VMA notes), but the TLB must not OR the two.
//   1. 4 KiB page X -> A is upgraded to a megapage -> M.         An OR reads 0x80600000 (A|M).
//   2. 4 KiB page X -> A is upgraded to a 64 KiB NAPOT page -> N.  An OR reads 0x80610000 (A|N).
//   3. ASID 1 maps X -> A; ASID 2 maps X -> B with G=1.           An OR reads 0x80600000 (A|B).

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

#define PA_A  0x80200000          // 4 KiB page
#define PA_M  0x80400000          // megapage; also page B in part 3
#define PA_N  0x80410000          // 64 KiB NAPOT page
#define VA_X  0xC0000000
#define VA_Y  0xC0001000          // another page in the same megapage / NAPOT region

// rd = PTE for physical address pa with flags
.macro PTE rd, pa, flags
    li \rd, \pa
    srli \rd, \rd, 12
    slli \rd, \rd, 10
    ori \rd, \rd, \flags
.endm

// rd = non-leaf PTE pointing to the table at label
.macro PTR rd, label
    la \rd, \label
    srli \rd, \rd, 12
    slli \rd, \rd, 10
    ori \rd, \rd, 1
.endm

// store val at address adr
.macro MARK adr, val
    li t0, \adr
    li t1, \val
    sd t1, 0(t0)
.endm

// in S mode, load X into s5, then Y into s6 and X again into s7; return to M mode
.macro LOAD_X_Y_X
    li a0, 1
    ecall                     # S mode
    li t0, VA_Y
    ld s6, 0(t0)              # misses: caches an entry that also covers X
    li t0, VA_X
    ld s7, 0(t0)              # X matches the old and the new entry
    li a0, 3
    ecall                     # M mode
.endm

// s7 must equal a or b
.macro CHECK_EITHER a, b, n
    li t2, \a
    beq s7, t2, 1f
    li t2, \b
    SC_CHECK_EQ s7, t2, \n
1:
.endm

main:
    MARK PA_A, 0xAAAAAAAAAAAAAAAA
    MARK PA_M, 0xBBBBBBBBBBBBBBBB
    MARK PA_M+0x1000, 0xBBBBBBBBBBBBBBBB
    MARK PA_A|PA_M, 0xCCCCCCCCCCCCCCCC
    MARK PA_N, 0xDDDDDDDDDDDDDDDD
    MARK PA_N+0x1000, 0xDDDDDDDDDDDDDDDD
    MARK PA_A|PA_N, 0xEEEEEEEEEEEEEEEE

    // ASID 1 tables: pt_root[3] -> pt_l1, pt_l1[0] -> pt_l0
    la s0, pt_l1
    la s1, pt_l0
    PTR t0, pt_l1
    la t1, pt_root
    sd t0, 24(t1)
    la t1, pt_root
    srli t1, t1, 12
    li t0, 0x8000100000000000 # Sv39, ASID 1
    or s2, t1, t0
    csrw satp, s2

    # Part 1: 4 KiB page upgraded to a megapage
    PTR t0, pt_l0
    sd t0, 0(s0)              # pt_l1[0] -> pt_l0
    PTE t0, PA_A, 0xC7        # V R W A D
    sd t0, 0(s1)              # X -> A
    sfence.vma
    li a0, 1
    ecall                     # S mode
    li t0, VA_X
    ld s5, 0(t0)              # caches the 4 KiB entry X -> A
    li a0, 3
    ecall                     # M mode
    PTE t0, PA_M, 0xC7
    sd t0, 0(s0)              # pt_l1[0] = megapage -> M; no sfence.vma
    LOAD_X_Y_X
    li t2, 0xAAAAAAAAAAAAAAAA
    SC_CHECK_EQ s5, t2, 1
    li t2, 0xBBBBBBBBBBBBBBBB
    SC_CHECK_EQ s6, t2, 2
    CHECK_EITHER 0xAAAAAAAAAAAAAAAA, 0xBBBBBBBBBBBBBBBB, 3

    # Part 2: 4 KiB page upgraded to a 64 KiB NAPOT page
    PTR t0, pt_l0
    sd t0, 0(s0)              # pt_l1[0] -> pt_l0
    PTE t0, PA_A, 0xC7
    sd t0, 0(s1)              # X -> A
    sfence.vma
    li a0, 1
    ecall                     # S mode
    li t0, VA_X
    ld s5, 0(t0)              # caches the 4 KiB entry X -> A
    li a0, 3
    ecall                     # M mode
    PTE t0, PA_N|0x8000, 0xC7 # NAPOT PPN[3:0] = 1000
    li t1, 1
    slli t1, t1, 63
    or t0, t0, t1             # N
    sd t0, 0(s1)              # pt_l0[0..15] = NAPOT -> N; no sfence.vma
    sd t0, 8(s1)
    sd t0, 16(s1)
    sd t0, 24(s1)
    sd t0, 32(s1)
    sd t0, 40(s1)
    sd t0, 48(s1)
    sd t0, 56(s1)
    sd t0, 64(s1)
    sd t0, 72(s1)
    sd t0, 80(s1)
    sd t0, 88(s1)
    sd t0, 96(s1)
    sd t0, 104(s1)
    sd t0, 112(s1)
    sd t0, 120(s1)
    LOAD_X_Y_X
    li t2, 0xAAAAAAAAAAAAAAAA
    SC_CHECK_EQ s5, t2, 4
    li t2, 0xDDDDDDDDDDDDDDDD
    SC_CHECK_EQ s6, t2, 5
    CHECK_EITHER 0xAAAAAAAAAAAAAAAA, 0xDDDDDDDDDDDDDDDD, 6

    # Part 3: a global entry in ASID 2 and a non-global entry in ASID 1 for the same VA
    PTE t0, PA_A, 0xC7
    sd t0, 0(s1)              # ASID 1: X -> A
    PTR t0, pt_l1b
    la t1, pt_root2
    sd t0, 24(t1)
    PTR t0, pt_l0b
    la t1, pt_l1b
    sd t0, 0(t1)
    PTE t0, PA_M, 0xE7        # V R W G A D
    la t1, pt_l0b
    sd t0, 0(t1)              # ASID 2: X -> B, global
    la t1, pt_root2
    srli t1, t1, 12
    li t0, 0x8000200000000000 # Sv39, ASID 2
    or s3, t1, t0
    sfence.vma
    li a0, 1
    ecall                     # S mode
    li t0, VA_X
    ld s5, 0(t0)              # ASID 1: caches X -> A
    csrw satp, s3
    ld s6, 0(t0)              # ASID 2: misses, caches the global X -> B
    csrw satp, s2
    ld s7, 0(t0)              # ASID 1: X matches both entries
    li a0, 3
    ecall                     # M mode
    li t2, 0xAAAAAAAAAAAAAAAA
    SC_CHECK_EQ s5, t2, 7
    li t2, 0xBBBBBBBBBBBBBBBB
    SC_CHECK_EQ s6, t2, 8
    CHECK_EITHER 0xAAAAAAAAAAAAAAAA, 0xBBBBBBBBBBBBBBBB, 9

    SC_PASS
    j done

.data
.align 12
pt_root:
    .dword 0, 0
    .dword 0x200000CF         # VPN2=2: identity gigapage for code and data, V R W X A D
    .dword 0                  # VPN2=3: -> pt_l1
    .fill 508, 8, 0
pt_root2:
    .dword 0, 0
    .dword 0x200000CF
    .dword 0                  # VPN2=3: -> pt_l1b
    .fill 508, 8, 0
pt_l1:
    .fill 512, 8, 0
pt_l0:
    .fill 512, 8, 0
pt_l1b:
    .fill 512, 8, 0
pt_l0b:
    .fill 512, 8, 0
