///////////////////////////////////////////
// vfrec7.sv
//
// Written: nfotenos@g.hmc.edu 2026-09-07
//
// Purpose: Vector floating-point reciprocal estimate (vfrec7) to 7 bits of precision.
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

module vfrec7 import cvw::*; #(parameter cvw_t P) (
  input  logic              Xs, XNaN, XSNaN, XZero, XInf, XSubnorm, // vs2 sign and class, from unpackinput
  input  logic [P.NE-1:0]   Xe,                                     // vs2 exponent, internal (double) bias
  input  logic [P.NF:0]     Xm,                                     // vs2 significand, left-justified
  input  logic [2:0]        Vsew,                                   // 001=16b, 010=32b, 011=64b
  input  logic [2:0]        Frm,                                    // rounding mode
  output logic [P.FLEN-1:0] Vfrec7Res,                              // result
  output logic [4:0]        Vfrec7Flg                               // fflags {NV, DZ, OF, UF, NX}
);

  // Requires D and ZFH without Q, so P.NE/NF/FLEN are the double widths shared by every SEW.
  localparam logic [2:0] VSEW_16 = 3'b001, VSEW_32 = 3'b010, VSEW_64 = 3'b011;
  localparam logic [2:0] RTZ = 3'b001, RDN = 3'b010, RUP = 3'b011;
  localparam integer     LOGNF = $clog2(P.NF+1);  //  lzc count spans 0..NF (NF+1 values), matches lzc ZeroCnt width
  localparam integer     EW    = P.NE + 2;  //  signed internal exponent: NormOutExp spans about -1..2*bias+NF
  localparam logic [6:0] REC7_TBL [0:127] = '{127,125,123,121,119,117,116,114,112,110,109,107,105,104,102,100,99,97,96,94,93,91,90,88,87,85,84,83,81,80,79,77,76,75,74,72,71,70,69,68,66,65,64,63,62,61,60,59,58,57,56,55,54,53,52,51,50,49,48,47,46,45,44,43,42,41,40,40,39,38,37,36,35,35,34,33,32,31,31,30,29,28,28,27,26,25,25,24,23,23,22,21,21,20,19,19,18,17,17,16,15,15,14,14,13,12,12,11,11,10,9,9,8,8,7,7,6,5,5,4,4,3,3,2,2,1,1,0};

  logic signed [EW-1:0] NativeBias, NormInExp, NormOutExp;
  logic [EW-1:0]        SpecialExp, ResExp;
  logic [LOGNF-1:0]     ZeroCount;
  logic [P.NF-1:0]      NormFrac, OutFrac, SpecialFrac, ResFrac;
  logic [P.NF:0]        SubFrac;
  logic [6:0]           LutOut;
  logic                 IsDenormResult, SubnormOverflow, IsSpecial, SatMaxFinite, ValidSew;

  // Native exponent bias for this SEW. Everything else is built as SEW-independent
  // {sign, exp, frac} fields and only packed into the native format at the end.
  assign bias = (Vsew == VSEW_64) ? P.D_BIAS : ((Vsew == VSEW_32) ? P.S_BIAS : P.H_BIAS);


  // Normalize. A subnormal has exponent -ZeroCount and shifts out its new leading 1;
  // a normal is rebiased from the internal (double) bias to this SEW's native bias.
  lzc #(.WIDTH(P.NF)) lzcfrac (.num(Xm[P.NF-1:0]), .ZeroCnt(ZeroCount));
  always_comb
    if (XSubnorm) begin
      NormInExp = -$signed({{(EW-LOGNF){1'b0}}, ZeroCount});
      NormFrac  = Xm[P.NF-1:0] << (ZeroCount + 1'b1);
    end else begin
      NormInExp = $signed({{(EW-P.NE){1'b0}}, Xe}) + NativeBias - EW'(P.D_BIAS);
      NormFrac  = Xm[P.NF-1:0];
    end

  // Reciprocal: LUT on the top 7 fraction bits; exponent = 2*bias - 1 - input exponent.
  // An output exponent of 0 or -1 means a subnormal result, shifted right by 1 or 2.
  assign LutOut         = REC7_TBL[NormFrac[P.NF-1 -: 7]];
  assign NormOutExp     = 2*NativeBias - 1 - NormInExp;
  assign IsDenormResult = (NormOutExp == 0) | (NormOutExp == -1);
  assign SubFrac        = {1'b1, LutOut, {(P.NF-7){1'b0}}} >> ((NormOutExp == 0) ? 1 : 2); // MSB always 0
  assign OutFrac        = IsDenormResult ? SubFrac[P.NF-1:0] : {LutOut, {(P.NF-7){1'b0}}};

  // Special cases. A subnormal with 2+ leading zeros overflows; it saturates to +/-max
  // finite instead of +/-inf when rounding points toward zero (RTZ, RDN if positive,
  // RUP if negative).
  assign SubnormOverflow = XSubnorm & (ZeroCount >= 2);
  assign IsSpecial       = XInf | XNaN | XZero | SubnormOverflow;
  assign SatMaxFinite    = SubnormOverflow & ((Frm == RTZ) | (~Xs & (Frm == RDN)) | (Xs & (Frm == RUP)));

  // The input classes are mutually exclusive. All-ones exponents and left-justified
  // fractions stay correct when truncated to each SEW's widths.
  always_comb begin
    SpecialExp  = '0;                                   // inf -> +/-0
    SpecialFrac = '0;
    if (XNaN) begin                                     // NaN -> canonical NaN
      SpecialExp  = '1;
      SpecialFrac = {1'b1, {(P.NF-1){1'b0}}};
    end else if (SatMaxFinite) begin                    // overflow -> +/-max finite
      SpecialExp  = ~EW'(1);
      SpecialFrac = '1;
    end else if (XZero | SubnormOverflow)               // zero or overflow -> +/-inf
      SpecialExp  = '1;
  end

  // Select special vs. normal fields, then pack into the native SEW format.
  assign ResExp  = IsSpecial ? SpecialExp  : (IsDenormResult ? '0 : NormOutExp) ;
  assign ResFrac = IsSpecial ? SpecialFrac : OutFrac;

  always_comb
    case (Vsew)
      VSEW_16: Vfrec7Res = {{(P.FLEN-16){1'b0}}, Xs & ~XNaN, ResExp[P.H_NE-1:0], ResFrac[P.NF-1 -: P.H_NF]};
      VSEW_32: Vfrec7Res = {{(P.FLEN-32){1'b0}}, Xs & ~XNaN, ResExp[P.S_NE-1:0], ResFrac[P.NF-1 -: P.S_NF]};
      VSEW_64: Vfrec7Res = {{(P.FLEN-64){1'b0}}, Xs & ~XNaN, ResExp[P.D_NE-1:0], ResFrac};
      default: Vfrec7Res = '0;
    endcase

  // Flags {NV, DZ, OF, UF, NX}: signaling NaN, divide by zero, and inexact overflow.
  assign ValidSew  = (Vsew == VSEW_16) | (Vsew == VSEW_32) | (Vsew == VSEW_64);
  assign Vfrec7Flg = ValidSew ? {XSNaN, XZero, SubnormOverflow, 1'b0, SubnormOverflow} : '0;

endmodule
