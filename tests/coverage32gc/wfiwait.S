///////////////////////////////////////////
// wfiwait.S
//
// Written: David_Harris@hmc.edu 27 October 2026 (RV32 port of tests/coverage64gc/wfitimeout.S and
//          wfiSnoTW.S)
//
// Purpose: The wfi wait counter in privdec.sv saturates after 2^WFI_TIMEOUT_BIT = 2^16 cycles.  It only
//          raises an illegal instruction (TWTimeoutM) when the wfi is in S mode with mstatus.TW = 1 or in
//          U mode; otherwise the wfi keeps waiting for an interrupt.  This test saturates the counter in
//          each of the three cases on rv32gc:
//            1. M mode with mstatus.TW = 1: TW does not apply in M, so the wfi waits for the machine timer
//               interrupt (covers the (PrivilegeModeW != M_MODE)_0 and (PrivilegeModeW == U_MODE)_0 rows
//               of TWTimeoutM).
//            2. S mode with mstatus.TW = 1: the wfi times out to an illegal instruction exception.
//            3. S mode with mstatus.TW = 0: the wfi has no time limit and waits for the (Sstc) supervisor
//               timer interrupt, which is not delegated and traps to M (covers the STATUS_TW_0 row).
//          mtime increments once per cycle, so the timer deadlines of 0x14000 and 0x18000 cycles are past
//          the point where the counter saturates.
//
//          Checks (mcause, mepc, mtval of the one trap each wfi causes): failure index 10-12 (case 1:
//          machine timer interrupt with mepc = wfi+4), 20-22 (case 2: illegal instruction at the wfi with
//          mtval = the wfi encoding), 30-32 (case 3: supervisor timer interrupt with mepc = wfi+4), and
//          13 (case 1 woke no earlier than the deadline).
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

.option norvc                           # the handler skips 4-byte instructions

#define MTIME    0x0200BFF8
#define MTIMECMP 0x02004000

// CHECK_TRAP cause, epc_reg, tval, index: fail (index, index+1, index+2) unless the recorded trap had
// mcause = cause, mepc = epc_reg and mtval = tval; then clear the record.
.macro CHECK_TRAP cause, epc_reg, tval, index
    la t2, trap_rec
    lw a1, 0(t2)
    li a2, \cause
    SC_CHECK_EQ a1, a2, \index
    la t2, trap_rec
    lw a1, 4(t2)
    SC_CHECK_EQ a1, \epc_reg, \index + 1
    la t2, trap_rec
    lw a1, 8(t2)
    li a2, \tval
    SC_CHECK_EQ a1, a2, \index + 2
    la t2, trap_rec
    sw zero, 0(t2)
    sw zero, 4(t2)
    sw zero, 8(t2)
.endm

main:
    la t0, wfi_trap
    csrw mtvec, t0
    csrw mideleg, zero
    li t0, -1
    li t1, MTIMECMP
    sw t0, 4(t1)                        // mtimecmp = max (high half first)
    sw t0, 0(t1)
    csrw stimecmph, t0
    csrw stimecmp, t0

    // 1. M mode, mstatus.TW = 1: wait for a machine timer interrupt well past the time limit
    li t0, 0x200000
    csrs mstatus, t0                    // mstatus.TW = 1
    li t0, 0x80
    csrw mie, t0                        // mie.MTIE only
    li t1, MTIME
    lw t2, 0(t1)
    lw t3, 4(t1)
    li t4, 0x14000
    add t4, t2, t4                      // deadline = mtime + 0x14000 (64-bit add)
    sltu t5, t4, t2
    add t5, t3, t5
    mv s0, t4                           // deadline low half
    mv s1, t5                           // deadline high half
    li t1, MTIMECMP
    sw t4, 0(t1)                        // the high half is the maximum, so this does not trigger
    sw t5, 4(t1)
    la s2, wfi_m_next
wfi_m:
    wfi
wfi_m_next:
    nop
    CHECK_TRAP 0x80000007, s2, 0, 10
    li t1, MTIME                        // the interrupt woke the hart, so mtime has reached the deadline
    lw a1, 4(t1)
    lw a2, 0(t1)
    li a3, 1
    bltu s1, a1, 1f                     // high half past the deadline's
    bne s1, a1, 2f                      // high half before the deadline's
    bgeu a2, s0, 1f                     // same high half: compare the low halves
2:  li a3, 0
1:  li a4, 1
    SC_CHECK_EQ a3, a4, 13

    // 2. S mode, mstatus.TW = 1: no interrupt is pending or enabled, so the wfi times out
    li a0, 1
    ecall                               // S mode
    la s2, wfi_s1
wfi_s1:
    wfi
    li a0, 3
    ecall                               // M mode
    CHECK_TRAP 2, s2, 0x10500073, 20

    // 3. S mode, mstatus.TW = 0: wait for the supervisor timer interrupt (Sstc), not delegated
    li t0, 0x200000
    csrc mstatus, t0                    // mstatus.TW = 0
    li t0, 0x80000000
    csrs menvcfgh, t0                   // menvcfg.STCE = 1: stimecmp drives STIP
    csrsi mcounteren, 2                 // mcounteren.TM = 1: S mode can read time and write stimecmp
    li t0, 0x20
    csrw mie, t0                        // mie.STIE only
    li a0, 1
    ecall                               // S mode
    la s2, wfi_s2
    addi s2, s2, 4
    csrr t2, time
    csrr t3, timeh
    li t4, 0x18000                      // well past the 2^16-cycle wait limit
    add t4, t2, t4
    sltu t5, t4, t2
    add t5, t3, t5
    csrw stimecmp, t4                   // stimecmph is the maximum, so this does not trigger
    csrw stimecmph, t5
wfi_s2:
    wfi
    nop
    li a0, 3
    ecall                               // M mode
    CHECK_TRAP 0x80000005, s2, 0, 30

    SC_PASS
    j done

// Trap handler: ecalls go on to the WALLY-init-lib.h handler.  Any other trap is recorded in
// trap_rec (mcause, mepc, mtval).  Interrupts silence both timers and return to mepc; exceptions
// skip the 4-byte faulting instruction.
.align 4
wfi_trap:
    csrrw tp, mscratch, tp              // tp = trap stack
    sw t0, -8(tp)
    sw t1, -12(tp)
    csrr t0, mcause
    li t1, 8
    bge t0, t1, wfi_trap_ecall          // ecalls (8, 9, 11) go on to trap_handler; interrupts are negative
    la t1, trap_rec
    sw t0, 0(t1)
    csrr t0, mepc
    sw t0, 4(t1)
    csrr t0, mtval
    sw t0, 8(t1)
    li t0, -1
    li t1, MTIMECMP
    sw t0, 4(t1)                        // mtimecmp = max
    sw t0, 0(t1)
    csrw stimecmph, t0                  // stimecmp = max, clearing STIP
    csrw stimecmp, t0
    csrr t0, mcause
    bltz t0, wfi_trap_ret               // interrupt: return to mepc
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0                       // exception: skip the faulting instruction
wfi_trap_ret:
    lw t1, -12(tp)
    lw t0, -8(tp)
    csrrw tp, mscratch, tp
    mret
wfi_trap_ecall:
    lw t1, -12(tp)
    lw t0, -8(tp)
    csrrw tp, mscratch, tp
    j trap_handler

.section .data
.align 3
trap_rec:
    .word 0                             // mcause
    .word 0                             // mepc
    .word 0                             // mtval
