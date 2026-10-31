///////////////////////////////////////////
// periphPMA.S
//
// Written: david_harris@hmc.edu 27 October 2026
//
// Purpose: rv32imc PMA checker coverage (trl5 group D).
//          1. Fetch from each word-accessible peripheral (CLINT, PLIC, PWM, SPI, GPIO).  The peripherals
//             are not executable, so each fetch takes an instruction access fault with mtval = the
//             fetch address (RV32 port of tests/coverage64gc/fetchperiph.S).  This selects the
//             peripheral in the IMMU address decoder with the access type invalid.  Also fetch from
//             the boot ROM's address range, which this configuration does not implement (access fault).
//          2. Word loads and stores to SPI and PWM, a byte load from each (word-only peripherals, so a
//             load access fault), an access to the SDC address range (no SDC on rv32imc, so a load
//             access fault), and a non-memory instruction whose ALU sum lands in SPI and PWM with a
//             word funct3, which selects the region in the DMMU decoder with no access.
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

#define SPI_BASE 0x10040000
#define PWM_BASE 0x10020000
#define SDC_BASE 0x00013000

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

// LOADFAULT op, adr, index: the load must take a load access fault (mcause 5) with mtval = adr.
// The library handler skips the 4-byte load.
.macro LOADFAULT op, adr, index
    csrw mcause, zero
    li t1, \adr
    \op t2, 0(t1)
    csrr t3, mcause
    li t4, 5
    SC_CHECK_EQ t3, t4, \index
    csrr t3, mtval
    SC_CHECK_EQ t3, t1, \index+1
.endm


main:
    // 1. Fetches from the peripherals
    li s9, 0
    la t0, fetchfault                   // the fault returns to ra, after the jump that faulted
    csrw mtvec, t0

    FETCHFAULT 0x02000000, 1            // CLINT
    FETCHFAULT 0x0C000000, 3            // PLIC
    FETCHFAULT 0x10020000, 5            // PWM
    FETCHFAULT 0x10040000, 7            // SPI
    FETCHFAULT 0x10060000, 9            // GPIO
    FETCHFAULT 0x00001000, 12           // boot ROM range: BOOTROM_SUPPORTED = 0

    la t0, trap_handler
    csrw mtvec, t0
    li t2, 6
    SC_CHECK_EQ s9, t2, 11              // exactly six instruction access faults

    // 2. Data accesses.  SPI sckdiv (offset 0x00) resets to 3; write and read it back, then restore.
    csrw mcause, zero
    li t1, SPI_BASE
    lw s1, 0(t1)
    li t2, 3
    SC_CHECK_EQ s1, t2, 20
    li t2, 7
    sw t2, 0(t1)
    lw t3, 0(t1)
    SC_CHECK_EQ t3, t2, 21
    sw s1, 0(t1)

    // PWM pwmcmp0 (offset 0x20): write and read back, then clear
    li t1, PWM_BASE
    li t2, 0x1234
    sw t2, 0x20(t1)
    lw t3, 0x20(t1)
    SC_CHECK_EQ t3, t2, 22
    sw zero, 0x20(t1)
    csrr t3, mcause
    SC_CHECK_EQ t3, zero, 23            // none of the word accesses trapped

    LOADFAULT lb, SPI_BASE, 24          // byte access to a word-only peripheral
    LOADFAULT lb, PWM_BASE, 26
    LOADFAULT lw, SDC_BASE, 28          // no SDC in this configuration

    // Non-memory instructions whose ALU sum is a peripheral address and whose funct3[1:0] = 10
    // (word size): mulhsu computes rs1 + rs2 in the adder that forms load/store addresses.
    csrw mcause, zero
    li t1, SPI_BASE
    mulhsu t2, t1, zero
    li t1, PWM_BASE
    mulhsu t2, t1, zero
    csrr t3, mcause
    SC_CHECK_EQ t3, zero, 30
    SC_CHECK_EQ t2, zero, 31            // mulhsu of a positive value by 0 is 0

    SC_PASS
    j done

.align 4                                // mtvec must be 4-byte aligned
fetchfault:
    csrr s10, mcause
    addi s8, s10, -1
    bnez s8, sc_trap_handler
    csrr s11, mtval
    addi s9, s9, 1
    csrw mepc, ra
    mret
