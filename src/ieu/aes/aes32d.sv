///////////////////////////////////////////
// aes32d.sv
//
// Written:  Ryan Swann ryan.swann@okstate.edu, James Stine james.stine@okstate.edu 20 February 2024
// Modified: David Harris David_Harris@hmc.edu
//
// Purpose: Inverse S-box and InvMixColumns on one byte for the RV32 aes32dsi and aes32dsmi decryption instructions.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-27 Harvey Mudd College & Oklahoma State University
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
