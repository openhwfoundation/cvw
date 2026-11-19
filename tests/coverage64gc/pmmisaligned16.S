///////////////////////////////////////////
// pmmisaligned16.S
//
// Written: naichewa@gmail.com 13 November 2026
//
// Purpose: Misaligned accesses across the top of the widest virtual address range with PMLEN 16 pointer masking
//          (Sv48, PMLEN 16; Sv57 is not supported with PMLEN 16).  Pointer masking applies to each byte of an
//          access, so the byte after virtual address 0x00007FFFFFFFFFFF is at 0x0000800000000000 with bits 63:48
//          ignored; bits 63:48 then become copies of bit 47, giving 0xFFFF800000000000, the lowest
//          address of the negative half.  Each access below starts in the last page of the positive half and ends
//          in the first page of the negative half.  When both pages are mapped the access must complete without
//          a trap; when the second page is unmapped it must take a page fault with mtval = 0xFFFF800000000000.  Without
//          pointer masking the same access spills into the non-canonical address 0x0000800000000000 and takes a
//          page fault.
//
//          Physical layout: the last 2 MiB of the positive half maps to PA 0x80200000 and the first 2 MiB of the
//          negative half maps to PA 0x80600000, so the two halves of an access are not adjacent in memory.
//
//          Requires PMLEN16_SUPPORTED (the pm16 derivative).  The test passes without checking anything if
//          menvcfg.PMM does not accept the PMLEN 16 encoding, so it can also run on rv64gc.
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

// Physical bytes on either side of the seam: PA 0x803FFFF8..0x803FFFFF then PA 0x80600000..0x80600007
//   0x803FFFF8: 88 77 66 55 44 33 22 11     0x80600000: 00 FF EE DD CC BB AA 99
.macro SEED
    li t3, 0x803FFFF8
    li t4, 0x1122334455667788
    sd t4, 0(t3)
    li t3, 0x80600000
    li t4, 0x99AABBCCDDEEFF00
    sd t4, 0(t3)
.endm

// RUN insn, adr: from M mode with mstatus.MPRV=1 and MPP=S, so the access is translated and pointer masked as in
// S mode, execute insn with s0 = adr.  pm_trap_handler records mcause in s8 and mtval in s9 and resumes at s11.
// MPRV is cleared afterward so that the checks are not translated.
.macro RUN insn, adr
    li s0, \adr
    li s8, -1
    li s9, -1
    la s11, 1f
    li t0, 0x1000
    csrc mstatus, t0
    li t0, 0x20800                  # MPRV, MPP = S
    csrs mstatus, t0
    \insn
1:
    li t0, 0x20000
    csrc mstatus, t0
.endm

// LOAD_OK insn, adr, value, idx: the load completes without a trap and s1 = value
.macro LOAD_OK insn, adr, value, idx
    li s1, 0
    RUN "\insn", \adr
    li t2, -1
    SC_CHECK_EQ s8, t2, \idx
    li t2, \value
    SC_CHECK_EQ s1, t2, \idx+1
.endm

// STORE_OK insn, adr, top, bottom, idx: the store of s1 completes without a trap and leaves the 8 bytes at
// PA 0x803FFFF8 = top and the 8 bytes at PA 0x80600000 = bottom (s1 = 0xA1B2C3D4E5F60718)
.macro STORE_OK insn, adr, top, bottom, idx
    SEED
    li s1, 0xA1B2C3D4E5F60718
    RUN "\insn", \adr
    li t2, -1
    SC_CHECK_EQ s8, t2, \idx
    li t3, 0x803FFFF8
    ld s2, 0(t3)
    li t2, \top
    SC_CHECK_EQ s2, t2, \idx+1
    li t3, 0x80600000
    ld s2, 0(t3)
    li t2, \bottom
    SC_CHECK_EQ s2, t2, \idx+2
.endm

// PTE_PTR table, idx, next: table[idx] = non-leaf PTE pointing to next (clobbers t0-t2)
.macro PTE_PTR table, idx, next
    la t0, \next
    srli t0, t0, 12
    slli t0, t0, 10
    ori t0, t0, 1
    la t1, \table
    li t2, \idx*8
    add t1, t1, t2
    sd t0, 0(t1)
.endm

main:
    # PMP: allow everything
    li t0, -1
    csrw pmpaddr0, t0
    li t0, 0x1F
    csrw pmpcfg0, t0

    # menvcfg.PMM = 11: pointer masking with PMLEN 16 in S mode.  Pass without testing if it is not supported.
    li t0, 3
    slli t0, t0, 32
    csrs menvcfg, t0
    csrr t1, menvcfg
    and t1, t1, t0
    bne t1, t0, skip

    # Sv48 page tables.  VPN3 = 255 (positive half) and 256 (negative half) are reached through
    # non-leaf PTEs; the last level is a 2 MiB leaf (VALID, R, W, A, D = 0xC7)
    PTE_PTR root48, 255, top2
    PTE_PTR top2,   0x1FF, top1
    PTE_PTR root48, 256, bot2
    PTE_PTR bot2,   0, bot1
    la t0, top1
    li t1, 0x200800C7               # PA 0x80200000
    li t2, 0x1FF*8
    add t0, t0, t2
    sd t1, 0(t0)
    la t0, bot1
    li t1, 0x201800C7               # PA 0x80600000
    sd t1, 0(t0)

    la t0, root48
    srli t0, t0, 12
    li t1, 9
    slli t1, t1, 60
    or t0, t0, t1
    csrw satp, t0                   # Sv48
    sfence.vma
    la t0, pm_trap_handler
    csrw mtvec, t0

    # Controls: aligned accesses entirely inside each page; bits 63:48 are 0x5A5A, 0 and 0xA5A5
    SEED
    LOAD_OK "ld s1, 0(s0)", 0x5A5A7FFFFFFFFFF8, 0x1122334455667788, 0x10
    LOAD_OK "ld s1, 0(s0)", 0x00007FFFFFFFFFF8, 0x1122334455667788, 0x12
    LOAD_OK "ld s1, 0(s0)", 0xA5A5800000000000, 0x99AABBCCDDEEFF00, 0x14

    # Misaligned loads that straddle 0x00007FFFFFFFFFFF/0xFFFF800000000000, with bits 63:48 set to 0x5A5A
    LOAD_OK "ld s1, 0(s0)",  0x5A5A7FFFFFFFFFFC, 0xDDEEFF0011223344, 0x20    # 4 + 4 bytes
    LOAD_OK "ld s1, 0(s0)",  0x5A5A7FFFFFFFFFF9, 0x0011223344556677, 0x22    # 7 + 1 bytes
    LOAD_OK "ld s1, 0(s0)",  0x5A5A7FFFFFFFFFFF, 0xAABBCCDDEEFF0011, 0x24   # 1 + 7 bytes
    LOAD_OK "lwu s1, 0(s0)", 0x5A5A7FFFFFFFFFFE, 0x00000000FF001122, 0x26    # 2 + 2 bytes
    LOAD_OK "lwu s1, 0(s0)", 0x5A5A7FFFFFFFFFFF, 0x00000000EEFF0011, 0x28    # 1 + 3 bytes
    LOAD_OK "lhu s1, 0(s0)", 0x5A5A7FFFFFFFFFFF, 0x0000000000000011, 0x2A    # 1 + 1 bytes
    # Same with bits 63:48 clear
    LOAD_OK "ld s1, 0(s0)",  0x00007FFFFFFFFFFC, 0xDDEEFF0011223344, 0x2C

    # Misaligned stores that straddle the seam
    STORE_OK "sd s1, 0(s0)", 0x5A5A7FFFFFFFFFFC, 0xE5F6071855667788, 0x99AABBCCA1B2C3D4, 0x30
    STORE_OK "sw s1, 0(s0)", 0x5A5A7FFFFFFFFFFE, 0x0718334455667788, 0x99AABBCCDDEEE5F6, 0x34
    STORE_OK "sh s1, 0(s0)", 0x5A5A7FFFFFFFFFFF, 0x1822334455667788, 0x99AABBCCDDEEFF07, 0x38

    # Second half unmapped: the walk of the masked address 0xFFFF800000000000 finds an invalid PTE, so the access
    # takes a page fault with mtval = 0xFFFF800000000000 (the start of the faulting portion, after masking)
    la t0, bot1
    sd zero, 0(t0)
    sfence.vma
    RUN "ld s1, 0(s0)", 0x5A5A7FFFFFFFFFFC
    li t2, 13
    SC_CHECK_EQ s8, t2, 0x3C
    li t2, 0xFFFF800000000000
    SC_CHECK_EQ s9, t2, 0x3D
    RUN "sd s1, 0(s0)", 0x5A5A7FFFFFFFFFFC
    li t2, 15
    SC_CHECK_EQ s8, t2, 0x3E
    li t2, 0xFFFF800000000000
    SC_CHECK_EQ s9, t2, 0x3F

    # Without pointer masking the second half is the non-canonical address 0x0000800000000000
    li t0, 3
    slli t0, t0, 32
    csrc menvcfg, t0                # menvcfg.PMM = 00
    SEED
    RUN "ld s1, 0(s0)", 0x00007FFFFFFFFFFC
    li t2, 13
    SC_CHECK_EQ s8, t2, 0x40
    li t2, 0x0000800000000000
    SC_CHECK_EQ s9, t2, 0x41

skip:
    SC_PASS
    j done

// Record mcause/mtval and resume at s11; forward interrupts and ecalls to the WALLY-init-lib.h handler
.p2align 4
pm_trap_handler:
    csrr s8, mcause
    bltz s8, pm_forward
    addi s10, s8, -8
    beqz s10, pm_forward            # ecall from U
    addi s10, s8, -9
    beqz s10, pm_forward            # ecall from S
    addi s10, s8, -11
    beqz s10, pm_forward            # ecall from M
    csrr s9, mtval
    csrw mepc, s11
    mret
pm_forward:
    j trap_handler

.data
.p2align 12
root48:
    .fill 512, 8, 0
.p2align 12
top2:
    .fill 512, 8, 0
.p2align 12
top1:
    .fill 512, 8, 0
.p2align 12
bot2:
    .fill 512, 8, 0
.p2align 12
bot1:
    .fill 512, 8, 0
