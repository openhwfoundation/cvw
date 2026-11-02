///////////////////////////////////////////
// uncachedQuad.S
//
// Written: David_Harris@hmc.edu 1 November 2026
//
// Purpose: 128-bit flq and fsq through an Svpbmt non-cacheable (NC) page, which the 64-bit bus
//          carries as two beats, and narrower loads and stores to the same page in either half of
//          the 128-bit word.  flq/fsq that are not 16-byte aligned raise address-misaligned
//          exceptions on the NC page and access faults to the byte-only UART.  Self-checking
//          (WALLY-selfcheck.h): record_trap logs the misaligned and access faults and fails the test
//          on any other trap but an ecall.  Passes trivially without Q.  Failure indices: 1-8 data
//          read or written through the NC page, 9-10 trap log, 0xF0 an unexpected trap.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"
.option norvc

#define NCPAT 0x3C3C0000            // word k of nc_data holds NCPAT + k
#define NCDW(j) (((NCPAT + 2*(j) + 1) << 32) | (NCPAT + 2*(j)))  // doubleword j of nc_data
#define QLO 0x0123456789ABCDEF      // quad stored through the NC page
#define QHI 0xFEDCBA9876543210
#define SWDATA 0x5A5A5A5A           // word stored to the upper half of a 128-bit word
#define UART 0x10000000

.macro L0_ENTRY label, reg
    la \reg, \label
    srli \reg, \reg, 12
    andi \reg, \reg, 0x1FF
    slli \reg, \reg, 3
    la t6, l0table
    add \reg, \reg, t6
.endm

main:
    csrr t0, misa
    srli t0, t0, 16             # misa.Q
    andi t0, t0, 1
    beqz t0, pass               # no Q: nothing to test
    la t0, record_trap
    csrw mtvec, t0
    li t0, 0x6000
    csrs mstatus, t0            # mstatus.FS = Dirty

    // Identity-map the first 2 MiB of RAM with 4 KiB pages (Sv39: root -> level 1 -> level 0)
    la t0, l0table
    li t1, 0x80000              # PPN of 0x80000000
    li t2, 512
build_l0:
    slli t3, t1, 10
    ori t3, t3, 0xCF            # V R W X A D
    sd t3, 0(t0)
    addi t0, t0, 8
    addi t1, t1, 1
    addi t2, t2, -1
    bnez t2, build_l0
    la t0, l1table
    la t1, l0table
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, 1               # non-leaf
    sd t1, 0(t0)                # level-1 entry 0: VA 0x80000000-0x801FFFFF
    la t0, roottable
    la t1, l1table
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, 1
    sd t1, 16(t0)               # root entry 2: VA 0x80000000-0xBFFFFFFF

    // PBMT = NC (bit 61) on the data page
    li t2, 0x2000000000000000
    L0_ENTRY nc_data, t0
    ld t1, 0(t0)
    or t1, t1, t2
    sd t1, 0(t0)
    li t0, 0x4000000000000000   # menvcfg.PBMTE
    csrs menvcfg, t0
    la t0, roottable
    srli t0, t0, 12
    li t1, 0x8000000000000000   # MODE = 8, Sv39
    or t0, t0, t1
    csrw satp, t0
    sfence.vma

    li a0, 1
    ecall                       # supervisor mode

    la a1, nc_data
    la a2, results
    flq ft0, 0(a1)              # both halves of a quad from the NC page
    fsq ft0, 0(a2)
    la a3, quadsrc
    flq ft1, 0(a3)
    fsq ft1, 32(a1)             # both halves of a quad to the NC page
    ld s2, 32(a1)
    ld s3, 40(a1)
    flq ft2, 16(a1)             # leaves doublewords 2 and 3 in the bus fetch buffer
    lw s4, 12(a1)               # narrow loads that follow see only their own bytes,
    ld s5, 8(a1)                # here from the upper half of a 128-bit word
    li t1, SWDATA
    sw t1, 52(a1)               # narrow store to the upper half of a 128-bit word
    ld s6, 48(a1)
mis_flq:
    flq ft3, 8(a1)              # not 16-byte aligned: address-misaligned exceptions
mis_fsq:
    fsq ft1, 72(a1)
    ld s7, 72(a1)               # the misaligned fsq wrote nothing

    li a0, 3
    ecall                       # machine mode
    li a4, UART
uart_flq:
    flq ft3, 0(a4)              # the UART takes only byte accesses: access faults
uart_fsq:
    fsq ft1, 0(a4)

    li t2, NCDW(0)
    ld t3, 0(a2)
    SC_CHECK_EQ t3, t2, 1       # flq from the NC page
    li t2, NCDW(1)
    ld t3, 8(a2)
    SC_CHECK_EQ t3, t2, 2
    li t2, QLO
    SC_CHECK_EQ s2, t2, 3       # fsq to the NC page
    li t2, QHI
    SC_CHECK_EQ s3, t2, 4
    li t2, NCPAT + 3
    SC_CHECK_EQ s4, t2, 5       # lw 12
    li t2, NCDW(1)
    SC_CHECK_EQ s5, t2, 6       # ld 8
    li t2, (SWDATA << 32) | (NCPAT + 12)
    SC_CHECK_EQ s6, t2, 7       # sw 52, read back with ld 48
    li t2, NCDW(9)
    SC_CHECK_EQ s7, t2, 8       # misaligned fsq wrote nothing

    la a1, traplog
    ld t2, 0(a1)
    li t3, 4
    SC_CHECK_EQ t2, t3, 9       # four traps
    addi a1, a1, 8
    la a2, expected_traps
    li a3, 12                   # 4 traps x (mcause, mepc, mtval)
1:  ld t2, 0(a1)
    ld t3, 0(a2)
    SC_CHECK_EQ_ADR t2, t3, a1, 10
    addi a1, a1, 8
    addi a2, a2, 8
    addi a3, a3, -1
    bnez a3, 1b
pass:
    SC_PASS
    j done

// Misaligned load (4), load access fault (5), misaligned store (6) and store access fault (7): log
// mcause, mepc and mtval in traplog, then let the library handler skip the instruction.  Everything else
// goes to sc_trap_handler, which passes ecalls to the library handler and fails the test on any other trap.
.align 4
record_trap:
    csrrw t0, mscratch, t0      # t0 = trap stack pointer, mscratch = saved t0
    sd t1, -16(t0)
    sd t2, -24(t0)
    sd t3, -32(t0)
    csrr t1, mcause
    addi t1, t1, -4
    li t2, 3
    bleu t1, t2, 1f             # mcause 4-7
    ld t3, -32(t0)
    ld t2, -24(t0)
    ld t1, -16(t0)
    csrrw t0, mscratch, t0      # restore t0 and the trap stack pointer
    j sc_trap_handler
1:  la t2, traplog
    ld t3, 0(t2)
    addi t3, t3, 1
    sd t3, 0(t2)                # count every trap
    li t1, 4
    bgtu t3, t1, 2f             # log the first four
    slli t1, t3, 4
    slli t3, t3, 3
    add t1, t1, t3
    add t1, t1, t2              # traplog + 24 * count: entry count - 1 is at -16(t1)
    csrr t3, mcause
    sd t3, -16(t1)
    csrr t3, mepc
    sd t3, -8(t1)
    csrr t3, mtval
    sd t3, 0(t1)
2:  ld t3, -32(t0)
    ld t2, -24(t0)
    ld t1, -16(t0)
    csrrw t0, mscratch, t0
    j trap_handler

.data
.p2align 12
roottable:
    .fill 512, 8, 0
l1table:
    .fill 512, 8, 0
l0table:
    .fill 512, 8, 0
nc_data:
    .set k, 0
    .rept 1024
    .word NCPAT + k
    .set k, k + 1
    .endr
.p2align 4
quadsrc:
    .dword QLO, QHI
results:
    .fill 2, 8, 0
traplog:                        # number of traps, then mcause, mepc, mtval of the first four
    .fill 1 + 3 * 4, 8, 0
expected_traps:                 # mcause, mepc, mtval of each trap expected, in order
    .dword 4, mis_flq, nc_data + 8
    .dword 6, mis_fsq, nc_data + 72
    .dword 5, uart_flq, UART
    .dword 7, uart_fsq, UART
