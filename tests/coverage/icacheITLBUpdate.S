///////////////////////////////////////////
// icacheITLBUpdate.S
//
// Written David_Harris@hmc.edu 10/5/26
//
// Purpose: An I$ fill must not start while the fetch's ITLB entry needs an A update
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

// With menvcfg.ADUE=1, a fetch that hits an ITLB entry with A=0 walks the page table to set A.  If software
// changed the PTE without sfence.vma, the walk may return a new PPN or memory type, so the I$ must not start a
// line fill or uncached read from the old physical address in parallel with the walk.  A fill that ends after
// the ITLB write is tagged with the new physical address but holds the old page's bytes, and stays wrong after
// sfence.vma until fence.i or eviction.  An uncached read in flight when the walk makes the page cacheable
// deadlocks: the bus waits for the stalled pipeline while the I$ waits for the bus.
// Each case caches an old megapage PTE {PPN=A, A=0} in the ITLB (with ADUE=0 the fetch page faults), sets
// ADUE, changes the PTE to PPN=B without sfence.vma, and calls a stub in the page.  The PTEs are in the D$, so
// the walk ends before the line fill writes the I$.  Either PTE may be used for that call; after sfence.vma
// the call must come from B, and untranslated calls to A and B must return their own stubs.
// PPN(A) | PPN(B) = PPN(B), so the results do not depend on whether the walk replaces the stale ITLB entry
// or adds a second one that lookups OR with it.
// Each page holds a stub at +0x800: nop; li a1, n; ret (n = 1 in A, 2 in B).

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

#define PTE_A     0x2008000B      // megapage -> 0x80200000 (page A), X R V, A=0
#define PTE_B     0x2018000B      // megapage -> 0x80600000 (page B), X R V, A=0
#define PTE_ACC   0x40            // A bit
#define PTE_NC    (1 << 61)       // PBMT = NC

// ICITLB_CASE oldpte, newpte, base: checks base+1 .. base+7
.macro ICITLB_CASE oldpte, newpte, base
    csrc menvcfg, s5          # ADUE = 0
    li t2, \oldpte
    sd t2, 8(s0)              # VA 0xC0200000 -> old PTE
    sfence.vma
    fence.i
    # ADUE=0: the fetch walks, caches the old PTE with A=0 in the ITLB, and takes an instruction page fault
    li s7, 0
    li a0, 1
    ecall                     # S mode
    jalr s3
    li a0, 3
    ecall                     # M mode
    li t2, 12
    SC_CHECK_EQ s7, t2, \base+1
    # ADUE=1 and new PTE without sfence.vma: the fetch hits the stale entry and walks to set A
    csrs menvcfg, s5          # ADUE = 1
    li t2, \newpte
    sd t2, 8(s0)
    li s7, 0
    li a1, 0
    li a0, 1
    ecall                     # S mode
    jalr s3                   # either PTE may be used: a1 = 1 or 2
    li a0, 3
    ecall                     # M mode
    mv s9, a1
    li t2, 1
    beq s9, t2, 1f
    li t2, 2
    SC_CHECK_EQ s9, t2, \base+2
1:  SC_CHECK_EQ s7, zero, \base+3
    # after sfence.vma the fetch must use the new PTE and come from B
    li a1, 0
    li a0, 1
    ecall                     # S mode
    sfence.vma
    jalr s3
    li a0, 3
    ecall                     # M mode
    mv s9, a1
    li t2, 2
    SC_CHECK_EQ s9, t2, \base+4
    # untranslated fetches from B and A return their own stubs
    li a1, 0
    li t3, 0x80600800
    jalr t3
    li t2, 2
    SC_CHECK_EQ a1, t2, \base+5
    li a1, 0
    li t3, 0x80200800
    jalr t3
    li t2, 1
    SC_CHECK_EQ a1, t2, \base+6
    SC_CHECK_EQ s7, zero, \base+7
.endm

main:
    la t0, icitlb_trap
    csrw mtvec, t0
    li t0, 1
    slli t0, t0, 62
    csrs menvcfg, t0          # menvcfg.PBMTE = 1
    li s5, 1
    slli s5, s5, 61           # menvcfg.ADUE

    li t2, 0x80200800         # stub in page A
    li t3, 1
    jal write_stub
    li t2, 0x80600800         # stub in page B
    li t3, 2
    jal write_stub
    fence.i

    # Sv39: identity gigapage at 0x80000000 for the code and data; VA 0xC0200000 -> megapage pt_l1[1]
    la t0, pt_l1
    srli t0, t0, 12
    slli t0, t0, 10
    ori t0, t0, 1
    la t1, pt_root
    sd t0, 24(t1)             # pt_root[3] -> pt_l1
    la s0, pt_l1
    srli t1, t1, 12
    li t0, 8
    slli t0, t0, 60
    or t1, t1, t0
    csrw satp, t1             # Sv39
    li s3, 0xC0200800         # the stub's virtual address

    # 1. new PTE already has A=1: the walk does not write the PTE and ends well before the line fill
    ICITLB_CASE PTE_A, PTE_B | PTE_ACC, 10
    # 2. new PTE has A=0: the walk sets A
    ICITLB_CASE PTE_A, PTE_B, 20
    # 3. new PTE is NC: the line fill from A is in flight when the page becomes uncached
    ICITLB_CASE PTE_A, PTE_B | PTE_ACC | PTE_NC, 30
    # 4. old PTE is NC: the uncached read from A is in flight when the page becomes cacheable
    ICITLB_CASE PTE_A | PTE_NC, PTE_B | PTE_ACC, 40

    SC_PASS
    j done

write_stub:                   # at t2: nop; li a1, t3; ret
    li t0, 0x00000013         # nop
    sw t0, 0(t2)
    slli t1, t3, 20
    li t0, 0x00000593         # li a1, 0
    or t0, t0, t1
    sw t0, 4(t2)
    li t0, 0x00008067         # ret
    sw t0, 8(t2)
    ret

# Instruction page faults return to ra with mcause in s7; everything else goes to trap_handler
.align 4
icitlb_trap:
    csrrw t0, mscratch, t0
    sd t1, -16(t0)
    csrr t1, mcause
    addi t1, t1, -12
    bnez t1, 1f
    csrr s7, mcause
    csrw mepc, ra
    ld t1, -16(t0)
    csrrw t0, mscratch, t0
    mret
1:  ld t1, -16(t0)
    csrrw t0, mscratch, t0
    j trap_handler

.data
.align 12
pt_root:
    .dword 0, 0
    .dword 0x200000CF         # identity gigapage at 0x80000000, V R W X A D
    .dword 0                  # -> pt_l1 (set by the test)
    .fill 508, 8, 0
pt_l1:
    .fill 512, 8, 0
