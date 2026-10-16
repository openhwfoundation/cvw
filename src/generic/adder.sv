///////////////////////////////////////////
// adder.sv
//
// Written: David_Harris@hmc.edu 2 October 2021
// Modified:
//
// Purpose: Adder
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module adder #(parameter WIDTH=8) (
  input  logic [WIDTH-1:0] a, b,
  output logic [WIDTH-1:0] y
);

  assign y = a + b;
endmodule
