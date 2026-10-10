///////////////////////////////////////////
// flopenr.sv
//
// Written:  David Harris David_Harris@hmc.edu 9 January 2021
// Modified:
//
// Purpose: D flip-flop with enable and synchronous reset.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module flopenr #(parameter WIDTH = 8) (
  input  logic             clk, reset, en,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  always_ff @(posedge clk)
    if (reset)   q <= '0;
    else if (en) q <= d;
endmodule
