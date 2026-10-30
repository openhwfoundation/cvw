///////////////////////////////////////////
// aes64ks1i.sv
//
// Written:  Ryan Swann ryan.swann@okstate.edu, James Stine james.stine@okstate.edu 20 February 2024
// Modified: David Harris, Kelvin Tran
//
// Purpose: AES key schedule step aes64ks1i.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module aes64ks1i(
  input  logic [3:0]   round,    // Round number
  input  logic [63:32] rs1,      // Source operand 1
  input  logic [31:0]  Sbox0Out, // Shared S-box output
  output logic [31:0]  SboxKIn,  // Input to shared S-box
  output logic [63:0]  result    // Result
);

  logic               finalround;
  logic [31:0]        rcon, rs1Rotate;

  rconlut32 rc(round, rcon);                             // Get rcon value from lookup table
  assign rs1Rotate = {rs1[39:32], rs1[63:40]};           // Get rotated value for use in tmp2
  assign finalround = (round == 4'b1010);                // round 10 is the last one
  assign SboxKIn = finalround ? rs1[63:32] : rs1Rotate;  // Don't rotate on the last round

  // Share sbox with encryption in zknde64.  This module just sends value to shared sbox and gets result back
  // send out value as SboxKIn, get back substituted result as Sbox0Out

  assign result = {2{Sbox0Out ^ rcon}};                  // Both words of the result are the same
endmodule
