///////////////////////////////////////////
// fpu.S
//
// Written: David_Harris@hmc.edu 28 March 2023
//
// Purpose: Test coverage for FPU
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

// load code to initialize stack, handle interrupts, terminate
#include "WALLY-init-lib.h"

main:

    bseti t0, zero, 14  # turn on FPU
    csrs mstatus, t0

    # fsqrt with Y = 0 to check divby0 flags
    fcvt.s.w f0, zero
    fli.s f1, 1
    fsqrt.s f2, f1

    #Pull denormalized FP number from memory and pass it to fclass.S for coverage
    la t0, TestData1
    flw ft0, 0(t0)
    fclass.s t1, ft0

    # zfa instructions (because Zfa tests aren't running yet)
    fli.d fs0, 16
    fcvtmod.w.d t0, fs0, rtz
#    fminm.d fs1, fs0, fs0
#    fmaxm.d fs1, fs0, fs0
#    fltq.d t0, fs1, ft0
#    fleq.d t0, fs1, ft0
    fcvt.d.q fs1, fs0
    fcvt.h.q fs1, fs0
    fcvt.s.q fs1, fs0
    # round for now because these tests are excluded from Zfa until rounding is implemented
    fround.s fs1, fs0
    froundnx.s fs1, fs0
    fround.d fs1, fs0
    froundnx.d fs1, fs0
    fround.h fs1, fs0
    froundnx.h fs1, fs0
    fround.s fs1, fs0
    froundnx.s fs1, fs0

    #Result Sign Test Coverage
    la t0, TestData2
    flw ft0, 0(t0)
    flw ft1, 4(t0)
    fadd.s ft2, ft0, ft1 #Adds coverage for inf as arg for FADD

    flw ft2, 4(t0)
    fmsub.s ft3, ft0, ft1, ft2 #Adds coverage for fmaAs or Z Sign Bit

    #Adds Coverage for Flag fmaAs, fmaPs, YSNaN, ZSNaN
    fmadd.s ft3, ft0, ft1, ft2

    flw ft0, 8(t0)
    fmadd.s ft3, ft0, ft1, ft2

    flw ft1, 12(t0)
    fmadd.s ft3, ft0, ft1, ft2

    flw ft2, 12(t0)
    flw ft1, 4(t0)
    fmadd.s ft3, ft0, ft1, ft2

    #Add Coverage for round lsbRes
    flw ft0, 16(t0)
    flw ft1, 4(t0)
    fmadd.s ft3, ft0, ft1, ft2

    #Fix BadNaNBox test on unpackinput Z
    la t0, TestData2
    flw ft3, 0(t0)
    flw ft4, 0(t0)
    fadd.s ft5, ft3, ft4

    # Test legal instructions not covered elsewhere
    flq ft0, 0(a0)
    flh ft0, 8(a0)
    fsq ft0, 0(a0)
    fsh ft0, 8(a0)

    # Tests for fpu/fctrl.sv
    fcvt.h.s ft1, ft0
    fcvt.q.s ft2, ft0
    fcvt.h.w ft3, a0
    fcvt.h.wu ft3, a0
    fcvt.h.l ft3, a0
    fcvt.h.lu ft3, a0
    fcvt.w.h a0, ft3
    fcvt.wu.h a0, ft3
    fcvt.l.h a0, ft3
    fcvt.lu.h a0, ft3
    fcvt.q.w ft3, a0
    fcvt.q.wu ft3, a0
    fcvt.q.l ft3, a0
    fcvt.q.lu ft3, a0
    fcvt.w.q a0, ft3
    fcvt.wu.q a0, ft3
    fcvt.l.q a0, ft3
    fcvt.lu.q a0, ft3
    fcvt.l.s a0, ft0
    fcvt.lu.s a0, ft0
    fcvt.s.l ft0, t0
    fcvt.s.lu ft0, t0

    // Tests verifying that half and quad floating point conversion instructions are not supported by rv64gc
    # fcvt.h.d ft3, ft0 // Somehow this instruction is taking the route on line 124
                      // idea: enable the Q extension for this to work properly? A: Q and halves not supported in rv64gc
    # fcvt.h.w ft3, a0
    # fcvt.w.h a0, ft0
    # fcvt.q.w ft3, a0
    # fcvt.w.q a0, ft0
    # fcvt.q.d ft3, ft0

    # half-precision NaN boxing
    la t0, TestData3
    fld ft2, 0(t0)          // bad NaN-boxed number
    fmadd.h ft1, ft2, ft2, ft2 // Test NaN boxing
    fmadd.s ft1, ft2, ft2, ft2 // Test NaN boxing

    // fdivsqrt: test busy->idle transition caused by a FlushE while divider is busy (when interrupt arrives)
    // This code doesn't actually trigger a busy->idle transition because the pending timer interrupt doesn't occur until the division finishes.
    li t0, 0x3F812345 # random value slightly bigger than 1
    li t1, 0x3F823456
    fmv.w.x ft0, t0  # move int to fp register
    fmv.w.x ft1, t1
    li t0, -1           # set mtimecmp to biggest number so it doesnt interrupt again
    li t1, 0x02004000   # MTIMECMP in CLINT
    sd t0, 0(t1)
    csrsi mstatus, 0b1000   # enable interrupts with mstatus.MIE
    li t1, 0x0200bff8   # read MTIME in CLINT
    ld t0, 0(t1)
    addi t0, t0, 11
    li t1, 0x02004000   # MTIMECMP in CLINT
    sd t0, 0(t1)        # write mtime+10 to cause interrupt soon  This is very touchy timing and is sensitive to cache line fetch latency
    nop
    fdiv.s ft2, ft1, ft0 # should get interrupted, triggering a flush
    csrci mstatus, 0b1000   # disable interrupts with mstatus.MIE

    # Completing branch coverage in fctrl.sv
    .word 0x38007553    // Testing the all False case for 119 - funct7 under, op = 101 0011
    .word 0x40000053    // Line 145 All False Test case - illegal instruction?
    .word 0xd0400053    // Line 156 All False Test case - illegal instruction?
    .word 0xc0400053    // Line 162 All False Test case - illegal instruction?
    .word 0xd2400053    // Line 168 All False Test case - illegal instruction?
    .word 0xc2400053    // Line 174 All False Test case - illegal instruction?

    # Increasing conditional coverage in fctrl.sv
    .word 0xc5000007    // Attempting to toggle (Op7 != 7) to 0 on line 97 in fctrl, not sure what instruction this works out to
    .word 0xe0101053    // toggling (Rs2D == 0) to 0 on line 139 in fctrl. Illegal Intsr (like fclass but incorrect rs2)
    .word 0xe0100053    // toggling (Rs2D == 0) to 0 on line 141 in fctrl. Illegal Intsr (like fmv but incorrect rs2)
    .word 0x40D00053    // toggling (Rs2D[4:2] == 0) to 0 on line 145 in fctrl.
    .word 0x40300053    // toggling SupportFmt2 to 0 on line 145 in fctrl.
    .word 0x42100053    // toggling (Rs2D[1:0] != 1) to 0 on line 147 in fctrl. Illegal Instr
    .word 0xf0100053    // toggling (Rs2D == 0) to 0 on line 143 in fctrl. Illegal Instr

    # Test illegal instructions are detected
    .word 0x00000007 // illegal floating-point load (bad Funct3)
    .word 0x00000027 // illegal floating-point store (bad Funct3)
    .word 0x58F00053 // illegal fsqrt (bad Rs2D)
    .word 0x20007053 // illegal fsgnj (bad Funct3)
    .word 0x28007053 // illegal fmin/max (bad Funct3)
    .word 0xA0007053 // illegal fcmp (bad Funct3)
    .word 0xE0007053 // illegal fclass/fmv (bad Funct3)
    .word 0xF0007053 // illegal fmv (bad Funct3)
    .word 0x43007053 // illegal fcvt.d.* (bad Rs2D)
    .word 0x42207053 // illegal fcvt.d.* (bad Rs2D[1])
    .word 0xD5F00053 // illegal fcvt.h.* (bad Rs2D)
    .word 0xC5F00053 // illegal fcvt.*.h (bad Rs2D)
    .word 0x04000043 // illegal fmadd.h (h not supported)
    .word 0xC2800053 // illegal fcvtmod.w.d with rm rne
    .word 0xF0101053 // illegal fli with Funct3D not 0
    .word 0xF0400053 // illegal fli with Rs2D not 1
    .word 0x44200053 // illegal instruction for f.cvt.h.h

    // Test divide by zero with rounding mode toward zero
    li t0, 1
    csrw frm, t0    // set rounding mode = 1
    li t0, 0x3f800000
    fcvt.s.w ft1, t0
    fcvt.s.w ft2, zero
    fdiv.s ft3, ft1, ft2

    # Test floating point convert to integer and using result
    fcvt.w.s t0, f0
    add t1, t0, t0

    j done

.section .data
.align 3
TestData1:
.int 0x00100000 #Denormalized FP number
TestData2:
.int 0x3f800000 #FP 1.0
.word 0x7f800000 #INF
.int 0xbf800000 #FP -1.0
.int 0x7fa00000 #SNaN
.int 0x3fffffff #OverFlow Test
# workaround for binutils 2.44 bug with displaying 6 byte instructions (https://sourceware.org/pipermail/binutils/2025-February/139413.html)
.word 0x0000
.align 3
TestData3:
.dword 0xABCD543212345678 # NaN box test
DivTestData:
