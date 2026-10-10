///////////////////////////////////////////
// sha512_32.sv
//
// Written:  Kelvin Tran kelvin.tran@okstate.edu, James Stine james.stine@okstate.edu 13 February 2024
// Modified: David Harris David_Harris@hmc.edu
//
// Purpose: RV32 SHA-512 sig0h/l, sig1h/l, sum0r, and sum1r functions on a 64-bit value split across two registers.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module sha512_32 (
   input  logic [31:0] A, B,
   input  logic [2:0]  ZKNHSelect,
   output logic [31:0] result
);

   logic [31:0] x[4][3];
   logic [31:0] y[3];

   // rotate/shift a 64-bit value contained in {B, A} and select 32 bits
   // sha512{sig0h/sig0l/sig1h/sig1l/sum0r/sum1r} select shifted operands for 32-bit xor

   // The l flavors differ from h by using low bits of B instead of zeros in x[0/1][2]

   // sha512sig0h/l
   assign x[0][0] = {B[0], A[31:1]};                           // ror 1
   assign x[0][1] = {B[7:0], A[31:8]};                         // ror 8
   assign x[0][2] = {B[6:0] & {7{ZKNHSelect[0]}}, A[31:7]};    // ror/srl 7

   // sha512sig1h/l
   assign x[1][0] = {A[28:0], B[31:29]};                       // ror 61
   assign x[1][1] = {B[18:0], A[31:19]};                       // ror 19
   assign x[1][2] = {B[5:0] & {6{ZKNHSelect[0]}}, A[31:6]};    // ror/srl 6

   // sha512sum0r
   assign x[2][0] = {A[6:0], B[31:7]};                         // ror 39
   assign x[2][1] = {A[1:0], B[31:2]};                         // ror 34
   assign x[2][2] = {B[27:0], A[31:28]};                       // ror 28

   // sha512sum1r
   assign x[3][0] = {A[8:0], B[31:9]};                         // ror 41
   assign x[3][1] = {B[13:0], A[31:14]};                       // ror 14
   assign x[3][2] = {B[17:0], A[31:18]};                       // ror 18

   // 32-bit muxes to select inputs to xor6 for sha512
   assign y[0] = x[ZKNHSelect[2:1]][0];
   assign y[1] = x[ZKNHSelect[2:1]][1];
   assign y[2] = x[ZKNHSelect[2:1]][2];

   // sha512 32-bit xor6
   assign result = y[0] ^ y[1] ^ y[2];
endmodule
