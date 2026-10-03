///////////////////////////////////////////
// icachebusbusy.S
//
// Written: David_Harris@hmc.edu 3 October 2026
//
// Purpose: Test coverage for an instruction cache miss that asks for the bus while the LSU's
//          transfer still holds it.  The IFU and LSU normally miss in the same cycle, when the
//          pipeline advances, and the EBU arbitrates between them.  A spill is the exception:
//          the IFU fetches the second half of a spilled instruction a cycle after the first,
//          even while the pipeline is stalled.  Here the first half hits in the instruction
//          cache in the cycle a load from the CLINT starts on the bus, and the second half
//          misses in the next cycle, while the APB bridge holds HREADY low for the load.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-init-lib.h"
.option norvc

main:
    li t0, 0x0200BFF8       # CLINT mtime
    j linea

.align 6                    # start of an instruction cache line
linea:
    .rept 12
    nop
    .endr
    .option rvc
    c.nop                   # puts the lw at 0x32, so the spilled addi is at 0x3E
    .option norvc
    lw t1, 0(t0)            # in the Memory stage when the addi is in Fetch
    nop
    nop
    addi t2, t2, 1          # spills into the next line, which has not been fetched yet

    j done
