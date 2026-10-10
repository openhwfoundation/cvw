///////////////////////////////////////////
// counter.sv
//
// Written:  David Harris David_Harris@hmc.edu 10 October 2021
// Modified:
//
// Purpose: Up counter with synchronous reset and enable.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module counter #(parameter WIDTH=8) (
  input  logic             clk, reset, en,
  output logic [WIDTH-1:0] q
);

  logic [WIDTH-1:0] qnext;

  assign qnext = q + 1;
  flopenr #(WIDTH) cntrflop(clk, reset, en, qnext, q);
endmodule
