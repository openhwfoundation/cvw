///////////////////////////////////////////
// packer.sv
//
// Written:  Kelvin Tran kelvin.tran@okstate.edu, James Stine james.stine@okstate.edu 5 October 2023
// Modified: David Harris
//
// Purpose: Zbkb pack, packh, and packw.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2023-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module packer #(parameter WIDTH=32) (
  input  logic [WIDTH/2-1:0] A, B,
  input  logic [2:0]         PackSelect,
  output logic [WIDTH-1:0]   PackResult
);

  logic [WIDTH-1:0]     Pack, PackH, PackW;

  assign Pack  = {B, A};                                                     // low halves of rs2 and rs1
  assign PackH = {{(WIDTH-16){1'b0}}, B[7:0], A[7:0]};                       // low bytes, zero-extended
  assign PackW = (WIDTH == 64) ? {{(WIDTH-32){B[15]}}, B[15:0], A[15:0]} : Pack;  // low 16 bits, sign-extended; not implemented for RV32, so treat as Pack to simplify logic in result mux

  // PackSelect = {packw, Funct3[1:0]}; packh has Funct3 = 111, pack has Funct3 = 100
  always_comb
    if      (PackSelect[1:0] == 2'b11) PackResult = PackH;
    else if (PackSelect[2]   == 1'b0)  PackResult = Pack;
    else                               PackResult = PackW;
endmodule
