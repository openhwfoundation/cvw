///////////////////////////////////////////
// synchronizer.sv
//
// Written: David_Harris@hmc.edu 25 October 2021
// Modified:
//
// Purpose: Two-stage flip-flop synchronizer
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module synchronizer (
  input  logic clk,
  input  logic d,
  output logic q);

  logic mid;

  always_ff @(posedge clk) begin
    mid <= d;
    q <= mid;
  end
endmodule
