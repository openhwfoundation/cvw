///////////////////////////////////////////
// wfiSnoTW.S
//
// Written David_Harris@hmc.edu 10/16/26
//
// Purpose: A wfi in S mode with mstatus.TW = 0 has no time limit.  It waits past the point where the
//          wait counter saturates (2^WFI_TIMEOUT_BIT cycles) and must still end in the interrupt that
//          wakes it (mcause 0x8000000000000005, mepc = wfi+4), not an illegal-instruction trap.
//
// The supervisor timer interrupt (Sstc stimecmp) is not delegated, so it is enabled in S mode and
// traps to M.
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

.option norvc                   # the handler skips 4-byte instructions

main:
    la t0, ti_handler
    csrw mtvec, t0
    csrw mie, zero
    csrw mideleg, zero          # STI is taken in M, so it is enabled in S mode
    li t0, 1
    slli t0, t0, 63
    csrs menvcfg, t0            # menvcfg.STCE = 1: stimecmp drives STIP
    csrsi mcounteren, 2         # mcounteren.TM = 1: S mode can read time and write stimecmp
    li t0, -1
    csrw stimecmp, t0
    li t0, 0x20
    csrw mie, t0                # mie.STIE = 1
    li t0, 0x200000
    csrc mstatus, t0            # mstatus.TW = 0
    li a0, 1
    ecall                       # S mode

    la s3, wfi_instr
    csrr t2, time
    li t3, 0x18000              # well past the 2^16-cycle wait limit
    add t2, t2, t3
    csrw stimecmp, t2
wfi_instr:
    wfi
    nop
    la t0, trap_rec
    ld a1, 0(t0)
    ld a2, 8(t0)
    li t2, 0x8000000000000005
    SC_CHECK_EQ a1, t2, 2       # the supervisor timer interrupt, not an illegal-instruction trap
    addi t2, s3, 4
    SC_CHECK_EQ a2, t2, 3       # taken after the wfi waited, so mepc = wfi+4
    SC_PASS
    j done

.align 4
ti_handler:
    csrrw tp, mscratch, tp      # tp = trap stack
    sd t0, 0(tp)
    sd t1, -8(tp)
    csrr t0, mcause
    li t1, 8
    bge t0, t1, ti_ecall        # ecalls (8, 9, 11) go on to trap_handler
    la t1, trap_rec
    sd t0, 0(t1)                # record mcause and mepc
    csrr t0, mepc
    sd t0, 8(t1)
    li t1, -1
    csrw stimecmp, t1           # clear STIP
    csrr t1, mcause
    bltz t1, ti_ret             # interrupt: return to mepc
    addi t0, t0, 4
    csrw mepc, t0               # exception: skip the wfi
ti_ret:
    ld t1, -8(tp)
    ld t0, 0(tp)
    csrrw tp, mscratch, tp
    mret
ti_ecall:
    ld t1, -8(tp)
    ld t0, 0(tp)
    csrrw tp, mscratch, tp
    j trap_handler

.section .data
.align 3
trap_rec:
    .dword 0                    # mcause
    .dword 0                    # mepc
