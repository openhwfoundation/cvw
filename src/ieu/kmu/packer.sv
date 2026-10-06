///////////////////////////////////////////
// packer.sv
//
// Written: kelvin.tran@okstate.edu, james.stine@okstate.edu
// Created: 5 October 2023
//
// Purpose: RISCV kbitmanip pack operation unit
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
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

module packer #(parameter WIDTH=32) (
  input  logic [WIDTH/2-1:0] A, B,
  input  logic [2:0]         PackSelect,
  output logic [WIDTH-1:0]   PackResult
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

  always_comb
    if      (PackSelect[1:0] == 2'b11) PackResult = PackH;
    else if (PackSelect[2]   == 1'b0)  PackResult = Pack;
    else                               PackResult = PackW;
endmodule
