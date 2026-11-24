///////////////////////////////////////////
// zknde64.sv
//
// Written:  Kelvin Tran kelvin.tran@okstate.edu, James Stine james.stine@okstate.edu 27 November 2023
// Modified: David Harris
//
// Purpose: RV64 Zkne/Zknd AES unit.
//          Encryption, decryption, and aes64ks1i share eight forward/inverse S-boxes, and
//          InvMixColumns is computed as MixColumns of a preprocessed column (Daemen & Rijmen 4.1.3).
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2023-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module zknde64 import cvw::*; #(parameter cvw_t P) (
  input  logic [63:0] A, B,
  input  logic [3:0]  round,
  input  logic [3:0]  ZKNSelect,
  output logic [63:0] ZKNDEResult
);

  logic        Decrypt, KeySched, FinalRound, InvMix;
  logic [63:0] ShiftRowsOut, InvShiftRowsOut, SboxIn, SboxOut;
  logic [63:0] MixIn, PreMixOut, MixColIn, MixOut, AESResult, ks1iResult, ks2Result;
  logic [31:0] SboxKIn, rcon;

  // ZKNSelect: [1:0] 00 aes64ds/dsm/im, 01 aes64es/esm, 10 aes64ks1i, 11 aes64ks2; [2] final round; [3] aes64im
  assign Decrypt    = P.ZKND_SUPPORTED & ~ZKNSelect[1] & ~ZKNSelect[0];
  assign KeySched   = ZKNSelect[1];
  assign FinalRound = ZKNSelect[2];
  assign InvMix     = P.ZKND_SUPPORTED & ZKNSelect[3];

  // ShiftRows and InvShiftRows are wiring; choose the bytes to substitute
  aesshiftrows64    srow({B, A}, ShiftRowsOut);
  aesinvshiftrows64 isrow({B, A}, InvShiftRowsOut);
  // aes64ks1i substitutes rs1[63:32], rotated except in round 10, in the low four S-boxes
  assign SboxKIn = (round == 4'b1010) ? A[63:32] : {A[39:32], A[63:40]};
  always_comb begin
    if (P.ZKNE_SUPPORTED & P.ZKND_SUPPORTED) SboxIn = Decrypt ? InvShiftRowsOut : ShiftRowsOut;
    else if (P.ZKND_SUPPORTED)               SboxIn = InvShiftRowsOut;
    else                                     SboxIn = ShiftRowsOut;
    if (KeySched) SboxIn[31:0] = SboxKIn;
  end

  // Eight S-boxes, inverse when decrypting
  genvar i;
  for (i = 0; i < 8; i++) begin : sbox
    aessboxfwdinv8 sb(.a(SboxIn[8*i+7:8*i]), .inv(Decrypt), .y(SboxOut[8*i+7:8*i]));
  end

  // MixColumns, or InvMixColumns = MixColumns(InvMixPre(x)); aes64im applies InvMixColumns to rs1
  assign MixIn = InvMix ? A : SboxOut;
  aesinvmixpre32 pre0(MixIn[31:0],  PreMixOut[31:0]);
  aesinvmixpre32 pre1(MixIn[63:32], PreMixOut[63:32]);
  assign MixColIn = Decrypt ? PreMixOut : MixIn;
  aesmixcolumns32 mw0(MixColIn[31:0],  MixOut[31:0]);
  aesmixcolumns32 mw1(MixColIn[63:32], MixOut[63:32]);
  assign AESResult = FinalRound ? SboxOut : MixOut;

  // Key schedule
  rconlut32 rc(round, rcon);
  assign ks1iResult = {2{SboxOut[31:0] ^ rcon}};
  aes64ks2 aes64ks2(.rs2(B), .rs1(A[63:32]), .result(ks2Result));

  mux4 #(64) zkndmux(AESResult, AESResult, ks1iResult, ks2Result, ZKNSelect[1:0], ZKNDEResult);
endmodule
