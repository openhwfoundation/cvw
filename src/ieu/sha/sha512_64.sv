///////////////////////////////////////////
// sha512_64.sv
//
// Written: kelvin.tran@okstate.edu, james.stine@okstate.edu
// Created: 13 February 2024
//
// Purpose: RISC-V (RV64) ZKNH 512-bit SHA: select shifted inputs and XOR3
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

module sha512_64 (
   input  logic [63:0] A,
   input  logic [1:0]  ZKNHSelect,
   output logic [63:0] result
);

   logic [63:0] x[4][3];
   logic [63:0] y[3];

   // sha512{sig0/sig1/sum0/sum1} select rotated/shifted operands for 64-bit xor3

   // sha512sig0
   assign x[0][0] = {A[0],   A[63:1]};    // ror 1
   assign x[0][1] = {A[7:0], A[63:8]};    // ror 8
   assign x[0][2] = {7'b0,   A[63:7]};    // >> 7

   // sha512sig1
   assign x[1][0] = {A[18:0], A[63:19]};  // ror 19
   assign x[1][1] = {A[60:0], A[63:61]};  // ror 61
   assign x[1][2] = {6'b0,    A[63:6]};   // >> 6

   // sha512sum0
   assign x[2][0] = {A[27:0], A[63:28]};  // ror 28
   assign x[2][1] = {A[33:0], A[63:34]};  // ror 34
   assign x[2][2] = {A[38:0], A[63:39]};  // ror 39

   // sha512sum1
   assign x[3][0] = {A[13:0], A[63:14]};  // ror 14
   assign x[3][1] = {A[17:0], A[63:18]};  // ror 18
   assign x[3][2] = {A[40:0], A[63:41]};  // ror 41

   // 64-bit muxes to select inputs to xor3 for sha512
   assign y[0] = x[ZKNHSelect[1:0]][0];
   assign y[1] = x[ZKNHSelect[1:0]][1];
   assign y[2] = x[ZKNHSelect[1:0]][2];

   // sha512 64-bit xor3
   assign result = y[0] ^ y[1] ^ y[2];
endmodule
