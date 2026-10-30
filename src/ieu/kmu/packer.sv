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
  input  logic [WIDTH/2-1:0] A, B,       // Operands
  input  logic [2:0]         PackSelect, // Pack operation select: {packw, funct3[1:0]}
  output logic [WIDTH-1:0]   PackResult  // pack result
);

  logic [WIDTH/2-1:0]   lowhalf, highhalf;
  logic [7:0]           lowhalfh, highhalfh;
  logic [15:0]          lowhalfw, highhalfw;
  logic [WIDTH-1:0]     Pack, PackH, PackW;

  assign lowhalf   = A[WIDTH/2-1:0];
  assign highhalf  = B[WIDTH/2-1:0];
  assign lowhalfh  = A[7:0];
  assign highhalfh = B[7:0];
  assign lowhalfw  = A[15:0];
  assign highhalfw = B[15:0];

  assign Pack = {highhalf, lowhalf};
  assign PackH = {{(WIDTH-16){1'b0}}, highhalfh, lowhalfh};
  assign PackW = (WIDTH == 64) ? {{(WIDTH-32){highhalfw[15]}}, highhalfw, lowhalfw} : Pack;  // not implemented for RV32; treat as Pack to simplify logic in result mux

  // PackSelect = {packw, Funct3[1:0]}; packh has Funct3 = 111, pack has Funct3 = 100
  always_comb
    if      (PackSelect[1:0] == 2'b11) PackResult = PackH;
    else if (PackSelect[2]   == 1'b0)  PackResult = Pack;
    else                               PackResult = PackW;
endmodule
