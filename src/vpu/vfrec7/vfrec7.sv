///////////////////////////////////////////
// vfrec7.sv
//
// Written: nfotneos@g.hmc.edu 2026-09-07
// Modified: nfotneos@g.hmc.edu 2026-09-18 -- split into vfrec7fmt/norm/lut/exp/special/pack
//
// Purpose: Compute floating point Reciprocal with 7 bit precision.
//
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
  // vs2, already run through the FPU's unpackinput unit; vfrec7 is purely
  // downstream and does not instantiate unpackinput itself
  input  logic            Xs,          // sign
  input  logic [P.NE-1:0] Xe,          // exponent
  input  logic [P.NF:0]   Xm,          // significand
  input  logic            XNaN,        // is NaN
  input  logic            XSNaN,       // is signaling NaN
  input  logic            XZero,       // is zero
  input  logic            XInf,        // is infinity
  input  logic            XSubnorm,    // is subnormal

  input  logic [2:0]      Vsew,        // vector SEW: 001=16b, 010=32b, 011=64b
  input  logic [2:0]      Frm,         // rounding mode

  output logic [P.FLEN-1:0] Vfrec7Res,   // result
  output logic [4:0]        Vfrec7Flg    // fflags
);

  // Requires D_SUPPORTED and ZFH_SUPPORTED with no Q_SUPPORTED, so P.FLEN/NE/NF
  // are exactly the double-precision widths shared by every SEW (H, S, D) here.

  ///////////////////////////////////////////////////////////////////////////////
  // Per-SEW format constants: native bias and special-case result constants
  ///////////////////////////////////////////////////////////////////////////////

  logic                ValidSew;
  logic signed [12:0]  NativeBias;
  logic [P.FLEN-1:0]   SignMask, PosInf, MaxFinite, CanonicalNan;

  vfrec7fmt #(P) fmt (.Vsew, .ValidSew, .NativeBias, .SignMask, .PosInf, .MaxFinite, .CanonicalNan);

  ///////////////////////////////////////////////////////////////////////////////
  // Normalize the input and generate the LUT index
  ///////////////////////////////////////////////////////////////////////////////

  logic signed [12:0]        NormInExp;
  logic [6:0]                LutIdx;
  logic [$clog2(P.NF+1)-1:0] ZeroCount;

  vfrec7norm #(P) norm (.Xe, .Xm, .XSubnorm, .NativeBias, .NormInExp, .LutIdx, .ZeroCount);

  ///////////////////////////////////////////////////////////////////////////////
  // LUT lookup
  ///////////////////////////////////////////////////////////////////////////////

  logic [6:0] LutOut;

  vfrec7lut lut (.LutIdx, .LutOut);

  ///////////////////////////////////////////////////////////////////////////////
  // Reciprocal exponent
  ///////////////////////////////////////////////////////////////////////////////

  logic signed [12:0] NormOutExp;
  logic                IsDenormResult;
  logic [1:0]          DenormShift;

  vfrec7exp expu (.NormInExp, .NativeBias, .NormOutExp, .IsDenormResult, .DenormShift);

  ///////////////////////////////////////////////////////////////////////////////
  // Special cases: infinity, NaN, +/- zero, subnormal reciprocal overflow
  ///////////////////////////////////////////////////////////////////////////////

  logic              IsSpecial;
  logic [P.FLEN-1:0] SpecialRes;
  logic [4:0]        SpecialFlg;

  vfrec7special #(P) special (.Xs, .XNaN, .XSNaN, .XZero, .XInf, .XSubnorm, .ZeroCount, .Frm,
                               .SignMask, .PosInf, .MaxFinite, .CanonicalNan,
                               .IsSpecial, .Res(SpecialRes), .Flg(SpecialFlg));

  ///////////////////////////////////////////////////////////////////////////////
  // Assemble the finite, nonzero, non-overflow result
  ///////////////////////////////////////////////////////////////////////////////

  logic [P.FLEN-1:0] NormalRes;

  vfrec7pack #(P) pack (.Vsew, .Xs, .LutOut, .NormOutExp, .IsDenormResult, .DenormShift, .Res(NormalRes));

  ///////////////////////////////////////////////////////////////////////////////
  // Select between the special-case and normal-path results
  ///////////////////////////////////////////////////////////////////////////////

  always_comb
    if (~ValidSew) begin
      Vfrec7Res = '0;
      Vfrec7Flg = 5'b0;
    end else if (IsSpecial) begin
      Vfrec7Res = SpecialRes;
      Vfrec7Flg = SpecialFlg;
    end else begin
      Vfrec7Res = NormalRes;
      Vfrec7Flg = 5'b0;
    end

endmodule
