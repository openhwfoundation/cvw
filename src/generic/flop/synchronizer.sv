///////////////////////////////////////////
// synchronizer.sv
//
// Written:  David Harris David_Harris@hmc.edu 25 October 2021
// Modified: Rose Thompson
//
// Purpose: Two-stage synchronizer.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module synchronizer #(parameter WIDTH = 1) (
  input  logic             clk,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  logic [WIDTH-1:0] mid;

  always_ff @(posedge clk) begin
    mid <= d;
    q <= mid;
  end
endmodule
