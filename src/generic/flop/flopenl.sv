///////////////////////////////////////////
// flopenl.sv
//
// Written:  David Harris David_Harris@hmc.edu 9 January 2021
// Modified:
//
// Purpose: D flip-flop with enable and synchronous load of a given value.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module flopenl #(parameter WIDTH = 8, parameter type TYPE=logic [WIDTH-1:0]) (
  input  logic clk, load, en,
  input  TYPE d,
  input  TYPE val,
  output TYPE q);

  always_ff @(posedge clk)
    if (load)    q <= val;
    else if (en) q <= d;
endmodule
