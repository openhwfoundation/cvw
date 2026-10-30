///////////////////////////////////////////
// WALLY-env.h
//
// Purpose: Minimal program environment for the self-checking peripheral tests.
//          Provides the halt sequence and signature area that the Wally testbench expects:
//            - the test ends by storing to tohost (the testbench stops on that store)
//            - begin_signature marks the start of the signature area; the test's own
//              sig_end_canary label marks its end
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

// Register width.  Signature entries, test table entries, and saved registers are XLEN bits wide.
#if __riscv_xlen == 64
#define LREG     ld
#define SREG     sd
#define WORD     .8byte
#define REGBYTES 8
#define REGSHIFT 3
#else
#define LREG     lw
#define SREG     sw
#define WORD     .4byte
#define REGBYTES 4
#define REGSHIFT 2
#endif
#define SEXT32(x) ((x) - (((x) >> 31) << 32))   // sign extend a 32-bit constant to XLEN bits

// End of test: store 1 to tohost to tell the simulator the test is done, then spin.
// The self-check failure handlers also jump to write_tohost after recording the failure.
.macro TEST_HALT
    li x1, 1
write_tohost:
    sw x1, tohost, t0
    j write_tohost
.endm

// Start of the signature area.  Also allocates tohost in its own section, as the linker script expects.
.macro SIGNATURE_BEGIN
    .section .tohost, "aw", @progbits
    .align 3
    .globl tohost
tohost:
    .dword 0
    .data
    .align 4
    .globl begin_signature
begin_signature:
.endm
