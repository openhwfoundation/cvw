///////////////////////////////////////////
// hypervisorInterrupts.S
//
// Written: Neil Chulani nchulani@g.hmc.edu 03 May 2026
//
// Purpose: Unit tests for implemented hypervisor interrupt behavior.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

// load code to initialize stack, handle interrupts, terminate
#include "WALLY-init-lib.h"

.equ CSR_HSTATUS,    0x600
.equ CSR_HIDELEG,    0x603
.equ CSR_HIE,        0x604
.equ CSR_HGEIE,      0x607
.equ CSR_HIP,        0x644
.equ CSR_HVIP,       0x645
.equ CSR_HGEIP,      0xE12
.equ CSR_VSIE,       0x204
.equ CSR_VSIP,       0x244
.equ CSR_MEDELEG,    0x302
.equ CSR_MIDELEG,    0x303
.equ CSR_MIE,        0x304
.equ CSR_SSTATUS,    0x100
.equ CSR_SEPC,       0x141
.equ CSR_SCAUSE,     0x142
.equ CSR_MCAUSE,     0x342

.equ MIE_BASE,       0x0000000000000080
.equ HSTATUS_BASE,   0x0000000200000000
.equ HSTATUS_VGEIN1, 0x0000000200001000
.equ MIDELEG_RO1,    0x0000000000001444
.equ HIDELEG_MASK,   0x0000000000000444
.equ HGEIE_MASK,     0x0000000000000002
.equ HIE_MASK,       0x0000000000001444
.equ HIE_SGEIE_MASK, 0x0000000000001000
.equ HIE_VS_MASK,    0x0000000000000444
.equ VSIE_MASK,      0x0000000000000222
.equ MIE_AFTER_HIE,  0x14C4
.equ MIE_AFTER_VSIE, 0x4C4
.equ HVIP_VSSIP_MASK,0x0000000000000004
.equ HVIP_VSTIP_MASK,0x0000000000000040
.equ HVIP_VSEIP_MASK,0x0000000000000400
.equ HS_MARKER,      0x13579BDF2468ACE0
.equ CAUSE_ILLEGAL,  2
.equ CAUSE_VSSI,     0x8000000000000002
.equ CAUSE_VSTI,     0x8000000000000006
.equ CAUSE_VSEI,     0x800000000000000A
.equ CAUSE_SGEI,     0x800000000000000C
.equ SSTATUS_SIE,    0x2
.equ HGEIP0_ADDR,    0x0200C000
.equ TRICKEN_ADDR,   0x0200A010
.equ TRICKEN_HGEIP,  0x40

.macro CHECK_CSR_RW csr, write_val, expect_val
    li t0, \write_val
    csrw \csr, t0
    csrr t1, \csr
    li t2, \expect_val
    bne t1, t2, fail
.endm

.macro CHECK_CSR_READ csr, expect_val
    csrr t1, \csr
    li t2, \expect_val
    bne t1, t2, fail
.endm

.macro CHECK_ILLEGAL_CSR_WRITE csr, write_val, expect_val
    csrw CSR_MCAUSE, zero
    li t0, \write_val
    csrw \csr, t0
    csrr t1, CSR_MCAUSE
    li t2, CAUSE_ILLEGAL
    bne t1, t2, fail
    csrr t1, \csr
    li t2, \expect_val
    bne t1, t2, fail
.endm

.macro TRIGGER_HVIP_INTERRUPT expect_cause, pending_mask, return_label
    la t0, hvip_handler
    csrw stvec, t0
    li s1, \expect_cause
    li s2, \pending_mask
    la s3, \return_label
    csrw CSR_HVIP, zero
    li t0, \pending_mask
    csrw CSR_HIE, t0
    csrsi CSR_SSTATUS, SSTATUS_SIE
    csrw CSR_HVIP, t0
    j fail
.endm

main:
    # GEILEN=1 should make VGEIN=1 legal, expose hgeie[1], and make the
    # supervisor guest external interrupt cause read-only delegated past M.
    CHECK_CSR_RW CSR_HSTATUS, 0x1000, HSTATUS_VGEIN1
    CHECK_CSR_RW CSR_HSTATUS, 0, HSTATUS_BASE
    CHECK_CSR_RW CSR_MIDELEG, 0, MIDELEG_RO1
    CHECK_CSR_RW CSR_HIDELEG, -1, HIDELEG_MASK
    CHECK_CSR_RW CSR_HGEIE, -1, HGEIE_MASK

    # H interrupt enables are stored in mie and exposed through hie.
    CHECK_CSR_RW CSR_HIE, -1, HIE_MASK
    CHECK_CSR_READ CSR_MIE, MIE_AFTER_HIE

    # VSIE writes alias into the delegated virtual interrupt-enable bits only.
    CHECK_CSR_RW CSR_HIE, 0, 0
    CHECK_CSR_READ CSR_MIE, MIE_BASE
    CHECK_CSR_RW CSR_VSIE, -1, VSIE_MASK
    CHECK_CSR_READ CSR_HIE, HIE_VS_MASK
    CHECK_CSR_READ CSR_MIE, MIE_AFTER_VSIE

    # HIP/HVIP/VSIP expose delegated virtual interrupt-pending aliases.
    CHECK_CSR_RW CSR_HVIP, 0, 0
    CHECK_CSR_RW CSR_HIP, -1, 0x4
    CHECK_CSR_READ CSR_HVIP, 0x4
    CHECK_CSR_READ CSR_VSIP, 0x2
    CHECK_CSR_RW CSR_HVIP, -1, HIDELEG_MASK
    CHECK_CSR_READ CSR_HIP, HIDELEG_MASK
    CHECK_CSR_READ CSR_VSIP, VSIE_MASK
    CHECK_CSR_RW CSR_HVIP, 0, 0
    CHECK_CSR_RW CSR_VSIP, -1, 0x2
    CHECK_CSR_READ CSR_HIP, 0x4
    CHECK_CSR_READ CSR_HVIP, 0x4
    CHECK_CSR_RW CSR_HVIP, 0, 0

    # HGEIP is source-driven and read-only from the CSR path.
    CHECK_ILLEGAL_CSR_WRITE CSR_HGEIP, -1, 0

    # Enter HS through the shared ecall helper, then drive guest external
    # interrupt sources through hvip and the local TrickBox HGEIP source.
    csrw CSR_HIDELEG, zero
    li a0, 1
    ecall

hs_mode_entry:
    li s0, HS_MARKER

    TRIGGER_HVIP_INTERRUPT CAUSE_VSSI, HVIP_VSSIP_MASK, vssi_done
vssi_done:
    TRIGGER_HVIP_INTERRUPT CAUSE_VSTI, HVIP_VSTIP_MASK, vsti_done
vsti_done:
    TRIGGER_HVIP_INTERRUPT CAUSE_VSEI, HVIP_VSEIP_MASK, vsei_done
vsei_done:

    la t0, sgei_handler
    csrw stvec, t0
    li t0, TRICKEN_ADDR
    li t1, TRICKEN_HGEIP
    sd t1, 0(t0)
    li t0, HGEIP0_ADDR
    sd zero, 0(t0)
    li t0, HGEIE_MASK
    csrw CSR_HGEIE, t0
    li t0, HIE_SGEIE_MASK
    csrw CSR_HIE, t0
    csrsi CSR_SSTATUS, SSTATUS_SIE
    li t0, HGEIP0_ADDR
    li t1, HGEIE_MASK
    sd t1, 0(t0)
    j fail

.align 4
sgei_handler:
    csrr t1, CSR_SCAUSE
    li t2, CAUSE_SGEI
    bne t1, t2, fail
    csrr t1, CSR_HGEIP
    li t2, HGEIE_MASK
    bne t1, t2, fail
    csrr t1, CSR_HIP
    li t2, HIE_SGEIE_MASK
    bne t1, t2, fail
    li t0, HGEIP0_ADDR
    sd zero, 0(t0)
    li t0, TRICKEN_ADDR
    sd zero, 0(t0)
    csrw CSR_HIE, zero
    csrw CSR_HGEIE, zero
    csrci CSR_SSTATUS, SSTATUS_SIE
    la t0, sgei_done
    csrw CSR_SEPC, t0
    sret

.align 4
hvip_handler:
    csrr t1, CSR_SCAUSE
    bne t1, s1, fail
    csrr t1, CSR_HVIP
    bne t1, s2, fail
    csrr t1, CSR_HIP
    bne t1, s2, fail
    csrw CSR_HVIP, zero
    csrw CSR_HIE, zero
    csrci CSR_SSTATUS, SSTATUS_SIE
    csrw CSR_SEPC, s3
    sret

sgei_done:
    li a0, 3
    ecall

back_in_m_from_hs:
    li t0, HS_MARKER
    bne s0, t0, fail
    csrw CSR_MIDELEG, zero
    csrw CSR_HVIP, zero
    csrw CSR_HIE, zero
    csrw CSR_HGEIE, zero
    j done

fail:
    la t1, tohost
    li t0, 3
    sw t0, 0(t1)
fail_loop:
    j fail_loop
