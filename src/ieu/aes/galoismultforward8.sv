///////////////////////////////////////////
// galoismultforward.sv
//
// Written: ryan.swann@okstate.edu, james.stine@okstate.edu, David_Harris@hmc.edu
// Created: 20 February 2024
//
// Purpose: Galois field operations for mix columns operation
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
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
