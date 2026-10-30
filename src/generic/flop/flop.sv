///////////////////////////////////////////
// flop.sv
//
// Written:  David Harris David_Harris@hmc.edu 9 January 2021
// Modified:
//
// Purpose: D flip-flop.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module flop #(parameter WIDTH = 8) (
  input  logic             clk,
  input  logic [WIDTH-1:0] d,   // Data input
  output logic [WIDTH-1:0] q);  // Data output

  always_ff @(posedge clk)
    q <= d;
endmodule
