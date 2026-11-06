///////////////////////////////////////////
// hypervisorUnitTests.S
//
// Written: Neil Chulani nchulani@g.hmc.edu 22 April 2026
//
// Purpose: Unit tests for implemented hypervisor CSR and decode behavior.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

// load code to initialize stack, handle interrupts, terminate
#include "WALLY-init-lib.h"

.equ CSR_HEDELEG,    0x602
.equ CSR_HIDELEG,    0x603
.equ CSR_HIE,        0x604
.equ CSR_HSTATUS,    0x600
.equ CSR_HTIMEDELTA, 0x605
.equ CSR_HCOUNTEREN, 0x606
.equ CSR_HGEIE,      0x607
.equ CSR_HENVCFG,    0x60A
.equ CSR_HTVAL,      0x643
.equ CSR_HIP,        0x644
.equ CSR_HVIP,       0x645
.equ CSR_HTINST,     0x64A
.equ CSR_HGATP,      0x680
.equ CSR_HGEIP,      0xE12
.equ CSR_VSSTATUS,   0x200
.equ CSR_VSIE,       0x204
.equ CSR_VSTVEC,     0x205
.equ CSR_VSSCRATCH,  0x240
.equ CSR_VSEPC,      0x241
.equ CSR_VSCAUSE,    0x242
.equ CSR_VSTVAL,     0x243
.equ CSR_VSIP,       0x244
.equ CSR_VSATP,      0x280
.equ CSR_VSTIMECMP,  0x24D
.equ CSR_MENVCFG,    0x30A
.equ CSR_MEDELEG,    0x302
.equ CSR_MIDELEG,    0x303
.equ CSR_MIE,        0x304
.equ CSR_SSTATUS,    0x100
.equ CSR_SEPC,       0x141
.equ CSR_SCAUSE,     0x142
.equ CSR_MCAUSE,     0x342
.equ CSR_MTINST,     0x34A
.equ CSR_MTVAL2,     0x34B

.equ MIE_BASE,       0x0000000000000080
.equ HSTATUS_BASE,   0x0000000200000000
.equ HSTATUS_EXPECT, 0x00000002007003E0
.equ HSTATUS_VGEIN1, 0x0000000200001000
.equ HEDELEG_MASK,   0x000000000000B1FE
.equ MIDELEG_RO1,    0x0000000000001444
.equ HIDELEG_MASK,   0x0000000000000444
.equ HGEIE_MASK,     0x0000000000000002
.equ HIE_MASK,       0x0000000000001444
.equ HIE_SGEIE_MASK, 0x0000000000001000
.equ HIE_VS_MASK,    0x0000000000000444
.equ VSIE_MASK,      0x0000000000000222
.equ MIE_AFTER_HIE,  0x14C4
.equ MIE_AFTER_VSIE, 0x4C4
.equ HCOUNTEREN_VAL, 0x00000000A5A55A5A
.equ HENVCFG_EXPECT, 0xE0000000000000F1
.equ HTIMEDELTA_VAL, 0x0123456789ABCDEF
.equ HTVAL_VAL,      0x1111222233334444
.equ HTINST_VAL,     0x5555666677778888
.equ HGATP_WRITE,    0x8000000000000123
.equ HGATP_EXPECT,   0x8000000000000120
.equ VSSTATUS_EXPECT,0x80000002000C6162
.equ VSTVEC_WRITE,   0x0000000080000123
.equ VSTVEC_EXPECT,  0x0000000080000101
.equ VSSCRATCH_VAL,  0x89ABCDEF01234567
.equ VSEPC_VAL,      0x0000000080001234
.equ VSCAUSE_VAL,    0x800000000000000A
.equ VSTVAL_VAL,     0x123456789ABCDEF0
.equ VSATP_VAL,      0x8000000000000456
.equ HS_STVEC_VAL,   0x0000000080000201
.equ HS_MARKER,      0x13579BDF2468ACE0
.equ MTINST_VAL,     0xDEADBEEFCAFEBABE
.equ MTVAL2_VAL,     0x0BADF00D12345678
.equ CAUSE_ILLEGAL,  2
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

main:
    # Hypervisor-extension CSRs are writable from M-mode; use that path to
    # exercise implemented H/VS register state without needing a full guest setup.
    CHECK_CSR_RW CSR_MTINST, MTINST_VAL, MTINST_VAL
    CHECK_CSR_RW CSR_MTVAL2, MTVAL2_VAL, MTVAL2_VAL
    CHECK_CSR_RW CSR_HSTATUS, -1, HSTATUS_EXPECT
    CHECK_CSR_RW CSR_HSTATUS, 0x1000, HSTATUS_VGEIN1
    CHECK_CSR_RW CSR_HSTATUS, 0, HSTATUS_BASE
    CHECK_CSR_RW CSR_HEDELEG, -1, HEDELEG_MASK
    CHECK_CSR_RW CSR_MIDELEG, 0, MIDELEG_RO1
    CHECK_CSR_RW CSR_HIDELEG, -1, HIDELEG_MASK
    CHECK_CSR_RW CSR_HCOUNTEREN, HCOUNTEREN_VAL, HCOUNTEREN_VAL
    CHECK_CSR_RW CSR_HGEIE, -1, HGEIE_MASK
    CHECK_CSR_RW CSR_HTVAL, HTVAL_VAL, HTVAL_VAL
    CHECK_CSR_RW CSR_HTINST, HTINST_VAL, HTINST_VAL
    CHECK_CSR_RW CSR_HGATP, HGATP_WRITE, HGATP_EXPECT

    CHECK_CSR_RW CSR_VSSTATUS, -1, VSSTATUS_EXPECT
    CHECK_CSR_RW CSR_VSTVEC, VSTVEC_WRITE, VSTVEC_EXPECT
    CHECK_CSR_RW CSR_VSSCRATCH, VSSCRATCH_VAL, VSSCRATCH_VAL
    CHECK_CSR_RW CSR_VSEPC, VSEPC_VAL, VSEPC_VAL
    CHECK_CSR_RW CSR_VSCAUSE, VSCAUSE_VAL, VSCAUSE_VAL
    CHECK_CSR_RW CSR_VSTVAL, VSTVAL_VAL, VSTVAL_VAL
    CHECK_CSR_RW CSR_VSATP, VSATP_VAL, VSATP_VAL

    # Direct HIE write should update the architectural alias in MIE.
    CHECK_CSR_RW CSR_HIE, -1, HIE_MASK
    CHECK_CSR_READ CSR_MIE, MIE_AFTER_HIE

    # VSIE writes alias into the delegated HIE bits.
    CHECK_CSR_RW CSR_HIE, 0, 0
    CHECK_CSR_READ CSR_MIE, MIE_BASE
    CHECK_CSR_RW CSR_VSIE, -1, VSIE_MASK
    CHECK_CSR_READ CSR_HIE, HIE_VS_MASK
    CHECK_CSR_READ CSR_MIE, MIE_AFTER_VSIE

    # HIP/HVIP/VSIP are partially aliased through the delegated virtual interrupt bits.
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

    # Timer/configuration CSRs are tested late so earlier HIP reads are not
    # disturbed by virtual timer pending state.
    CHECK_CSR_RW CSR_VSTIMECMP, -1, -1
    CHECK_CSR_RW CSR_MENVCFG, HENVCFG_EXPECT, HENVCFG_EXPECT
    CHECK_CSR_RW CSR_HENVCFG, -1, HENVCFG_EXPECT
    CHECK_CSR_RW CSR_HTIMEDELTA, HTIMEDELTA_VAL, HTIMEDELTA_VAL

    # HGEIP is source-driven and read-only from the CSR path.
    CHECK_ILLEGAL_CSR_WRITE CSR_HGEIP, -1, 0

    # Enter HS via the existing ecall privilege-change helper and exercise an
    # H-specific instruction there. Delegate illegal-instruction traps to HS so
    # an unexpectedly illegal HFENCE.GVMA fails immediately rather than vanishing
    # through the common M-mode trap-return path.
    li t0, 0x4
    csrw CSR_MEDELEG, t0
    la t0, hs_trap_fail
    csrw stvec, t0

    li a0, 1
    ecall

hs_mode_entry:
    csrr t0, CSR_HSTATUS
    .word 0x62000073 # hfence.gvma x0, x0
    li s0, HS_MARKER

    # Drive guest external interrupt 1 through the CLINT/TrickBox HGEIP slot.
    # With GEILEN=1, hgeie[1] and hie.SGEIE should deliver an HS-level SGEI.
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

sgei_done:

    li a0, 3
    ecall

back_in_m_from_hs:
    li t0, HS_MARKER
    bne s0, t0, fail
    csrw CSR_MEDELEG, zero
    li t0, HS_STVEC_VAL
    csrw stvec, t0

    # Legal HFENCE encodings should not trap in M-mode.
    csrw CSR_MCAUSE, zero
    .word 0x22000073 # hfence.vvma x0, x0
    csrr t1, CSR_MCAUSE
    bnez t1, fail

    csrw CSR_MCAUSE, zero
    .word 0x62000073 # hfence.gvma x0, x0
    csrr t1, CSR_MCAUSE
    bnez t1, fail

    # Same HFENCE.VVMA pattern with rd != x0 should decode as illegal.
    csrw CSR_MCAUSE, zero
    .word 0x220000F3 # illegal: hfence.vvma-like encoding with rd = x1
    csrr t1, CSR_MCAUSE
    li t2, CAUSE_ILLEGAL
    bne t1, t2, fail

    j done

fail:
    la t1, tohost
    li t0, 3
    sw t0, 0(t1)
hs_trap_fail:
    j fail
fail_loop:
    j fail_loop
