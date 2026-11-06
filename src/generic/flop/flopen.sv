///////////////////////////////////////////
// flopen.sv
//
// Written: David_Harris@hmc.edu 9 January 2021
// Modified:
//
// Purpose: D flip-flop with enable
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module flopen #(parameter WIDTH = 8) (
  input  logic             clk, en,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  always_ff @(posedge clk)
    if (en) q <= d;
endmodule
