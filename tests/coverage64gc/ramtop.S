///////////////////////////////////////////
// ramtop.S
//
// Written: david_harris@hmc.edu 14 October 2026
//
// Purpose: The top doubleword of the uncore RAM region must be backed by storage.  Before the
//          ram_ahb fix, the array held RANGE/8 = 2^24 - 1 doublewords, one short of the 128 MiB
//          region, so 0x87FFFFF8 was out of the array.  The D$ hides the array until a
//          writeback, so force the line through with cbo.flush + cbo.inval.
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

main:
    li t5, 0x87FFFFC0         // top cache line of the 128 MiB UNCORE_RAM region
    li t6, 0x123456789ABCDEF0
    sd t6, 56(t5)             // 0x87FFFFF8: the region's last doubleword
    cbo.flush (t5)            // write the line back to the RAM array
    cbo.inval (t5)
    ld t2, 56(t5)             // refill from the RAM array
    SC_CHECK_EQ t2, t6, 1
    SC_PASS
    j done
