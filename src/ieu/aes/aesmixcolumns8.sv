///////////////////////////////////////////
// aesmixcolumns8.sv
//
// Written: ryan.swann@okstate.edu, james.stine@okstate.edu, David_Harris@hmc.edu
// Created: 20 February 2024
//
// Purpose: Galois field operation to byte in an individual 32-bit word
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////


module aesmixcolumns8(
   input  logic [7:0]  a,
   output logic [31:0] y
);

   logic [7:0] xa, xapa;

   galoismultforward8 gm(a, xa); // xa
   assign xapa = a ^ xa;         // a ^ xa
   assign y = {xapa, a, a, xa};
endmodule
