///////////////////////////////////////////
// hypervisorLoadStore.S
//
// Written: Neil Chulani nchulani@g.hmc.edu 6 May 2026
//
// Purpose: Unit tests for implemented hypervisor virtual-machine load/store
//          behavior with VS-stage and G-stage translation both Bare.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

// load code to initialize stack, handle interrupts, terminate
#include "WALLY-init-lib.h"

.equ CSR_MSTATUS,       0x300
.equ CSR_HSTATUS,       0x600
.equ CSR_HGATP,         0x680
.equ CSR_VSATP,         0x280
.equ CSR_SATP,          0x180

.equ MSTATUS_MPP_MASK,  0x0000000000001800
.equ HSTATUS_SPVP,      0x0000000000000100
.equ HSTATUS_HU,        0x0000000000000200

.equ X_T0,              5
.equ X_T1,              6
.equ X_T2,              7

.macro CHECK_EQ actual_reg, expect_val
    li t6, \expect_val
    bne \actual_reg, t6, fail
.endm

.macro HLV_B rd, rs1
    .word 0x60004073 | (\rd << 7) | (\rs1 << 15)
.endm

.macro HLV_BU rd, rs1
    .word 0x60104073 | (\rd << 7) | (\rs1 << 15)
.endm

.macro HLV_H rd, rs1
    .word 0x64004073 | (\rd << 7) | (\rs1 << 15)
.endm

.macro HLV_HU rd, rs1
    .word 0x64104073 | (\rd << 7) | (\rs1 << 15)
.endm

.macro HLV_W rd, rs1
    .word 0x68004073 | (\rd << 7) | (\rs1 << 15)
.endm

.macro HLV_WU rd, rs1
    .word 0x68104073 | (\rd << 7) | (\rs1 << 15)
.endm

.macro HLV_D rd, rs1
    .word 0x6C004073 | (\rd << 7) | (\rs1 << 15)
.endm

.macro HLVX_HU rd, rs1
    .word 0x64304073 | (\rd << 7) | (\rs1 << 15)
.endm

.macro HLVX_WU rd, rs1
    .word 0x68304073 | (\rd << 7) | (\rs1 << 15)
.endm

.macro HSV_B rs1, rs2
    .word 0x62004073 | (\rs1 << 15) | (\rs2 << 20)
.endm

.macro HSV_H rs1, rs2
    .word 0x66004073 | (\rs1 << 15) | (\rs2 << 20)
.endm

.macro HSV_W rs1, rs2
    .word 0x6A004073 | (\rs1 << 15) | (\rs2 << 20)
.endm

.macro HSV_D rs1, rs2
    .word 0x6E004073 | (\rs1 << 15) | (\rs2 << 20)
.endm

main:
    # The first RTL path intentionally covers the architecturally legal
    # Bare/Bare case. Full two-stage translation coverage belongs with the
    # later G-stage/VS-stage walker work.
    csrw CSR_SATP, zero
    csrw CSR_VSATP, zero
    csrw CSR_HGATP, zero

    # SPVP=1 makes HLV/HLVX/HSV accesses act as VS-level accesses per the H spec.
    li t0, HSTATUS_SPVP
    csrw CSR_HSTATUS, t0

    la t1, hlsv_data

    HLV_B X_T0, X_T1
    CHECK_EQ t0, -128

    HLV_BU X_T0, X_T1
    CHECK_EQ t0, 0x80

    HLV_H X_T0, X_T1
    CHECK_EQ t0, 0xFFFFFFFFFFFF8080

    HLV_HU X_T0, X_T1
    CHECK_EQ t0, 0x8080

    HLV_W X_T0, X_T1
    CHECK_EQ t0, 0xFFFFFFFF81348080

    HLV_WU X_T0, X_T1
    CHECK_EQ t0, 0x81348080

    HLV_D X_T0, X_T1
    CHECK_EQ t0, 0x8877665581348080

    HLVX_HU X_T0, X_T1
    CHECK_EQ t0, 0x8080

    HLVX_WU X_T0, X_T1
    CHECK_EQ t0, 0x81348080

    la t1, hlsv_store
    sd zero, 0(t1)
    li t0, 0xAA
    HSV_B X_T1, X_T0
    lbu t2, 0(t1)
    CHECK_EQ t2, 0xAA

    sd zero, 0(t1)
    li t0, 0xBEEF
    HSV_H X_T1, X_T0
    lhu t2, 0(t1)
    CHECK_EQ t2, 0xBEEF

    sd zero, 0(t1)
    li t0, 0x89ABCDEF
    HSV_W X_T1, X_T0
    lwu t2, 0(t1)
    CHECK_EQ t2, 0x89ABCDEF

    sd zero, 0(t1)
    li t0, 0x0123456789ABCDEF
    HSV_D X_T1, X_T0
    ld t2, 0(t1)
    CHECK_EQ t2, 0x0123456789ABCDEF

    # HU=1 allows U-mode HLV/HLVX/HSV use in the same way as HS-mode.
    li t0, HSTATUS_SPVP | HSTATUS_HU
    csrw CSR_HSTATUS, t0
    la t0, u_hlsv_entry
    csrw mepc, t0
    li t0, MSTATUS_MPP_MASK
    csrc CSR_MSTATUS, t0
    mret

u_return_to_m:
    la t1, hlsv_user_store
    lbu t2, 0(t1)
    CHECK_EQ t2, 0x5A

    j done

.align 4
u_hlsv_entry:
    la t1, hlsv_data
    HLV_BU X_T2, X_T1
    CHECK_EQ t2, 0x80

    la t1, hlsv_user_store
    li t0, 0x5A
    HSV_B X_T1, X_T0

    li a0, 3
    ecall
    j u_return_to_m

fail:
    la t1, tohost
    li t0, 3
    sw t0, 0(t1)
fail_loop:
    j fail_loop

.section .data
.align 3
hlsv_data:
    .dword 0x8877665581348080
hlsv_store:
    .dword 0
hlsv_user_store:
    .dword 0
