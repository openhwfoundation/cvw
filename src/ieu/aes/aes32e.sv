///////////////////////////////////////////
// aes32e.sv
//
// Written: ryan.swann@okstate.edu, james.stine@okstate.edu
// Created: 20 February 2024
//
// Purpose: aes32esmi and aes32esi instruction: RV32 middle and final round AES encryption
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module aes32e(
  input  logic [7:0]  SboxIn,
  input  logic        finalround,
  output logic [31:0] result
);

  logic [7:0]         SboxOut;
  logic [31:0]        so, mixed;

  aessbox8 sbox(SboxIn, SboxOut);                 // Substitute
  assign so = {24'h0, SboxOut};                   // Pad sbox output
  aesmixcolumns32 mb(so, mixed);                  // Mix using MixColumns component
  mux2 #(32) rmux(mixed, so, finalround, result); // on final round, skip MixColumns
endmodule
