///////////////////////////////////////////
// zbkb.sv
//
// Written: kelvin.tran@okstate.edu, james.stine@okstate.edu
// Created: 4 October 2023
//
// Purpose: RISC-V ZBKB top level unit: bit manipulation instructions for crypto
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

module zbkb #(parameter WIDTH=32) (
  input  logic [WIDTH-1:0]   A,
  input  logic [WIDTH/2-1:0] B,
  input  logic [2:0]         Funct3,
  input  logic [2:0]         ZBKBSelect,
  output logic [WIDTH-1:0]   ZBKBResult
);

  logic [WIDTH-1:0]         Brev8Result;  // rev8, brev8
  logic [WIDTH-1:0]         PackResult;   // pack, packh, packw (RB64 only)
  logic [WIDTH-1:0]         ZipResult;    // zip, unzip

  // brev8 just uses wires
  genvar i, j;
  for (i=0;i<WIDTH/8;i=i+1)
    for (j=0; j<8; j=j+1)
      assign Brev8Result[i*8+j] = A[i*8+7-j];

  packer #(WIDTH) pack(.A(A[WIDTH/2-1:0]), .B(B[WIDTH/2-1:0]), .PackSelect({ZBKBSelect[2], Funct3[1:0]}), .PackResult);
  zipper #(WIDTH) zipper(.A, .ZipSelect(Funct3[2]), .ZipResult);

  // ZBKB Result Select Mux
  mux3 #(WIDTH) zbkbresultmux(Brev8Result, PackResult, ZipResult, ZBKBSelect[1:0], ZBKBResult);
endmodule
