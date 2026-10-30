///////////////////////////////////////////
// galoismultforward8.sv
//
// Written:  Ryan Swann ryan.swann@okstate.edu, James Stine james.stine@okstate.edu, David Harris David_Harris@hmc.edu 20 February 2024
// Modified: Kelvin Tran
//
// Purpose: GF(2^8) multiply by 2 for AES MixColumns.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module galoismultforward8(
  input  logic [7:0] a, // Input
  output logic [7:0] y  // Output
);

  logic [7:0] leftshift;

  assign leftshift = {a[6:0], 1'b0};
  // Multiply by x in GF(2^8): shift left and reduce by the AES polynomial (0x1B) if bit 7 overflows
  assign y = a[7] ? (leftshift ^ 8'b00011011) : leftshift;
endmodule
