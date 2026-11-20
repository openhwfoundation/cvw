///////////////////////////////////////////
// vsext.sv
//
// Written: Malina Andrews mandrews@g.hmc.edu
// Created: 11 November 2026
// Modified: 17 November 2026
//
// Purpose: Vector sign and zero extend
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


module vext import cvw::*; #(parameter cvw_t P) (
input  logic [4:0] Vs1,
input  logic [P.ELEN-1:0]  B,
output logic [P.ELEN-1:0] ExtResult
);
always_comb
    case(Vs1[2:0])
    3'b000:  ExtResult = {{32{B[31]}}, B[31:0]}; // vf2 sign extend SEW/2 (e32) to SEW destination, lmul = 1
    3'b101:  ExtResult = {{48{B[15]}}, B[15:0]}; // vf4 sign extend SEW/4 (e16) to SEW destination, lmul = 1
    3'b011:  ExtResult = {{56{B[7]}},  B[7:0]};  // vf8 sign extend SEW/8 (e8) to SEW destination, lmul = 1
    3'b110:  ExtResult = {{32'b0}, B[31:0]};     // vf2 zero extend SEW/2 (e32) to SEW destination, lmul = 1
    3'b100:  ExtResult = {{48'b0}, B[15:0]};     // vf4 zero extend SEW/4 (e16) to SEW destination, lmul = 1
    3'b010:  ExtResult = {{56'b0},  B[7:0]};     // vf8 zero extend SEW/8 (e8) to SEW destination, lmul = 1
    default: ExtResult = {{32{B[31]}}, B[31:0]}; // vsext.vf2 is default
    endcase
endmodule
