///////////////////////////////////////////
// fpdecode.S
//
// Written: David_Harris@hmc.edu 27 October 2026
//
// Purpose: RV32-specific decode and FPU corner cases on rv32gc:
//          - Reserved OP-FP encodings next to the RV32-only Zfa moves and the fmv/fli groups: funct3 != 0
//            with funct7 = fmv.x.w (rs2 = 0), fmvh.x.d (rs2 = 1), fmv.w.x (rs2 = 0), fli.s (rs2 = 1) and
//            fmvp.d.x.  Each is an illegal instruction (fctrl.sv Funct3D == 0 conditions).
//          - Reserved compressed encodings: c.addi16sp with imm = 0 and c.lwsp with rd = x0
//            (decompress.sv immCIASP != 0 and c.lwsp rds1 != 0 conditions).
//          - sret with rs1 != 0, which is reserved and so illegal in M mode (privdec.sv rs1zeroM).
//          - fsqrt with f0 = +0: fsqrt has rs2 = 0, so the divider's Y operand is f0, and a zero Y must not
//            raise divide-by-zero for a square root (flags.sv DivByZero Sqrt term).
//          - fdiv.d finishing while an injected ExternalStall holds the pipeline (fdivsqrtfsm.sv DONE with
//            StallM): the testbench stall injector (slti x0, x0, imm with imm = {length, delay}) starts a
//            stall right after the divide starts, so the divider reaches DONE with StallM = 1.
//
//          Checks: each reserved encoding traps with mcause = 2 at its own address (failure index n,
//          n + 1); the square roots are exact with no flags raised (60-63); every stalled divide returns
//          the right quotient (70) with no flags (71).
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

// RESERVED16 encoding, index: the 16-bit encoding must raise an illegal instruction at its own address;
// the WALLY-init-lib.h handler then skips it (mepc + 2).
.macro RESERVED16 encoding, index
    csrw mcause, zero
1:
    .2byte \encoding
    csrr t2, mcause
    li t3, 2
    SC_CHECK_EQ t2, t3, \index
    csrr t2, mepc
    la t3, 1b + 2
    SC_CHECK_EQ t2, t3, \index + 1
.endm

// RESERVED32 encoding, index: as RESERVED16 for a 32-bit encoding (mepc + 4).
.macro RESERVED32 encoding, index
    csrw mcause, zero
1:
    .4byte \encoding
    csrr t2, mcause
    li t3, 2
    SC_CHECK_EQ t2, t3, \index
    csrr t2, mepc
    la t3, 1b + 4
    SC_CHECK_EQ t2, t3, \index + 1
.endm

main:
    li t0, 0x2000
    csrs mstatus, t0                    // mstatus.FS = Initial
    csrwi frm, 0                        // round to nearest even

    // Reserved OP-FP encodings (funct3 = 010, a supported static rounding mode, so fctrl reaches the
    // funct7 cases)
    RESERVED32 0xe000a2d3, 10           // funct7 = 1110000 (fmv.x.w), rs2 = 0, funct3 != 000/001
    RESERVED32 0xe210a2d3, 12           // funct7 = 1110001 (fmvh.x.d), rs2 = 1, funct3 != 000
    RESERVED32 0xf002a0d3, 14           // funct7 = 1111000 (fmv.w.x), rs2 = 0, funct3 != 000
    RESERVED32 0xf01020d3, 16           // funct7 = 1111000 (fli.s), rs2 = 1, funct3 != 000
    RESERVED32 0xb262a0d3, 18           // funct7 = 1011001 (fmvp.d.x), funct3 != 000

    // Reserved compressed encodings
    RESERVED16 0x6101, 30               // c.addi16sp with nzimm = 0
    RESERVED16 0x4002, 32               // c.lwsp with rd = x0

    // sret with rs1 = x31 is reserved
    RESERVED32 0x102F8073, 40

    // fsqrt with f0 = +0 (the unused Y operand) is exact, with no divide-by-zero
    fcvt.d.w f0, zero                   // f0 = +0.0 (double)
    li t0, 16
    fcvt.d.w f1, t0
    csrw fflags, zero
    fsqrt.d f2, f1
    fcvt.w.d a1, f2
    li a2, 4
    SC_CHECK_EQ a1, a2, 60
    csrr a1, fflags
    SC_CHECK_EQ a1, zero, 61
    fmv.w.x f0, zero                    // f0 = +0.0 (single, NaN-boxed)
    fcvt.s.w f1, t0
    fsqrt.s f2, f1
    fcvt.w.s a1, f2
    SC_CHECK_EQ a1, a2, 62
    csrr a1, fflags
    SC_CHECK_EQ a1, zero, 63

    // fdiv.d completing during an ExternalStall.  The injector is armed when the slti retires in M,
    // the cycle the fdiv starts in E; a stall of 31 cycles starting delay cycles later then covers the
    // divide's last cycle for small delays.  The quotient 96/8 = 12 is exact.
    li t0, 96
    fcvt.d.w f4, t0
    li t0, 8
    fcvt.d.w f5, t0
    li a2, 12
    .set d, 0
    .rept 8
    slti x0, x0, (31 << 6) | d
    fdiv.d f6, f4, f5
    fcvt.w.d a1, f6
    SC_CHECK_EQ a1, a2, 70
    .set d, d+1
    .endr
    csrr a1, fflags
    SC_CHECK_EQ a1, zero, 71

    SC_PASS
    j done
