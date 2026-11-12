///////////////////////////////////////////
// vfpeu.sv
//
// Written: Georgia Tai ytai@g.hmc.edu
// Created: 11 October 2026
// Modified: 11 November 2026
//
// Purpose: Vector floating-point execution unit.
//
// Documentation: TODO: RISC-V System on Chip Design Volume 2
////
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Skyworks Solutions Inc.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
////////////////////////////////////////////////////////////////////////////////////////////////

module vfpeu import cvw::*, fpu_pkg::*;  #(parameter cvw_t P, parameter fpu_t FP) (
  input  logic                         clk, reset,
  // Hazards
  input  logic                         VectorStallE, StallM, StallW,
  input  logic                         VectorFlushE, VectorFlushM, FlushW,
  // Flow control
  input  logic                         ControllerValidD,
  input  logic                         ControllerWBReadyW,
  output logic                         ExecutionUnitReadyD,
  output logic                         ExecutionUnitResultValidW,
  input  logic [P.VPU_QUEUEDEPTH-1:0]  ExecutionUnitOrderD,
  output logic [P.VPU_QUEUEDEPTH-1:0]  ExecutionUnitOrderW,
  // Control from the controller
  input  logic                         VMD,                      // 0 = mask enabled, 1 mask disabled
  input  logic [1:0]                   VALUSrcAD,                // 10: fs1 replaces vs1
  input  logic [2:0]                   VFUnitD, VFOpCtrlD,       // vflane unit and operation control
  input  logic                         VFToIntD,                 // convert to integer
  input  logic [1:0]                   VFOperandOrderD,          // vflane operand order
  input  logic                         VFStaticRmD,              // VFRmD replaces frm (true for cvt)
  input  logic [2:0]                   VFRmD,                    // rounding mode of vfcvt.rtz and vfncvt.rod
  input  logic                         VFMoveD, VFMergeD,        // vfmv/vfmerge, vfmerge
  input  logic                         VScalarMoveD,             // element 0 only
  input  logic                         VReductionD,
  input  logic [2:0]                   VdEEWD, Vs2EEWD, Vs1EEWD, // log2(EEW), 000 = mask
  input  logic [2:0]                   MicroOpD,                 // register of the group, TODO: from the controller
  input  logic [P.XLEN-1:0]            VLD,
  input  logic [2:0]                   FrmD,
  input  logic [4:0]                   VdFinalD,
  input  logic                         VRegWriteD,               // TODO: cleared on all but the last reduction micro-op
  // Operands
  input  logic [P.VLEN-1:0]            VRD1D, VRD2D, VRD3D,      // vs1, vs2, old vd
  input  logic [P.VLEN-1:0]            v0D,                      // mask v0
  input  logic [P.FLEN-1:0]            FRD1D,                    // fs1 for .vf
  // Results
  output logic [P.VLEN-1:0]            VFPEUResultW,
  output logic [4:0]                   VFPEUFlagsW,
  output logic                         VFPEUVRegWriteW,
  output logic [4:0]                   VFPEUVdFinalW
);

  localparam LOGLANES = $clog2(P.VPU_FP_LANES);
  localparam LOGVLEN  = $clog2(P.VLEN);
  localparam BEATW    = $clog2(P.VLEN/16);                     // beat index width (16-bit reduction has most beats)
  localparam INTSPLIT = $clog2(P.VPU_INT_EU);                  // vieufsm divides its count by the integer lanes
  localparam FSMW     = BEATW + INTSPLIT;                      // vieufsm count width

  logic                       CaptureD;
  logic                       FsmReadyD;                       // vieufsm is ready, before the E stall
  logic                       LocalStallE, LocalStallM, LocalStallW;
  logic                       NotConsummedW;
  logic                       BubbleM;                         // E holds its beat while M moves on
  logic                       DivBusyE;                        // a lane is dividing, so E holds
  logic                       DivStartE, DivStartedE;          // the lanes start one divide per beat

  logic [FSMW-1:0]            BeatE;                           // beat of the micro-op
  logic [BEATW-1:0]           BeatM;
  logic [BEATW-1:0]           LastBeatD, LastBeatE;            // index of the last beat
  logic                       ExecutionUnitResultValidE, ExecutionUnitResultValidM;
  logic                       BeatValidE, BeatValidM;
  logic                       BeatDoneE, BeatDoneM;            // beat leaves E or M
  logic [2:0]                 BeatEEWD, BeatEEWE, BeatEEWM;    // EEW that sets the elements in a micro-op
  logic [LOGVLEN-1:0]         ElementBaseE;                    // element of lane 0 in the register
  logic [LOGVLEN-1:0]         GroupBaseE;                      // first element of the register in the group
  logic [LOGVLEN-1:0]         MaskBeatM, VdBeatM;              // beat position in vd

  // Lane controls from the decoder
  logic [2:0]                 VFUnitE, VFOpCtrlE;
  logic                       VFToIntE;
  logic [1:0]                 VFOperandOrderE;
  logic [2:0]                 FrmFinalD, FrmFinalE;            // frm or rounding mode of rtz/rod converts
  logic [1:0]                 VALUSrcAE;
  logic                       VFMoveE, VFMergeE, VScalarMoveE;
  logic                       FmaOpE, DivOpE, CvtOpE, CmpOpE, SgnOpE, ClassOpE, RecOpE;
  logic                       SignExtE;                        // signed integer source of cvt
  logic                       VReductionE, VReductionM;
  logic                       ReductionStartedE;               // an element of the reduction has been through E
  logic                       VME;

  logic [2:0]                 VdEEWE, Vs2EEWE, Vs1EEWE, VdEEWM;
  logic [2:0]                 MicroOpE, MicroOpM;
  logic [4:0]                 VdFinalE, VdFinalM, PreVdFinalW;
  logic                       VRegWriteE, VRegWriteM, PreVRegWriteW;
  logic [P.VPU_QUEUEDEPTH-1:0] ExecutionUnitOrderE, ExecutionUnitOrderM;

  logic [P.VLEN-1:0]          VRD1E, VRD2E, VRD3E, v0E;
  logic [P.FLEN-1:0]          FRD1E;
  logic [P.XLEN-1:0]          VLE;
  logic [P.VPU_FP_LANES-1:0]  ActiveE, ActiveM;                // element is in the body and unmasked

  logic [15:0]                ScalarHE;                        // fs1 as half, canonical NaN if not NaN-boxed
  logic [31:0]                ScalarSE;                        // fs1 as single, canonical NaN if not NaN-boxed
  logic [P.ELEN-1:0]          ScalarDE, ScalarE;

  logic [P.VPU_FP_BLEN-1:0]   BeatResultM;
  logic [4:0]                 LaneFlagsM [P.VPU_FP_LANES-1:0];
  logic [4:0]                 BeatFlagsM, FlagsNextM, PreFlagsW;
  logic [P.VPU_FP_LANES-1:0]  LaneDivBusyE;
  logic [P.VLEN-1:0]          OldVdM;
  logic [P.VLEN-1:0]          PlacedResultM [7:0];             // beat demuxed to its place in vd, indexed by log2(VdEEW)
  logic [P.VLEN-1:0]          PlacedEnableM [7:0];             // bits of vd the beat writes
  logic [P.VLEN-1:0]          OldResultM, ResultNextM, PreResultW;

  genvar                      i, j, e;

  // Local hazard unit
  assign NotConsummedW = ExecutionUnitResultValidW & ~ControllerWBReadyW;
  assign LocalStallW   = StallW | NotConsummedW;
  assign LocalStallM   = StallM | LocalStallW;
  assign LocalStallE   = VectorStallE | DivBusyE | LocalStallM;
  assign BubbleM       = LocalStallE & ~LocalStallM;

  // Beat sequencing ***TODO: replace vieufsm with vfpeufsm
  // vieufsm can do subword (64-b always) but vfpeufsm is one elem/lane, so vlE is scaled up
  vieufsm #(P, FSMW) vieufsm(.clk, .reset, .VectorFlushE, .LocalStallE, .NotConsummedW,
    .ControllerValidD(ControllerValidD & ~LocalStallE), .ExecutionUnitReadyD(FsmReadyD), .BeatE,
    .ExecutionUnitResultValidE, .BeatValidE, .vlE((FSMW'(LastBeatE) << INTSPLIT) | FSMW'(1)));
  assign ExecutionUnitReadyD = FsmReadyD & ~LocalStallE;
  assign CaptureD            = ControllerValidD & ExecutionUnitReadyD;
  assign BeatDoneE           = BeatValidE & ~LocalStallE;

  // The wider of vd and vs2 sets EEW width in a micro-op
  // Reduction runs serially in lane 0
  assign BeatEEWD  = (VdEEWD > Vs2EEWD & ~VReductionD) ? VdEEWD : Vs2EEWD;
  assign LastBeatD = {BEATW{1'b1}} >> (BeatEEWD - 3'd4 + (VReductionD ? 3'd0 : 3'(LOGLANES)));

  // Frm, or the static rounding mode of the rtz and rod converts
  mux2 #(3) frmmux(FrmD, VFRmD, VFStaticRmD, FrmFinalD);

  flopenrc #(P.VLEN) VRD1EReg(clk, reset, VectorFlushE, CaptureD, VRD1D, VRD1E);
  flopenrc #(P.VLEN) VRD2EReg(clk, reset, VectorFlushE, CaptureD, VRD2D, VRD2E);
  flopenrc #(P.VLEN) VRD3EReg(clk, reset, VectorFlushE, CaptureD, VRD3D, VRD3E);
  flopenrc #(P.VLEN) v0EReg  (clk, reset, VectorFlushE, CaptureD, v0D,   v0E);
  flopenrc #(P.FLEN) FRD1EReg(clk, reset, VectorFlushE, CaptureD, FRD1D, FRD1E);
  flopenrc #(P.XLEN) VLEReg  (clk, reset, VectorFlushE, CaptureD, VLD,   VLE);

  flopenrc #(40+BEATW+P.VPU_QUEUEDEPTH) ControlRegE(clk, reset, VectorFlushE, CaptureD,
    {VFUnitD, VFOpCtrlD, VFToIntD, VFOperandOrderD, FrmFinalD, VALUSrcAD, VFMoveD, VFMergeD, VScalarMoveD, VReductionD, VMD,
     VdEEWD, Vs2EEWD, Vs1EEWD, BeatEEWD, MicroOpD, VdFinalD, VRegWriteD, LastBeatD, ExecutionUnitOrderD},
    {VFUnitE, VFOpCtrlE, VFToIntE, VFOperandOrderE, FrmFinalE, VALUSrcAE, VFMoveE, VFMergeE, VScalarMoveE, VReductionE, VME,
     VdEEWE, Vs2EEWE, Vs1EEWE, BeatEEWE, MicroOpE, VdFinalE, VRegWriteE, LastBeatE, ExecutionUnitOrderE});

  assign {RecOpE, ClassOpE, SgnOpE, CmpOpE, CvtOpE, DivOpE, FmaOpE} = 7'b0000001 << VFUnitE;
  assign SignExtE = CvtOpE & VFOpCtrlE[2] & VFOpCtrlE[0];

  // .vf, fs1 is NaN-box checked against its EEW
  assign ScalarHE = &FRD1E[P.FLEN-1:16] ? FRD1E[15:0] : 16'h7E00;

  if (P.FLEN > 32) begin : sboxed
    assign ScalarSE = &FRD1E[P.FLEN-1:32] ? FRD1E[31:0] : 32'h7FC00000;
  end else begin : sonly
    assign ScalarSE = FRD1E[31:0];
  end

  if (P.ELEN == 64 & P.FLEN > 64) begin : dboxed
    assign ScalarDE = &FRD1E[P.FLEN-1:64] ? FRD1E[63:0] : 64'h7FF8000000000000;
  end else if (P.ELEN == 64 & P.FLEN == 64) begin : donly
    assign ScalarDE = FRD1E[63:0];
  end else begin : nod                                         // no 64-bit elements
    assign ScalarDE = '0;
  end

  // Vs1EEWE: 100 half, 101 single, 110 double
  mux3 #(P.ELEN) scalarmux(P.ELEN'(ScalarHE), P.ELEN'(ScalarSE), ScalarDE, Vs1EEWE[1:0], ScalarE);

  // lane i takes element[ElementBaseE + i] of each register
  assign ElementBaseE = VReductionE ? LOGVLEN'(BeatE) : LOGVLEN'(BeatE) << LOGLANES;
  assign GroupBaseE   = LOGVLEN'(MicroOpE) << (5'(LOGVLEN) - 5'(BeatEEWE));

  // Divide starts once per beat, so a lane that finishes early should not restart
  assign DivStartE = BeatValidE & ~DivStartedE;
  flopenr #(1) DivStartedEReg(clk, reset, ~LocalStallM, LocalStallE & BeatValidE, DivStartedE);

  // First active element of a reduction
  flopenr #(1) ReductionStartedEReg(clk, reset | (CaptureD & MicroOpD == '0), BeatDoneE & ActiveE[0], 1'b1, ReductionStartedE);

  // Per-lane element selection and sign extension
  // vfwcvt may widen a 8-bit element to 16 bits
  for (i = 0; i < P.VPU_FP_LANES; i++) begin : lane
    logic [LOGVLEN-1:0] ElementE, GroupElementE, Vs1ElementE;
    logic [P.ELEN-1:0]  VRD1ElemE [3:0], VRD2ElemE [3:0], VRD3ElemE [3:0]; // element at 8, 16, 32 and 64 bits
    logic [P.ELEN-1:0]  VRD1SelectedE, VRD2SelectedE, VRD3SelectedE, VSrcAE, VSrcBE;
    logic               MaskBitE, ScalarSelE;
    logic [4:0]         VfFlgM;

    assign ElementE      = ElementBaseE + LOGVLEN'(i);
    assign GroupElementE = GroupBaseE + ElementE;
    assign Vs1ElementE   = VReductionE ? '0 : ElementE;          // a reduction reads vs1[0]

    for (e = 0; e < 4; e++) begin : eew
      localparam EW = 8 << e;                                  // element width in bits
      localparam IW = $clog2(P.VLEN/EW);                       // element index width in a register
      if (EW <= P.ELEN) begin : fits
        logic [EW-1:0] Vs2RawE;
        assign VRD1ElemE[e] = P.ELEN'(VRD1E[int'(Vs1ElementE[IW-1:0])*EW +: EW]);
        assign VRD3ElemE[e] = P.ELEN'(VRD3E[int'(ElementE[IW-1:0])*EW +: EW]);
        assign Vs2RawE      = VRD2E[int'(ElementE[IW-1:0])*EW +: EW];
        assign VRD2ElemE[e] = SignExtE ? P.ELEN'(signed'(Vs2RawE)) : P.ELEN'(Vs2RawE);
      end else begin : wide
        assign VRD1ElemE[e] = '0;
        assign VRD3ElemE[e] = '0;
        assign VRD2ElemE[e] = '0;
      end
    end

    // log2(EEW) 011, 100, 101, 110 selects 8, 16, 32, 64 bits
    assign VRD1SelectedE = VRD1ElemE[Vs1EEWE[1:0] + 2'd1];
    assign VRD2SelectedE = VRD2ElemE[Vs2EEWE[1:0] + 2'd1];
    assign VRD3SelectedE = VRD3ElemE[VdEEWE[1:0] + 2'd1];

    // Active: within vl, unmasked (and in lane 0 for a reduction)
    // vfmerge is every body element
    // TODO: vstart
    assign MaskBitE   = v0E[GroupElementE];
    assign ActiveE[i] = BeatValidE & (P.XLEN'(GroupElementE) < VLE) & (1'(i == 0) | ~VReductionE) &
                        ~(VScalarMoveE & GroupElementE != '0) & (VME | VFMergeE | MaskBitE);

    // Moves copy fs1 or vs2 through lane as fsgnj(x, x) = x
    // TODO: vfmv.f.s
    assign ScalarSelE = VALUSrcAE[1] & (~VFMergeE | MaskBitE);
    mux3 #(P.ELEN) vsrcamux(VRD1SelectedE, VRD2SelectedE, ScalarE, {ScalarSelE, VFMoveE}, VSrcAE);
    mux2 #(P.ELEN) vsrcbmux(VRD2SelectedE, VSrcAE, VFMoveE, VSrcBE);

    // TODO: switch lane format to the decoder's log2(EEW)
    vflane #(P, FP) vflane(.clk, .reset, .StallM(LocalStallM), .FlushE(1'b0), .FlushM(VectorFlushM | BubbleM),
      .Vs2E(VSrcBE), .Vs1E(VSrcAE), .VdE(VRD3SelectedE),
      .Vs2EEWE(Vs2EEWE - 3'd3), .Vs1EEWE(Vs1EEWE - 3'd3), .VdEEWE(VdEEWE - 3'd3), .OperandOrderE(VFOperandOrderE),
      .FmaOpE, .DivOpE, .CvtOpE, .CmpOpE, .SgnOpE, .ClassOpE, .RecOpE, .OpCtrlE(VFOpCtrlE), .ToIntE(VFToIntE),
      .VReductionE(VReductionE & ActiveE[i]), .VReductionStartE(VReductionE & ~ReductionStartedE), .FrmE(FrmFinalE),
      .FPUActiveE(ActiveE[i]), .FDivStartE(DivStartE), .FDivBusyE(LaneDivBusyE[i]), .FDivDoneE(),
      .VfResM(BeatResultM[i*P.ELEN +: P.ELEN]), .VfFlgM(VfFlgM));

    // only active elements set flags
    assign LaneFlagsM[i] = VfFlgM & {5{ActiveM[i]}};
  end

  assign DivBusyE = |LaneDivBusyE;

  flopenrc #(1) BeatValidMReg(clk, reset, VectorFlushM, ~LocalStallM, BeatDoneE, BeatValidM);
  flopenrc #(P.VPU_FP_LANES) ActiveMReg(clk, reset, VectorFlushM, ~LocalStallM, ActiveE, ActiveM);

  flopenrc #(17+BEATW+P.VPU_QUEUEDEPTH) ControlRegM(clk, reset, VectorFlushM, ~LocalStallM,
    {VdFinalE, VRegWriteE, ExecutionUnitOrderE, BeatE[BEATW-1:0], ExecutionUnitResultValidE, VdEEWE, BeatEEWE, MicroOpE, VReductionE},
    {VdFinalM, VRegWriteM, ExecutionUnitOrderM, BeatM, ExecutionUnitResultValidM, VdEEWM, BeatEEWM, MicroOpM, VReductionM});

  flopenr #(P.VLEN) OldVdMReg(clk, reset, BeatDoneE & (BeatE == '0), VRD3E, OldVdM);

  // Assemble lane results in vd
  // Reduction result is element 0 and inactive elements keep old vd
  // TODO: adapt to sVRF and special cases instructions
  assign MaskBeatM   = (LOGVLEN'(MicroOpM) << (5'(LOGVLEN) - 5'(BeatEEWM) - 5'(LOGLANES))) + LOGVLEN'(BeatM);
  assign VdBeatM     = VReductionM ? '0 : ((VdEEWM == 3'b000) ? MaskBeatM : LOGVLEN'(BeatM));

  for (e = 0; e < 8; e++) begin : lanedemux
    localparam EW = (e == 0) ? 1 : 2**e;                     // element width in bits
    for (j = 0; j < P.VLEN; j++) begin : bitpos
      localparam LANE = (j / EW) % P.VPU_FP_LANES;
      localparam BEAT = (j / EW) / P.VPU_FP_LANES;
      if (e == 0 | (e >= 3 & EW <= P.ELEN)) begin : used
        assign PlacedResultM[e][j] = BeatResultM[LANE*P.ELEN + j%EW];
        assign PlacedEnableM[e][j] = ActiveM[LANE] & (VdBeatM == LOGVLEN'(BEAT));
      end else begin : unused
        assign PlacedResultM[e][j] = 1'b0;
        assign PlacedEnableM[e][j] = 1'b0;
      end
    end
  end

  assign BeatDoneM = BeatValidM & ~LocalStallM;

  mux2 #(P.VLEN) oldresultmux(PreResultW, OldVdM, BeatM == '0, OldResultM);
  assign ResultNextM = (PlacedResultM[VdEEWM] & PlacedEnableM[VdEEWM]) | (OldResultM & ~PlacedEnableM[VdEEWM]);
  flopenr #(P.VLEN) ResultWReg(clk, reset, BeatDoneM, ResultNextM, PreResultW);

  // fflags
  or_rows #(P.VPU_FP_LANES, 5) flagsor(LaneFlagsM, BeatFlagsM);
  assign FlagsNextM = BeatFlagsM | (PreFlagsW & {5{BeatM != '0}});
  flopenr #(5) FlagsWReg(clk, reset, BeatDoneM, FlagsNextM, PreFlagsW);

  flopenrc #(1) ResultValidWReg(clk, reset, FlushW, ~LocalStallW, BeatDoneM & ExecutionUnitResultValidM, ExecutionUnitResultValidW);

  flopenrc #(6+P.VPU_QUEUEDEPTH) ControlRegW(clk, reset, FlushW, ~LocalStallW,
    {VdFinalM, VRegWriteM, ExecutionUnitOrderM},
    {PreVdFinalW, PreVRegWriteW, ExecutionUnitOrderW});

  // AND part of the AO-mux
  assign VFPEUResultW    = ControllerWBReadyW ? PreResultW : '0;
  assign VFPEUFlagsW     = ControllerWBReadyW ? PreFlagsW : '0;
  assign VFPEUVdFinalW   = ControllerWBReadyW ? PreVdFinalW : '0;
  assign VFPEUVRegWriteW = ControllerWBReadyW ? PreVRegWriteW : '0;

endmodule
