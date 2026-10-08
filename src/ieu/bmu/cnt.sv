///////////////////////////////////////////
// cnt.sv
//
// Written: Kevin Kim <kekim@hmc.edu>
// Created: 4 February 2023
// Modified:
//
// Purpose: Count Instruction Submodule
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
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

module cnt #(parameter WIDTH = 32) (
  input  logic [WIDTH-1:0] A, RevA,    // Operands
  input  logic [1:0]       B,          // Last 2 bits of immediate
  input  logic             W64,        // Indicates word operation
  output logic [WIDTH-1:0] CntResult   // count result
);

  //count instructions
  logic [WIDTH-1:0] czResult;        // count zeros result
  logic [WIDTH-1:0] cpopResult;      // population count result
  logic [WIDTH-1:0] lzcA, popcntA;

  //only in rv64
  if (WIDTH==64) begin
    //clz input select mux
    mux4 #(WIDTH) lzcmux64(A, {A[31:0],{32{1'b1}}}, RevA, {RevA[63:32],{32{1'b1}}}, {B[0],W64}, lzcA);
    //cpop select mux
    mux2 #(WIDTH) popcntmux64(A, {{32{1'b0}}, A[31:0]}, W64, popcntA);
  end
  //rv32
  else begin
    assign popcntA = A;
    mux2 #(WIDTH) lzcmux32(A, RevA, B[0], lzcA);
  end

  lzc #(WIDTH) lzc(.num(lzcA), .ZeroCnt(czResult[$clog2(WIDTH):0]));
  popcnt #(WIDTH) popcntw(.num(popcntA), .PopCnt(cpopResult[$clog2(WIDTH):0]));
  // zero extend these results to fit into width
  assign czResult[WIDTH-1:$clog2(WIDTH)+1] = '0;
  assign cpopResult[WIDTH-1:$clog2(WIDTH)+1] = '0;

  mux2 #(WIDTH) cntresultmux(czResult, cpopResult, B[1], CntResult);
endmodule
