///////////////////////////////////////////
// deferredwalk.S
//
// Written: David_Harris@hmc.edu 11/1/26
//
// Purpose: Exercise synchronous exceptions that TrapM defers while the IFU has a committed I$ line
//          fill (trap.sv: TrapM = (ExceptionM & ~CommittedF) | InterruptM, issue #845).  A load, store,
//          AMO, LR/SC, FP load/store, or CBO in S mode faults on an address whose DTLB entry is cold, so
//          the fault arises only after a page table walk (D$-resident PTEs), possibly while the next
//          I$ line is being filled.  Walk faults (invalid PTE, non-leaf with A set, PTE read from an
//          unmapped address) are one-cycle pulses from the walker; permission faults after the TLB fill
//          (read-only, execute-only, A=0) are levels.  Misaligned accesses that cross from a valid page
//          into a faulting one fault on the second half.  Each op is swept across the 16 word positions
//          of a fresh I$ line so one position starts the next line's fill as the op reaches M.
//          The faults are delegated to S mode, and each attempt has its own handler in a line that has
//          never been fetched, so the trap's first fetch misses: a trap that cut the fill short would
//          start that fetch in the middle of the fill's AHB burst (issue #412).  Every attempt must trap
//          at the op with the expected cause and must not write rd.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

.option norelax                // linker relaxation would shift the I$-line alignment of the attempts
#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

.equ SENT,     0x5A5A5A5A       // rd sentinel: a faulting op must not overwrite it
// Sv39 VPN2=4 points to pt_l1; each pt_l1 entry covers a 2 MiB megapage
.equ VA_INV,   0x100000000      // pt_l1[0]  invalid: walk page fault
.equ VA_BADPT, 0x100200000      // pt_l1[1]  non-leaf -> L0 table at unmapped PA: walk access fault
.equ VA_NLA,   0x100400000      // pt_l1[2]  non-leaf with A set: walk page fault
.equ VA_RO,    0x100600000      // pt_l1[3]  read-only leaf -> PA 0x80000000: store fault after TLB fill
.equ VA_XO,    0x100800000      // pt_l1[4]  execute-only leaf: load and store faults after TLB fill
.equ VA_NOA,   0x100A00000      // pt_l1[5]  leaf with A=0 (menvcfg.ADUE=0): fault after TLB fill
.equ VA_RWINV, 0x100C00000      // pt_l1[6]  read/write leaf; pt_l1[7] invalid
.equ VA_RWRO,  0x101000000      // pt_l1[8]  read/write leaf; pt_l1[9] read-only
.equ VA_RWXO,  0x101400000      // pt_l1[10] read/write leaf; pt_l1[11] execute-only

// The op under test, selected by number so it passes cleanly through the macros
.equ OP_LW, 0
.equ OP_LD, 1
.equ OP_LRW, 2
.equ OP_FLW, 3
.equ OP_SW, 4
.equ OP_AMOADDW, 5
.equ OP_SCW, 6
.equ OP_FSW, 7
.equ OP_CBOZERO, 8
.equ OP_CBOCLEAN, 9
.equ OP_CBOFLUSH, 10
.equ OP_CBOINVAL, 11
.equ OP_SD, 12
.macro EMITOP op
    .if \op == OP_LW
        lw s7, 0(s1)
    .elseif \op == OP_LD
        ld s7, 0(s1)
    .elseif \op == OP_LRW
        lr.w s7, (s1)
    .elseif \op == OP_FLW
        flw f0, 0(s1)
    .elseif \op == OP_SW
        sw s6, 0(s1)
    .elseif \op == OP_AMOADDW
        amoadd.w s7, s6, (s1)
    .elseif \op == OP_SCW
        sc.w s7, s6, (s1)
    .elseif \op == OP_FSW
        fsw f0, 0(s1)
    .elseif \op == OP_CBOZERO
        cbo.zero (s1)
    .elseif \op == OP_CBOCLEAN
        cbo.clean (s1)
    .elseif \op == OP_CBOFLUSH
        cbo.flush (s1)
    .elseif \op == OP_CBOINVAL
        cbo.inval (s1)
    .elseif \op == OP_SD
        sd s6, 0(s1)
    .else
        .error "unknown op"
    .endif
.endm

// One attempt: the op sits at word \k of a fresh 64-byte I$ line, followed by 15-\k nops, so the next
// line is cold too.  s1 = address, s4 = expected cause, s3 = expected tval (checked if \chk).
// The S-mode handler records scause/stval/sepc in s8/s9/s10 and skips the 4-byte op.
.macro ATTEMPT k, idx, chk, op
    li s7, SENT
    li s8, 0
    li s10, 0
    la t0, handler\@
    csrw stvec, t0
    sfence.vma                 // cold DTLB; the PTEs stay in the D$, so the walk is short
    .option push
    .option norvc
    .option norelax
    .balign 64
    .rept \k
        nop
    .endr
op\@:
    EMITOP \op
    .rept (15 - \k)
        nop
    .endr
    j check\@
    .balign 64                 // the handler starts a line of its own that has never been fetched
handler\@:
    csrr s8, scause
    csrr s9, stval
    csrr s10, sepc
    addi s11, s10, 4
    csrw sepc, s11
    sret
    .option pop
check\@:
    la t2, op\@
    SC_CHECK_EQ s10, t2, (\idx)   // trapped at the op
    SC_CHECK_EQ s8, s4, (\idx)    // with the expected cause
    SC_CHECK_EQ s7, s5, (\idx)    // and rd was not written
    .if \chk
    SC_CHECK_EQ s9, s3, (\idx)    // and the expected tval
    .endif
.endm

.macro SWEEP base, chk, op
    .set kk, 0
    .rept 16
        ATTEMPT kk, (\base + kk), \chk, \op
        .set kk, kk+1
    .endr
.endm

// Set s1 = s3 = \va + offset of the scratch dword, s4 = \cause
.macro TARGET va, cause
    li s1, \va
    add s1, s1, s2
    mv s3, s1
    li s4, \cause
.endm

.macro LOADOPS base, chk
    SWEEP (\base + 0),  \chk, OP_LW
    SWEEP (\base + 16), \chk, OP_LD
    SWEEP (\base + 32), \chk, OP_LRW
    SWEEP (\base + 48), \chk, OP_FLW
.endm

.macro STOREOPS base, chk
    SWEEP (\base + 0),  \chk, OP_SW
    SWEEP (\base + 16), \chk, OP_AMOADDW
    SWEEP (\base + 32), \chk, OP_SCW
    SWEEP (\base + 48), \chk, OP_FSW
    SWEEP (\base + 64), \chk, OP_CBOZERO
.endm

.macro CBMOPS base, chk
    SWEEP (\base + 0),  \chk, OP_CBOCLEAN
    SWEEP (\base + 16), \chk, OP_CBOFLUSH
    SWEEP (\base + 32), \chk, OP_CBOINVAL
.endm

main:
    // menvcfg.CBZE/CBCFE/CBIE = 1/1/11 so S mode can use the CBOs; ADUE stays 0 (A=0 faults)
    li t0, 0xF0
    csrs menvcfg, t0
    li t0, 0x2000
    csrs mstatus, t0           // mstatus.FS = Initial

    // Page tables
    la t1, pt_root
    la t2, pt_l1
    srli t3, t2, 12
    slli t3, t3, 10
    ori t0, t3, 0x01
    sd t0, 32(t1)              // pt_root[4] -> pt_l1
    ori t0, t3, 0x41
    sd t0, 16(t2)              // pt_l1[2]: non-leaf with A set
    li t0, 0x10000001
    sd t0, 8(t2)               // pt_l1[1]: non-leaf -> PA 0x40000000 (no memory there)
    li t0, 0x200000C3          // V R A D -> PA 0x80000000
    sd t0, 24(t2)              // pt_l1[3]: read-only
    sd t0, 72(t2)              // pt_l1[9]: read-only
    li t0, 0x200000C9          // V X A D
    sd t0, 32(t2)              // pt_l1[4]: execute-only
    sd t0, 88(t2)              // pt_l1[11]: execute-only
    li t0, 0x20000007          // V R W, A=0
    sd t0, 40(t2)              // pt_l1[5]: A clear
    li t0, 0x200000C7          // V R W A D
    sd t0, 48(t2)              // pt_l1[6]
    sd t0, 64(t2)              // pt_l1[8]
    sd t0, 80(t2)              // pt_l1[10]

    // The first halves of the page-crossing accesses read/write PA 0x801FFFFC..0x801FFFFF
    li t0, 0x801FFFF8
    sd zero, 0(t0)

    // Sv39
    srli t1, t1, 12
    li t0, 8
    slli t0, t0, 60
    or t1, t1, t0
    csrw satp, t1
    sfence.vma

    li t0, 0xA0A0              // delegate load/store access (5, 7) and page (13, 15) faults to S mode
    csrw medeleg, t0

    la s2, scratch
    li t0, 0x80000000
    sub s2, s2, t0             // s2 = offset of scratch within each megapage
    li s5, SENT
    li s6, 0x12345678
    fmv.w.x f0, s6

    li a0, 1
    ecall                      // S mode

    // Faults from the walk itself (one-cycle pulses)
    TARGET VA_INV, 13
    LOADOPS 1000, 1
    TARGET VA_INV, 15
    STOREOPS 1100, 1
    CBMOPS 1200, 1
    TARGET VA_BADPT, 5
    LOADOPS 2000, 1
    TARGET VA_BADPT, 7
    STOREOPS 2100, 1
    CBMOPS 2200, 1
    TARGET VA_NLA, 13
    LOADOPS 3000, 1
    TARGET VA_NLA, 15
    STOREOPS 3100, 1
    CBMOPS 3200, 1
    // Faults after the TLB fill (levels)
    TARGET VA_RO, 15
    STOREOPS 4100, 1
    TARGET VA_XO, 13
    LOADOPS 5000, 1
    TARGET VA_XO, 15
    STOREOPS 5100, 1
    TARGET VA_NOA, 13
    LOADOPS 6000, 1
    TARGET VA_NOA, 15
    STOREOPS 6100, 1
    CBMOPS 6200, 1
    // Misaligned accesses whose second half faults (tval not checked: either half's address is allowed)
    li s4, 13
    li s1, (VA_RWINV + 0x1FFFFE)
    SWEEP 7000, 0, OP_LW
    SWEEP 7016, 0, OP_FLW
    li s1, (VA_RWINV + 0x1FFFFC)
    SWEEP 7032, 0, OP_LD
    li s4, 15
    li s1, (VA_RWINV + 0x1FFFFE)
    SWEEP 7100, 0, OP_SW
    SWEEP 7116, 0, OP_FSW
    li s1, (VA_RWINV + 0x1FFFFC)
    SWEEP 7132, 0, OP_SD
    li s1, (VA_RWRO + 0x1FFFFE)
    SWEEP 8100, 0, OP_SW
    SWEEP 8116, 0, OP_FSW
    li s1, (VA_RWRO + 0x1FFFFC)
    SWEEP 8132, 0, OP_SD
    li s4, 13
    li s1, (VA_RWXO + 0x1FFFFE)
    SWEEP 9000, 0, OP_LW
    SWEEP 9016, 0, OP_FLW
    li s1, (VA_RWXO + 0x1FFFFC)
    SWEEP 9032, 0, OP_LD

    li a0, 3
    ecall                      // back to M mode
    csrw medeleg, zero
    SC_PASS
    j done

.data
.align 3
scratch:
    .dword 0
.align 12
pt_root:
    .dword 0, 0
    .dword 0x200000CF           // VPN2=2: identity gigapage 0x80000000, V R W X A D
    .dword 0
    .dword 0                    // VPN2=4: -> pt_l1, filled at run time
    .fill 507, 8, 0
.align 12
pt_l1:
    .fill 512, 8, 0
