///////////////////////////////////////////
// aes64ks1i.sv
//
// Written:  Ryan Swann ryan.swann@okstate.edu, James Stine james.stine@okstate.edu 20 February 2024
// Modified: David Harris David_Harris@hmc.edu, Kelvin Tran kelvin.tran@okstate.edu
//
// Purpose: AES key schedule step for aes64ks1i: rotate a word, substitute it through the shared S-box, and XOR the round constant.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module aes64ks1i(
  input  logic [3:0]   round,
  input  logic [63:32] rs1,
  input  logic [31:0]  Sbox0Out,
  output logic [31:0]  SboxKIn,
  output logic [63:0]  result
);

  logic               finalround;
  logic [31:0]        rcon, rs1Rotate;

  rconlut32 rc(round, rcon);                             // Get rcon value from lookup table
  assign rs1Rotate = {rs1[39:32], rs1[63:40]};           // Get rotated value for use in tmp2
  assign finalround = (round == 4'b1010);                // round 10 is the last one
  assign SboxKIn = finalround ? rs1[63:32] : rs1Rotate;  // Don't rotate on the last round

  // Share sbox with encryption in zknde64.  This module just sends value to shared sbox and gets result back
  // send out value as SboxKIn, get back subsittuted result as Sbox0Out

  assign result[31:0]  = Sbox0Out ^ rcon;
  assign result[63:32] = Sbox0Out ^ rcon;
endmodule
