///////////////////////////////////////////
// aes32e.sv
//
// Written:  Ryan Swann ryan.swann@okstate.edu, James Stine james.stine@okstate.edu 20 February 2024
// Modified: David Harris
//
// Purpose: RV32 AES encryption (aes32esi, aes32esmi).
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module aes32e(
  input  logic [7:0]  SboxIn,     // S-box input byte
  input  logic        finalround, // Final round of AES (skip MixColumns)
  output logic [31:0] result      // Result
);

  logic [7:0]         SboxOut;
  logic [31:0]        so, mixed;

  aessbox8 sbox(SboxIn, SboxOut);                 // Substitute
  assign so = {24'h0, SboxOut};                   // Pad sbox output
  aesmixcolumns32 mb(so, mixed);                  // Mix using MixColumns component
  mux2 #(32) rmux(mixed, so, finalround, result); // on final round, skip MixColumns
endmodule
