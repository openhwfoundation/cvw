///////////////////////////////////////////
// aesinvsbox64.sv
//
// Written: ryan.swann@okstate.edu, james.stine@okstate.edu
// Created: 20 February 2024
//
// Purpose: 4 sets of Rinjdael Inverse S-BOX for whole word look up
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module aesinvsbox64(
   input  logic [63:0] a,
   output logic [63:0] y
);

   // inverse substitutions boxes for each byte of the 32-bit word
   aesinvsbox8 sbox0(a[7:0],   y[7:0]);
   aesinvsbox8 sbox1(a[15:8],  y[15:8]);
   aesinvsbox8 sbox2(a[23:16], y[23:16]);
   aesinvsbox8 sbox3(a[31:24], y[31:24]);
   aesinvsbox8 sbox4(a[39:32], y[39:32]);
   aesinvsbox8 sbox5(a[47:40], y[47:40]);
   aesinvsbox8 sbox6(a[55:48], y[55:48]);
   aesinvsbox8 sbox7(a[63:56], y[63:56]);
endmodule
