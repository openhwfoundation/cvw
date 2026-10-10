///////////////////////////////////////////
// galoismultforward8.sv
//
// Written:  Ryan Swann ryan.swann@okstate.edu, James Stine james.stine@okstate.edu, David Harris David_Harris@hmc.edu 20 February 2024
// Modified: Kelvin Tran kelvin.tran@okstate.edu
//
// Purpose: Multiplies a byte by 2 in GF(2^8) modulo the AES polynomial for MixColumns.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module galoismultforward8(
   input  logic [7:0] a,
   output logic [7:0] y
);

   logic [7:0] leftshift;

   assign leftshift = {a[6:0], 1'b0};
   assign y = a[7] ? (leftshift ^ 8'b00011011) : leftshift;
endmodule
