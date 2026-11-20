///////////////////////////////////////////
// superscalarFuseIdxLoad_32.S
//
// Purpose: Self-checking RV32 test for Indexed Load macro-op fusion (issue.sv): an add (or c.add, c.mv,
//          sh1add/sh2add/sh3add) followed by a load of offset 0 from the add's rd into the same rd is
//          executed by slot 0 as one load from rs1 + rs2, with slot 1 a bubble.  Checked:
//            - the loaded value, for each width and signedness (the load's funct3 rides beside the add's)
//            - consumers of the loaded rd in both slots of the very next bundle (load-use)
//            - slot 0's own operand coming from a load just ahead (it must stall, not go late)
//            - a store just ahead to the same address (store-then-load)
//            - c.mv and c.add with c.lw, and sh2add where Zba is implemented
//            - lookalikes that must not fuse: a different rd, a nonzero offset
//            - a misaligned fused load: replayed unfused, so rd holds the add's sum and the load traps
//              alone with its own PC (cause 4)
//          Each case starts a bundle at an 8-byte-aligned jump target, so the slots are as marked.  The
//          simulation's "fusion:" line reports how many pairs actually fused.
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
    la   s8, tptr
    li   s9, 0
    .option norvc

    // 1. add + lw, and both slots of the next bundle read the loaded a0 at once.
    mv   a1, s6
    li   a2, 4
    j    1f
    .align 3
1:  add  a0, a1, a2             // slot 0 \  fused: a0 = mem[a1 + a2]
    lw   a0, 0(a0)              // slot 1 /
    addi a3, a0, 1              // slot 0: load-use
    addi a4, a0, 2              // slot 1: load-use
    CHECK a0, 0x22222222, 1
    CHECK a3, 0x22222223, 2
    CHECK a4, 0x22222224, 3
    CHECKREG a1, s6, 4          // the add's sources are untouched

    // 2. Each width: the LSU must use the load's funct3, not the add's (000, which is lb).
    li   a2, 9
    j    1f
    .align 3
1:  add  a0, a1, a2             // slot 0 \  lb from tdata+9: 0x80
    lb   a0, 0(a0)              // slot 1 /
    CHECK a0, 0xFFFFFF80, 5
    li   a2, 8
    j    1f
    .align 3
1:  add  a0, a1, a2             // slot 0 \  lhu from tdata+8: 0x807F
    lhu  a0, 0(a0)              // slot 1 /
    CHECK a0, 0x0000807F, 6
    li   a2, 10
    j    1f
    .align 3
1:  add  a0, a1, a2             // slot 0 \  lh from tdata+10: 0x8001
    lh   a0, 0(a0)              // slot 1 /
    CHECK a0, 0xFFFF8001, 7
    li   a2, 8
    j    1f
    .align 3
1:  add  a0, a1, a2             // slot 0 \  lbu from tdata+8: 0x7F
    lbu  a0, 0(a0)              // slot 1 /
    CHECK a0, 0x0000007F, 8

    // 3. Slot 0's rs1 comes from a load in the bundle just ahead.  The fused add's sum is the address,
    //    so it must be right in Execute: the bundle stalls rather than going late.
    li   a2, 12
    j    1f
    .align 3
1:  lw   a1, 0(s8)              // slot 0: a1 = tdata
    nop                         // slot 1
    add  a0, a1, a2             // slot 0 \  fused, a1 is a load result one bundle ahead
    lw   a0, 0(a0)              // slot 1 /
    CHECK a0, 0x44444444, 9

    // 4. A store to the same address in the bundle just ahead.
    li   a5, 0x5A5A5A5A
    li   a2, 16
    j    1f
    .align 3
1:  sw   a5, 16(s6)             // slot 0
    nop                         // slot 1
    add  a0, a1, a2             // slot 0 \  fused, reads the word just stored
    lw   a0, 0(a0)              // slot 1 /
    CHECK a0, 0x5A5A5A5A, 10

    // 5. The add reads the register it writes.
    mv   a0, s6
    li   a2, 4
    j    1f
    .align 3
1:  add  a0, a0, a2             // slot 0 \  fused
    lw   a0, 0(a0)              // slot 1 /
    CHECK a0, 0x22222222, 11

    // 6. Compressed: c.mv and c.add with c.lw.
    .option rvc
    addi a1, s6, 4
    li   a2, 12
    j    1f
    .align 3
1:  c.mv a0, a1                 // slot 0 \  fused: a0 = mem[a1]
    c.lw a0, 0(a0)              // slot 1 /
    c.nop
    c.nop
    CHECK a0, 0x22222222, 12
    mv   a0, s6
    j    1f
    .align 3
1:  c.add a0, a2                // slot 0 \  fused: a0 = mem[a0 + a2]
    c.lw  a0, 0(a0)             // slot 1 /
    c.nop
    c.nop
    CHECK a0, 0x44444444, 13
    .option norvc
    mv   a1, s6

    // 7. Lookalikes that must not fuse, but still compute the right thing.
    li   a2, 4
    j    1f
    .align 3
1:  add  a0, a1, a2             // different rd: a0 stays live, so this does not fuse
    lw   a3, 0(a0)
    CHECK a3, 0x22222222, 14
    addi t0, s6, 4
    CHECKREG a0, t0, 15
    j    1f
    .align 3
1:  add  a0, a1, a2             // nonzero offset: the address is a1 + a2 + 4
    lw   a0, 4(a0)
    CHECK a0, 0x8001807F, 16

    // 8. sh2add (Zba), the paper's LEA + Indexed Load.  Where Zba is not implemented the probe traps as
    //    an illegal instruction and the case is skipped.
    mv   s4, s9
    .insn r 0x33, 4, 0x10, t0, x0, x0     // sh2add t0, x0, x0
    bne  s4, s9, 2f
    li   a1, 1
    mv   a2, s6
    j    1f
    .align 3
1:  .insn r 0x33, 4, 0x10, a0, a1, a2     // slot 0 \  sh2add a0, a1, a2: fused, a0 = mem[(1 << 2) + tdata]
    lw   a0, 0(a0)                        // slot 1 /
    CHECK a0, 0x22222222, 17
2:  mv   s9, s4                 // forget the probe's trap, if it took one
    mv   a1, s6

    // 9. A misaligned fused load.  The trap would name the add's PC, so the pair is replayed unfused:
    //    the add commits alone and writes its sum, and the load traps by itself.
    mv   s4, s9
    li   a2, 2
    j    1f
    .align 3
1:  add  a0, a1, a2             // slot 0 \  fused; a1 + a2 is misaligned for a word
flt:lw   a0, 0(a0)              // slot 1 /
    TRAPPED 4, flt, 18
    addi t0, s6, 2
    CHECKREG t5, t0, 21         // mtval is the address
    CHECKREG a0, t0, 22         // a0 holds the add's sum: the load never wrote it

    j pass

.section .data
.align 4
tdata:
    .word 0x11111111            // +0
    .word 0x22222222            // +4
    .word 0x8001807F            // +8: bytes 7F 80 01 80
    .word 0x44444444            // +12
    .word 0x00000000            // +16: written by case 4
tptr:
    .word tdata

.section .tohost
.align 3
tohost:
    .word 0
    .word 0
