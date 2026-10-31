///////////////////////////////////////////
// decode.S
//
// Written: david_harris@hmc.edu 27 October 2026
//
// Purpose: rv32imc decoder coverage (trl5 group D).  Executes the compressed and 32-bit encodings
//          that are reserved on rv32imc or belong to extensions it lacks (F, D, Zcb, A, RV64-only
//          opcodes, sfence.vma without S mode), each of which must raise an illegal instruction
//          exception, base opcodes with reserved funct3/funct7 fields (ld, sd, slli with a bad funct7,
//          an OP funct7, branch funct3 010, jalr funct3 001, SYSTEM funct3 100, ebreak with rs1 = x1),
//          and the compressed HINT encodings, which must execute as nops.
//          Also runs addi HINTs whose immediate equals the sfence.w.inval / sfence.inval.ir
//          funct12, which privdec decodes from the instruction bits whatever the opcode.
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

// RESERVED16 encoding, index: the 16-bit encoding must trap as an illegal instruction (mcause 2) with
// mepc at the encoding and mtval holding it.  The library handler returns past it (mepc + 2).
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
    csrr t2, mtval
    li t3, \encoding
    SC_CHECK_EQ t2, t3, \index + 2
.endm

// RESERVED32 encoding, index: as RESERVED16 for a 32-bit encoding (the handler returns to mepc + 4).
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
    csrr t2, mtval
    li t3, \encoding
    SC_CHECK_EQ t2, t3, \index + 2
.endm

// HINT16 encoding, index: the 16-bit HINT must execute as a nop: no trap, x8 unchanged.
.macro HINT16 encoding, index
    csrw mcause, zero
    li x8, 0x1234
    .2byte \encoding
    csrr t2, mcause
    SC_CHECK_EQ t2, zero, \index
    li t3, 0x1234
    SC_CHECK_EQ x8, t3, \index + 1
.endm

main:
    // Compressed quadrant 0: c.fld, c.flw (RV32), c.lbu (Zcb), c.fsd, c.fsw (RV32) need D, F or Zcb
    RESERVED16 0x2000, 1        // c.fld  f8, 0(x8)
    RESERVED16 0x6000, 4        // c.flw  f8, 0(x8)
    RESERVED16 0x8000, 7        // c.lbu  x8, 0(x8)
    RESERVED16 0xA000, 10       // c.fsd  f8, 0(x8)
    RESERVED16 0xE000, 13       // c.fsw  f8, 0(x8)

    // Compressed quadrant 1 reserved encodings
    RESERVED16 0x6101, 16       // c.addi16sp with nzimm = 0
    RESERVED16 0x6401, 19       // c.lui x8 with nzimm = 0
    RESERVED16 0x9005, 22       // c.srli x8 with shamt[5] = 1 (RV32C)
    RESERVED16 0x9405, 25       // c.srai x8 with shamt[5] = 1 (RV32C)
    RESERVED16 0x9C01, 28       // instr[12:10] = 111: c.subw on RV64, reserved on RV32

    // Compressed quadrant 2
    RESERVED16 0x1402, 31       // c.slli x8 with shamt[5] = 1 (RV32C)
    RESERVED16 0x2002, 34       // c.fldsp f0
    RESERVED16 0x4002, 37       // c.lwsp with rd = x0
    RESERVED16 0x6002, 40       // c.flwsp f0 (RV32)
    RESERVED16 0x8002, 43       // c.jr with rs1 = x0
    RESERVED16 0xA002, 46       // c.fsdsp f0
    RESERVED16 0xE002, 49       // c.fswsp f0 (RV32)

    // Compressed HINTs execute as nops
    HINT16 0x0402, 52           // c.slli x8, 0 (shamt = 0)
    HINT16 0x0006, 54           // c.slli x0, 1 (rd = x0)

    // 32-bit opcodes of extensions rv32imc lacks
    RESERVED32 0x00002007, 56   // flw f0, 0(x0)
    RESERVED32 0x00002027, 59   // fsw f0, 0(x0)
    RESERVED32 0x0000202F, 62   // amoadd.w x0, x0, (x0) (funct3 = 010)
    RESERVED32 0x0000002F, 65   // AMO opcode with funct3 = 000
    RESERVED32 0x0000001B, 68   // addiw x0, x0, 0 (OP-IMM-32, RV64 only)
    RESERVED32 0x0000003B, 71   // addw x0, x0, x0 (OP-32, RV64 only)
    RESERVED32 0x12000073, 74   // sfence.vma x0, x0: no S mode

    // Base opcodes with a reserved funct3/funct7: the controller's per-opcode legality checks fail
    RESERVED32 0x00003003, 80   // LOAD funct3 011 (ld, RV64 only)
    RESERVED32 0x40001013, 83   // OP-IMM slli with funct7 0100000
    RESERVED32 0x00003023, 86   // STORE funct3 011 (sd, RV64 only)
    RESERVED32 0x04000033, 89   // OP with funct7 0000010
    RESERVED32 0x00002063, 92   // BRANCH funct3 010
    RESERVED32 0x00001067, 95   // JALR funct3 001
    RESERVED32 0x00004073, 98   // SYSTEM funct3 100
    RESERVED32 0x00108073, 101  // ebreak's funct12 with rs1 = x1: privdec requires rs1 = 0

    // addi HINTs (rd = x0) and an addi whose immediate is the sfence.w.inval (0x180) or
    // sfence.inval.ir (0x181) funct12, with rs1 and rd each zero and nonzero
    csrw mcause, zero
    li t1, 0x55
    addi x0, x0, 0x180
    addi x0, t1, 0x180
    addi t2, x0, 0x180
    addi x0, x0, 0x181
    addi x0, t1, 0x181
    addi t3, x0, 0x181
    csrr t4, mcause
    SC_CHECK_EQ t4, zero, 77
    li t4, 0x180
    SC_CHECK_EQ t2, t4, 78
    li t4, 0x181
    SC_CHECK_EQ t3, t4, 79

    SC_PASS
    j done
