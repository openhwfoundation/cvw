///////////////////////////////////////////
// vfrecrsqrt7.sv
//
// Written: nfotenos@g.hmc.edu 2026-09-07
//
// Purpose: Vector floating-point reciprocal (vfrec7) and reciprocal square-root (vfrsqrt7)
//          estimates to 7 bits of precision.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
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

module vfrecrsqrt7 import cvw::*; #(parameter cvw_t P) (
  input  logic              IsSqrt,                                 // 1 = vfrsqrt7, 0 = vfrec7
  input  logic              Xs, XNaN, XSNaN, XZero, XInf, XSubnorm, // vs2 sign and class, from unpackinput
  input  logic [P.NE-1:0]   Xe,                                     // vs2 exponent, internal (double) bias
  input  logic [P.NF:0]     Xm,                                     // vs2 significand, left-justified
  input  logic [2:0]        Vsew,                                   // 001=16b, 010=32b, 011=64b
  input  logic [2:0]        Frm,                                    // rounding mode
  output logic [P.FLEN-1:0] VfrecRes,                               // result
  output logic [4:0]        VfrecFlg                                // fflags {NV, DZ, OF, UF, NX}
);

  localparam logic [2:0] VSEW_16 = 3'b001, VSEW_32 = 3'b010, VSEW_64 = 3'b011;
  localparam logic [2:0] RTZ = 3'b001, RDN = 3'b010, RUP = 3'b011;
  localparam integer     EW     = P.NE + 1;       // one extra bit holds the unshifted rsqrt exponent
  localparam integer     NBYTES = (P.NF + 7) / 8; // fraction bytes searched when normalizing a subnormal (7 for double)
  localparam logic [6:0] REC7_TBL [0:127] =
    '{127,125,123,121,119,117,116,114,112,110,109,107,105,104,102,100,99,97,96,94,93,91,90,88,87,85,84,
      83,81,80,79,77,76,75,74,72,71,70,69,68,66,65,64,63,62,61,60,59,58,57,56,55,54,53,52,51,50,49,48,
      47,46,45,44,43,42,41,40,40,39,38,37,36,35,35,34,33,32,31,31,30,29,28,28,27,26,25,25,24, 23,23,22,
      21,21,20,19,19,18,17,17,16,15,15,14,14,13,12,12,11,11,10,9,9,8,8,7,7,6,5,5,4,4,3,3,2,2,1,1,0};
  localparam logic [6:0] REC7SQRT_TBL [0:127] =
    '{52,51,50,48,47,46,44,43,42,41,40,39,38,36,35,34,33,32,31,30,30,29,28,27,26,25,24,23,23,22,21,20,
      19,19,18,17,16,16,15,14,14,13,12,12,11,10,10,9,9,8,7,7,6,6,5,4,4,3,3,2,2,1,1,0,127,125,123,121,
      119,118,116,114,113,111,109,108,106,105,103,102,100,99,97,96,95,93,92,91,90,88,87,86,85,84,83,82,
      80,79,78,77,76,75,74,73,72,71,70,70,69,68,67,66,65,64,63,63,62,61,60,59,59,58,57,56,56,55,54,53};

  logic [EW-1:0]    K, ExpSum;
  logic [P.NE-1:0]  NormExp, RecDenormXe, ResExp;
  logic [5:0]       ZeroCount;
  logic [8*NBYTES+7:0]  Pad;
  logic [15:0]      Win;
  logic [NBYTES-1:0]    ByteNZ, LeadByte;
  logic [7:0]       LeadBit;
  logic [2:0]       ByteNum, BitNum;
  logic [6:0]       SubIdx, Idx, LutOut;
  logic [8:0]       Frac9, ResFrac9;
  logic [P.NF-1:0]  ResFrac;
  logic             Denorm0, Denorm1, SubnormOverflow, SqrtNeg, SatMaxFinite, ResSgn;

  // Normalize a subnormal (Xm is left-justified for every SEW) in two one-hot steps: find the
  // leading nonzero byte and take a 16-bit window starting there, then find the leading 1 in the
  // window's top byte and take the 7 table-index bits below it. Z = 8*byte + bit needs no adder.
  assign Pad = {Xm[P.NF-1:0], (8*NBYTES+8-P.NF)'(0)};
  always_comb begin
    Win = '0; ByteNum = '0; BitNum = '0; SubIdx = '0;
    for (int k = 0; k < NBYTES; k++) ByteNZ[k] = |Pad[8*NBYTES+7-8*k -: 8];
    for (int k = 0; k < NBYTES; k++) begin
      LeadByte[k] = ByteNZ[k] & ~|(ByteNZ & ((NBYTES'(1) << k) - 1'b1));
      Win     |= {16{LeadByte[k]}} & Pad[8*NBYTES+7-8*k -: 16];
      ByteNum |= {3{LeadByte[k]}} & 3'(k);
    end
    for (int j = 0; j < 8; j++) begin
      LeadBit[j] = Win[15-j] & ~|(Win[15 -: 8] >> (8-j));
      SubIdx |= {7{LeadBit[j]}} & Win[14-j -: 7];
      BitNum |= {3{LeadBit[j]}} & 3'(j);
    end
  end
  assign ZeroCount = {ByteNum, BitNum};
  assign Idx       = XSubnorm ? SubIdx : Xm[P.NF-1 -: 7];

  // Table lookup. Rsqrt indexes on {native exponent LSB, top 6 fraction bits}; the native and
  // internal biases are both odd, so that LSB is Xe[0] for a normal and Z[0] for a subnormal.
  assign LutOut = IsSqrt ? REC7SQRT_TBL[{XSubnorm ? ZeroCount[0] : Xe[0], Idx[6:1]}] : REC7_TBL[Idx];

  // Output exponent constants for native bias B and internal bias D = P.D_BIAS (e = unbiased input exponent):
  //   normal input, Xe = e + D:        rec  B-1-e          = (B+D-1) - Xe
  //                                    rsqrt (3B-1-(e+B))/2 = ((2B+D-1) - Xe) / 2
  //   subnormal input, e = -B - Z:     rec  2B-1+Z,  rsqrt (3B-1+Z)/2
  // so the exponent is one adder: K + ~Xe (K = constant + 1, since ~Xe = -Xe-1) or K + Z.
  // The rsqrt divide by 2 is a shift of the sum.
  always_comb
    case (Vsew)
      VSEW_16: K = XSubnorm ? (IsSqrt ? EW'(3*P.H_BIAS - 1) : EW'(2*P.H_BIAS - 1)) :
                              (IsSqrt ? EW'(2*P.H_BIAS + P.D_BIAS) : EW'(P.H_BIAS + P.D_BIAS));
      VSEW_32: K = XSubnorm ? (IsSqrt ? EW'(3*P.S_BIAS - 1) : EW'(2*P.S_BIAS - 1)) :
                              (IsSqrt ? EW'(2*P.S_BIAS + P.D_BIAS) : EW'(P.S_BIAS + P.D_BIAS));
      default: K = XSubnorm ? (IsSqrt ? EW'(3*P.D_BIAS - 1) : EW'(2*P.D_BIAS - 1)) :
                              (IsSqrt ? EW'(2*P.D_BIAS + P.D_BIAS) : EW'(P.D_BIAS + P.D_BIAS));
    endcase
  assign ExpSum  = K + (XSubnorm ? EW'(ZeroCount) : {1'b1, ~Xe});
  assign NormExp = IsSqrt ? ExpSum[P.NE:1] : ExpSum[P.NE-1:0];

  // Only a reciprocal of a normal can be subnormal: output exponent 0 (Xe = B+D-1) or -1 (Xe = B+D),
  // detected directly on Xe, off the adder path. The result is {1, LutOut} shifted right by 1 or 2.
  assign RecDenormXe = (Vsew == VSEW_16) ? P.NE'(P.H_BIAS + P.D_BIAS - 1) :
                      ((Vsew == VSEW_32) ? P.NE'(P.S_BIAS + P.D_BIAS - 1) : P.NE'(2*P.D_BIAS - 1));
  assign Denorm0 = ~IsSqrt & ~XSubnorm & (Xe == RecDenormXe);
  assign Denorm1 = ~IsSqrt & ~XSubnorm & (Xe == RecDenormXe + 1'b1);
  assign Frac9   = Denorm0 ? {1'b1, LutOut, 1'b0} : (Denorm1 ? {2'b01, LutOut} : {LutOut, 2'b00});

  // Special cases. For the reciprocal, a subnormal with 2+ leading zeros overflows; it
  // saturates to +/-max finite instead of +/-inf when rounding points toward zero (RTZ,
  // RDN if positive, RUP if negative). The reciprocal square root never overflows, but
  // any negative input that is not zero or NaN (including -inf) is invalid.
  assign SubnormOverflow = ~IsSqrt & XSubnorm & ~Xm[P.NF-1] & ~Xm[P.NF-2];
  assign SqrtNeg         = IsSqrt & Xs & ~XZero & ~XNaN;
  assign SatMaxFinite    = SubnormOverflow & ((Frm == RTZ) | (~Xs & (Frm == RDN)) | (Xs & (Frm == RUP)));

  // Exponent all 1s: NaN, +/-inf, max finite (LSB cleared). 0: inf input or subnormal result.
  // All-ones exponents and left-justified fractions stay correct when truncated to each SEW's widths.
  always_comb
    if      (XNaN | SqrtNeg)                begin ResExp = '1; ResFrac9 = 9'b1_0000_0000; end // canonical NaN
    else if (SatMaxFinite)                  begin ResExp = ~P.NE'(1); ResFrac9 = '1;     end // max finite
    else if (XZero | SubnormOverflow)       begin ResExp = '1; ResFrac9 = '0;            end // inf
    else if (XInf)                          begin ResExp = '0; ResFrac9 = '0;            end // zero
    else                                    begin ResExp = (Denorm0 | Denorm1) ? '0 : NormExp; ResFrac9 = Frac9; end
  assign ResFrac = {ResFrac9, {(P.NF-9){SatMaxFinite}}};
  assign ResSgn  = Xs & ~XNaN & ~SqrtNeg;               // canonical NaN is positive

  always_comb
    case (Vsew)
      VSEW_16: VfrecRes = {{(P.FLEN-16){1'b0}}, ResSgn, ResExp[P.H_NE-1:0], ResFrac[P.NF-1 -: P.H_NF]};
      VSEW_32: VfrecRes = {{(P.FLEN-32){1'b0}}, ResSgn, ResExp[P.S_NE-1:0], ResFrac[P.NF-1 -: P.S_NF]};
      VSEW_64: VfrecRes = {{(P.FLEN-64){1'b0}}, ResSgn, ResExp[P.D_NE-1:0], ResFrac};
      default: VfrecRes = '0;
    endcase

  // Flags {NV, DZ, OF, UF, NX}: signaling NaN or negative rsqrt, divide by zero, and inexact overflow.
  assign VfrecFlg = (Vsew == VSEW_16 | Vsew == VSEW_32 | Vsew == VSEW_64) ?
                    {XSNaN | SqrtNeg, XZero, SubnormOverflow, 1'b0, SubnormOverflow} : '0;

endmodule
