///////////////////////////////////////////
// vfma.sv
//
// Written: ytai@g.hmc.edu 2026-09-07
//
// Purpose: RVV vector floating-point arithmetic unit lane. Covers add/sub/mul/FMA,
//          both non-widening and widening forms
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

module vfma import fpu_pkg::*; #(parameter fpu_t FP) (
  input  logic [FP.FLEN-1:0]              X, Y, Z,                    // three operands
  input  logic                           XWide, YWide, ZWide,        // is the operand widened (EEW = 2*SEW)
  input  logic [FP.FMTBITS-1:0]           OutFmt,                     // target format for the result (S_FMT or D_FMT)
  input  logic [2:0]                     OpCtrl,                     // operation control
  input  logic [2:0]                     Frm,                        // rounding mode 000 = rount to nearest, ties to even   001 = round twords zero  010 = round down  011 = round up  100 = round to nearest, ties to max magnitude
  input  logic                           FPUActive,                  // kill inputs when FPU not active
  output logic [FP.FLEN-1:0]              VfmaRes,                    // result at OutFmt precision
  output logic [4:0]                     VfmaFlg                     // fp flags
);

  //  OpCtrl for FPU FMA:
  //    Fma: {not multiply-add?, negate prod?, negate Z?}
  //        000 - fmadd
  //        001 - fmsub
  //        010 - fnmsub
  //        011 - fnmadd
  //        100 - mul
  //        110 - add
  //        111 - sub

  logic  FmaAddSub;   // OpCtrl == 110 (add) or 111 (sub)
  logic  FmaMul;      // OpCtrl == 100 (mul)
  assign FmaAddSub = OpCtrl[2] &  OpCtrl[1];
  assign FmaMul    = OpCtrl[2] & ~OpCtrl[1];

  // assuming  FP.FLEN >= FP.D_LEN and FP.D_SUPPORT == 1, TODO: add ELEN support
  logic [FP.FLEN-1:0] BoxedOne, BoxedZero;
  assign BoxedOne  = (OutFmt == FP.D_FMT)
                     ? {{(FP.FLEN-FP.D_LEN){1'b1}}, 2'b00, {(FP.D_NE-1){1'b1}}, {FP.D_NF{1'b0}}}
                     : {{(FP.FLEN-FP.S_LEN){1'b1}}, 2'b00, {(FP.S_NE-1){1'b1}}, {FP.S_NF{1'b0}}};
  assign BoxedZero = (OutFmt == FP.D_FMT)
                     ? {{(FP.FLEN-FP.D_LEN){1'b1}}, {FP.D_LEN{1'b0}}}
                     : {{(FP.FLEN-FP.S_LEN){1'b1}}, {FP.S_LEN{1'b0}}};

  // Route operands to fma's X/Y/Z depending on operation and pick format
  logic [FP.FLEN-1:0]    FmaXin, FmaYin, FmaZin;
  logic [FP.FMTBITS-1:0] FmaXFmt, FmaYFmt, FmaZFmt;

  assign FmaXin  = X;
  assign FmaYin  = FmaAddSub ? BoxedOne : Y;
  assign FmaZin  = FmaAddSub ? Y : (FmaMul ? BoxedZero : Z);

  assign FmaXFmt = XWide ? FP.D_FMT : FP.S_FMT;
  assign FmaYFmt = FmaAddSub ? OutFmt : (YWide ? FP.D_FMT : FP.S_FMT);
  assign FmaZFmt = FmaAddSub ? (YWide ? FP.D_FMT : FP.S_FMT)
                             : (FmaMul  ? OutFmt : (ZWide ? FP.D_FMT : FP.S_FMT));

  // Unpack all three per-operand format
  logic              Xs, Ys, Zs;
  logic [FP.NE-1:0]   Xe, Ye, Ze;
  logic [FP.NF:0]     Xm, Ym, Zm;
  logic              XNaN, YNaN, ZNaN;
  logic              XSNaN, YSNaN, ZSNaN;
  logic              XZero, YZero, ZZero;
  logic              XInf, YInf, ZInf;

  unpackinput #(FP) unpackX (
    .A(FmaXin), .Fmt(FmaXFmt), .En(1'b1), .FPUActive,
    .Sgn(Xs), .Exp(Xe), .Man(Xm),
    .NaN(XNaN), .SNaN(XSNaN), .Zero(XZero), .Inf(XInf),
    .ExpMax(), .Subnorm(), .PostBox()
  );

  unpackinput #(FP) unpackY (
    .A(FmaYin), .Fmt(FmaYFmt), .En(1'b1), .FPUActive,
    .Sgn(Ys), .Exp(Ye), .Man(Ym),
    .NaN(YNaN), .SNaN(YSNaN), .Zero(YZero), .Inf(YInf),
    .ExpMax(), .Subnorm(), .PostBox()
  );

  unpackinput #(FP) unpackZ (
    .A(FmaZin), .Fmt(FmaZFmt), .En(1'b1), .FPUActive,
    .Sgn(Zs), .Exp(Ze), .Man(Zm),
    .NaN(ZNaN), .SNaN(ZSNaN), .Zero(ZZero), .Inf(ZInf),
    .ExpMax(), .Subnorm(), .PostBox()
  );

  // FMA unit
  logic                          As, Ps, Ss, ASticky;
  logic [FP.NE+1:0]               Se;
  logic [FP.FMALEN-1:0]           Sm;
  logic [$clog2(FP.FMALEN+1)-1:0] SCnt;

  fma #(FP) fma (
    .Xs, .Ys, .Zs,
    .Xe, .Ye, .Ze,
    .Xm, .Ym, .Zm,
    .XZero, .YZero, .ZZero,
    .OpCtrl,
    .As, .Ps, .Ss, .Se, .Sm,
    .InvA(), .SCnt, .ASticky
  );

  // Postprocess: round to OutFmt, TODO: make work with ELEN, make more compact with lane specific operations
  postprocess #(FP) postproc (
    .Xs, .Ys,
    .Xm, .Ym, .Zm,
    .Frm,
    .Fmt(OutFmt),
    .OpCtrl,
    .XZero, .YZero,
    .XInf, .YInf, .ZInf,
    .XNaN, .YNaN, .ZNaN,
    .XSNaN, .YSNaN, .ZSNaN,
    .PostProcSel(2'b10),

    // FMA signals
    .FmaAs(As), .FmaPs(Ps), .FmaSs(Ss),
    .FmaSe(Se), .FmaSm(Sm),
    .FmaASticky(ASticky), .FmaSCnt(SCnt),

    // Divide signals
    .DivSticky(1'b0),
    .DivUe({(FP.NE+2){1'b0}}),
    .DivUm({(FP.DIVb+1){1'b0}}),

    // Convert signals
    .CvtCs(1'b0),
    .CvtCe({(FP.NE+1){1'b0}}),
    .CvtResSubnormUf(1'b0),
    .CvtShiftAmt({FP.LOGCVTLEN{1'b0}}),
    .ToInt(1'b0),
    .Zfa(1'b0),
    .CvtLzcIn({FP.CVTLEN{1'b0}}),
    .IntZero(1'b1),

    .PostProcRes(VfmaRes),
    .PostProcFlg(VfmaFlg),
    .FCvtIntRes()
  );

endmodule
