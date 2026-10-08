///////////////////////////////////////////
// WALLY-selfcheck.h
//
// Written: david_harris@hmc.edu 15 September 2026
//
// Purpose: Self-check helpers for directed tests built with WALLY-init-lib.h.  A test that includes this file
//          records its outcome in selfcheck_record, which the testbench reports (see CheckSelfCheck in
//          testbench/testbench.sv): 0 = did not finish, 1 = passed, 2 = value mismatch (fields: index,
//          address, expected, actual).  Include after WALLY-init-lib.h.  The macros clobber t0 and t1.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

// SC_CHECK_EQ actual, expected, index: fail the test (status 2) if the registers differ.
.macro SC_CHECK_EQ actual, expected, index
    beq \actual, \expected, 9f
    la t0, selfcheck_record
    li t1, 2
    sd t1, 0(t0)
    li t1, \index
    sd t1, 8(t0)
    sd zero, 16(t0)
    sd \expected, 24(t0)
    sd \actual, 32(t0)
    j done
9:
.endm

// SC_CHECK_EQ_ADR actual, expected, adr, index: as SC_CHECK_EQ, also recording the address in a register.
.macro SC_CHECK_EQ_ADR actual, expected, adr, index
    beq \actual, \expected, 9f
    la t0, selfcheck_record
    li t1, 2
    sd t1, 0(t0)
    li t1, \index
    sd t1, 8(t0)
    sd \adr, 16(t0)
    sd \expected, 24(t0)
    sd \actual, 32(t0)
    j done
9:
.endm

// SC_FAIL index: unconditionally fail the test (e.g., reached an unexpected trap or path).
.macro SC_FAIL index
    la t0, selfcheck_record
    li t1, 2
    sd t1, 0(t0)
    li t1, \index
    sd t1, 8(t0)
    j done
.endm

// SC_PASS: record success.  Call right before `j done`.
.macro SC_PASS
    la t0, selfcheck_record
    li t1, 1
    sd t1, 0(t0)
.endm

// SC_STRICT_TRAPS: route traps through sc_trap_handler, which forwards ecalls (privilege changes and test
// termination) to the WALLY-init-lib.h handler but fails the test on any other exception, recording
// index 0xF0, address = mepc, expected = 0, actual = mcause.  The default handler would silently skip a
// faulting instruction, hiding a leaked page fault from a wrong-path page table walk.
.macro SC_STRICT_TRAPS
    la t0, sc_trap_handler
    csrw mtvec, t0
.endm

.section .text.main
.align 4
sc_trap_handler:
    csrrw t0, mscratch, t0      # t0 = trap stack pointer, mscratch = saved t0
    sd t1, -16(t0)
    csrr t1, mcause
    addi t1, t1, -8             # ecall from U (8), S (9), M (11)?
    beqz t1, sc_trap_ecall
    addi t1, t1, -1
    beqz t1, sc_trap_ecall
    addi t1, t1, -2
    beqz t1, sc_trap_ecall
    # unexpected exception or interrupt: fail
    la t0, selfcheck_record
    li t1, 2
    sd t1, 0(t0)
    li t1, 0xF0
    sd t1, 8(t0)
    csrr t1, mepc
    sd t1, 16(t0)
    sd zero, 24(t0)
    csrr t1, mcause
    sd t1, 32(t0)
    j done
sc_trap_ecall:
    ld t1, -16(t0)
    csrrw t0, mscratch, t0      # restore t0 and the trap stack pointer
    j trap_handler

.section .data
.align 3
    .dword 0                    # pad so selfcheck_record has its own address for the objdump label map
.globl selfcheck_record
selfcheck_record:
    .fill 8, 8, 0

.section .text.main
