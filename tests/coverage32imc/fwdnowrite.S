///////////////////////////////////////////
// fwdnowrite.S
//
// Written: David_Harris@hmc.edu 30 October 2026
//
// Purpose: The forwarding logic in controller.sv compares each Execute-stage source with RdW, which is
//          bits 11:7 of the Writeback-stage instruction whatever its type, and forwards only when
//          RegWriteW is set.  A store has no rd, so bits 11:7 hold the low bits of its offset: sb with an
//          offset of 6 makes RdW = x6 with RegWriteW = 0.  Two instructions later, an instruction that
//          reads x6 as rs1, then as rs2, must take x6 from the register file rather than forward
//          (covers the RegWriteW_0 row of (Rs1E == RdW) & RegWriteW, and of the Rs2E version).
//          Self-checking: failure index 1 (rs1 read) and 2 (rs2 read) check that each result is x6.
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

.option norvc                           # keep the three-instruction spacing exact

main:
    la a0, buf
    li t0, 0x5A
    li t1, 0x1234                       # x6, read from the register file below
    sb t0, 6(a0)                        # bits 11:7 = 6: RdW = x6, RegWriteW = 0
    nop
    add t2, t1, zero                    # rs1 = x6 in Execute while the sb is in Writeback
    sb t0, 6(a0)
    nop
    add t3, zero, t1                    # rs2 = x6 in Execute while the sb is in Writeback

    li t4, 0x1234
    SC_CHECK_EQ t2, t4, 1
    SC_CHECK_EQ t3, t4, 2

    SC_PASS
    j done

.data
.p2align 3
buf:
    .fill 2, 4, 0
