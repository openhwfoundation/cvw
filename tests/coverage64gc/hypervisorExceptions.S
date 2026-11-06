///////////////////////////////////////////
// hypervisorExceptions.S
//
// Written: Neil Chulani nchulani@g.hmc.edu 26 April 2026
//
// Purpose: Unit tests for implemented hypervisor exception behavior.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

// load code to initialize stack, handle interrupts, terminate
#include "WALLY-init-lib.h"

.equ CSR_MSTATUS,       0x300
.equ CSR_MEDELEG,       0x302
.equ CSR_MTVEC,         0x305
.equ CSR_MCAUSE,        0x342
.equ CSR_MTVAL,         0x343
.equ CSR_HSTATUS,       0x600
.equ CSR_HEDELEG,       0x602
.equ CSR_HENVCFG,       0x60A
.equ CSR_HGATP,         0x680
.equ CSR_MENVCFG,       0x30A
.equ CSR_SENVCFG,       0x10A
.equ CSR_VSATP,         0x280

.equ CAUSE_ILLEGAL,     2
.equ CAUSE_VIRTUAL,     22
.equ CAUSE_VS_ECALL,    10

.equ MSTATUS_MPP_MASK,  0x0000000000001800
.equ MSTATUS_MPP_S,     0x0000000000000800
.equ MSTATUS_MPP_M,     0x0000000000001800
.equ MSTATUS_MPV,       0x0000008000000000
.equ MSTATUS_TVM,       0x0000000000100000
.equ HSTATUS_VTVM,      0x0000000000100000
.equ HSTATUS_VTSR,      0x0000000000400000
.equ ENVCFG_CBO_ALL,    0x00000000000000F0

.equ INST_CSRR_HSTATUS, 0x600022F3
.equ INST_HFENCE_VVMA,  0x22000073
.equ INST_HLV_B,        0x600040F3
.equ INST_CBO_FLUSH,    0x0020200F
.equ INST_CSRR_SATP,    0x180022F3
.equ INST_SRET,         0x10200073
.equ INST_HFENCE_GVMA,  0x62000073

.equ NUM_VS_TRAPS,      6

.macro CHECK_EQ actual_reg, expect_val
    li t6, \expect_val
    bne \actual_reg, t6, fail
.endm

.macro CHECK_TRAP idx, expect_cause, expect_tval
    li t3, \idx
    slli t3, t3, 3
    la t4, trap_causes
    add t4, t4, t3
    ld t5, 0(t4)
    CHECK_EQ t5, \expect_cause
    la t4, trap_tvals
    add t4, t4, t3
    ld t5, 0(t4)
    CHECK_EQ t5, \expect_tval
.endm

main:
    csrr s1, CSR_MTVEC

    # Keep guest-stage and VS-stage translation disabled. These tests only
    # exercise exception classification, not guest page faults.
    csrw CSR_HGATP, zero
    csrw CSR_VSATP, zero
    csrw CSR_HEDELEG, zero
    csrw CSR_MEDELEG, zero

    # VTVM/VTSR make VS-mode SATP and SRET attempts virtual-instruction traps.
    li t0, HSTATUS_VTVM | HSTATUS_VTSR
    csrw CSR_HSTATUS, t0

    # Enable CBO below M, but leave henvcfg/senvcfg disabled so V-mode CBO
    # attempts are HS-qualified and blocked by virtual envcfg state.
    li t0, ENVCFG_CBO_ALL
    csrw CSR_MENVCFG, t0
    csrw CSR_HENVCFG, zero
    csrw CSR_SENVCFG, zero

    la t0, trap_count
    sd zero, 0(t0)
    # Use a local M-mode trap handler for the VS exception block. The shared
    # WALLY-init-lib handler skips exceptions, but it does not keep the per-trap
    # mcause/mtval history this test checks after returning to M-mode.
    la t0, m_trap_record
    csrw CSR_MTVEC, t0

    # Enter VS-mode with mret: MPP=S and MPV=1.
    la t0, vs_exception_entry
    csrw mepc, t0
    li t0, MSTATUS_MPP_MASK | MSTATUS_MPV
    csrc CSR_MSTATUS, t0
    li t0, MSTATUS_MPP_S | MSTATUS_MPV
    csrs CSR_MSTATUS, t0
    mret

after_vs_block:
    csrw CSR_MTVEC, s1

    la t0, trap_count
    ld t1, 0(t0)
    CHECK_EQ t1, NUM_VS_TRAPS

    CHECK_TRAP 0, CAUSE_VIRTUAL, INST_CSRR_HSTATUS
    CHECK_TRAP 1, CAUSE_VIRTUAL, INST_HFENCE_VVMA
    CHECK_TRAP 2, CAUSE_VIRTUAL, INST_HLV_B
    CHECK_TRAP 3, CAUSE_VIRTUAL, INST_CBO_FLUSH
    CHECK_TRAP 4, CAUSE_VIRTUAL, INST_CSRR_SATP
    CHECK_TRAP 5, CAUSE_VIRTUAL, INST_SRET

    # In HS-mode, HFENCE.GVMA is illegal when mstatus.TVM=1. Delegate illegal
    # instruction to HS so the HS trap CSRs are updated and checked locally.
    li t0, 0x4
    csrw CSR_MEDELEG, t0
    la t0, hs_trap_handler
    csrw stvec, t0
    li t0, MSTATUS_TVM
    csrs CSR_MSTATUS, t0

    li a0, 1
    ecall

hs_tvm_entry:
    csrw scause, zero
    csrw stval, zero
    .word INST_HFENCE_GVMA
    csrr t0, scause
    CHECK_EQ t0, CAUSE_ILLEGAL
    csrr t0, stval
    CHECK_EQ t0, INST_HFENCE_GVMA

    li a0, 3
    ecall

back_from_hs:
    li t0, MSTATUS_TVM
    csrc CSR_MSTATUS, t0
    csrw CSR_MEDELEG, zero
    j done

.align 4
m_trap_record:
    # Temporary M-mode trap handler for expected VS-mode traps. Records each
    # trap's mcause and mtval, skips the faulting 32-bit instruction, and returns
    # to VS-mode so the next exception case can run.
    csrr t0, CSR_MCAUSE
    li t1, CAUSE_VS_ECALL
    beq t0, t1, m_trap_return_from_vs

    # Use trap_count as the array index. Any extra unexpected trap fails.
    la t1, trap_count
    ld t2, 0(t1)
    li t3, NUM_VS_TRAPS
    bgeu t2, t3, fail

    # Store mcause in trap_causes[index].
    slli t3, t2, 3
    la t4, trap_causes
    add t4, t4, t3
    sd t0, 0(t4)

    # Store mtval in trap_tvals[index].
    csrr t5, CSR_MTVAL
    la t4, trap_tvals
    add t4, t4, t3
    sd t5, 0(t4)

    addi t2, t2, 1
    sd t2, 0(t1)

    # All VS test instructions are 32-bit .word encodings, so advance mepc by 4.
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0
    mret

m_trap_return_from_vs:
    la t0, after_vs_block
    csrw mepc, t0
    li t0, MSTATUS_MPP_MASK | MSTATUS_MPV
    csrc CSR_MSTATUS, t0
    li t0, MSTATUS_MPP_M
    csrs CSR_MSTATUS, t0
    mret

.align 4
hs_trap_handler:
    csrr t0, sepc
    addi t0, t0, 4
    csrw sepc, t0
    sret

.align 4
vs_exception_entry:
    .word INST_CSRR_HSTATUS
    .word INST_HFENCE_VVMA
    .word INST_HLV_B
    .word INST_CBO_FLUSH
    .word INST_CSRR_SATP
    .word INST_SRET
    li a0, 0
    ecall

fail:
    la t1, tohost
    li t0, 3
    sw t0, 0(t1)
fail_loop:
    j fail_loop

.section .data
.align 3
trap_count:
    .dword 0
trap_causes:
    .fill NUM_VS_TRAPS, 8, 0
trap_tvals:
    .fill NUM_VS_TRAPS, 8, 0
