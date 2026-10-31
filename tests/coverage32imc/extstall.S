///////////////////////////////////////////
// extstall.S
//
// Written: david_harris@hmc.edu 27 October 2026
//
// Purpose: rv32imc stall/flush interactions (trl5 group D), mostly driven by the testbench's
//          ExternalStall injector: retiring the HINT slti x0, x0, imm with imm = {length[5:0], delay[5:0]}
//          holds ExternalStall (and so StallW and every earlier stage) for length cycles starting delay
//          cycles later.  The test sweeps the delay so the stall lands on each cycle of:
//          1. an integer divide: the divider sees StallM when the divide enters Execute (it must not
//             start) and when it finishes (it must hold DONE until the stall ends);
//          2. a load from a bus peripheral: the LSU bus FSM sees the stall in its MEM3 state;
//          3. a wait for a machine timer interrupt: the interrupt becomes pending while StallW is high.
//          It also runs a CSR write directly followed by a divide, so the CSR write's flush of Execute
//          coincides with the divider starting.
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

#define MTIME      0x0200BFF8
#define MTIMECMP   0x02004000
#define MCAUSE_MTI 0x80000007
#define SPI_BASE   0x10040000

// STALL len, dly: arm the testbench ExternalStall injector
.macro STALL len, dly
    slti x0, x0, ((\len) << 6) | (\dly)
.endm

// TRYDIV dly: divide 1000 / 7 with a 4-cycle external stall starting dly cycles after the HINT
.macro TRYDIV dly
    li a1, 1000
    li a2, 7
    STALL 4, \dly
    div a0, a1, a2
    rem a3, a1, a2
    li t2, 142
    SC_CHECK_EQ a0, t2, 100 + \dly
    li t2, 6
    SC_CHECK_EQ a3, t2, 200 + \dly
.endm

// TRYLOAD dly: read SPI sckdiv (reset value 3) with a 2-cycle external stall dly cycles after the HINT
.macro TRYLOAD dly
    li t1, SPI_BASE
    STALL 2, \dly
    lw a0, 0(t1)
    li t2, 3
    SC_CHECK_EQ a0, t2, 300 + \dly
.endm

main:
    csrci mstatus, 8            // MIE = 0 until part 3

    // 1. Divides
    .set d, 0
    .rept 40
    TRYDIV d
    .set d, d+1
    .endr

    // A CSR write immediately followed by a divide: the CSR write in Memory flushes Execute in the
    // cycle the divider would start.
    li a1, 99
    li a2, 9
    csrr t3, mscratch
    csrw mscratch, t3
    div a0, a1, a2
    li t2, 11
    SC_CHECK_EQ a0, t2, 250

    // 2. Peripheral loads
    .set d, 0
    .rept 10
    TRYLOAD d
    .set d, d+1
    .endr

    // 3. Machine timer interrupts while the pipeline is externally stalled.  Each pass schedules
    //    the interrupt a few cycles further out and waits in a loop that is externally stalled
    //    31 of every ~35 cycles.
    la t0, ti_trap
    csrw mtvec, t0
    li s3, 0                    // interrupts taken
    li s5, 0                    // pass
    li s6, 8                    // passes
4:  mv s7, s3
    li t2, MTIME
    lw t3, 0(t2)
    lw t4, 4(t2)
    addi t5, t3, 100
    add t5, t5, s5              // stagger the interrupt from pass to pass
    sltu t6, t5, t3
    add t4, t4, t6
    li t2, MTIMECMP
    li t6, -1
    sw t6, 4(t2)
    sw t5, 0(t2)
    sw t4, 4(t2)
    csrsi mstatus, 8            // MIE = 1
    li t3, 200                  // give up eventually; the count check then fails
1:  STALL 31, 0
    bne s3, s7, 2f
    addi t3, t3, -1
    bnez t3, 1b
2:  csrci mstatus, 8
    addi s5, s5, 1
    blt s5, s6, 4b
    SC_CHECK_EQ s3, s6, 400     // one interrupt per pass

    la t0, trap_handler
    csrw mtvec, t0
    SC_PASS
    j done

.align 4
ti_trap:
    csrrw tp, mscratch, tp
    sw t0, 0(tp)
    sw t1, -4(tp)
    csrr t0, mcause
    li t1, MCAUSE_MTI
    bne t0, t1, ti_bad
    li t0, -1
    li t1, MTIMECMP
    sw t0, 4(t1)                // no further timer interrupt
    sw t0, 0(t1)
    addi s3, s3, 1
    li t0, 0x80                 // return with MIE clear (MPIE = 0) so the loop exit is not interrupted
    csrc mstatus, t0
    lw t1, -4(tp)
    lw t0, 0(tp)
    csrrw tp, mscratch, tp
    mret
ti_bad:
    SC_FAIL 0xF1                // an exception or other interrupt
