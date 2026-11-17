///////////////////////////////////////////
// vsext.sv
//
// Written: Malina Andrews mandrews@g.hmc.edu
// Created: 11 November 2026
// Modified: 17 November 2026
//
// Purpose: Vector sign extend
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


module vsext import cvw::*; #(parameter cvw_t P) (
input logic [P.ELEN-1:0]  B,           //  source register, vs2 = B
input logic [1:0]         Fraction,        // vf2, vf4, vf8
output logic [P.ELEN-1:0] Vd
);
always_comb
    case(Fraction)
    2'b11: Vd = {{32{B[31]}}, B[31:0]}; // vf2 sign extend SEW/2 (e32) to SEW destination, lmul = 1
    2'b10: Vd = {{48{B[15]}}, B[15:0]}; // vf4 sign extend SEW/4 (e16) to SEW destination, lmul = 1
    2'b01: Vd = {{56{B[7]}},  B[7:0]};  // vf8 sign extend SEW/8 (e8) to SEW destination, lmul = 1
    default: Vd = '0;
    endcase
endmodule
//*** want to double check that input signal Fraction is how the selection btwn vf2, vf4 and vf8 should be happening for vsext and vzext
