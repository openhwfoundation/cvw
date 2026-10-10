///////////////////////////////////////////
// aes32d.sv
//
// Written: ryan.swann@okstate.edu, james.stine@okstate.edu
// Created: 20 February 2024
//
// Purpose: aes32dsmi and aes32dsi instruction: RV32 middle and final round AES decryption
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module aes32d(
  input  logic [7:0]  SboxIn,
  input  logic        finalround,
  output logic [31:0] result
);

  logic [7:0]         SboxOut;
  logic [31:0]        so, mixed;

   aesinvsbox8 inv_sbox(SboxIn, SboxOut);          // Apply inverse sbox to si
   aesinvmixcolumns8 mix(SboxOut, mixed);          // Run so through the InvMixColumns AES function
   assign so = {24'h0, SboxOut};                   // Pad output of inverse substitution box
   mux2 #(32) rmux(mixed, so, finalround, result); // on final round, skip mixcolumns
endmodule
