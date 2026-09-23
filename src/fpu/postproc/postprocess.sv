///////////////////////////////////////////
// postprocess.sv
//
// Written: me@KatherineParry.com
// Modified: 7/5/2022
//
// Purpose: Post-Processing: normalization, rounding, sign, flags, special cases
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
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

module postprocess import cvw::*;  #(parameter cvw_t P) (
  // general signals
  input logic                              Xs, Ys,              // input signs
  input logic  [P.NF:0]                    Xm, Ym, Zm,          // input mantissas
  input logic  [2:0]                       Frm,                 // rounding mode 000 = rount to nearest, ties to even   001 = round twords zero  010 = round down  011 = round up  100 = round to nearest, ties to max magnitude
  input logic  [P.FMTBITS-1:0]             Fmt,                 // precision 1 = double 0 = single
  input logic  [2:0]                       OpCtrl,              // choose which operation (look below for values)
  input logic                              XZero, YZero,        // inputs are zero
  input logic                              XInf, YInf, ZInf,    // inputs are infinity
  input logic                              XNaN, YNaN, ZNaN,    // inputs are NaN
  input logic                              XSNaN, YSNaN, ZSNaN, // inputs are signaling NaNs
  input logic  [1:0]                       PostProcSel,         // select result to be written to fp register
  //fma signals
  input logic                              FmaAs,               // the modified Z sign - depends on instruction
  input logic                              FmaPs,               // the product's sign
  input logic                              FmaSs,               // Sum sign
  input logic  [P.NE+1:0]                  FmaSe,               // the sum's exponent
  input logic  [P.FMALEN-1:0]              FmaSm,               // the positive sum
  input logic                              FmaASticky,          // sticky bit that is calculated during alignment
  input logic  [$clog2(P.FMALEN+1)-1:0]    FmaSCnt,             // the normalization shift count
  //divide signals
  input logic                              DivSticky,           // divider sticky bit
  input logic  [P.NE+1:0]                  DivUe,               // divsqrt exponent
  input logic  [P.DIVb:0]                  DivUm,               // divsqrt significand
  // conversion signals
  input logic                              CvtCs,               // the result's sign
  input logic  [P.NE:0]                    CvtCe,               // the calculated exponent
  input logic                              CvtResSubnormUf,     // the convert result is subnormal or underflows
  input logic  [P.LOGCVTLEN-1:0]           CvtShiftAmt,         // how much to shift by
  input logic                              ToInt,               // is fp->int (since it's writing to the integer register)
  input logic                              Zfa,                 // Zfa operation (fcvtmod.w.d)
  input logic                              Bf16Dst,             // Zfbfmin: destination is BF16 (fcvt.bf16.s)
  input logic  [P.CVTLEN-1:0]              CvtLzcIn,            // input to the Leading Zero Counter (without msb)
  input logic                              IntZero,             // is the integer input zero
  // final results
  output logic [P.FLEN-1:0]                PostProcRes,         // postprocessor final result
  output logic [4:0]                       PostProcFlg,         // postprocesser flags
  output logic [P.XLEN-1:0]                FCvtIntRes           // the integer conversion result
  );

  // general signals
  logic                        Rs;                   // result sign
  logic [P.NF-1:0]             Rf;                   // Result fraction
  logic [P.NE-1:0]             Re;                   // Result exponent
  logic                        Ms;                   // normalized sign
  logic [P.NORMSHIFTSZ-1:0]    Mf;                   // normalized fraction
  logic [P.NE+1:0]             Me;                   // normalized exponent
  logic [P.NE+1:0]             FullRe;               // Re with bits to determine sign and overflow
  logic                        UfPlus1;              // do you add one (for determining underflow flag)
  logic [P.LOGNORMSHIFTSZ-1:0] ShiftAmt;             // normalization shift amount
  logic [P.NORMSHIFTSZ-1:0]    ShiftIn;              // input to normalization shift
  logic [P.NORMSHIFTSZ-1:0]    Shifted;              // the output of the normalized shifter (before shift correction)
  logic                        Plus1;                // add one to the final result?
  logic                        Overflow;             // overflow flag used to select results
  logic                        Invalid;              // invalid flag used to select results
  logic                        Guard, Round, Sticky; // bits needed to determine rounding
  logic [P.FMTBITS-1:0]        OutFmt;               // output format
  // fma signals
  logic [P.NE+1:0]             FmaMe;                // exponent of the normalized sum
  logic                        FmaSZero;             // is the sum zero
  logic [P.NE+1:0]             NormSumExp;           // exponent of the normalized sum not taking into account Subnormal or zero results
  logic                        FmaPreResultSubnorm;  // is the result subnormal - calculated before LZA correction
  logic [$clog2(P.FMALEN+1)-1:0] FmaShiftAmt;          // normalization shift amount for fma
  // division signals
  logic [P.LOGNORMSHIFTSZ-1:0] DivShiftAmt;          // divsqrt shift amount
  logic [P.NE+1:0]             Ue;                   // divsqrt corrected exponent after correction shift
  logic                        DivByZero;            // divide by zero flag
  logic                        DivResSubnorm;        // is the divsqrt result subnormal
  logic                        DivSubnormShiftPos;   // is the divsqrt subnorm shift amount positive (not underflowed)
  // conversion signals
  logic [P.CVTLEN+P.NF:0]      CvtShiftIn;           // number to be shifted for converter
  logic [1:0]                  CvtNegResMsbs;        // most significant bits of possibly negated int result
  logic [P.XLEN+1:0]           CvtNegRes;            // possibly negated integer result
  logic                        CvtResUf;             // did the convert result underflow
  logic                        IntInvalid;           // invalid integer flag
  // readability signals
  logic                        Mult;                 // multiply operation
  logic                        Sqrt;                 // is the divsqrt operation sqrt
  logic                        Int64;                // is the integer 64 bits?
  logic                        Signed;               // is the operation with a signed integer?
  logic                        IntToFp;              // is the operation an int->fp conversion?
  logic                        CvtOp;                // conversion operation
  logic                        FmaOp;                // fma operation
  logic                        DivOp;                // divider operation
  logic                        InfIn;                // are any of the inputs infinity
  logic                        NaNIn;                // are any of the inputs NaN

  // signals to help readability
  assign Signed  = OpCtrl[0];
  assign Int64   = OpCtrl[1];
  assign IntToFp = OpCtrl[2];
  assign Mult    = OpCtrl[2]&~OpCtrl[1]&~OpCtrl[0];
  assign CvtOp   = (PostProcSel == 2'b00);
  assign FmaOp   = (PostProcSel == 2'b10);
  assign DivOp   = (PostProcSel == 2'b01);
  assign Sqrt    =  OpCtrl[0];

  // is there an input of infinity or NaN being used
  assign InfIn = XInf|YInf|ZInf;
  assign NaNIn = XNaN|YNaN|ZNaN;

  // choose the output format depending on the operation
  //      - fp -> fp: OpCtrl contains the precision of the output
  //      - otherwise: Fmt contains the precision of the output
  if (P.FPSIZES == 2)
      assign OutFmt = IntToFp|~CvtOp ? Fmt : (OpCtrl[1:0] == P.FMT);
  else if (P.FPSIZES == 3 | P.FPSIZES == 4)
      assign OutFmt = IntToFp|~CvtOp ? Fmt : OpCtrl[1:0];
  else assign OutFmt = 0; // FPSIZES = 1

  ///////////////////////////////////////////////////////////////////////////////
  // Normalization
  ///////////////////////////////////////////////////////////////////////////////

  // final claulations before shifting
  cvtshiftcalc #(P) cvtshiftcalc(.ToInt, .CvtCe, .CvtResSubnormUf, .Xm, .CvtLzcIn,
      .XZero, .IntToFp, .OutFmt, .Bf16Dst, .CvtResUf, .CvtShiftIn);

  fmashiftcalc #(P) fmashiftcalc(.FmaSCnt, .Fmt, .NormSumExp, .FmaSe, .FmaSm,
      .FmaSZero, .FmaPreResultSubnorm, .FmaShiftAmt);

  divshiftcalc #(P) divshiftcalc(.DivUe, .DivResSubnorm, .DivSubnormShiftPos, .DivShiftAmt);

  // select which unit's output to shift
  always_comb
    case(PostProcSel)
      2'b10: begin // fma
        ShiftAmt = {{P.LOGNORMSHIFTSZ-$clog2(P.FMALEN-1){1'b0}}, FmaShiftAmt};
        ShiftIn  =  {{2'b00, FmaSm}, {P.NORMSHIFTSZ-(P.FMALEN+2){1'b0}}};
      end
      2'b00: begin // cvt
        ShiftAmt = {{P.LOGNORMSHIFTSZ-$clog2(P.CVTLEN+1){1'b0}}, CvtShiftAmt};
        ShiftIn  =  {CvtShiftIn, {P.NORMSHIFTSZ-(P.CVTLEN+P.NF+1){1'b0}}};
      end
      2'b01: begin //divsqrt
        ShiftAmt = DivShiftAmt;
        ShiftIn  = {{P.NF{1'b0}}, DivUm, {P.NORMSHIFTSZ-(P.DIVb+1+P.NF){1'b0}}};
      end
      default: begin
        ShiftAmt = {P.LOGNORMSHIFTSZ{1'bx}};
        ShiftIn  = {P.NORMSHIFTSZ{1'bx}};
      end
    endcase

  // main normalization shift
  normshift #(P) normshift (.ShiftIn, .ShiftAmt, .Shifted);

  // correct for LZA/divsqrt error
  shiftcorrection #(P) shiftcorrection(.FmaOp, .FmaPreResultSubnorm, .NormSumExp,
      .DivResSubnorm, .DivSubnormShiftPos, .DivOp, .DivUe, .Ue, .FmaSZero, .Shifted, .FmaMe, .Mf);

  ///////////////////////////////////////////////////////////////////////////////
  // Rounding
  ///////////////////////////////////////////////////////////////////////////////

  // round to nearest even
  // round to zero
  // round to -infinity
  // round to infinity
  // round to nearest max magnitude

  // calculate result sign used in rounding unit
  roundsign roundsign(.FmaOp, .DivOp, .CvtOp, .Sqrt, .FmaSs, .Xs, .Ys, .CvtCs, .Ms);

  round #(P) round(.OutFmt, .Frm, .FmaASticky, .Plus1, .PostProcSel, .CvtCe, .Ue,
      .Ms, .FmaMe, .FmaOp, .CvtOp, .CvtResSubnormUf, .Mf, .ToInt,  .CvtResUf,
      .DivSticky, .DivOp, .UfPlus1, .FullRe, .Rf, .Re, .Sticky, .Round, .Guard, .Me, .Bf16Dst);

  ///////////////////////////////////////////////////////////////////////////////
  // Sign calculation
  ///////////////////////////////////////////////////////////////////////////////

  resultsign resultsign(.Frm, .FmaPs, .FmaAs, .Round, .Sticky, .Guard,
      .FmaOp, .ZInf, .InfIn, .FmaSZero, .Mult, .Ms, .Rs);

  ///////////////////////////////////////////////////////////////////////////////
  // Flags
  ///////////////////////////////////////////////////////////////////////////////

  flags #(P) flags(.XSNaN, .YSNaN, .ZSNaN, .XInf, .YInf, .ZInf, .InfIn, .XZero, .YZero,
              .Xs, .Sqrt, .ToInt, .IntToFp, .Int64, .Signed, .OutFmt, .CvtCe,
              .NaNIn, .FmaAs, .FmaPs, .Round, .IntInvalid, .DivByZero,
              .Guard, .Sticky, .UfPlus1, .CvtOp, .DivOp, .FmaOp, .FullRe, .Plus1,
              .Me, .CvtNegResMsbs, .Invalid, .Overflow, .PostProcFlg);

  ///////////////////////////////////////////////////////////////////////////////
  // Select the result
  ///////////////////////////////////////////////////////////////////////////////

  negateintres #(P) negateintres(.Xs, .Shifted, .Signed, .Int64, .Plus1, .CvtNegResMsbs, .CvtNegRes);

  specialcase #(P) specialcase(.Xs, .Xm, .Ym, .Zm, .XZero, .IntInvalid,
      .IntZero, .Frm, .OutFmt, .Bf16Dst, .XNaN, .YNaN, .ZNaN, .CvtResUf,
      .NaNIn, .IntToFp, .Int64, .Signed, .Zfa, .CvtOp, .FmaOp, .Plus1, .Invalid, .Overflow, .InfIn, .CvtNegRes,
      .XInf, .YInf, .DivOp, .DivByZero, .FullRe, .CvtCe, .Rs, .Re, .Rf, .PostProcRes, .FCvtIntRes);

endmodule
