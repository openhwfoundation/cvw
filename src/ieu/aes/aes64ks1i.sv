///////////////////////////////////////////
// aes64ks1i.sv
//
// Written: ryan.swann@okstate.edu, james.stine@okstate.edu
// Created: 20 February 2024
//
// Purpose: aes64ks1i instruction: part of AES keyschedule with involving sbox
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
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
