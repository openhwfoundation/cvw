///////////////////////////////////////////
// superscalarFuseAluBr_32.S
//
// Purpose: Self-checking RV32 test for ALU op + branch macro-op fusion (issue.sv): a branch that compares
//          slot 0's result is fused with it, and slot 1's comparator takes that result straight from slot
//          0's ALU in the same cycle (datapath.sv).  Each case runs a fused pair over a table of operand
//          values chosen for the edges -- signed overflow, unsigned wrap to 0, negatives, equal values --
//          and checks it against a reference: the same two instructions with a nop between them, which
//          keeps them from fusing.  The branch direction and the ALU result must both agree.  Covered:
//            - add, sub, xor, and, or, slli, slt, addi, andi, li, lui in slot 0
//            - beq, bne, blt, bge, bltu, bgeu, with slot 0's result as rs1, as rs2, as both, and against x0
//            - compressed c.mv, c.addi, c.andi, c.li with c.beqz/c.bnez
//          Each fused pair starts a bundle at an 8-byte-aligned jump target.  The simulation's "fusion:"
//          line reports how many pairs fused.  A failing check stores (index << 1) | 1 to tohost.
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

.equ NVEC, 12                   // rows in vec

.section .text.init
.option norelax                 // keep the .align padding the bundles depend on
.global rvtest_entry_point
rvtest_entry_point:
    j main

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

.macro FAILIF a, b, index
    beq \a, \b, 1f
    li t1, ((\index) << 1) | 1
    j fail
1:
.endm

// One case: "op t0, srcs" in slot 0 and "br" on t0 in slot 1, run over every row {a1, a2, a3} of vec.
//   ord 0: br t0, a3     ord 1: br a3, t0     ord 2: br t0, t0     ord 3: br t0, zero
// t2 = 1 if the fused branch was taken, t3 = 1 if the reference branch was.
.macro FB index, op, srcs, br, ord
    la   s0, vec
    li   s2, NVEC
7:  lw   a1, 0(s0)
    lw   a2, 4(s0)
    lw   a3, 8(s0)
    li   t2, 0
    li   t3, 0
    j    3f
    .align 3
3:  \op  t0, \srcs                  // slot 0 \  fused
  .if \ord == 0                     // slot 1 /
    \br  t0, a3, 2f
  .elseif \ord == 1
    \br  a3, t0, 2f
  .elseif \ord == 2
    \br  t0, t0, 2f
  .else
    \br  t0, zero, 2f
  .endif
    j    4f
2:  li   t2, 1
4:  \op  t1, \srcs                  // reference: the nop keeps the branch out of t1's bundle
    nop
  .if \ord == 0
    \br  t1, a3, 5f
  .elseif \ord == 1
    \br  a3, t1, 5f
  .elseif \ord == 2
    \br  t1, t1, 5f
  .else
    \br  t1, zero, 5f
  .endif
    j    6f
5:  li   t3, 1
6:  FAILIF t2, t3, \index           // same direction
    FAILIF t0, t1, \index           // same result
    addi s0, s0, 12
    addi s2, s2, -1
    bnez s2, 7b                     // 7, not 1: FAILIF defines its own 1
.endm

// The compressed form: slot 0 and the branch are 16-bit, on a0 (fused) and a4 (reference), both in x8-x15.
// a0 and a4 start as a1, for the forms that read their own rd (c.addi, c.andi).
.macro FBC index, op, srcs0, srcs4, br
    la   s0, vec
    li   s2, NVEC
7:  lw   a1, 0(s0)
    mv   a0, a1
    mv   a4, a1
    li   t2, 0
    li   t3, 0
    j    3f
    .align 3
3:  \op  a0, \srcs0                 // slot 0 \  fused
    \br  a0, 2f                     // slot 1 /
    c.nop
    c.j  4f
2:  li   t2, 1
4:  \op  a4, \srcs4
    c.nop
    c.nop
    \br  a4, 5f
    c.nop
    c.j  6f
5:  li   t3, 1
6:  FAILIF t2, t3, \index
    FAILIF a0, a4, \index
    addi s0, s0, 12
    addi s2, s2, -1
    bnez s2, 7b                     // 7, not 1: FAILIF defines its own 1
.endm

main:
    .option norvc
    FB  1, add,  "a1, a2", blt,  0
    FB  2, add,  "a1, a2", bge,  1
    FB  3, add,  "a1, a2", bltu, 0
    FB  4, add,  "a1, a2", bgeu, 1
    FB  5, add,  "a1, a2", beq,  0
    FB  6, sub,  "a1, a2", bne,  1
    FB  7, sub,  "a1, a2", blt,  0
    FB  8, xor,  "a1, a2", bltu, 1
    FB  9, and,  "a1, a2", beq,  0
    FB 10, or,   "a1, a2", bge,  0
    FB 11, addi, "a1, -1", bge,  0
    FB 12, andi, "a1, 255", bltu, 0
    FB 13, andi, "a1, 1",  bne,  1
    FB 14, slli, "a1, 3",  blt,  0
    FB 15, slt,  "a1, a2", beq,  2
    FB 16, li,   "5",      beq,  1
    FB 17, lui,  "0x80000", bltu, 1
    FB 18, addi, "a1, -1", bne,  3
    FB 19, and,  "a1, a2", beq,  3
    .option rvc
    FBC 20, c.mv,   "a1", "a1", c.bnez
    FBC 21, c.addi, "-1", "-1", c.beqz
    FBC 22, c.andi, "1",  "1",  c.bnez
    FBC 23, c.li,   "0",  "0",  c.beqz
    .option norvc
    j pass

.section .data
.align 4
// {a1, a2, a3}
vec:
    .word 0x7fffffff, 0x00000001, 0x80000000   // add overflows to negative
    .word 0xffffffff, 0x00000001, 0x00000000   // add wraps to 0
    .word 0x00000005, 0xfffffffd, 0x00000002   // 5 + -3 == 2
    .word 0x00000005, 0xfffffffd, 0x00000003
    .word 0xfffffffb, 0x00000002, 0xfffffffd   // -5 + 2 == -3
    .word 0x80000000, 0x80000000, 0x00000000
    .word 0x00000000, 0x00000000, 0x00000000
    .word 0x00000001, 0x00000002, 0xffffffff
    .word 0x12345678, 0x0f0f0f0f, 0x00000001
    .word 0xffffffff, 0xffffffff, 0xfffffffe
    .word 0x00000064, 0x00000017, 0x0000007b   // 100 + 23 == 123
    .word 0x40000000, 0x40000000, 0x7fffffff

.section .tohost
.align 3
tohost:
    .word 0
    .word 0
