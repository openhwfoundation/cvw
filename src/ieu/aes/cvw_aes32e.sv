///////////////////////////////////////////
// cvw_aes32e.sv
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

module cvw_aes32e(
  input  logic [7:0]  SboxIn,
  input  logic        finalround,
  output logic [31:0] result
);

  logic [7:0]         SboxOut;
  logic [31:0]        so, mixed;

  cvw_aessbox8 sbox(SboxIn, SboxOut);                 // Substitute
  assign so = {24'h0, SboxOut};                   // Pad sbox output
  cvw_aesmixcolumns32 mb(so, mixed);                  // Mix using MixColumns component
  cvw_mux2 #(32) rmux(mixed, so, finalround, result); // on final round, skip MixColumns
endmodule
