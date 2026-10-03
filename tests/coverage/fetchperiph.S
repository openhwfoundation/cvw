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

main:
    la t0, fetchfault       # the fault returns to ra, after the jump that faulted
    csrw mtvec, t0

    li t1, 0x02000000       # CLINT
    jalr ra, t1
    li t1, 0x0C000000       # PLIC
    jalr ra, t1
    li t1, 0x10020000       # PWM
    jalr ra, t1
    li t1, 0x10040000       # SPI
    jalr ra, t1
    li t1, 0x10060000       # GPIO
    jalr ra, t1

    la t0, trap_handler
    csrw mtvec, t0
    j done

.align 2
fetchfault:
    csrw mepc, ra
    mret
