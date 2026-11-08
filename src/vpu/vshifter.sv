///////////////////////////////////////////
// vmul.sv
//
// Written: Angela Zheng angela20061015@gmail.com
// Created: 7 Nov 2026
// Modified: 7 Nov 2026
//
// Purpose: RISC-V Vector Arithmetic/Logic Unit
//
// Documentation: RISC-V System on Chip Design Volume 2
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
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

module vshifter import cvw::*; #(parameter cvw_t P) (
    input logic [P.ELEN-1:0] A, B,
    input logic dir,    // 1 for right, 0 for left
    input logic arith,
    output logic [P.ELEN-1:0] Y
);
    logic [$clog2(P.ELEN)-1:0] shiftAmount;
    assign shiftAmount = A[$clog2(P.ELEN)-1:0];

    always_comb
        if (~dir) Y = B << shiftAmount;
        else if (arith) Y = $signed(B) >>> shiftAmount;
        else Y = B >> shiftAmount;

endmodule
