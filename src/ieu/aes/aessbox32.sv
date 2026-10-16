///////////////////////////////////////////
// aessbox32.sv
//
// Written: ryan.swann@okstate.edu, james.stine@okstate.edu
// Created: 20 February 2024
//
// Purpose: 4 sets of Rijndael S-BOX so whole word can be looked up simultaneously.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module aessbox32(
   input  logic [31:0] a,
   output logic [31:0] y
);

   // substitutions boxes for each byte of the 32-bit word
   aessbox8 sbox0(a[7:0],   y[7:0]);
   aessbox8 sbox1(a[15:8],  y[15:8]);
   aessbox8 sbox2(a[23:16], y[23:16]);
   aessbox8 sbox3(a[31:24], y[31:24]);
endmodule
