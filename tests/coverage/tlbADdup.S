///////////////////////////////////////////
// tlbADdup.S
//
// Written David_Harris@hmc.edu 10/5/26
//
// Purpose: A/D-update walk on a TLB hit must replace the hit entry, not add a second entry for the same page
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

// Each part caches a PTE in a TLB, changes the PTE in memory without sfence.vma, then makes an access that
// hits the stale entry and needs an A/D update.  The spec allows the old or the new PTE to be used.  If the walk
// adds a second entry for the page instead of replacing the hit entry, lookups OR the two together:
//   1. DTLB: PPN A -> B (D=0), then a store.  The store goes to page A|B = C.
//   2. DTLB: RW -> read-only (D=0), then a store.  The OR keeps W=1, D=0, so the store walks forever.
//   3. ITLB: PPN A -> B (A=0), then a fetch.  The fetch comes from page C.
// Pages A, B and C are 16 KiB aligned + 0x1000, 0x2000 and 0x3000, so PPN(A) | PPN(B) = PPN(C).

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

main:
    la t0, tlbdup_trap
    csrw mtvec, t0
    li s11, 0                 # 1 while the timer guards against a livelock
    li t0, 1
    slli t0, t0, 61
    csrs menvcfg, t0          # menvcfg.ADUE = 1

    # page tables: VA 0xC0000000 + n*0x1000 -> pt_l0[n]
    la t0, pt_l1
    srli t0, t0, 12
    slli t0, t0, 10
    ori t0, t0, 1
    la t1, pt_root
    sd t0, 24(t1)             # pt_root[3] -> pt_l1
    la t0, pt_l0
    srli t0, t0, 12
    slli t0, t0, 10
    ori t0, t0, 1
    la t1, pt_l1
    sd t0, 0(t1)              # pt_l1[0] -> pt_l0
    la s0, pt_l0
    la t0, pg_a
    srli t0, t0, 12
    slli s1, t0, 10           # s1 = PPN(A) in PTE position
    la t0, pg_b
    srli t0, t0, 12
    slli s2, t0, 10           # s2 = PPN(B) in PTE position
    ori t0, s1, 0x47          # V R W A, D=0
    sd t0, 0(s0)              # VA P = 0xC0000000 -> A
    la t0, pg_d
    srli t0, t0, 12
    slli t0, t0, 10
    ori t0, t0, 0x47          # V R W A, D=0
    sd t0, 8(s0)              # VA Q = 0xC0001000 -> D
    ori t0, s1, 0x0B          # V R X, A=0
    sd t0, 16(s0)             # VA R = 0xC0002000 -> A
    la t1, pt_root
    srli t1, t1, 12
    li t0, 8
    slli t0, t0, 60
    or t1, t1, t0
    csrw satp, t1             # Sv39
    sfence.vma
    li s3, 0xC0000000         # VA P
    li s4, 0x5555666677778888 # store value

    # Part 1: DTLB PPN change
    li a0, 1
    ecall                     # S mode
    ld s5, 0(s3)              # DTLB fill: P -> A, D=0
    li a0, 3
    ecall                     # M mode
    ori t0, s2, 0x47
    sd t0, 0(s0)              # P -> B, D=0; no sfence.vma
    li a0, 1
    ecall                     # S mode
    sd s4, 0(s3)              # hits the stale entry with D=0: A/D walk
    ld s6, 0(s3)
    li a0, 3
    ecall                     # M mode
    li t2, 0xAAAAAAAAAAAAAAAA
    SC_CHECK_EQ s5, t2, 1     # the first load read A
    la t0, pg_c
    ld s7, 0(t0)
    li t2, 0xCCCCCCCCCCCCCCCC
    SC_CHECK_EQ s7, t2, 2     # nothing may write C
    SC_CHECK_EQ s6, s4, 3     # the load sees the store
    la t0, pg_a
    ld s7, 0(t0)
    la t0, pg_b
    ld s8, 0(t0)
    li t2, 0xAAAAAAAAAAAAAAAA
    bne s7, t2, 1f
    SC_CHECK_EQ s8, s4, 4     # A untouched: the store went to B (new PTE)
    j 2f
1:  SC_CHECK_EQ s7, s4, 5     # or it went to A (old PTE)
    li t2, 0xBBBBBBBBBBBBBBBB
    SC_CHECK_EQ s8, t2, 6     # and B is untouched
2:  ld s7, 0(s0)
    ori s8, s2, 0xC7
    SC_CHECK_EQ s7, s8, 7     # the walk set D in the new PTE

    # Part 2: DTLB RW -> read-only
    li s3, 0xC0001000         # VA Q
    li a0, 1
    ecall                     # S mode
    ld s5, 0(s3)              # DTLB fill: Q -> D, RW, D=0
    li a0, 3
    ecall                     # M mode
    ld t0, 8(s0)
    andi t0, t0, -5
    sd t0, 8(s0)              # Q read-only, D=0; no sfence.vma
    li t0, 0x0200BFF8
    ld t1, 0(t0)              # mtime
    li t0, 20000
    add t1, t1, t0
    li t0, 0x02004000
    sd t1, 0(t0)              # mtimecmp = mtime + 20000
    li s11, 1
    li s7, 0
    li a0, 1
    ecall                     # S mode
.option push
.option norvc
    sd s4, 0(s3)              # hits the stale RW entry with D=0: A/D walk
.option pop
    li a0, 3
    ecall                     # M mode
    li s11, 0
    li t0, -1
    li t1, 0x02004000
    sd t0, 0(t1)              # disarm the timer
    la t0, pg_d
    ld s8, 0(t0)
    li t2, 0xDDDDDDDDDDDDDDDD
    beqz s7, 1f               # store done with the old PTE?
    SC_CHECK_EQ s8, t2, 9     # no: it faulted with the new PTE and D is unchanged
    li t2, 15
    SC_CHECK_EQ s7, t2, 10
    j 2f
1:  SC_CHECK_EQ s8, s4, 11
2:

    # Part 3: ITLB PPN change.  With ADUE=0 a fetch from a page with A=0 fills the ITLB and page faults.
    # The I$ fill started during the A-update walk uses the old PTE, so the nop may come from A.
    li t0, 1
    slli t0, t0, 61
    csrc menvcfg, t0          # menvcfg.ADUE = 0
    li s3, 0xC0002800         # VA R + 0x800: nop; li a1, n; ret
    li s7, 0
    li a1, 0
    li a0, 1
    ecall                     # S mode
    jalr s3                   # ITLB fill: R -> A, A=0; instruction page fault returns here
    li a0, 3
    ecall                     # M mode
    li t2, 12
    SC_CHECK_EQ s7, t2, 12
    SC_CHECK_EQ a1, zero, 13
    li t0, 1
    slli t0, t0, 61
    csrs menvcfg, t0          # menvcfg.ADUE = 1
    ori t0, s2, 0x0B
    sd t0, 16(s0)             # R -> B, A=0; no sfence.vma
    li s7, 0
    li a0, 1
    ecall                     # S mode
    jalr s3                   # hits the stale entry with A=0: A/D walk
    li a0, 3
    ecall                     # M mode
    SC_CHECK_EQ s7, zero, 14  # no fault
    li t2, 1
    beq a1, t2, 1f            # fetched from A (old PTE)
    li t2, 2
    SC_CHECK_EQ a1, t2, 15    # or from B (new PTE); 3 means from C
1:  ld s7, 16(s0)
    ori s8, s2, 0x4B
    SC_CHECK_EQ s7, s8, 16    # the walk set A in the new PTE

    SC_PASS
    j done

// Traps: ecalls go to trap_handler.  Instruction page faults return to ra; store page faults skip the store;
// a timer interrupt while s11 = 1 means the store in part 2 never completed.
.align 4
tlbdup_trap:
    csrrw t0, mscratch, t0    # t0 = trap stack pointer, mscratch = saved t0
    sd t1, -16(t0)
    csrr t1, mcause
    bltz t1, tlbdup_int
    addi t1, t1, -12
    beqz t1, tlbdup_ipf
    addi t1, t1, -3
    beqz t1, tlbdup_spf
tlbdup_default:
    ld t1, -16(t0)
    csrrw t0, mscratch, t0
    j trap_handler
tlbdup_int:
    beqz s11, tlbdup_default
    csrr s8, mepc
    ld t1, -16(t0)
    csrrw t0, mscratch, t0
    SC_CHECK_EQ s8, zero, 8   # livelock: still at the store when the timer fired
tlbdup_ipf:
    csrr s7, mcause
    csrw mepc, ra
    j tlbdup_ret
tlbdup_spf:
    csrr s7, mcause
    csrr t1, mepc
    addi t1, t1, 4
    csrw mepc, t1
tlbdup_ret:
    ld t1, -16(t0)
    csrrw t0, mscratch, t0
    mret

.data
.align 14
pt_root:                      # 16 KiB aligned
    .dword 0, 0
    .dword 0x200000CF         # VPN2=2: identity gigapage, V R W X A D
    .dword 0                  # VPN2=3: -> pt_l1, filled in at run time
    .fill 508, 8, 0
pg_a:                         # pt_root + 0x1000
    .dword 0xAAAAAAAAAAAAAAAA
    .balign 0x800
.option push
.option norvc
    nop
    li a1, 1
    ret
.option pop
    .balign 0x1000
pg_b:                         # pt_root + 0x2000
    .dword 0xBBBBBBBBBBBBBBBB
    .balign 0x800
.option push
.option norvc
    nop
    li a1, 2
    ret
.option pop
    .balign 0x1000
pg_c:                         # pt_root + 0x3000 = pg_a | pg_b
    .dword 0xCCCCCCCCCCCCCCCC
    .balign 0x800
.option push
.option norvc
    nop
    li a1, 3
    ret
.option pop
    .balign 0x1000
pg_d:
    .dword 0xDDDDDDDDDDDDDDDD
    .balign 0x1000
pt_l1:
    .fill 512, 8, 0
pt_l0:
    .fill 512, 8, 0
