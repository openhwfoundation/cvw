///////////////////////////////////////////
// vfred.sv
//
// Written: huahuang@g.hmc.edu 2026-09-30
//
// Purpose: RVV vector floating point reduction lane. Covers widening forms
//
// Documentation: TODO: RISC-V System on Chip Design
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

module vfred import cvw::*; #(parameter cvw_t P) (
  input  logic [P.FLEN-1:0]              X, Z,                       // two operands
  input  logic                           XWide, ZWide,               // is the operand widened (EEW = 2*SEW)
  input  logic [P.FMTBITS-1:0]           OutFmt,                     // target format for the result (S_FMT or D_FMT)
  input  logic [2:0]                     OpCtrl,                     // operation control, should be 110 for sum or min, 101 for max
  input  logic                           SumM,                       // is the instruction sum or min/max (M stage)
  input  logic [2:0]                     FrmM,                       // M stage, rounding mode 000 = round to nearest, ties to even   001 = round twords zero  010 = round down  011 = round up  100 = round to nearest, ties to max magnitude
  input  logic                           FPUActive,                  // kill inputs when FPU not active
  input  logic                           First,                      // checks whether it is the first time operating on this function
  input  logic                           XsM,
  input  logic [P.NF:0]                  XmM, ZmM,
  input  logic                           XZeroM,
  input  logic                           XInfM, ZInfM,
  input  logic                           XNaNM, ZNaNM,
  input  logic                           XSNaNM, ZSNaNM,
  input  logic [P.FLEN-1:0]              CmpFpResM,
  input  logic                           CmpNVM,
  input  logic [P.FMTBITS-1:0]           OutFmtM,
  input  logic [2:0]                     OpCtrlM,
  input  logic [P.FMALEN-1:0]            SmM,
  input  logic [P.NE+1:0]                SeM,
  input  logic                           AsM,
  input  logic                           PsM,
  input  logic                           SsM,
  input  logic [$clog2(P.FMALEN+1)-1:0]  SCntM,
  input  logic                           FmaAStickyM,
  output logic                           XsE,
  output logic [P.NF:0]                  XmE, ZmE,
  output logic                           XZeroE,
  output logic                           XInfE, ZInfE,
  output logic                           XNaNE, ZNaNE,
  output logic                           XSNaNE, ZSNaNE,
  output logic [P.FLEN-1:0]              CmpFpResE,
  output logic                           CmpNVE,
  output logic [P.FMALEN-1:0]            SmE,
  output logic [P.NE+1:0]                SeE,
  output logic                           AsE,
  output logic                           PsE,
  output logic                           SsE,
  output logic [$clog2(P.FMALEN+1)-1:0]  SCntE,
  output logic                           FmaAStickyE,
  output logic [P.FLEN-1:0]              VfredRes,                   // result at OutFmt precision
  output logic [4:0]                     VfredFlg                    // fp flags
);

  logic [P.FMTBITS-1:0] FmaXFmt, FmaZFmt;
  logic [P.FLEN-1:0] Accumulated;

  assign FmaXFmt = XWide ? P.D_FMT : P.S_FMT;
  assign FmaZFmt = ZWide ? P.D_FMT : P.S_FMT;
  assign Accumulated = First ? Z : VfredRes;

  // Unpack X and Z
  logic              Zs;
  logic [P.NE-1:0]   Xe, Ze;
  logic              ZZero;

  unpackinput #(P) unpackX (
    .A(X), .Fmt(FmaXFmt), .En(1'b1), .FPUActive,
    .Sgn(XsE), .Exp(Xe), .Man(XmE),
    .NaN(XNaNE), .SNaN(XSNaNE), .Zero(XZeroE), .Inf(XInfE),
    .ExpMax(), .Subnorm(), .PostBox()
  );

  unpackinput #(P) unpackZ (
    .A(Accumulated), .Fmt(FmaZFmt), .En(1'b1), .FPUActive,
    .Sgn(Zs), .Exp(Ze), .Man(ZmE),
    .NaN(ZNaNE), .SNaN(ZSNaNE), .Zero(ZZero), .Inf(ZInfE),
    .ExpMax(), .Subnorm(), .PostBox()
  );

  // fma for sum, set Y=1
  fma #(P) fma (
    .Xs(XsE), .Ys(0), .Zs,
    .Xe, .Ye(P.NE'(P.BIAS)), .Ze,
    .Xm(XmE), .Ym({1'b1, {(P.NF){1'b0}}}), .Zm(ZmE),
    .XZero(XZeroE), .YZero(0), .ZZero,
    .OpCtrl,
    .As(AsE), .Ps(PsE), .Ss(SsE), .Se(SeE), .Sm(SmE),
    .InvA(), .SCnt(SCntE), .ASticky(FmaAStickyE)
  );

  // compare for min or max
  logic [P.ELEN-1:0] CmpIntRes;

  fcmp #(P) fcmp (
    .Fmt(OutFmt), .OpCtrl, .Zfa(1'b0),
    .Xs(XsE), .Ys(Zs),
    .Xe, .Ye(Ze),
    .Xm(XmE), .Ym(ZmE),
    .XZero(XZeroE), .YZero(ZZero),
    .XNaN(XNaNE), .YNaN(ZNaNE),
    .XSNaN(XSNaNE), .YSNaN(ZSNaNE),
    .X, .Y(Accumulated),
    .CmpNV(CmpNVE), .CmpFpRes(CmpFpResE), .CmpIntRes
  );

  logic [4:0] VfmaFlg;
  logic [P.FLEN-1:0] VfmaRes;
  postprocess #(P, 1) postproc (
    .Xs(XsM), .Ys(0),
    .Xm(XmM), .Ym({1'b1,{(P.NF){1'b0}}}), .Zm(ZmM),
    .Frm(FrmM),
    .Fmt(OutFmtM),
    .OpCtrl(OpCtrlM),
    .XZero(XZeroM), .YZero(0),
    .XInf(XInfM), .YInf(0), .ZInf(ZInfM),
    .XNaN(XNaNM), .YNaN(0), .ZNaN(ZNaNM),
    .XSNaN(XSNaNM), .YSNaN(0), .ZSNaN(ZSNaNM),
    .PostProcSel(2'b10),

    // FMA signals
    .FmaAs(AsM), .FmaPs(PsM), .FmaSs(SsM),
    .FmaSe(SeM), .FmaSm(SmM),
    .FmaASticky(FmaAStickyM), .FmaSCnt(SCntM),

    // Divide signals
    .DivSticky(1'b0),
    .DivUe({(P.NE+2){1'b0}}),
    .DivUm({(P.DIVb+1){1'b0}}),

    // Convert signals
    .CvtCs(1'b0),
    .CvtCe({(P.NE+1){1'b0}}),
    .CvtResSubnormUf(1'b0),
    .CvtShiftAmt({P.LOGCVTLEN{1'b0}}),
    .ToInt(1'b0),
    .Zfa(1'b0),
    .CvtLzcIn({P.CVTLEN{1'b0}}),
    .IntZero(1'b1),

    .PostProcRes(VfmaRes),
    .PostProcFlg(VfmaFlg),
    .FCvtIntRes()
  );

  assign VfredFlg = SumM ? VfmaFlg: {CmpNVM, 4'b0};
  assign VfredRes = SumM ? VfmaRes: CmpFpResM;

endmodule
