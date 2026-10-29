///////////////////////////////////////////
// vflane.sv
//
// Written: huahuang@g.hmc.edu 2026-10-08
//
// Purpose: RVV vector floating point lane. Executes one already decoded element operation
//          (FMA, divide/sqrt, convert, compare, sign injection, classify, rec7/rsqrt7)
//          including widening/narrowing forms and reductions
//
// Documentation: RISC-V System on Chip Design
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

module vflane import cvw::*, fpu_pkg::*; #(parameter cvw_t P, parameter fpu_t FP) (
  input  logic                           clk, reset,
  input  logic                           StallM,                     // stall the M stage
  input  logic                           FlushE, FlushM,             // flush the E and M stages
  input  logic [P.ELEN-1:0]              Vs2, Vs1, Vd,               // inputs
  input  logic [2:0]                     Vs2EEW, Vs1EEW, VdEEW,      // EEWs
  input  logic [1:0]                     OperandOrderE,              // operand order
  input  logic [2:0]                     UnitE,                      // functional unit: 000 FMA  001 divide/sqrt  010 convert  011 compare/min/max  100 sign injection  101 classify  110 rec7/rsqrt7
  input  logic [2:0]                     OpCtrlE,                    // operation control, meaning depends on Unit (see below)
  input  logic                           ToInt,                      // convert unit: is fp->int
  input  logic                           VReductionE,                // reduction element: accumulator replaces Z (FMA) or Y (compare)
  input  logic                           First,                      // first element of a reduction: use Z rather than the accumulator
  input  logic [2:0]                     Frm,                        // rounding mode 000 = round to nearest, ties to even   001 = round twords zero  010 = round down  011 = round up  100 = round to nearest, ties to max magnitude  110 = round to odd
  input  logic                           FPUActive,                  // kill inputs when FPU not active
  input  logic                           FDivStartE,                 // start a divide or square root
  output logic                           FDivBusyE, FDivDoneE,       // divide/sqrt is busy or finishing (to sequencer)
  output logic [P.ELEN-1:0]              VfRes,                      // result at OutFmt precision
  output logic [4:0]                     VfFlg                       // fp flags
);

  logic [P.FMTBITS-1:0] Vs2Fmt, Vs1Fmt, OutFmt, XFmt, YFmt, ZFmt, YSrcFmt, ZSrcFmt;
  logic [P.ELEN-1:0]    X, Y, Z;

  logic                 FmaOpE, DivOpE, CvtOpE, CmpOpE, SgnOpE, ClassOpE, RecOpE;
  logic                 FmaAddSubE;                                  // OpCtrl == 110 (add) or 111 (sub)
  logic                 FmaMulE;                                     // OpCtrl == 100 (mul)
  logic                 IntToFpE, ToIntE, FtoFE;                     // convert type
  logic                 RedFmaE, RedCmpE;                            // reduction using the FMA or compare unit
  logic                 CmpNeE;                                      // not equal compare

  assign FmaOpE     = (UnitE == 3'b000);
  assign DivOpE     = (UnitE == 3'b001);
  assign CvtOpE     = (UnitE == 3'b010);
  assign CmpOpE     = (UnitE == 3'b011);
  assign SgnOpE     = (UnitE == 3'b100);
  assign ClassOpE   = (UnitE == 3'b101);
  assign RecOpE     = (UnitE == 3'b110);
  assign FmaAddSubE = FmaOpE & OpCtrlE[2] &  OpCtrlE[1];
  assign FmaMulE    = FmaOpE & OpCtrlE[2] & ~OpCtrlE[1];
  assign IntToFpE   = CvtOpE & OpCtrlE[2];
  assign ToIntE     = CvtOpE & ToInt;
  assign FtoFE      = CvtOpE & ~ToInt & ~OpCtrlE[2];
  assign RedFmaE    = VReductionE & FmaOpE;
  assign RedCmpE    = VReductionE & CmpOpE;
  assign CmpNeE     = CmpOpE & (OpCtrlE == 3'b111);

  assign Vs2Fmt = (Vs2EEW == 3'b011) ? P.D_FMT : P.S_FMT;
  assign Vs1Fmt = (Vs1EEW == 3'b011) ? P.D_FMT : P.S_FMT;
  assign OutFmt = (VdEEW  == 3'b011) ? P.D_FMT : P.S_FMT;

  always_comb
    case (OperandOrderE)
      2'b00:   begin X = Vs2; Y = Vs1; Z = Vd;  XFmt = Vs2Fmt; YSrcFmt = Vs1Fmt; ZSrcFmt = OutFmt; end
      2'b01:   begin X = Vs1; Y = Vs2; Z = Vd;  XFmt = Vs1Fmt; YSrcFmt = Vs2Fmt; ZSrcFmt = OutFmt; end
      2'b10:   begin X = Vs1; Y = Vd;  Z = Vs2; XFmt = Vs1Fmt; YSrcFmt = OutFmt; ZSrcFmt = Vs2Fmt; end
      default: begin X = Vs2; Y = Vs1; Z = Vs1; XFmt = Vs2Fmt; YSrcFmt = Vs1Fmt; ZSrcFmt = Vs1Fmt; end
    endcase

  assign YFmt = (FmaAddSubE | RedCmpE) ? OutFmt : YSrcFmt;
  assign ZFmt = RedFmaE ? OutFmt : (FmaAddSubE ? YSrcFmt : (FmaMulE ? OutFmt : ZSrcFmt));

  logic [P.FLEN-1:0] BoxedOne, BoxedZero;
  assign BoxedOne  = (OutFmt == P.D_FMT)
                     ? {{(P.FLEN-P.D_LEN){1'b1}}, 2'b00, {(P.D_NE-1){1'b1}}, {P.D_NF{1'b0}}}
                     : {{(P.FLEN-P.S_LEN){1'b1}}, 2'b00, {(P.S_NE-1){1'b1}}, {P.S_NF{1'b0}}};
  assign BoxedZero = (OutFmt == P.D_FMT)
                     ? {{(P.FLEN-P.D_LEN){1'b1}}, {P.D_LEN{1'b0}}}
                     : {{(P.FLEN-P.S_LEN){1'b1}}, {P.S_LEN{1'b0}}};

  logic              VReductionM;                                    // a reduction element is in the M stage
  logic [P.FLEN-1:0] AccReg;                                         // result of the last completed reduction element
  logic [P.FLEN-1:0] Accumulated;

  assign Accumulated = First ? Z : (VReductionM ? VfRes : AccReg);

  logic [P.FLEN-1:0] FmaXin, FmaYin, FmaZin;

  logic [P.FLEN-1:0] YSel, ZSel;

  assign YSel = FmaAddSubE ? BoxedOne : (RedCmpE ? Accumulated : Y);
  assign ZSel = RedFmaE ? Accumulated : (FmaAddSubE ? Y : (FmaMulE ? BoxedZero : Z));

  assign FmaXin = (XFmt == P.D_FMT) ? X : {{(P.FLEN-P.S_LEN){1'b1}}, X[P.S_LEN-1:0]};
  assign FmaYin = (YFmt == P.D_FMT) ? YSel : {{(P.FLEN-P.S_LEN){1'b1}}, YSel[P.S_LEN-1:0]};
  assign FmaZin = (ZFmt == P.D_FMT) ? ZSel : {{(P.FLEN-P.S_LEN){1'b1}}, ZSel[P.S_LEN-1:0]};

  // Unpack all three per-operand format
  logic              XEnE, YEnE, ZEnE;                               // operand is used by the current operation
  logic              XsE, YsE, ZsE;
  logic [P.NE-1:0]   XeE, YeE, ZeE;
  logic [P.NF:0]     XmE, YmE, ZmE;
  logic              XNaNE, YNaNE, ZNaNE;
  logic              XSNaNE, YSNaNE, ZSNaNE;
  logic              XZeroE, YZeroE, ZZeroE;
  logic              XInfE, YInfE, ZInfE;
  logic              XSubnormE;
  logic [P.FLEN-1:0] XPostBoxE;

  assign XEnE = ~IntToFpE;                                           // integer input to convert is not a float
  assign YEnE = FmaOpE | CmpOpE | SgnOpE | (DivOpE & ~OpCtrlE[0]);
  assign ZEnE = FmaOpE;

  unpackinput #(FP) unpackX (
    .A(FmaXin), .Fmt(XFmt), .En(XEnE), .FPUActive,
    .Sgn(XsE), .Exp(XeE), .Man(XmE),
    .NaN(XNaNE), .SNaN(XSNaNE), .Zero(XZeroE), .Inf(XInfE),
    .ExpMax(), .Subnorm(XSubnormE), .PostBox(XPostBoxE)
  );

  unpackinput #(FP) unpackY (
    .A(FmaYin), .Fmt(YFmt), .En(YEnE), .FPUActive,
    .Sgn(YsE), .Exp(YeE), .Man(YmE),
    .NaN(YNaNE), .SNaN(YSNaNE), .Zero(YZeroE), .Inf(YInfE),
    .ExpMax(), .Subnorm(), .PostBox()
  );

  unpackinput #(FP) unpackZ (
    .A(FmaZin), .Fmt(ZFmt), .En(ZEnE), .FPUActive,
    .Sgn(ZsE), .Exp(ZeE), .Man(ZmE),
    .NaN(ZNaNE), .SNaN(ZSNaNE), .Zero(ZZeroE), .Inf(ZInfE),
    .ExpMax(), .Subnorm(), .PostBox()
  );

  ///////////////////////////////////////////////////////////////////////////////
  // E stage units
  ///////////////////////////////////////////////////////////////////////////////

  // vfma
  logic                          AsE, PsE, SsE, FmaAStickyE;
  logic [P.NE+1:0]               SeE;
  logic [P.FMALEN-1:0]           SmE;
  logic [$clog2(P.FMALEN+1)-1:0] SCntE;

  fma #(P) fma (
    .Xs(XsE), .Ys(YsE), .Zs(ZsE),
    .Xe(XeE), .Ye(YeE), .Ze(ZeE),
    .Xm(XmE), .Ym(YmE), .Zm(ZmE),
    .XZero(XZeroE), .YZero(YZeroE), .ZZero(ZZeroE),
    .OpCtrl(OpCtrlE),
    .As(AsE), .Ps(PsE), .Ss(SsE), .Se(SeE), .Sm(SmE),
    .InvA(), .SCnt(SCntE), .ASticky(FmaAStickyE)
  );

  // vfdivsqrt
  logic [P.NE-2:0]      BiasE;                                       // bias of the result format
  logic [P.LOGFLEN-1:0] NfE;                                         // number of fraction bits in the result format
  logic                 DivStartE;                                   // start a divide or square root
  logic                 IFDivStartE;                                 // divider starting this cycle
  logic                 SqrtM;                                       // square root rather than divide in the M stage
  logic                 DivStickyM;                                  // divider sticky bit
  logic [P.NE+1:0]      UeM;                                         // divsqrt exponent
  logic [P.DIVb:0]      UmM;                                         // divsqrt significand

  assign DivStartE = FDivStartE & FPUActive & DivOpE;

  fmtparams #(FP) fmtparams (.Fmt(OutFmt), .Bias(BiasE), .Nf(NfE));

  fdivsqrt #(P) fdivsqrt(.clk, .reset, .FmtE(OutFmt), .XmE, .YmE, .XeE, .YeE, .SqrtE(OpCtrlE[0]), .SqrtM,
    .XInfE, .YInfE, .XZeroE, .YZeroE, .XNaNE, .YNaNE, .BiasE, .NfE, .FDivStartE(DivStartE), .IDivStartE(1'b0), .XsE,
    .ForwardedSrcAE('0), .ForwardedSrcBE('0), .Funct3E(3'b000), .Funct3M(3'b000), .IntDivE(1'b0), .W64E(1'b0),
    .StallM, .FlushE, .DivStickyM, .FDivBusyE, .IFDivStartE, .FDivDoneE, .UeM,
    .UmM, .FIntDivResultM());

  // vfcvt
  logic [2:0]             VfcvtOpCtrlE;
  logic [P.NE:0]          CeE;
  logic [P.LOGCVTLEN-1:0] CvtShiftAmtE;
  logic                   CvtResSubnormUfE, CsE, IntZeroE;
  logic [P.CVTLEN-1:0]    CvtLzcInE;

  // OpCtrl[1:0] interpreted as Fmt for fp->fp conversion
  assign VfcvtOpCtrlE = FtoFE ? {1'b0, OutFmt} : OpCtrlE;

  fcvt #(P) fcvt (
    .Xs(XsE), .Xe(XeE), .Xm(XmE), .Int(X[P.ELEN-1:0]), .OpCtrl(VfcvtOpCtrlE),
    .ToInt(ToIntE), .XZero(XZeroE), .Fmt(IntToFpE ? OutFmt : XFmt), .Ce(CeE), .ShiftAmt(CvtShiftAmtE),
    .ResSubnormUf(CvtResSubnormUfE), .Cs(CsE), .IntZero(IntZeroE), .LzcIn(CvtLzcInE)
  );

  // compare: min/max and compare, the reduction compares against the accumulator
  logic [P.FLEN-1:0] CmpFpResE;                                      // min/max result
  logic              CmpNVE;                                         // compare invalid flag
  logic [P.ELEN-1:0] CmpIntResE;                                     // compare result
  logic [2:0]        CmpOpCtrlE;                                     // fcmp has no not equal
  logic              CmpMaskE;                                       // compare result bit

  assign CmpOpCtrlE = CmpNeE ? 3'b010 : OpCtrlE;
  assign CmpMaskE   = CmpIntResE[0] ^ CmpNeE;

  fcmp #(P) fcmp (
    .Fmt(OutFmt), .OpCtrl(CmpOpCtrlE), .Zfa(1'b0),
    .Xs(XsE), .Ys(YsE),
    .Xe(XeE), .Ye(YeE),
    .Xm(XmE), .Ym(YmE),
    .XZero(XZeroE), .YZero(YZeroE),
    .XNaN(XNaNE), .YNaN(YNaNE),
    .XSNaN(XSNaNE), .YSNaN(YSNaNE),
    .X(FmaXin), .Y(FmaYin),
    .CmpNV(CmpNVE), .CmpFpRes(CmpFpResE), .CmpIntRes(CmpIntResE)
  );

  // sign injection
  logic [P.FLEN-1:0] SgnResE;

  fsgninj #(P) fsgninj(
    .Xs(XsE), .Ys(YsE), .X(XPostBoxE), .Fmt(OutFmt), .OpCtrl(OpCtrlE[1:0]),
    .SgnRes(SgnResE)
  );

  // classify
  logic [P.ELEN-1:0] ClassResE;

  fclassify #(P) fclassify(
    .Xs(XsE), .XNaN(XNaNE), .XSNaN(XSNaNE), .XSubnorm(XSubnormE), .XZero(XZeroE), .XInf(XInfE),
    .ClassRes(ClassResE)
  );

  // reciprocal and reciprocal square root
  logic [P.FLEN-1:0] VfrecResE;
  logic [4:0]        VfrecFlgE;

  vfrecrsqrt7 #(P) vfrecrsqrt7 (
    .IsSqrt(OpCtrlE[0]), .Xs(XsE), .XNaN(XNaNE), .XSNaN(XSNaNE), .XZero(XZeroE), .XInf(XInfE), .XSubnorm(XSubnormE),
    .Xe(XeE), .Xm(XmE), .Vsew(VdEEW), .Frm,
    .VfrecRes(VfrecResE), .VfrecFlg(VfrecFlgE)
  );

  // select the results that finish in the E stage
  logic [P.FLEN-1:0] PreFpResE;                                      // sign injection, min/max, or rec7/rsqrt7 result
  logic [P.ELEN-1:0] PreIntResE;                                     // classify or compare result
  logic [4:0]        PreFlgE;                                        // flags of the above

  assign PreFpResE  = SgnOpE ? SgnResE : (RecOpE ? VfrecResE : CmpFpResE);
  assign PreIntResE = ClassOpE ? {{(P.ELEN-10){1'b0}}, ClassResE[9:0]} : {{(P.ELEN-1){1'b0}}, CmpMaskE};
  assign PreFlgE    = {5{FPUActive}} & (CmpOpE ? {CmpNVE, 4'b0000} : (RecOpE ? VfrecFlgE : 5'b00000));

  // control for the M stage
  logic [1:0]            PostProcSelE;                               // select the postprocessor input: 00 convert  01 divide/sqrt  10 FMA
  logic [2:0]            PostOpCtrlE;                                // postprocessor operation control
  logic                  UsePostProcE;                               // result comes from the postprocessor
  logic                  IntSelE;

  assign PostProcSelE = FmaOpE ? 2'b10 : (DivOpE ? 2'b01 : 2'b00);
  assign PostOpCtrlE  = FmaOpE ? OpCtrlE : (DivOpE ? {2'b00, OpCtrlE[0]} : VfcvtOpCtrlE);
  assign UsePostProcE = FmaOpE | DivOpE | CvtOpE;
  assign IntSelE      = ClassOpE | (CmpOpE & ~(OpCtrlE[2] & (OpCtrlE[1] ^ OpCtrlE[0])));

  ///////////////////////////////////////////////////////////////////////////////
  // E to M pipe registers
  ///////////////////////////////////////////////////////////////////////////////

  logic                          StallUnpackedM;
  logic [P.NF:0]                 XmM, YmM, ZmM;
  logic                          XsM, YsM, XZeroM, YZeroM, XInfM, YInfM, ZInfM;
  logic                          XNaNM, YNaNM, ZNaNM, XSNaNM, YSNaNM, ZSNaNM;
  logic [P.FLEN-1:0]             PreFpResM;
  logic [P.ELEN-1:0]             PreIntResM;
  logic [4:0]                    PreFlgM;
  logic [P.FMALEN-1:0]           SmM;
  logic                          AsM, PsM, SsM, FmaAStickyM;
  logic [P.NE+1:0]               SeM;
  logic [$clog2(P.FMALEN+1)-1:0] SCntM;
  logic [P.NE:0]                 CeM;
  logic [P.LOGCVTLEN-1:0]        CvtShiftAmtM;
  logic                          CvtResSubnormUfM, CsM, IntZeroM;
  logic [P.CVTLEN-1:0]           CvtLzcInM;
  logic [1:0]                    PostProcSelM;
  logic [2:0]                    PostOpCtrlM;
  logic [P.FMTBITS-1:0]          FmtM;
  logic [2:0]                    FrmM;
  logic                          ToIntM, UsePostProcM, ActiveM, IntSelM;

  assign StallUnpackedM = StallM | (FDivBusyE & ~IFDivStartE | FDivDoneE); // stall during divsqrt

  flopenrc #(P.NF+1) EMFpReg2 (clk, reset, FlushM, ~StallM, XmE, XmM);
  flopenrc #(P.NF+1) EMFpReg3 (clk, reset, FlushM, ~StallM, YmE, YmM);
  flopenrc #(P.NF+1) EMFpReg4 (clk, reset, FlushM, ~StallM, ZmE, ZmM);
  flopenrc #(P.ELEN) EMFpReg6 (clk, reset, FlushM, ~StallM, PreIntResE, PreIntResM);
  flopenrc #(P.FLEN) EMFpReg7 (clk, reset, FlushM, ~StallM, PreFpResE, PreFpResM);
  flopenr #(13) EMFpReg5 (clk, reset, ~StallUnpackedM,
    {XsE, YsE, XZeroE, YZeroE, XInfE, YInfE, ZInfE, XNaNE, YNaNE, ZNaNE, XSNaNE, YSNaNE, ZSNaNE},
    {XsM, YsM, XZeroM, YZeroM, XInfM, YInfM, ZInfM, XNaNM, YNaNM, ZNaNM, XSNaNM, YSNaNM, ZSNaNM});
  flopenrc #(5)  EMRegCmpFlg (clk, reset, FlushM, ~StallM, PreFlgE, PreFlgM);
  flopenrc #(P.FMALEN) EMRegFma2(clk, reset, FlushM, ~StallM, SmE, SmM);
  flopenrc #($clog2(P.FMALEN+1)+4+P.NE+2) EMRegFma4(clk, reset, FlushM, ~StallM,
    {FmaAStickyE, SCntE, AsE, PsE, SsE, SeE},
    {FmaAStickyM, SCntM, AsM, PsM, SsM, SeM});
  flopenrc #(P.NE+1+P.LOGCVTLEN+P.CVTLEN+3) EMRegCvt(clk, reset, FlushM, ~StallM,
    {CeE, CvtShiftAmtE, CvtResSubnormUfE, CsE, IntZeroE, CvtLzcInE},
    {CeM, CvtShiftAmtM, CvtResSubnormUfM, CsM, IntZeroM, CvtLzcInM});
  flopenrc #(13+P.FMTBITS) EMRegCtrl(clk, reset, FlushM, ~StallM,
    {PostProcSelE, PostOpCtrlE, OutFmt, Frm, ToIntE, UsePostProcE, VReductionE, FPUActive, IntSelE},
    {PostProcSelM, PostOpCtrlM, FmtM, FrmM, ToIntM, UsePostProcM, VReductionM, ActiveM, IntSelM});

  // reduction accumulator: holds the result of the last completed reduction element
  flopenr #(P.FLEN) MRegAcc(clk, reset, VReductionM & ~StallM, VfRes, AccReg);

  assign SqrtM = PostOpCtrlM[0];

  ///////////////////////////////////////////////////////////////////////////////
  // M stage
  ///////////////////////////////////////////////////////////////////////////////

  logic [P.FLEN-1:0] PostProcResM;                                   // postprocessor result
  logic [4:0]        PostProcFlgM;                                   // postprocessor flags
  logic [P.ELEN-1:0] FCvtIntResM;                                    // postprocessor integer result

  postprocess #(P, 1) postproc (
    .Xs(XsM), .Ys(YsM),
    .Xm(XmM), .Ym(YmM), .Zm(ZmM),
    .Frm(FrmM),
    .Fmt(FmtM),
    .OpCtrl(PostOpCtrlM),
    .XZero(XZeroM), .YZero(YZeroM),
    .XInf(XInfM), .YInf(YInfM), .ZInf(ZInfM),
    .XNaN(XNaNM), .YNaN(YNaNM), .ZNaN(ZNaNM),
    .XSNaN(XSNaNM), .YSNaN(YSNaNM), .ZSNaN(ZSNaNM),
    .PostProcSel(PostProcSelM),

    // FMA signals
    .FmaAs(AsM), .FmaPs(PsM), .FmaSs(SsM),
    .FmaSe(SeM), .FmaSm(SmM),
    .FmaASticky(FmaAStickyM), .FmaSCnt(SCntM),

    // Divide signals
    .DivSticky(DivStickyM),
    .DivUe(UeM),
    .DivUm(UmM),

    // Convert signals
    .CvtCs(CsM),
    .CvtCe(CeM),
    .CvtResSubnormUf(CvtResSubnormUfM),
    .CvtShiftAmt(CvtShiftAmtM),
    .ToInt(ToIntM),
    .Zfa(1'b0),
    .CvtLzcIn(CvtLzcInM),
    .IntZero(IntZeroM),

    .PostProcRes(PostProcResM),
    .PostProcFlg(PostProcFlgM),
    .FCvtIntRes(FCvtIntResM)
  );

  // final results
  assign VfRes    = ToIntM ? FCvtIntResM : (IntSelM ? PreIntResM : (UsePostProcM ? PostProcResM : PreFpResM));
  assign VfFlg    = {5{ActiveM}} & (UsePostProcM ? PostProcFlgM : PreFlgM);

endmodule
