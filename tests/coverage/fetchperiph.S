///////////////////////////////////////////
// fetchperiph.S
//
// Written: David_Harris@hmc.edu 3 October 2026
//
// Purpose: Test coverage for instruction fetches from the peripherals.  The peripherals only
//          accept reads and writes, so a fetch from one matches its address decoder in the
//          instruction PMA checker but is not a valid access, and takes an instruction access
//          fault.  The UART is not fetched from: it only accepts byte accesses, and the IFU
//          always checks a word.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

// FETCHFAULT adr, index: jump to adr, which must take an instruction access fault (mcause 1) with
// mtval = adr.  fetchfault records mcause in s10 and mtval in s11, and counts the faults in s9.
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
    la t0, fetchfault       # the fault returns to ra, after the jump that faulted
    csrw mtvec, t0

    FETCHFAULT 0x02000000, 1    # CLINT
    FETCHFAULT 0x0C000000, 3    # PLIC
    FETCHFAULT 0x10020000, 5    # PWM
    FETCHFAULT 0x10040000, 7    # SPI
    FETCHFAULT 0x10060000, 9    # GPIO

    la t0, trap_handler
    csrw mtvec, t0
    li t2, 5
    SC_CHECK_EQ s9, t2, 11      # exactly five instruction access faults

    SC_PASS
    j done

// Instruction access faults: record mcause and mtval, count, and return after the jump that
// faulted.  Anything else goes to sc_trap_handler, which fails the test.
.align 2
fetchfault:
    csrr s10, mcause
    addi s8, s10, -1
    bnez s8, sc_trap_handler
    csrr s11, mtval
    addi s9, s9, 1
    csrw mepc, ra
    mret
