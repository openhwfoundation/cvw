///////////////////////////////////////////
// vshifter.sv
//
// Written: Angela Zheng angela20061015@gmail.com
// Created: 7 Nov 2026
// Modified: 9 Nov 2026
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
    input logic [P.ELEN-1:0]                B,
    input logic [$clog2(P.ELEN)-1:0]        Amt,                // Shift amount
    input logic                             Right, SubArith,    // Shift right, arithmetic shift
    output logic [P.ELEN-1:0]               Y
);
    logic [2*P.ELEN-2:0]    Z, Zshift;
    logic [$clog2(P.ELEN)-1:0] Offset;           // funnel shift amount
    logic [P.ELEN-2:0]      Zero;                // ELEN copies of zero and sign
    logic                   Sign;

    assign Sign = B[P.ELEN-1] & SubArith;
    assign Zero = '0;
    always_comb
        case ({Right, SubArith})
            2'b00: Z = {B[P.ELEN-1:0], Zero};
            2'b01: Z = {B[P.ELEN-1:0], Zero};
            2'b10: Z = {Zero, B[P.ELEN-1:0]};
            2'b11: Z = {{(P.ELEN-1){Sign}}, B[P.ELEN-1:0]};
        endcase

    // Shift right Amt for right shifts, and (~Amt) for left shifts
    assign Offset = Right ? Amt : ~Amt;
    assign Zshift = Z >> Offset;
    assign Y = Zshift[P.ELEN-1:0];

endmodule
