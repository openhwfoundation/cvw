///////////////////////////////////////////
// superscalarStoreSlot1_32.S
//
// Purpose: Self-checking RV32 test for stores in slot 1.  A slot 1 store that faults is replayed, which
//          withholds FlushW so that slot 0 can commit, so the LSU must cancel the write itself.  Each
//          faulting case checks that slot 0 of the bundle committed exactly once, that the store then
//          trapped alone with its own PC and cause, and that memory is unchanged:
//            - a misaligned sw and sh, and a misaligned c.sw (no misaligned support: cause 6)
//            - a store to the read-only boot ROM (cause 7)
//          Stores that should succeed are checked too, with their address and data forwarded from the
//          bundle ahead, data from a load, a load right behind the store, and c.swsp.  Finally, a store
//          beside a taken slot 0 branch, and beside a branch whose operand is a load just ahead (which
//          a late branch would resolve only in Memory), must never write.
//          A failing check stores (index << 1) | 1 to tohost.
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

.section .text.init
.option norelax                 // keep the .align padding the bundles depend on
.global rvtest_entry_point
rvtest_entry_point:
    la t0, trap_handler
    csrw mtvec, t0
    j main

// Every trap is expected: record mcause, mepc and mtval in t3-t5, count it in s9, and skip the
// trapping instruction, which may be compressed.
.align 2
trap_handler:
    csrr t3, mcause
    csrr t4, mepc
    csrr t5, mtval
    addi s9, s9, 1
    lhu  t6, 0(t4)
    andi t6, t6, 3
    addi t6, t6, -3
    beqz t6, 1f
    addi t6, t4, 2
    j    2f
1:  addi t6, t4, 4
2:  csrw mepc, t6
    mret

pass:
    la t0, tohost
    li t1, 1
    sw t1, 0(t0)
1:  j 1b

// t1 holds (index << 1) | 1
fail:
    la t0, tohost
    sw t1, 0(t0)
1:  j 1b

.macro CHECK reg, value, index
    li t2, \value
    beq \reg, t2, 1f
    li t1, ((\index) << 1) | 1
    j fail
1:
.endm

.macro CHECKREG a, b, index
    beq \a, \b, 1f
    li t1, ((\index) << 1) | 1
    j fail
1:
.endm

// Exactly one trap since s4 was taken from s9, with this cause, at this label
.macro TRAPPED cause, label, index
    addi s4, s4, 1
    CHECKREG s9, s4, \index
    CHECK t3, \cause, \index+1
    la a2, \label
    CHECKREG t4, a2, \index+2
.endm

main:
    la   s6, tdata
    li   s9, 0
    li   a0, 0xAAAAAAAA
    .option norvc

    // Misaligned sw in slot 1.  Each bundle starts at a jump target, so the slots are as marked.
    mv   s4, s9
    li   s5, 0
    addi a1, s6, 2
    j    1f
    .align 3
1:  addi s5, s5, 1              // slot 0: must commit once, not again on the replay
st1:sw   a0, 0(a1)              // slot 1: misaligned
    TRAPPED 6, st1, 1
    CHECK s5, 1, 4
    CHECKREG t5, a1, 5          // mtval is the address
    lw   a2, 0(s6)
    CHECK a2, 0x11111111, 6
    lw   a2, 4(s6)
    CHECK a2, 0x22222222, 7

    // Misaligned sh in slot 1
    mv   s4, s9
    li   s5, 0
    addi a1, s6, 1
    j    1f
    .align 3
1:  addi s5, s5, 1              // slot 0
st2:sh   a0, 0(a1)              // slot 1: misaligned
    TRAPPED 6, st2, 8
    CHECK s5, 1, 11
    lw   a2, 0(s6)
    CHECK a2, 0x11111111, 12

    // Store to the boot ROM, which is readable but not writable.  Where there is no boot ROM the
    // loads fault too, are skipped, and leave s7 and s8 both 0.
    li   a1, 0x1000
    li   s7, 0
    li   s8, 0
    lw   s7, 0(a1)
    mv   s4, s9
    li   s5, 0
    j    1f
    .align 3
1:  addi s5, s5, 1              // slot 0
st3:sw   a0, 0(a1)              // slot 1: access fault
    TRAPPED 7, st3, 13
    CHECK s5, 1, 16
    lw   s8, 0(a1)
    CHECKREG s7, s8, 17

    // Misaligned c.sw in slot 1
    .option rvc
    mv   s4, s9
    li   s5, 0
    addi a1, s6, 2
    j    1f
    .align 3
1:  c.addi s5, 1                // slot 0
st4:c.sw a0, 0(a1)              // slot 1: misaligned
    TRAPPED 6, st4, 18
    CHECK s5, 1, 21
    lw   a2, 0(s6)
    CHECK a2, 0x11111111, 22
    lw   a2, 4(s6)
    CHECK a2, 0x22222222, 23
    .option norvc

    // Stores that succeed.  The first takes its address and data from the bundle ahead.
    mv   s4, s9
    li   a5, 0x7F
    j    1f
    .align 3
1:  lui  a3, 0x12345            // slot 0
    addi a4, s6, 8              // slot 1
    addi s5, zero, 1            // slot 0
    sw   a3, 0(a4)              // slot 1: 0x12345000 to 8
    addi s5, zero, 2            // slot 0
    sh   a3, 12(s6)             // slot 1: 0x5000 to 12
    addi s5, zero, 3            // slot 0
    sb   a5, 14(s6)             // slot 1: 0x7F to 14
    lw   a2, 8(s6)
    CHECK a2, 0x12345000, 24
    lw   a2, 12(s6)
    CHECK a2, 0x007F5000, 25

    // Store data from a load in the bundle ahead, and a load of the same word right behind the store
    j    1f
    .align 3
1:  lw   a6, 24(s6)             // slot 0: 5
    addi s5, zero, 4            // slot 1
    addi s5, zero, 5            // slot 0
    sw   a6, 16(s6)             // slot 1: data is the load's
    lw   a2, 16(s6)             // slot 0: reads the store just ahead
    CHECK a2, 5, 26

    // c.swsp in slot 1
    .option rvc
    mv   s3, sp
    mv   sp, s6
    li   a3, 0x3C3C
    j    1f
    .align 3
1:  c.addi s5, 1                // slot 0
    c.swsp a3, 28(sp)           // slot 1
    mv   sp, s3
    lw   a2, 28(s6)
    CHECK a2, 0x3C3C, 27
    .option norvc
    CHECKREG s9, s4, 28         // none of these trapped

    // A store beside a taken slot 0 branch.  On the first pass the branch is not in the BTB, so the
    // pair issues and the branch resolves taken in Execute; the store must not reach memory.
    li   s11, 4
    j    3f
    .align 3
3:  beq  zero, zero, 4f         // slot 0: taken
    sw   a0, 20(s6)             // slot 1: wrong path
4:  addi s11, s11, -1
    bnez s11, 3b
    lw   a2, 20(s6)
    CHECK a2, 0, 29

    // A store beside a branch whose operand is a load in the bundle just ahead.  A late branch would
    // let the store reach Memory before the branch is resolved, so this pair must resolve in Execute.
    li   s11, 4
    li   s3, 5
    j    3f
    .align 4
3:  lw   s2, 24(s6)             // slot 0: 5
    addi s10, s10, 1            // slot 1
    beq  s2, s3, 4f             // slot 0: operand from the load, taken
    sw   a0, 20(s6)             // slot 1: wrong path
4:  addi s11, s11, -1
    bnez s11, 3b
    lw   a2, 20(s6)
    CHECK a2, 0, 30

    j pass

.section .tohost
.align 3
tohost:
    .dword 0
fromhost:
    .dword 0

.data
.align 3
tdata:
    .word 0x11111111    // 0: misaligned stores must leave this ...
    .word 0x22222222    // 4: ... and this unchanged
    .word 0             // 8
    .word 0             // 12
    .word 0             // 16
    .word 0             // 20: must never be written
    .word 5             // 24
    .word 0             // 28
