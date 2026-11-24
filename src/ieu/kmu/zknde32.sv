///////////////////////////////////////////
// zknde32.sv
//
// Written:  Kelvin Tran kelvin.tran@okstate.edu, James Stine james.stine@okstate.edu 27 November 2023
// Modified: David Harris
//
// Purpose: RV32 Zkne/Zknd AES unit.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2023-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module zknde32 import cvw::*; #(parameter cvw_t P) (
  input  logic [31:0] A, B,
  input  logic [1:0]  bs,
  input  logic [3:0]  ZKNSelect,
  output logic [31:0] ZKNDEResult
);

  logic           Decrypt;
  logic [4:0]     shamt;
  logic [7:0]     SboxIn, SboxOut;
  logic [31:0]    so, Mixed, InvMixed, rotin, rotout;

  // ZKNSelect[2] = final round (aes32dsi/aes32esi), ZKNSelect[0] = encrypt
  assign Decrypt = P.ZKND_SUPPORTED & (~P.ZKNE_SUPPORTED | ~ZKNSelect[0]);

  // Initial shamt and Sbox input selection steps shared between encrypt and decrypt
  assign shamt = {bs, 3'b0};      // shamt = bs * 8 (convert bytes to bits)
  assign SboxIn = B[shamt +: 8];  // select byte bs of rs2

  // One S-box shared by encrypt and decrypt
  aessboxfwdinv8 sb(.a(SboxIn), .inv(Decrypt), .y(SboxOut));
  assign so = {24'h0, SboxOut};

  // MixColumns or InvMixColumns of the column holding only the substituted byte; skip on the final round
  if (P.ZKNE_SUPPORTED) begin : zkne
    aesmixcolumns32 mix(so, Mixed);
  end else assign Mixed = '0;
  if (P.ZKND_SUPPORTED) begin : zknd
    aesinvmixcolumns8 invmix(SboxOut, InvMixed);
  end else assign InvMixed = '0;
  assign rotin = ZKNSelect[2] ? so : (Decrypt ? InvMixed : Mixed);

  // final rotate and XOR steps shared between encrypt and decrypt
  mux4 #(32) mrotmux(rotin, {rotin[23:0], rotin[31:24]},
                     {rotin[15:0], rotin[31:16]}, {rotin[7:0], rotin[31:8]}, bs, rotout); // Rotate the mixcolumns output left by shamt (bs * 8)
  assign ZKNDEResult = A ^ rotout; // xor with running value (A = rs1)
endmodule
