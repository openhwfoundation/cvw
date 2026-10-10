///////////////////////////////////////////
// zbkx.sv
//
// Written: kelvin.tran@okstate.edu, james.stine@okstate.edu
// Created: 1 February 2024
//
// Purpose: RISC-V ZBKX top level unit: crossbar permutation instructions for crypto
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module zbkx #(parameter WIDTH=32) (
  input  logic [WIDTH-1:0] A, B,
  input  logic             ZBKXSelect,
  output logic [WIDTH-1:0] ZBKXResult
);

  logic [WIDTH-1:0]         xperm4, xperm8;
  /* verilator lint_off UNUSEDSIGNAL */
  logic [WIDTH-1:0]         xperm4lookup, xperm8lookup; // not all bits are used
  /* verilator lint_on UNUSEDSIGNAL */
  int                       i;

  always_comb begin
    for(i=0; i<WIDTH; i=i+4) begin : xperm4calc
      xperm4lookup = A >> {B[i+:4], 2'b0};
      xperm4[i+:4] = xperm4lookup[3:0];
    end
    for(i=0; i<WIDTH; i=i+8) begin : xperm8calc
      xperm8lookup = A >> {B[i+:8], 3'b0};
      xperm8[i+:8] = xperm8lookup[7:0];
    end
  end

  assign ZBKXResult = ZBKXSelect ? xperm4 : xperm8;
endmodule
