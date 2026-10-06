///////////////////////////////////////////
// sha256.sv
//
// Written: kelvin.tran@okstate.edu, james.stine@okstate.edu
// Created: 13 February 2024
//
// Purpose: RISC-V ZKNH 256-bit SHA: select shifted inputs and XOR3
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

module sha256 (
   input  logic [31:0] A,
   input  logic [1:0]  ZKNHSelect,
   output logic [31:0] result
);

   logic [31:0] x[4][3];
   logic [31:0] y[3];

   // sha256{sig0/sig1/sum0/sum1} select shifted operands for 32-bit xor3 and then sign-extend

   // sha256sig0
   assign x[0][0] = {A[6:0], A[31:7]};    // ror 7
   assign x[0][1] = {A[17:0], A[31:18]};  // ror 18
   assign x[0][2] = {3'b0, A[31:3]};      // >> 3

   // sha256sig1
   assign x[1][0] = {A[16:0], A[31:17]};  // ror 17
   assign x[1][1] = {A[18:0], A[31:19]};  // ror 19
   assign x[1][2] = {10'b0, A[31:10]};    // >> 10

   // sha256sum0
   assign x[2][0] = {A[1:0],  A[31:2]};   // ror 2
   assign x[2][1] = {A[12:0], A[31:13]};  // ror 13
   assign x[2][2] = {A[21:0], A[31:22]};  // ror 22

   // sha256sum1
   assign x[3][0] = {A[5:0], A[31:6]};    // ror 6
   assign x[3][1] ={ A[10:0], A[31:11]};  // ror 11
   assign x[3][2] = {A[24:0], A[31:25]};  // ror 25

   // 32-bit muxes to select inputs to xor3 for sha256
   assign y[0] = x[ZKNHSelect[1:0]][0];
   assign y[1] = x[ZKNHSelect[1:0]][1];
   assign y[2] = x[ZKNHSelect[1:0]][2];

   // sha256 32-bit xor3
   assign result = y[0] ^ y[1] ^ y[2];
endmodule
