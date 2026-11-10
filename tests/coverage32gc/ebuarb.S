///////////////////////////////////////////
// ebuarb.S
//
// Written: David_Harris@hmc.edu 27 October 2026
//
// Purpose: rv32gc coverage for the EBU arbiter and the IFU bus FSM when the IFU asks for the bus while
//          the LSU holds it.  The IFU and LSU normally miss in the same cycle, when the pipeline advances.
//          A spill is the exception: the IFU fetches the second half of a spilled instruction a cycle
//          after the first, even while the pipeline is stalled.  In each sequence the first half hits in
//          the I$ in the cycle a load starts on the bus, and the second half misses in the next cycle.
//          1. The load misses in the D$, so the LSU is one beat into a 16-beat line fill when the IFU asks.
//             ebufsmarb.sv starts counting the LSU's beats only when it enters ARBITRATE, so it sees the
//             LSU's request drop (both = 0, HREADY = 1) before its own count reaches the final beat
//             (FinalBeatD = 0) and stays in ARBITRATE until the count finishes.
//          2. (RV32 port of tests/coverage64gc/icachebusbusy.S) The load reads mtime from the CLINT, and
//             the APB bridge holds HREADY low while the IFU's line fill asks for the bus
//             (buscachefsm.sv HTRANS with CacheBusRW and HREADY = 0 in ADR_PHASE).
//          The results of the loads and of the spilled instructions are checked afterwards.
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
.option norvc                   # 4-byte instructions; rvc is turned on around each .align, so the padding
main:                           # may use 2-byte nops
    SC_STRICT_TRAPS
    // 1. Load that misses in the D$, with a spill whose second half misses in the I$
    li t2, 0x55                 # the spilled addi adds 1
    la t0, coldline             # never accessed before, so the load misses
    j linea

.option rvc
.align 6                        # start of an I$ line
.option norvc
linea:
    .rept 12
    nop
    .endr
    .option rvc
    c.nop                       # puts the lw at 0x32, so the spilled addi is at 0x3E
    .option norvc
    lw t1, 0(t0)                # in the Memory stage when the addi is in Fetch
    nop
    nop
    addi t2, t2, 1              # spills into the next line, which has not been fetched yet

    .option rvc
    c.nop                       # back to a 4-byte boundary, so .align 6 pads with 4-byte nops
    .option norvc

    // 2. Uncached load from the CLINT, with a spill whose second half misses in the I$
    li t3, 0x77
    li t0, 0x0200BFF8           # CLINT mtime
    j lineb

.option rvc
.align 6
.option norvc
lineb:
    .rept 12
    nop
    .endr
    .option rvc
    c.nop
    .option norvc
    lw t4, 0(t0)                # in the Memory stage when the addi is in Fetch
    nop
    nop
    addi t3, t3, 1              # spills into the next line, which has not been fetched yet

    .option rvc
    c.nop
    .option norvc

    // The checks follow the sequences, so they do not change their timing
    li t5, 0x56
    SC_CHECK_EQ t2, t5, 1       # the first spilled addi ran once
    li t5, 0x12345678
    SC_CHECK_EQ t1, t5, 2       # the cacheable load returned its data
    li t5, 0x78
    SC_CHECK_EQ t3, t5, 3       # the second spilled addi ran once
    bnez t4, 1f                 # the load returned mtime, which has counted cycles since reset
    SC_FAIL 4
1:  li t0, 0x0200BFF8
    lw t5, 0(t0)                # mtime now, a few cycles after the load read it
    sub t5, t5, t4
    bnez t5, 2f
    SC_FAIL 5
2:  li t6, 1000
    bltu t5, t6, 3f
    SC_FAIL 6
3:  SC_PASS
    j done

.data
.align 6
coldline:
    .word 0x12345678
    .fill 15, 4, 0
