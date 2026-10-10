///////////////////////////////////////////
// fpu.S
//
// Written: David_Harris@hmc.edu 28 March 2023
//
// Purpose: Test coverage for FPU
//          Checks the result (all 64 bits, so NaN-boxing too) and the exception flags of each
//          legal operation, and that each illegal instruction raises an illegal instruction
//          exception at its own address.  The flags are read and cleared after each check.
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
#include "WALLY-selfcheck.h"

// CHECKF freg, val, index: check all 64 bits of an FP register (a single or half is NaN-boxed)
.macro CHECKF freg, val, index
    fmv.x.d t2, \freg
    li t3, \val
    SC_CHECK_EQ t2, t3, \index
.endm

// CHECKX reg, val, index: check an integer register
.macro CHECKX reg, val, index
    li t3, \val
    SC_CHECK_EQ \reg, t3, \index
.endm

// FLAGS val, index: check the accrued exception flags (NV=0x10 DZ=0x08 OF=0x04 UF=0x02 NX=0x01), then clear them
.macro FLAGS val, index
    csrrw t2, fflags, zero
    li t3, \val
    SC_CHECK_EQ t2, t3, \index
.endm

// TRAP cause, index, insn: run insn and check mcause = cause afterwards (0: no trap).  When it traps,
// also check that it trapped at its own address; the library handler returns past it, so mepc = its
// address + 4.
.macro TRAP cause, index, insn:vararg
    csrw mcause, zero
1:
    \insn
    csrr t2, mcause
    li t3, \cause
    SC_CHECK_EQ t2, t3, \index
.if \cause
    csrr t2, mepc
    la t3, 1b + 4
    SC_CHECK_EQ t2, t3, \index + 1
.endif
.endm

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
    // Checks for the block above, kept after it so its instruction sequence is unchanged
    CHECKF f2, 0xffffffff3f800000, 1    // sqrt(1) = 1
    CHECKX t1, 0x20, 3                  // fclass: positive subnormal
    CHECKX t0, 16, 4                    // fcvtmod.w.d(16.0) = 16
    FLAGS 0, 5                          // all exact; fsqrt's Y (f0, from the rs2 field) = 0 must not raise divide by zero
#    fminm.d fs1, fs0, fs0
#    fmaxm.d fs1, fs0, fs0
#    fltq.d t0, fs1, ft0
#    fleq.d t0, fs1, ft0
    TRAP 2, 6, fcvt.d.q fs1, fs0        // Q is not supported
    TRAP 2, 8, fcvt.h.q fs1, fs0
    TRAP 2, 10, fcvt.s.q fs1, fs0
    # round for now because these tests are excluded from Zfa until rounding is implemented
    # fs0 holds the double 16.0, which is not a NaN-boxed single or half, so those read it as the canonical NaN
    fround.s fs1, fs0
    froundnx.s fs2, fs0
    fround.d fs3, fs0
    froundnx.d fs4, fs0
    fround.h fs5, fs0
    froundnx.h fs6, fs0
    fround.s fs7, fs0
    froundnx.s fs8, fs0
    CHECKF fs1, 0xffffffff7fc00000, 12
    CHECKF fs2, 0xffffffff7fc00000, 13
    CHECKF fs3, 0x4030000000000000, 14
    CHECKF fs4, 0x4030000000000000, 15
    CHECKF fs5, 0xffffffffffff7e00, 16
    CHECKF fs6, 0xffffffffffff7e00, 17
    CHECKF fs7, 0xffffffff7fc00000, 18
    CHECKF fs8, 0xffffffff7fc00000, 19
    FLAGS 0, 20                         // quiet NaNs and an integral value: no flags, not even inexact

    #Result Sign Test Coverage
    la t0, TestData2
    flw ft0, 0(t0)
    flw ft1, 4(t0)
    fadd.s ft2, ft0, ft1 #Adds coverage for inf as arg for FADD
    CHECKF ft2, 0xffffffff7f800000, 21  // 1 + inf = inf
    FLAGS 0, 22

    flw ft2, 4(t0)
    fmsub.s ft3, ft0, ft1, ft2 #Adds coverage for fmaAs or Z Sign Bit
    CHECKF ft3, 0xffffffff7fc00000, 23  // 1 * inf - inf = canonical NaN
    FLAGS 0x10, 24                      // invalid

    #Adds Coverage for Flag fmaAs, fmaPs, YSNaN, ZSNaN
    fmadd.s ft3, ft0, ft1, ft2
    CHECKF ft3, 0xffffffff7f800000, 25  // 1 * inf + inf = inf
    FLAGS 0, 26

    flw ft0, 8(t0)
    fmadd.s ft3, ft0, ft1, ft2
    CHECKF ft3, 0xffffffff7fc00000, 27  // -1 * inf + inf = canonical NaN
    FLAGS 0x10, 28

    flw ft1, 12(t0)
    fmadd.s ft3, ft0, ft1, ft2
    CHECKF ft3, 0xffffffff7fc00000, 29  // -1 * sNaN + inf
    FLAGS 0x10, 30                      // signaling NaN operand

    flw ft2, 12(t0)
    flw ft1, 4(t0)
    fmadd.s ft3, ft0, ft1, ft2
    CHECKF ft3, 0xffffffff7fc00000, 31  // -1 * inf + sNaN
    FLAGS 0x10, 32

    #Add Coverage for round lsbRes
    flw ft0, 16(t0)
    flw ft1, 4(t0)
    fmadd.s ft3, ft0, ft1, ft2
    CHECKF ft3, 0xffffffff7fc00000, 33  // 0x3fffffff * inf + sNaN
    FLAGS 0x10, 34

    #Fix BadNaNBox test on unpackinput Z
    la t0, TestData2
    flw ft3, 0(t0)
    flw ft4, 0(t0)
    fadd.s ft5, ft3, ft4
    CHECKF ft5, 0xffffffff40000000, 35  // 1 + 1 = 2
    FLAGS 0, 36

    # Test legal instructions not covered elsewhere.  Q (flq, fsq) is not supported.  a0 = 0, and there
    # is no memory at address 8, so flh and fsh take access faults.
    li a0, 0                            // as from reset
    TRAP 2, 37, flq ft0, 0(a0)
    TRAP 5, 39, flh ft0, 8(a0)          // load access fault
    TRAP 2, 41, fsq ft0, 0(a0)
    TRAP 7, 43, fsh ft0, 8(a0)          // store/AMO access fault

    # Tests for fpu/fctrl.sv
    fcvt.h.s ft1, ft0
    CHECKF ft1, 0xffffffffffff4000, 45  // ft0 = 0x3fffffff = 2 - 2^-23 rounds to 2.0
    FLAGS 0x01, 46                      // inexact
    TRAP 2, 47, fcvt.q.s ft2, ft0
    fcvt.h.w ft3, a0
    fcvt.h.wu ft6, a0
    fcvt.h.l ft7, a0
    fcvt.h.lu ft8, a0
    li a1, -1                           // sentinels, so the checks see the conversions write 0
    li a2, -1
    li a3, -1
    li a4, -1
    fcvt.w.h a1, ft3
    fcvt.wu.h a2, ft3
    fcvt.l.h a3, ft3
    fcvt.lu.h a4, ft3
    CHECKF ft3, 0xffffffffffff0000, 49  // integer 0 converts to +0.0 half
    CHECKF ft6, 0xffffffffffff0000, 50
    CHECKF ft7, 0xffffffffffff0000, 51
    CHECKF ft8, 0xffffffffffff0000, 52
    CHECKX a1, 0, 53                    // and back to integer 0
    CHECKX a2, 0, 54
    CHECKX a3, 0, 55
    CHECKX a4, 0, 56
    FLAGS 0, 57
    TRAP 2, 58, fcvt.q.w ft3, a0
    TRAP 2, 60, fcvt.q.wu ft3, a0
    TRAP 2, 62, fcvt.q.l ft3, a0
    TRAP 2, 64, fcvt.q.lu ft3, a0
    TRAP 2, 66, fcvt.w.q a0, ft3
    TRAP 2, 68, fcvt.wu.q a0, ft3
    TRAP 2, 70, fcvt.l.q a0, ft3
    TRAP 2, 72, fcvt.lu.q a0, ft3
    fcvt.l.s a0, ft0
    fcvt.lu.s a5, ft0
    CHECKX a0, 2, 74                    // 2 - 2^-23 rounds to 2 (rne)
    CHECKX a5, 2, 75
    FLAGS 0x01, 76                      // inexact
    li t0, 0x80004004                   // a fixed value (TestData2's address when the test was written)
    fcvt.s.l ft0, t0
    fcvt.s.lu ft9, t0
    CHECKF ft0, 0xffffffff4f000040, 77  // 2^31 + 16388 rounds to 2^31 + 64 * 256 (ulp 256)
    CHECKF ft9, 0xffffffff4f000040, 78
    FLAGS 0x01, 79

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
    fmadd.s ft10, ft2, ft2, ft2 // Test NaN boxing
    CHECKF ft1, 0xffffffffffff7e00, 80  // improperly boxed operands read as the canonical NaN
    CHECKF ft10, 0xffffffff7fc00000, 81
    FLAGS 0, 82                         // quiet NaNs: no flags

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
    // The interrupt may or may not catch the fdiv (the library handler returns past the interrupted
    // instruction), so its result and inexact flag depend on timing and are not checked.  Clear the flags.
    csrw fflags, zero

    # Completing branch coverage in fctrl.sv
    TRAP 2, 83, .word 0x38007553    // Testing the all False case for 119 - funct7 under, op = 101 0011
    TRAP 2, 85, .word 0x40000053    // Line 145 All False Test case - illegal instruction?
    TRAP 2, 87, .word 0xd0400053    // Line 156 All False Test case - illegal instruction?
    TRAP 2, 89, .word 0xc0400053    // Line 162 All False Test case - illegal instruction?
    TRAP 2, 91, .word 0xd2400053    // Line 168 All False Test case - illegal instruction?
    TRAP 2, 93, .word 0xc2400053    // Line 174 All False Test case - illegal instruction?

    # Increasing conditional coverage in fctrl.sv
    TRAP 2, 95, .word 0xc5000007    // Attempting to toggle (Op7 != 7) to 0 on line 97 in fctrl; a vector load, and V is not supported
    TRAP 2, 97, .word 0xe0101053    // toggling (Rs2D == 0) to 0 on line 139 in fctrl. Illegal Intsr (like fclass but incorrect rs2)
    TRAP 2, 99, .word 0xe0100053    // toggling (Rs2D == 0) to 0 on line 141 in fctrl. Illegal Intsr (like fmv but incorrect rs2)
    TRAP 2, 101, .word 0x40D00053   // toggling (Rs2D[4:2] == 0) to 0 on line 145 in fctrl.
    TRAP 2, 103, .word 0x40300053   // toggling SupportFmt2 to 0 on line 145 in fctrl (fcvt.s.q, and Q is not supported)
    TRAP 2, 105, .word 0x42100053   // toggling (Rs2D[1:0] != 1) to 0 on line 147 in fctrl. Illegal Instr
    TRAP 0, 107, .word 0xf0100053   // toggling (Rs2D == 0) to 0 on line 143 in fctrl.  Legal: Zfa fli.s f0, -1.0
    CHECKF f0, 0xffffffffbf800000, 108

    # Test illegal instructions are detected
    TRAP 2, 109, .word 0x00000007 // illegal floating-point load (bad Funct3)
    TRAP 2, 111, .word 0x00000027 // illegal floating-point store (bad Funct3)
    TRAP 2, 113, .word 0x58F00053 // illegal fsqrt (bad Rs2D)
    TRAP 2, 115, .word 0x20007053 // illegal fsgnj (bad Funct3)
    TRAP 2, 117, .word 0x28007053 // illegal fmin/max (bad Funct3)
    TRAP 2, 119, .word 0xA0007053 // illegal fcmp (bad Funct3)
    TRAP 2, 121, .word 0xE0007053 // illegal fclass/fmv (bad Funct3)
    TRAP 2, 123, .word 0xF0007053 // illegal fmv (bad Funct3)
    TRAP 2, 125, .word 0x43007053 // illegal fcvt.d.* (bad Rs2D)
    TRAP 0, 127, .word 0x42207053 // fcvt.d.* with Rs2D[1] set: legal fcvt.d.h f0, f0 (Zfh, dynamic rounding)
    CHECKF f0, 0x7ff8000000000000, 128  // f0 (the single -1.0) is not a NaN-boxed half: canonical NaN
    TRAP 2, 129, .word 0xD5F00053 // illegal fcvt.h.* (bad Rs2D)
    TRAP 2, 131, .word 0xC5F00053 // illegal fcvt.*.h (bad Rs2D)
    TRAP 0, 133, .word 0x04000043 // fmadd.h f0, f0, f0, f0, rne: legal (Zfh)
    CHECKF f0, 0xffffffffffff7e00, 134  // f0 (a double NaN) is not a NaN-boxed half: canonical NaN
    TRAP 2, 135, .word 0xC2800053 // illegal fcvtmod.w.d with rm rne
    TRAP 2, 137, .word 0xF0101053 // illegal fli with Funct3D not 0
    TRAP 2, 139, .word 0xF0400053 // illegal fli with Rs2D not 1
    TRAP 2, 141, .word 0x44200053 // illegal instruction for f.cvt.h.h
    FLAGS 0, 143                  // illegal instructions and quiet NaN operations raise no flags

    // Test divide by zero with rounding mode toward zero
    li t0, 1
    csrw frm, t0    // set rounding mode = 1
    li t0, 0x3f800000
    fcvt.s.w ft1, t0
    fcvt.s.w ft2, zero
    fdiv.s ft3, ft1, ft2
    CHECKF ft1, 0xffffffff4e7e0000, 144 // 0x3f800000 = 1065353216 = 2^29 * 1.984375 converts exactly
    CHECKF ft2, 0xffffffff00000000, 145
    CHECKF ft3, 0xffffffff7f800000, 146 // x / 0 = +inf in every rounding mode
    FLAGS 0x08, 147                     // divide by zero

    # Test floating point convert to integer and using result
    fcvt.w.s a1, f0
    add a2, a1, a1
    CHECKX a1, 0x7fffffff, 148          // f0 = 0xffffffff_ffff7e00 is a NaN-boxed single NaN: 2^31 - 1
    CHECKX a2, 0xfffffffe, 149
    FLAGS 0x10, 150                     // invalid

    SC_PASS
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
