///////////////////////////////////////////
// vshifter.sv
//
// Written: Angela Zheng angela20061015@gmail.com
// Created: 7 Nov 2026
// Modified: 9 Nov 2026
//
// Purpose: RISC-V Vector Shifter Unit
//
// Documentation: RISC-V System on Chip Design Volume 2
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module vshifter import cvw::*; #(parameter cvw_t P) (
    input logic [P.ELEN-1:0]                B,
    input logic [$clog2(P.ELEN)-1:0]        Amt,                // Shift amount, log2(SEW)
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
