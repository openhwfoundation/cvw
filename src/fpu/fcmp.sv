///////////////////////////////////////////
// fcmp.sv
//
// Written: me@KatherineParry.com
// Modified: 7/5/2022
//
// Purpose: Floating-point comparison unit
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
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

// OpCtrl values
//    110   min
//    101   max
//    010   equal
//    001   less than
//    011   less than or equal

module fcmp import cvw::*;  #(parameter cvw_t P) (
  input  logic [P.FMTBITS-1:0]   Fmt,           // format of fp number
  input  logic [2:0]             OpCtrl,        // see above table
  input  logic                   Zfa,           // Zfa variants: fminm, fmaxm, fleq, fltq
  input  logic                   Xs, Ys,        // input signs
  input  logic [P.NE-1:0]        Xe, Ye,        // input exponents
  input  logic [P.NF:0]          Xm, Ym,        // input mantissa
  input  logic                   XZero, YZero,  // is zero
  input  logic                   XNaN, YNaN,    // is NaN
  input  logic                   XSNaN, YSNaN,  // is signaling NaN
  input  logic [P.FLEN-1:0]      X, Y,          // original inputs (before unpacker)
  output logic                   CmpNV,         // invalid flag
  output logic [P.FLEN-1:0]      CmpFpRes,      // compare floating-point result
  output logic [P.XLEN-1:0]      CmpIntRes      // compare integer result
);

  logic LTabs, LT, EQ;          // is X < or > or = Y
  logic [P.FLEN-1:0] NaNRes;    // NaN result
  logic BothZero;               // are both inputs zero
  logic EitherNaN, EitherSNaN;  // are either input a (signaling) NaN

  assign LTabs= {1'b0, Xe, Xm} < {1'b0, Ye, Ym}; // unsigned comparison, treating FP as integers
  assign LT = (Xs & ~Ys) | (Xs & Ys & ~LTabs & ~EQ) | (~Xs & ~Ys & LTabs); // signed comparison
  assign EQ = (X == Y);

  assign BothZero = XZero&YZero;
  assign EitherNaN = XNaN|YNaN;
  assign EitherSNaN = XSNaN|YSNaN;

  // flags
  //    Min/Max - if an input is a signaling NaN set invalid flag
  //    LT/LE - signaling - sets invalid if NaN input
  //    EQ - quiet - sets invalid if signaling NaN input
  always_comb begin
    casez (OpCtrl[2:0])
        3'b110: CmpNV = EitherSNaN; //min
        3'b101: CmpNV = EitherSNaN; //max
        3'b010: CmpNV = EitherSNaN; //equal
        3'b0?1: if (P.ZFA_SUPPORTED)
                  CmpNV = Zfa ? EitherSNaN : EitherNaN; // fltq,fleq / flt,fle perform CompareQuietLess / CompareSignalingLess differing on when to set invalid
                else CmpNV = EitherNaN;                 // flt, fle
        3'b100: CmpNV = 1'b0;
        default: CmpNV = 1'b0; // Don't set any flags for non-compares
    endcase
  end

  // fmin/fmax of two NaNs returns a quiet NaN of the appropriate size
  // for IEEE, return the payload of X
  // for RISC-V, return the canonical NaN

  // select the NaN result
  if (P.FPSIZES == 1)
    if(P.IEEE754) assign NaNRes = {Xs, {P.NE{1'b1}}, 1'b1, Xm[P.NF-2:0]};
    else          assign NaNRes = {1'b0, {P.NE{1'b1}}, 1'b1, {P.NF-1{1'b0}}};

  else if (P.FPSIZES == 2)
    if(P.IEEE754) assign NaNRes = Fmt ? {Xs, {P.NE{1'b1}}, 1'b1, Xm[P.NF-2:0]} : {{P.FLEN-P.LEN1{1'b1}}, Xs, {P.NE1{1'b1}}, 1'b1, Xm[P.NF-2:P.NF-P.NF1]};
    else          assign NaNRes = Fmt ? {1'b0, {P.NE{1'b1}}, 1'b1, {P.NF-1{1'b0}}} : {{P.FLEN-P.LEN1{1'b1}}, 1'b0, {P.NE1{1'b1}}, 1'b1, (P.NF1-1)'(0)};

  else if (P.FPSIZES == 3)
    always_comb
          case (Fmt)
              P.FMT:
                if(P.IEEE754) NaNRes = {Xs, {P.NE{1'b1}}, 1'b1, Xm[P.NF-2:0]};
                else         NaNRes = {1'b0, {P.NE{1'b1}}, 1'b1, {P.NF-1{1'b0}}};
              P.FMT1:
                if(P.IEEE754) NaNRes = {{P.FLEN-P.LEN1{1'b1}}, Xs, {P.NE1{1'b1}}, 1'b1, Xm[P.NF-2:P.NF-P.NF1]};
                else         NaNRes = {{P.FLEN-P.LEN1{1'b1}}, 1'b0, {P.NE1{1'b1}}, 1'b1, (P.NF1-1)'(0)};
              P.FMT2:
                if(P.IEEE754) NaNRes = {{P.FLEN-P.LEN2{1'b1}}, Xs, {P.NE2{1'b1}}, 1'b1, Xm[P.NF-2:P.NF-P.NF2]};
                else         NaNRes = {{P.FLEN-P.LEN2{1'b1}}, 1'b0, {P.NE2{1'b1}}, 1'b1, (P.NF2-1)'(0)};
              default:        NaNRes = {P.FLEN{1'bx}};
          endcase

  else if (P.FPSIZES == 4)
    always_comb
          case (Fmt)
              2'h3:
                if(P.IEEE754) NaNRes = {Xs, {P.NE{1'b1}}, 1'b1, Xm[P.NF-2:0]};
                else         NaNRes = {1'b0, {P.NE{1'b1}}, 1'b1, {P.NF-1{1'b0}}};
              2'h1:
                if(P.IEEE754) NaNRes = {{P.FLEN-P.D_LEN{1'b1}}, Xs, {P.D_NE{1'b1}}, 1'b1, Xm[P.NF-2:P.NF-P.D_NF]};
                else         NaNRes = {{P.FLEN-P.D_LEN{1'b1}}, 1'b0, {P.D_NE{1'b1}}, 1'b1, (P.D_NF-1)'(0)};
              2'h0:
                if(P.IEEE754) NaNRes = {{P.FLEN-P.S_LEN{1'b1}}, Xs, {P.S_NE{1'b1}}, 1'b1, Xm[P.NF-2:P.NF-P.S_NF]};
                else         NaNRes = {{P.FLEN-P.S_LEN{1'b1}}, 1'b0, {P.S_NE{1'b1}}, 1'b1, (P.S_NF-1)'(0)};
              2'h2:
                if(P.IEEE754) NaNRes = {{P.FLEN-P.H_LEN{1'b1}}, Xs, {P.H_NE{1'b1}}, 1'b1, Xm[P.NF-2:P.NF-P.H_NF]};
                else         NaNRes = {{P.FLEN-P.H_LEN{1'b1}}, 1'b0, {P.H_NE{1'b1}}, 1'b1, (P.H_NF-1)'(0)};
          endcase

  // Min/Max
  //    - outputs the min/max of X and Y
  //    - -0 < 0
  //    - if both are NaN return quiet X
  //    - if one is a NaN output the non-NaN
  always_comb
    if(OpCtrl[0]) // MAX
        if (Zfa & P.ZFA_SUPPORTED) // fmaxm perform IEEE754 maxNum that produce NaN if either input is NaN
          if (XNaN | YNaN) CmpFpRes = NaNRes; // either input is NaN
          else
            if (LT) CmpFpRes = Y; // X < Y
            else    CmpFpRes = X; // X > Y
        else // fmax performs IEEE754 maxNumber that produces NaN if both inputs are NaN
          if(XNaN)
            if(YNaN)    CmpFpRes = NaNRes;   // X = NaN Y = NaN
            else        CmpFpRes = Y;        // X = NaN Y != NaN
          else
            if(YNaN)    CmpFpRes = X;        // X != NaN Y = NaN
            else // X,Y != NaN
                if(LT)  CmpFpRes = Y;        // X < Y
                else    CmpFpRes = X;        // X > Y
    else  // MIN
        if (Zfa & P.ZFA_SUPPORTED) // fminm perform IEEE754 minNum that produce NaN if either input is NaN
          if (XNaN | YNaN) CmpFpRes = NaNRes; // either input is NaN
          else
            if (LT) CmpFpRes = X; // X < Y
            else    CmpFpRes = Y; // X > Y
        else // fmin performs IEEE754 minNumber that produces NaN if both inputs are NaN
          if(XNaN)
            if(YNaN)    CmpFpRes = NaNRes;   // X = NaN Y = NaN
            else        CmpFpRes = Y;        // X = NaN Y != NaN
          else
            if(YNaN)    CmpFpRes = X;        // X != NaN Y = NaN
            else // X,Y != NaN
                if(LT)  CmpFpRes = X;        // X < Y
                else    CmpFpRes = Y;        // X > Y

  // LT/LE/EQ
  //    - -0 = 0
  //    - inf = inf and -inf = -inf
  //    - return 0 if comparison with NaN (unordered)
  assign CmpIntRes = {(P.XLEN-1)'(0), (((EQ|BothZero)&OpCtrl[1])|(LT&OpCtrl[0]&~BothZero))&~EitherNaN};
endmodule
