///////////////////////////////////////////
// decompReserved.S
//
// Written: david_harris@hmc.edu 29 May 2026
//
// Purpose: Coverage for the compressed-instruction decoder (src/ifu/decompress.sv).
//          Closes the uncovered branch at decompress.sv:164 ("All False") and the
//          condition (rds1 != 5'b0)_0 in the c.jr decode:
//              5'b10100: if (instr16[12]==0) if (rs2==0) if (rds1 != 5'b0) ... // c.jr
//          c.jr requires rs1 != 0; the rs1==0 form (instr 0x8002) is a RESERVED
//          encoding that no compiler emits, so the rds1==0 / all-false path was never
//          exercised. Emitting the raw 16-bit reserved instruction drives the decoder
//          down that path (it raises an illegal-instruction trap, which the harness
//          trap handler skips by advancing mepc past the 2-byte instruction).
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////


#include "WALLY-init-lib.h"

main:
    # c.jr x0 : funct3=100, instr16[12]=0, rs1=00000, rs2=00000, op=10  => 0x8002
    # This is the RESERVED c.jr encoding (c.jr is only defined for rs1 != 0).
    # The decompressor evaluates `if (rds1 != 5'b0)` at decompress.sv:164 with rds1==0,
    # taking the previously-uncovered all-false branch / (rds1!=0)_0 condition.
    # It decodes to an illegal instruction; the trap handler advances mepc by 2 and returns.
    .2byte 0x8002

    j done
