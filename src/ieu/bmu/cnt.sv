///////////////////////////////////////////
// cnt.sv
//
// Written:  Kevin Kim kekim@hmc.edu 4 February 2023
// Modified:
//
// Purpose: Leading zero, trailing zero, and population counts for clz, ctz, cpop, and their W forms.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2023-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
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
