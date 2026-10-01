///////////////////////////////////////////
// vfcvt.sv
//
// Written: huahuang@g.hmc.edu 2026-09-08
//
// Purpose: RVV vector floating-point convert lane. Covers vector convert instructions,
//          including narrowing, non-widening, and widening conversions
//
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

module vfcvt import cvw::*; #(parameter cvw_t P) (
  input logic [P.FLEN-1:0] X,
  input logic [2:0] Frm,
  input logic [2:0] OpCtrl,
  input logic ToInt,
  input logic [2:0] Vsew,
  input logic [1:0] WideNarrow, // equivalent to R1[4:3], 00 Nonwidening, 01 Wide, 10 Narrow, 11 Reserved
  input logic FPUActive,
  output logic [P.FLEN-1:0] VfcvtRes,
  output logic [4:0] VfcvtFlg,
  output logic [P.ELEN-1:0] VfcvtIntRes
);

  // OpCtrl[0]: Signed
  // OpCtrl[1]: Int64
  // OpCtrl[2]: IntToFp

  logic Xs;
  logic [P.NE-1:0] Xe;
  logic [P.NF:0] Xm;
  logic XNaN, XSNaN, XZero, XInf;
  logic [P.FMTBITS-1:0] XinFmt, XoutFmt;

  logic FtoF;
  assign FtoF = ~ToInt & ~OpCtrl[2];

  always_comb
    case ({WideNarrow, Vsew})
      // non-widening
      5'b00_001: begin XinFmt = P.H_FMT; XoutFmt = P.H_FMT; end
      5'b00_010: begin XinFmt = P.S_FMT; XoutFmt = P.S_FMT; end
      5'b00_011: begin XinFmt = P.D_FMT; XoutFmt = P.D_FMT; end

      // widening
      5'b01_001: begin XinFmt = P.H_FMT; XoutFmt = P.S_FMT; end
      5'b01_010: begin XinFmt = P.S_FMT; XoutFmt = P.D_FMT; end
      5'b01_011: begin XinFmt = P.D_FMT; XoutFmt = P.Q_FMT; end

      // narrowing
      5'b10_001: begin XinFmt = P.S_FMT; XoutFmt = P.H_FMT; end
      5'b10_010: begin XinFmt = P.D_FMT; XoutFmt = P.S_FMT; end
      5'b10_011: begin XinFmt = P.Q_FMT; XoutFmt = P.D_FMT; end

      default: begin XinFmt = 'x; XoutFmt = 'x; end
    endcase

  logic [2:0] VfcvtOpCtrl;

  // OpCtrl[1:0] interpreted as Fmt for fp->fp conversion
  assign VfcvtOpCtrl = FtoF ? {1'b0, XoutFmt} : OpCtrl;

  // unpack X
  unpackinput #(P) unpackX (
    .A(X), .Fmt(XinFmt), .En(~OpCtrl[2]), .FPUActive,
    .Sgn(Xs), .Exp(Xe), .Man(Xm),
    .NaN(XNaN), .SNaN(XSNaN), .Zero(XZero), .Inf(XInf),
    .ExpMax(), .Subnorm(), .PostBox()
  );

  logic [P.NE:0] Ce;
  logic [P.LOGCVTLEN-1:0] CvtShiftAmt;
  logic CvtResSubnormUf, Cs, IntZero;
  logic [P.CVTLEN-1:0] CvtLzcIn;

  // fpu converter
  fcvt #(P) fcvt (.Xs(Xs), .Xe(Xe), .Xm(Xm), .Int(X[P.ELEN-1:0]), .OpCtrl(VfcvtOpCtrl),
  .ToInt(ToInt), .XZero(XZero), .Fmt(XoutFmt), .Ce(Ce), .ShiftAmt(CvtShiftAmt),
  .ResSubnormUf(CvtResSubnormUf), .Cs(Cs), .IntZero(IntZero), .LzcIn(CvtLzcIn));

  // postprocessor
  postprocess #(P, 1) postproc (
    .Xs(Xs), .Ys(1'b0),
    .Xm(Xm), .Ym({(P.NF+1){1'b0}}), .Zm({(P.NF+1){1'b0}}),
    .Frm(Frm),
    .Fmt(XoutFmt),
    .OpCtrl(VfcvtOpCtrl),
    .XZero(XZero), .YZero(1'b0),
    .XInf(XInf), .YInf(1'b0), .ZInf(1'b0),
    .XNaN(XNaN), .YNaN(1'b0), .ZNaN(1'b0),
    .XSNaN(XSNaN), .YSNaN(1'b0), .ZSNaN(1'b0),
    .PostProcSel(2'b00),

    // FMA signals
    .FmaAs(1'b0), .FmaPs(1'b0), .FmaSs(1'b0),
    .FmaSe({(P.NE+2){1'b0}}), .FmaSm({(P.FMALEN){1'b0}}),
    .FmaASticky(1'b0), .FmaSCnt({($clog2(P.FMALEN+1)){1'b0}}),

    // Divide signals
    .DivSticky(1'b0),
    .DivUe({(P.NE+2){1'b0}}),
    .DivUm({(P.DIVb+1){1'b0}}),

    // Convert signals
    .CvtCs(Cs),
    .CvtCe(Ce),
    .CvtResSubnormUf(CvtResSubnormUf),
    .CvtShiftAmt(CvtShiftAmt),
    .ToInt(ToInt),
    .Zfa(1'b0),
    .CvtLzcIn(CvtLzcIn),
    .IntZero(IntZero),

    .PostProcRes(VfcvtRes),
    .PostProcFlg(VfcvtFlg),
    .FCvtIntRes(VfcvtIntRes)
  );

endmodule
