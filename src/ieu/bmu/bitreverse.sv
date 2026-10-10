///////////////////////////////////////////
// bitreverse.sv
//
// Written:  Kevin Kim kekim@hmc.edu, Kip Macsai-Goren kmacsaigoren@hmc.edu 1 February 2023
// Modified:
//
// Purpose: Reverses the bit order of a word.
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

module bitreverse #(parameter WIDTH=32) (
  input  logic [WIDTH-1:0] A,
  output logic [WIDTH-1:0] RevA);

  genvar i;
  for (i=0; i<WIDTH;i++) begin : loop
    assign RevA[WIDTH-i-1] = A[i];
  end
endmodule
