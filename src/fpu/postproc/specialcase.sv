///////////////////////////////////////////
// specialcase.sv
//
// Written: me@KatherineParry.com
// Modified: 7/5/2022
//
// Purpose: special case selection
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

module specialcase import cvw::*;  #(parameter cvw_t P) (
  input  logic                 Xs,                // X sign
  input  logic [P.NF:0]        Xm, Ym, Zm,        // input significand's
  input  logic                 XNaN, YNaN, ZNaN,  // are the inputs NaN
  input  logic [2:0]           Frm,               // rounding mode
  input  logic [P.FMTBITS-1:0] OutFmt,            // output format
  input  logic                 InfIn,             // are any inputs infinity
  input  logic                 NaNIn,             // are any input NaNs
  input  logic                 XInf, YInf,        // are X or Y inifnity
  input  logic                 XZero,             // is X zero
  input  logic                 Plus1,             // do you add one for rounding
  input  logic                 Rs,                // the result's sign
  input  logic                 Invalid, Overflow, // flags to choose the result
  input  logic [P.NE-1:0]      Re,                // Result exponent
  input  logic [P.NE+1:0]      FullRe,            // Result full exponent
  input  logic [P.NF-1:0]      Rf,                // Result fraction
  // fma
  input  logic                 FmaOp,             // is it a fma operation
  // divsqrt
  input  logic                 DivOp,             // is it a divsqrt operation
  input  logic                 DivByZero,         // divide by zero flag
  // cvt
  input  logic                 CvtOp,             // is it a conversion operation
  input  logic                 IntZero,           // is the integer input zero
  input  logic                 IntToFp,           // is cvt int -> fp operation
  input  logic                 Int64,             // is the integer 64 bits
  input  logic                 Signed,            // is the integer signed
  input  logic                 Zfa,               // Zfa conversion operation: fcvtmod.w.d
  input  logic [P.NE:0]        CvtCe,             // the calculated exponent for cvt
  input  logic                 IntInvalid,        // integer invalid flag to choose the result
  input  logic                 CvtResUf,          // does the convert result underflow
  input  logic [P.XLEN+1:0]    CvtNegRes,         // the possibly negated of the integer result
  // outputs
  output logic [P.FLEN-1:0]    PostProcRes,       // final result
  output logic [P.XLEN-1:0]    FCvtIntRes         // final integer result
);

  logic [P.FLEN-1:0]   XNaNRes;    // X is NaN result
  logic [P.FLEN-1:0]   YNaNRes;    // Y is NaN result
  logic [P.FLEN-1:0]   ZNaNRes;    // Z is NaN result
  logic [P.FLEN-1:0]   InvalidRes; // Invalid result result
  logic [P.FLEN-1:0]   UfRes;      // underflowed result result
  logic [P.FLEN-1:0]   OfRes;      // overflowed result result
  logic [P.FLEN-1:0]   NormRes;    // normal result
  logic [P.XLEN-1:0]   OfIntRes;   // the overflow result for integer output
  logic [P.XLEN-1:0]   OfIntRes2;  // the overflow result for integer output after accounting for fcvtmod.w.d
  logic [P.XLEN-1:0]   Int64Res;   // Result for conversion to 64-bit int after accounting for fcvtmod.w.d
  logic                OfResMax;   // does the of result output maximum norm fp number
  logic                KillRes;    // kill the result for underflow
  logic                SelOfRes;   // should the overflow result be selected (excluding convert)
  logic                SelCvtOfRes; // select overflow result for convert instruction

  // does the overflow result output the maximum normalized floating point number
  //                output infinity if the input is infinity
  assign OfResMax = (~InfIn|(IntToFp&CvtOp))&~DivByZero&((Frm[1:0]==2'b01) | (Frm[1:0]==2'b10&~Rs) | (Frm[1:0]==2'b11&Rs));

  // select correct outputs for special cases
  if (P.FPSIZES == 1) begin
      //NaN res selection depending on standard
      if(P.IEEE754) begin
          assign XNaNRes    = {1'b0, {P.NE{1'b1}}, 1'b1, Xm[P.NF-2:0]};
          assign YNaNRes    = {1'b0, {P.NE{1'b1}}, 1'b1, Ym[P.NF-2:0]};
          assign ZNaNRes    = {1'b0, {P.NE{1'b1}}, 1'b1, Zm[P.NF-2:0]};
          assign InvalidRes = {1'b0, {P.NE{1'b1}}, 1'b1, {P.NF-1{1'b0}}};
      end else begin
          assign InvalidRes = {1'b0, {P.NE{1'b1}}, 1'b1, {P.NF-1{1'b0}}};
      end

      assign OfRes   =  OfResMax ? {Rs, {P.NE-1{1'b1}}, 1'b0, {P.NF{1'b1}}} : {Rs, {P.NE{1'b1}}, {P.NF{1'b0}}};
      assign UfRes   = {Rs, {P.FLEN-2{1'b0}}, Plus1&Frm[1]&~(DivOp&YInf)};
      assign NormRes = {Rs, Re, Rf};

  end else if (P.FPSIZES == 2) begin
      if(P.IEEE754) begin
          assign XNaNRes    = OutFmt ? {1'b0, {P.NE{1'b1}}, 1'b1, Xm[P.NF-2:0]} : {{P.FLEN-P.LEN1{1'b1}}, 1'b0, {P.NE1{1'b1}}, 1'b1, Xm[P.NF-2:P.NF-P.NF1]};
          assign YNaNRes    = OutFmt ? {1'b0, {P.NE{1'b1}}, 1'b1, Ym[P.NF-2:0]} : {{P.FLEN-P.LEN1{1'b1}}, 1'b0, {P.NE1{1'b1}}, 1'b1, Ym[P.NF-2:P.NF-P.NF1]};
          assign ZNaNRes    = OutFmt ? {1'b0, {P.NE{1'b1}}, 1'b1, Zm[P.NF-2:0]} : {{P.FLEN-P.LEN1{1'b1}}, 1'b0, {P.NE1{1'b1}}, 1'b1, Zm[P.NF-2:P.NF-P.NF1]};
          assign InvalidRes = OutFmt ? {1'b0, {P.NE{1'b1}}, 1'b1, {P.NF-1{1'b0}}} : {{P.FLEN-P.LEN1{1'b1}}, 1'b0, {P.NE1{1'b1}}, 1'b1, (P.NF1-1)'(0)};
      end else begin
          assign InvalidRes = OutFmt ? {1'b0, {P.NE{1'b1}}, 1'b1, {P.NF-1{1'b0}}} : {{P.FLEN-P.LEN1{1'b1}}, 1'b0, {P.NE1{1'b1}}, 1'b1, (P.NF1-1)'(0)};
      end

      always_comb
          if(OutFmt)
              if(OfResMax)    OfRes = {Rs, {P.NE-1{1'b1}}, 1'b0, {P.NF{1'b1}}};
              else            OfRes = {Rs, {P.NE{1'b1}}, {P.NF{1'b0}}};
          else
              if(OfResMax)    OfRes = {{P.FLEN-P.LEN1{1'b1}}, Rs, {P.NE1-1{1'b1}}, 1'b0, {P.NF1{1'b1}}};
              else            OfRes = {{P.FLEN-P.LEN1{1'b1}}, Rs, {P.NE1{1'b1}}, (P.NF1)'(0)};
      assign UfRes = OutFmt ? {Rs, (P.FLEN-2)'(0), Plus1&Frm[1]&~(DivOp&YInf)} : {{P.FLEN-P.LEN1{1'b1}}, Rs, (P.LEN1-2)'(0), Plus1&Frm[1]&~(DivOp&YInf)};
      assign NormRes = OutFmt ? {Rs, Re, Rf} : {{P.FLEN-P.LEN1{1'b1}}, Rs, Re[P.NE1-1:0], Rf[P.NF-1:P.NF-P.NF1]};

  end else if (P.FPSIZES == 3) begin
      always_comb
          case (OutFmt)
              P.FMT: begin
                  if(P.IEEE754) begin
                      XNaNRes    = {1'b0, {P.NE{1'b1}}, 1'b1, Xm[P.NF-2:0]};
                      YNaNRes    = {1'b0, {P.NE{1'b1}}, 1'b1, Ym[P.NF-2:0]};
                      ZNaNRes    = {1'b0, {P.NE{1'b1}}, 1'b1, Zm[P.NF-2:0]};
                      InvalidRes = {1'b0, {P.NE{1'b1}}, 1'b1, {P.NF-1{1'b0}}};
                  end else begin
                      InvalidRes = {1'b0, {P.NE{1'b1}}, 1'b1, {P.NF-1{1'b0}}};
                  end

                  OfRes   = OfResMax ? {Rs, {P.NE-1{1'b1}}, 1'b0, {P.NF{1'b1}}} : {Rs, {P.NE{1'b1}}, {P.NF{1'b0}}};
                  UfRes   = {Rs, (P.FLEN-2)'(0), Plus1&Frm[1]&~(DivOp&YInf)};
                  NormRes = {Rs, Re, Rf};
              end
              P.FMT1: begin
                  if(P.IEEE754) begin
                      XNaNRes    = {{P.FLEN-P.LEN1{1'b1}}, 1'b0, {P.NE1{1'b1}}, 1'b1, Xm[P.NF-2:P.NF-P.NF1]};
                      YNaNRes    = {{P.FLEN-P.LEN1{1'b1}}, 1'b0, {P.NE1{1'b1}}, 1'b1, Ym[P.NF-2:P.NF-P.NF1]};
                      ZNaNRes    = {{P.FLEN-P.LEN1{1'b1}}, 1'b0, {P.NE1{1'b1}}, 1'b1, Zm[P.NF-2:P.NF-P.NF1]};
                      InvalidRes = {{P.FLEN-P.LEN1{1'b1}}, 1'b0, {P.NE1{1'b1}}, 1'b1, (P.NF1-1)'(0)};
                  end else begin
                      InvalidRes = {{P.FLEN-P.LEN1{1'b1}}, 1'b0, {P.NE1{1'b1}}, 1'b1, (P.NF1-1)'(0)};
                  end
                  OfRes          = OfResMax ? {{P.FLEN-P.LEN1{1'b1}}, Rs, {P.NE1-1{1'b1}}, 1'b0, {P.NF1{1'b1}}} : {{P.FLEN-P.LEN1{1'b1}}, Rs, {P.NE1{1'b1}}, (P.NF1)'(0)};
                  UfRes          = {{P.FLEN-P.LEN1{1'b1}}, Rs, (P.LEN1-2)'(0), Plus1&Frm[1]&~(DivOp&YInf)};
                  NormRes        = {{P.FLEN-P.LEN1{1'b1}}, Rs, Re[P.NE1-1:0], Rf[P.NF-1:P.NF-P.NF1]};
              end
              P.FMT2: begin
                  if(P.IEEE754) begin
                      XNaNRes    = {{P.FLEN-P.LEN2{1'b1}}, 1'b0, {P.NE2{1'b1}}, 1'b1, Xm[P.NF-2:P.NF-P.NF2]};
                      YNaNRes    = {{P.FLEN-P.LEN2{1'b1}}, 1'b0, {P.NE2{1'b1}}, 1'b1, Ym[P.NF-2:P.NF-P.NF2]};
                      ZNaNRes    = {{P.FLEN-P.LEN2{1'b1}}, 1'b0, {P.NE2{1'b1}}, 1'b1, Zm[P.NF-2:P.NF-P.NF2]};
                      InvalidRes = {{P.FLEN-P.LEN2{1'b1}}, 1'b0, {P.NE2{1'b1}}, 1'b1, (P.NF2-1)'(0)};
                  end else begin
                      InvalidRes = {{P.FLEN-P.LEN2{1'b1}}, 1'b0, {P.NE2{1'b1}}, 1'b1, (P.NF2-1)'(0)};
                  end

                  OfRes   = OfResMax ? {{P.FLEN-P.LEN2{1'b1}}, Rs, {P.NE2-1{1'b1}}, 1'b0, {P.NF2{1'b1}}} : {{P.FLEN-P.LEN2{1'b1}}, Rs, {P.NE2{1'b1}}, (P.NF2)'(0)};
                  UfRes   = {{P.FLEN-P.LEN2{1'b1}}, Rs, (P.LEN2-2)'(0), Plus1&Frm[1]&~(DivOp&YInf)};
                  NormRes = {{P.FLEN-P.LEN2{1'b1}}, Rs, Re[P.NE2-1:0], Rf[P.NF-1:P.NF-P.NF2]};
              end
              default: begin
                  if(P.IEEE754) begin
                      XNaNRes    = (P.FLEN)'(0);
                      YNaNRes    = (P.FLEN)'(0);
                      ZNaNRes    = (P.FLEN)'(0);
                      InvalidRes = (P.FLEN)'(0);
                  end else begin
                      InvalidRes = (P.FLEN)'(0);
                  end
                  OfRes          = (P.FLEN)'(0);
                  UfRes          = (P.FLEN)'(0);
                  NormRes        = (P.FLEN)'(0);
              end
          endcase

  end else if (P.FPSIZES == 4) begin
      always_comb
          case (OutFmt)
              2'h3: begin
                  if(P.IEEE754) begin
                      XNaNRes    = {1'b0, {P.NE{1'b1}}, 1'b1, Xm[P.NF-2:0]};
                      YNaNRes    = {1'b0, {P.NE{1'b1}}, 1'b1, Ym[P.NF-2:0]};
                      ZNaNRes    = {1'b0, {P.NE{1'b1}}, 1'b1, Zm[P.NF-2:0]};
                      InvalidRes = {1'b0, {P.NE{1'b1}}, 1'b1, {P.NF-1{1'b0}}};
                  end else begin
                      InvalidRes = {1'b0, {P.NE{1'b1}}, 1'b1, {P.NF-1{1'b0}}};
                  end

                  OfRes   = OfResMax ? {Rs, {P.NE-1{1'b1}}, 1'b0, {P.NF{1'b1}}} : {Rs, {P.NE{1'b1}}, {P.NF{1'b0}}};
                  UfRes   = {Rs, (P.FLEN-2)'(0), Plus1&Frm[1]&~(DivOp&YInf)};
                  NormRes = {Rs, Re, Rf};
              end
              2'h1: begin
                  if(P.IEEE754) begin
                      XNaNRes    = {{P.FLEN-P.D_LEN{1'b1}}, 1'b0, {P.D_NE{1'b1}}, 1'b1, Xm[P.NF-2:P.NF-P.D_NF]};
                      YNaNRes    = {{P.FLEN-P.D_LEN{1'b1}}, 1'b0, {P.D_NE{1'b1}}, 1'b1, Ym[P.NF-2:P.NF-P.D_NF]};
                      ZNaNRes    = {{P.FLEN-P.D_LEN{1'b1}}, 1'b0, {P.D_NE{1'b1}}, 1'b1, Zm[P.NF-2:P.NF-P.D_NF]};
                      InvalidRes = {{P.FLEN-P.D_LEN{1'b1}}, 1'b0, {P.D_NE{1'b1}}, 1'b1, (P.D_NF-1)'(0)};
                  end else begin
                      InvalidRes = {{P.FLEN-P.D_LEN{1'b1}}, 1'b0, {P.D_NE{1'b1}}, 1'b1, (P.D_NF-1)'(0)};
                  end
                  OfRes   = OfResMax ? {{P.FLEN-P.D_LEN{1'b1}}, Rs, {P.D_NE-1{1'b1}}, 1'b0, {P.D_NF{1'b1}}} : {{P.FLEN-P.D_LEN{1'b1}}, Rs, {P.D_NE{1'b1}}, (P.D_NF)'(0)};
                  UfRes   = {{P.FLEN-P.D_LEN{1'b1}}, Rs, (P.D_LEN-2)'(0), Plus1&Frm[1]&~(DivOp&YInf)};
                  NormRes = {{P.FLEN-P.D_LEN{1'b1}}, Rs, Re[P.D_NE-1:0], Rf[P.NF-1:P.NF-P.D_NF]};
              end
              2'h0: begin
                  if(P.IEEE754) begin
                      XNaNRes    = {{P.FLEN-P.S_LEN{1'b1}}, 1'b0, {P.S_NE{1'b1}}, 1'b1, Xm[P.NF-2:P.NF-P.S_NF]};
                      YNaNRes    = {{P.FLEN-P.S_LEN{1'b1}}, 1'b0, {P.S_NE{1'b1}}, 1'b1, Ym[P.NF-2:P.NF-P.S_NF]};
                      ZNaNRes    = {{P.FLEN-P.S_LEN{1'b1}}, 1'b0, {P.S_NE{1'b1}}, 1'b1, Zm[P.NF-2:P.NF-P.S_NF]};
                      InvalidRes = {{P.FLEN-P.S_LEN{1'b1}}, 1'b0, {P.S_NE{1'b1}}, 1'b1, (P.S_NF-1)'(0)};
                  end else begin
                      InvalidRes = {{P.FLEN-P.S_LEN{1'b1}}, 1'b0, {P.S_NE{1'b1}}, 1'b1, (P.S_NF-1)'(0)};
                  end

                  OfRes   = OfResMax ? {{P.FLEN-P.S_LEN{1'b1}}, Rs, {P.S_NE-1{1'b1}}, 1'b0, {P.S_NF{1'b1}}} : {{P.FLEN-P.S_LEN{1'b1}}, Rs, {P.S_NE{1'b1}}, (P.S_NF)'(0)};
                  UfRes   = {{P.FLEN-P.S_LEN{1'b1}}, Rs, (P.S_LEN-2)'(0), Plus1&Frm[1]&~(DivOp&YInf)};
                  NormRes = {{P.FLEN-P.S_LEN{1'b1}}, Rs, Re[P.S_NE-1:0], Rf[P.NF-1:P.NF-P.S_NF]};
              end
              2'h2: begin
                  if(P.IEEE754) begin
                      XNaNRes    = {{P.FLEN-P.H_LEN{1'b1}}, 1'b0, {P.H_NE{1'b1}}, 1'b1, Xm[P.NF-2:P.NF-P.H_NF]};
                      YNaNRes    = {{P.FLEN-P.H_LEN{1'b1}}, 1'b0, {P.H_NE{1'b1}}, 1'b1, Ym[P.NF-2:P.NF-P.H_NF]};
                      ZNaNRes    = {{P.FLEN-P.H_LEN{1'b1}}, 1'b0, {P.H_NE{1'b1}}, 1'b1, Zm[P.NF-2:P.NF-P.H_NF]};
                      InvalidRes = {{P.FLEN-P.H_LEN{1'b1}}, 1'b0, {P.H_NE{1'b1}}, 1'b1, (P.H_NF-1)'(0)};
                  end else begin
                      InvalidRes = {{P.FLEN-P.H_LEN{1'b1}}, 1'b0, {P.H_NE{1'b1}}, 1'b1, (P.H_NF-1)'(0)};
                  end

                  OfRes   = OfResMax ? {{P.FLEN-P.H_LEN{1'b1}}, Rs, {P.H_NE-1{1'b1}}, 1'b0, {P.H_NF{1'b1}}} : {{P.FLEN-P.H_LEN{1'b1}}, Rs, {P.H_NE{1'b1}}, (P.H_NF)'(0)};
                // zero is exact if dividing by infinity so don't add 1
                  UfRes   = {{P.FLEN-P.H_LEN{1'b1}}, Rs, (P.H_LEN-2)'(0), Plus1&Frm[1]&~(DivOp&YInf)};
                  NormRes = {{P.FLEN-P.H_LEN{1'b1}}, Rs, Re[P.H_NE-1:0], Rf[P.NF-1:P.NF-P.H_NF]};
              end
          endcase
  end

  // determine if you should kill the res - Cvt
  //      - do so if the res underflows, is zero (the exp doesnt calculate correctly). or the integer input is 0
  //      - dont set to zero if fp input is zero but not using the fp input
  //      - dont set to zero if int input is zero but not using the int input
  assign KillRes = CvtOp ? (CvtResUf|(XZero&~IntToFp)|(IntZero&IntToFp)) : FullRe[P.NE+1] | (((YInf&~XInf)|XZero)&DivOp);//Underflow & ~ResSubnorm & (Re!=1);

  // calculate if the overflow result should be selected
  assign SelOfRes = Overflow|DivByZero|(InfIn&~(YInf&DivOp));

  // output infinity with result sign if divide by zero
  if(P.IEEE754)
    always_comb
      if(XNaN&~(IntToFp&CvtOp))   PostProcRes = XNaNRes;
      else if(YNaN&~CvtOp)        PostProcRes = YNaNRes;
      else if(ZNaN&FmaOp)         PostProcRes = ZNaNRes;
      else if(Invalid)            PostProcRes = InvalidRes;
      else if(SelOfRes)           PostProcRes = OfRes;
      else if(KillRes)            PostProcRes = UfRes;
      else                        PostProcRes = NormRes;
  else
    always_comb
      if(NaNIn|Invalid)           PostProcRes = InvalidRes;
      else if(SelOfRes)           PostProcRes = OfRes;
      else if(KillRes)            PostProcRes = UfRes;
      else                        PostProcRes = NormRes;

  ///////////////////////////////////////////////////////////////////////////////////////
  // integer result selection
  ///////////////////////////////////////////////////////////////////////////////////////

  // Causes undefined behavior for invalid:

  // Invalid cases are different for IEEE 754 vs. RISC-V.  For RISC-V, typical results are used
  // unsigned: if invalid (e.g., negative fp to unsigned int, result should overflow and
  //           overflows to the maximum value
  // signed: if invalid, result should overflow to maximum negative value
  //         but is undefined and used for information only
  // Note: The IEEE 754 result comes from values in TestFloat for x86_64

  // IEEE 754
  // select the overflow integer res
  //      - negative infinity and out of range negative input
  //                 |  int   |  long  |
  //          signed | -2^31  | -2^63  |
  //        unsigned | 2^32-1 | 2^64-1 |
  //
  //      - positive infinity and out of range positive input and NaNs
  //                 |   int  |  long  |
  //          signed | -2^31  |-2^63   |
  //        unsigned | 2^32-1 | 2^64-1 |
  //
  //      other: 32 bit unsigned res should be sign extended as if it were a signed number

  // RISC-V
  // select the overflow integer res
  //      - negative infinity and out of range negative input
  //                 |  int  |  long  |
  //          signed | -2^31 | -2^63  |
  //        unsigned |   0   |    0   |
  //
  //      - positive infinity and out of range positive input and NaNs
  //                 |   int  |  long  |
  //          signed | 2^31-1 | 2^63-1 |
  //        unsigned | 2^32-1 | 2^64-1 |
  //
  //      other: 32 bit unsigned res should be sign extended as if it were a signed number

    if(P.IEEE754) begin
      always_comb
        if(Signed)
            if(Xs&~NaNIn) // signed negative
                    if(Int64)   OfIntRes = {1'b1, {P.XLEN-1{1'b0}}};
                    else        OfIntRes = {{P.XLEN-32{1'b1}}, 1'b1, {31{1'b0}}};
            else          // signed positive
                    if(Int64)   OfIntRes = {1'b1, {P.XLEN-1{1'b0}}};
                    else        OfIntRes = {{P.XLEN-32{1'b1}}, 1'b1, {31{1'b0}}};
        else
            if(Xs&~NaNIn) OfIntRes = {P.XLEN{1'b1}}; // unsigned negative
            else          OfIntRes = {P.XLEN{1'b1}}; // unsigned positive
    end else begin
      always_comb
        if(Signed)
            if(Xs&~NaNIn) // signed negative
                    if(Int64)   OfIntRes = {1'b1, {P.XLEN-1{1'b0}}};
                    else        OfIntRes = {{P.XLEN-32{1'b1}}, 1'b1, {31{1'b0}}};
            else          // signed positive
                    if(Int64)   OfIntRes = {1'b0, {P.XLEN-1{1'b1}}};
                    else        OfIntRes = {{P.XLEN-32{1'b0}}, 1'b0, {31{1'b1}}};
        else
            if(Xs&~NaNIn) OfIntRes = {P.XLEN{1'b0}}; // unsigned negative
            else          OfIntRes = {P.XLEN{1'b1}}; // unsigned positive
    end

  // fcvtmod.w.d logic
  // fcvtmod.w.d is like fcvt.w.d excep that it takes bits [31:0] and sign extends the rest,
  // and converts +/-inf and NaN to zero.

  if (P.ZFA_SUPPORTED & P.D_SUPPORTED) // fcvtmod.w.d support
    always_comb begin
        if (Zfa) OfIntRes2 = '0;                // fcvtmod.w.d produces 0 on overflow
        else     OfIntRes2 = OfIntRes;
        if (Zfa) Int64Res = {{(P.XLEN-32){CvtNegRes[P.XLEN-1]}}, CvtNegRes[31:0]};
        else     Int64Res = CvtNegRes[P.XLEN-1:0];
        if (Zfa) SelCvtOfRes = InfIn | NaNIn | (CvtCe > 32 + 52); // fcvtmod.w.d only overflows to 0 on NaN or Infinity, or if the shift is so large that only zeros are left
        else     SelCvtOfRes = IntInvalid;    // regular fcvt gives an overflow if out of range
    end
  else
    always_comb begin // no fcvtmod.w.d support
        OfIntRes2 = OfIntRes;
        Int64Res = CvtNegRes[P.XLEN-1:0];
        SelCvtOfRes = IntInvalid;
    end

  // select the integer output
  //      - if the input is invalid (out of bounds NaN or Inf) then output overflow res
  //      - if the input underflows
  //          - if rounding and signed operation and negative input, output -1
  //          - otherwise output a rounded 0
  //      - otherwise output the normal res (trmined and sign extended if necessary)
  always_comb
    if(SelCvtOfRes)         FCvtIntRes = OfIntRes2;
    else if(CvtCe[P.NE])
      if(Xs&Signed&Plus1)   FCvtIntRes = {{P.XLEN{1'b1}}};
      else                  FCvtIntRes = {{P.XLEN-1{1'b0}}, Plus1};
    else if(Int64)          FCvtIntRes = Int64Res;
    else                    FCvtIntRes = {{P.XLEN-32{CvtNegRes[31]}}, CvtNegRes[31:0]};
endmodule
