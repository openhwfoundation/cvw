///////////////////////////////////////////
// fetchperiph.S
//
// Written: David_Harris@hmc.edu 3 October 2026; RV32 port 27 October 2026
//
// Purpose: RV32 port of tests/coverage64gc/fetchperiph.S, plus two decoder cases rv32gc misses.
//          1. Instruction fetches from the peripherals.  The peripherals only accept reads and
//             writes, so a fetch from one matches its address decoder in the instruction PMA
//             checker but is not a valid access (AccessValid_0), and takes an instruction access
//             fault.  The UART is not fetched from: it only accepts byte accesses, and the IFU
//             always checks a word.
//          2. A word load from the SDC address range.  rv32gc does not support the SDC, so the
//             data PMA checker's sdcdec matches a valid word access that is not supported
//             (Supported_0), and the load takes a load access fault.
//          3. PMP entry 15 in TOR mode over [0, 0x80000000) during the fetches and loads above, so
//             both PMP checkers' last address decoder sees a TOR match.  Entry 0 (RWX over all
//             memory) matches first and still decides every access.
//          Self-checking: each fault has the expected mcause and mtval, and the number of faults
//          is exact.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

// FETCHFAULT adr, index: jump to adr, which must take an instruction access fault (mcause 1) with
// mtval = adr.  accessfault records mcause in s10 and mtval in s11, and counts the faults in s9.
.macro FETCHFAULT adr, index
    li s10, 0
    li s11, 0
    li t1, \adr
    jalr ra, t1
    li t2, 1
    SC_CHECK_EQ s10, t2, \index         // mcause = instruction access fault
    li t2, \adr
    SC_CHECK_EQ s11, t2, \index+1       // mtval = the fetch address
.endm

main:
    li s9, 0
    la t0, accessfault      # the fault returns to ra, after the jump or load that faulted
    csrw mtvec, t0

    // PMP entry 15 = TOR [0, 0x80000000), no permissions.  The peripheral fetches and the SDC load fall
    // in its range; entry 0 matches first, so the PMP allows them and only the PMA faults them.
    csrw pmpaddr14, zero
    li t0, 0x20000000
    csrw pmpaddr15, t0
    li t0, 0x08000000           # pmp15cfg = TOR
    csrw pmpcfg3, t0

    FETCHFAULT 0x02000000, 1    # CLINT
    FETCHFAULT 0x0C000000, 3    # PLIC
    FETCHFAULT 0x10020000, 5    # PWM
    FETCHFAULT 0x10040000, 7    # SPI
    FETCHFAULT 0x10060000, 9    # GPIO

    // Word load from the unsupported SDC range: load access fault (mcause 5), mtval = address
    li s10, 0
    li s11, 0
    li t1, 0x00013000
    la ra, 1f
    lw t3, 0(t1)
1:  li t2, 5
    SC_CHECK_EQ s10, t2, 11
    li t2, 0x00013000
    SC_CHECK_EQ s11, t2, 12

    la t1, scratch
    lw t3, 0(t1)
    li t2, 0x12345678
    SC_CHECK_EQ t3, t2, 13
    csrw pmpcfg3, zero

    la t0, trap_handler
    csrw mtvec, t0
    li t2, 6
    SC_CHECK_EQ s9, t2, 14      # exactly five instruction access faults and one load access fault

    SC_PASS
    j done

// Instruction and load access faults: record mcause and mtval, count, and return to ra.
// Anything else goes to sc_trap_handler, which fails the test.
.align 2
accessfault:
    csrr s10, mcause
    addi s8, s10, -1
    beqz s8, 1f
    addi s8, s10, -5
    bnez s8, sc_trap_handler
1:  csrr s11, mtval
    addi s9, s9, 1
    csrw mepc, ra
    mret

.data
.align 2
scratch:
    .word 0x12345678
