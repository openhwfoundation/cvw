///////////////////////////////////////////
// vieu.sv
//
// Written: Rose Thompson rose.thompson@skyworksinc.com
// Created: 2 September 2026
// Modified: 2 September 2026
//
// Purpose: vector integer execution unit
//
// Documentation: RISC-V System on Chip Design Volume 2
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University & Skyworks Solutions Inc.
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

module vieu import cvw::*;  #(parameter cvw_t P)
  (
  input logic                         clk,
  input logic                         reset,
  // Hazards
  input logic                         VectorStallE, StallM, StallW,         // stall signals (from HZU)
  input logic                         VectorFlushE, VectorFlushM, FlushW,   // flush signals (from HZU)
  // pass PC and the instruction through the specific execution unit. The VPU executes multiple
  // instructions currently so it cannot use the scalar pipeline to track the instruction progress.
  input logic [31:0]                  InstrD,
  input logic [P.XLEN-1:0]            PCD,                            // Decode stage instruction address
  // flow control
  input logic                         ControllerValidD,
  output logic                        ExecutionUnitReadyD,
  output logic                        ExecutionUnitResultValidW,
  output logic [P.VPU_QUEUEDEPTH-1:0] ExecutionUnitOrderW,
  input logic [P.VPU_QUEUEDEPTH-1:0]  ExecutionUnitOrderD,
   // control from the controller
  input logic                         VMD,                            // 0 = mask enabled, 1 mask disabled
  input logic [5:0]                   Funct6D,
  input logic [2:0]                   Funct3D,
  input logic [4:0]                   VdFinalD,
  input logic                         RegWriteD,
  input logic                         VRegWriteD,
  input logic [1:0]                   VALUSrcAD,
  input logic                         VALUResultSrcD,
  input logic [2:0]                   VSEWD,                          // vtype.vsew: 000 e8, 001 e16, 010 e32, 011 e64
  input logic [2:0]                   VALUSelectD,
  input logic                         VSubD,
  input logic                         VRSubD,
  input logic [2:0]                   VLaneSelectD,                   // vlane result: 00 valu, 01 vmul, 10 move, 11 shift
  input logic [1:0]                   VShiftSelectD,                  // vlane shift: 00 sll, 10 srl, 11 sra
  input logic [1:0]                   VMulSelectD,                    // vmul result: 00 vmul, 01 vmulh, 10 vwmul
  input logic [1:0]                   VMulSignD,                      // vmul signedness: {vs1 signed, vs2 signed}
  input logic [$clog2(P.VLEN):0]      VLD,
   // datapath from VRF banks, bank i holds beat i of reg read i cycles after dispatch
  // *** banks are shared by int and float EUs and vieu should take one bank per beat while VPU_BLEN = VPU_INT_BLEN
  input logic [P.VPU_BLEN-1:0]        VRD1D [P.VPU_BANKS-1:0],
  input logic [P.VPU_BLEN-1:0]        VRD2D [P.VPU_BANKS-1:0],
  input logic [P.VPU_BLEN-1:0]        VRD3D [P.VPU_BANKS-1:0],        // vd as an operand (vmacc, vslideup)
  input logic [P.VLEN-1:0]            v0D,                            // v0 as an operand (vmerge, vadc), whole register
   //
  // from/to the scalar core
  input logic [P.XLEN-1:0]            R1D,                            // Scalar rs1 read in Decode (from IEU)
  output logic [P.XLEN-1:0]           VIEUResultToScalarW,            // Int or FP result for
  output logic [P.VPU_INT_BLEN-1:0]   VIEUResultW,                    // result beat (to sVRF)
  // control output
  output logic                        VIEURegWriteW, VIEUVRegWriteW,
  output logic                        VIEUBeatValidW,                 // result beat is valid
  output logic [P.VPU_INT_BLEN/8-1:0] VIEUByteMaskW,
  output logic [$clog2((P.VLEN/P.ELEN) + 1)-1:0] VIEUBeatW,           // beat number of result
  output logic [4:0]                  VIEUVdFinalW
);
  // might have to bring back notconsummedW and the localStall back when later making svrf entries less than EU number

  localparam BEATBITLEN = $clog2((P.VLEN/P.ELEN) + 1);
  localparam BEATSELBITS = (P.VPU_INT_MAX_BEATS > 1) ? $clog2(P.VPU_INT_MAX_BEATS) : 1;  // selects a beat of the register
  //localparam VLBITLEN = $clog2(P.VLEN);
  localparam XLENTOINTLANES = P.VPU_INT_BLEN / P.XLEN;

  logic [5:0] Funct6E;
  logic [2:0] Funct3E;
  logic       RegWriteE;
  logic       VRegWriteE;
  logic [1:0] VALUSrcAE;
  logic       VALUResultSrcE;
  logic [2:0] VSEWE;
  logic [2:0] VALUSelectE;
  logic       VSubE;
  logic       VRSubE;
  logic [2:0] VLaneSelectE;
  logic [1:0] VShiftSelectE;
  logic [1:0] VMulSelectE;
  logic [1:0] VMulSignE;
  logic [$clog2(P.VLEN):0] VLE;
  logic [P.VPU_INT_BLEN-1:0] VSlideResultE, VEUResultE;
  logic [BEATBITLEN-1:0] VSlideBeatE, VdBeatE;  // vd beat the result goes to
  logic [P.VPU_INT_BLEN/8-1:0] VSlideByteMaskE, ByteMaskE, ByteMaskM;


  logic       RegWriteM;
  logic       VRegWriteM;
  logic       VALUResultSrcM;

  logic       VALUResultSrcW;

  logic [BEATBITLEN-1:0] BeatE, BeatM;
  logic                  CaptureD;
  logic                  ExecutionUnitResultValidE, ExecutionUnitResultValidM;
  logic [P.VPU_QUEUEDEPTH-1:0] ExecutionUnitOrderE, ExecutionUnitOrderM;

  logic [P.XLEN-1:0]         R1E;                 // scalar rs1 captured with the micro-op
  logic [BEATSELBITS-1:0]    ReadBankD;           // bank holding the beat Execute computes next
  logic [P.VPU_INT_BLEN-1:0] VRD1E, VRD2E, VRD3E; // operand beat in Execute
  logic [P.VLEN-1:0]         v0E;                 // v0 read once per micro-op
  logic                      BeatValidE, BeatValidM;

  logic [P.VPU_INT_BLEN-1:0] VImmE;

  logic [P.VPU_INT_BLEN-1:0] VSrcAE, VSrcBE, VSrcCE;
  logic [P.VPU_INT_BLEN-1:0] VALUResultE, VALUResultM;
  logic [P.VPU_INT_BLEN-1:0] VLaneResultM, VProductM;   // registered lane result and vmul result
  logic                      VMulE, VMulM;              // the result comes from vmul

  logic [4:0]                VdFinalE, VdFinalM;


  logic [31:0]               InstrE, InstrM, InstrW;
  logic [P.XLEN-1:0]         PCE, PCM, PCW;


  logic                      ResultValidW, BeatValidW;



  // simm5 from the vs1 field, sign-extended to ELEN; shifts (vsll, vsrl, vsra, vssrl, vssra) take a uimm5
  // *** make SEW-dependent when lanes support SEW < ELEN
  // *** vslideup/vslidedown/vrgather.vi need zero-extended uimm5
  logic VUImmE;
  assign VUImmE = (VLaneSelectE == 3'b011);
  assign VImmE = {P.VPU_INT_LANES{{(P.ELEN-5){InstrE[19] & ~VUImmE}}, InstrE[19:15]}};

  vieufsm #(P, BEATBITLEN) vieufsm(.clk, .reset, .VectorFlushE, .LocalStallE(VectorStallE),
                       .ControllerValidD, .ExecutionUnitReadyD, .CaptureD, .ExtraBeatE(VLaneSelectE[2] & Funct6E[0]), .BeatE, .ExecutionUnitResultValidE, .BeatValidE);

  flopenrc #(P.XLEN) R1EReg  (clk, reset, VectorFlushE, ~VectorStallE & CaptureD, R1D,   R1E);
  flopenrc #($clog2(P.VLEN)+1) VEReg(clk, reset, VectorFlushE, ~VectorStallE & CaptureD, VLD, VLE);
  // *** select the mask bits of the beat for vmerge / vadc / vmadc
  flopenrc #(P.VLEN) v0EReg  (clk, reset, VectorFlushE, ~VectorStallE & CaptureD, v0D,   v0E);

  // take one beat per cycle from the stream
  // not cleared by flush
  // stream holds while Execute stalls
  assign ReadBankD = CaptureD ? '0 : BeatE[BEATSELBITS-1:0] + 1'b1;
  flopenr #(P.VPU_INT_BLEN) VRD1EReg(clk, reset, ~VectorStallE, VRD1D[ReadBankD], VRD1E);
  flopenr #(P.VPU_INT_BLEN) VRD2EReg(clk, reset, ~VectorStallE, VRD2D[ReadBankD], VRD2E);
  flopenr #(P.VPU_INT_BLEN) VRD3EReg(clk, reset, ~VectorStallE, VRD3D[ReadBankD], VRD3E);

  // unlike the integer controller and datapath, the controller must be pipelined inside the vieu, because the
  // controll is routed to different EUs.

  flopenrc #(36+P.VPU_QUEUEDEPTH) contrlregE
    (clk, reset, VectorFlushE, ~VectorStallE & CaptureD,
     {ExecutionUnitOrderD, VdFinalD, Funct6D, Funct3D, RegWriteD, VRegWriteD, VALUSrcAD, VALUResultSrcD,
      VSEWD, VALUSelectD, VSubD, VRSubD, VLaneSelectD, VShiftSelectD, VMulSelectD, VMulSignD},
     {ExecutionUnitOrderE, VdFinalE, Funct6E, Funct3E, RegWriteE, VRegWriteE, VALUSrcAE, VALUResultSrcE,
      VSEWE, VALUSelectE, VSubE, VRSubE, VLaneSelectE, VShiftSelectE, VMulSelectE, VMulSignE});

  flopenrc #(P.XLEN) pcereg(clk, reset, VectorFlushE, ~VectorStallE & CaptureD, PCD, PCE);
  flopenrc #(32) instrereg(clk, reset, VectorFlushE, ~VectorStallE & CaptureD, InstrD, InstrE);

  mux3 #(P.VPU_INT_BLEN) vscramux(VRD1E, VImmE, {XLENTOINTLANES{R1E}}, VALUSrcAE, VSrcAE);

  assign VSrcBE = VRD2E;
  assign VSrcCE = VRD3E; // *** to the lanes for vmacc

  vlane #(P) vlane[P.VPU_INT_LANES-1:0] (.clk, .reset, .StallM, .FlushM(VectorFlushM), .SrcA(VSrcAE), .SrcB(VSrcBE), .VSEWE, .VALUSelectE, .VSubE, .VRSubE,
                                         .VLaneSelectE(VLaneSelectE[1:0]), .VShiftSelectE, .VMulSelectE, .VMulSignE, .LaneResultE(VALUResultE), .ProductM(VProductM));
  vslide #(P) vslide(.clk, .reset, .NextBeat(BeatValidE & ~VectorStallE), .VSrcB(VSrcBE), .SrcA(R1E), .Imm(InstrE[19:15]), .Funct3(Funct3E), .Down(Funct6E[0]),
                                          .SEW(VSEWE[1:0]), .Vl(VLE), .Beat(BeatE), .VSlideResult(VSlideResultE), .VSlideBeat(VSlideBeatE), .VSlideByteMask(VSlideByteMaskE));
  mux2 #(P.VPU_INT_BLEN) veuresultumux(VALUResultE, VSlideResultE, VLaneSelectE[2], VEUResultE);
  mux2 #(BEATBITLEN) vdbeatmux(BeatE, VSlideBeatE, VLaneSelectE[2], VdBeatE);
  mux2 #(P.VPU_INT_BLEN/8) bytemaskmux('1, VSlideByteMaskE, VLaneSelectE[2], ByteMaskE);

  flopenrc #(P.VPU_INT_BLEN) VALUResultMReg(clk, reset, VectorFlushM, ~StallM, VEUResultE, VLaneResultM); // *** may need an enable
  flopenrc #(P.VPU_INT_BLEN/8) ByteMaskMReg(clk, reset, VectorFlushM, ~StallM, ByteMaskE, ByteMaskM);

  assign VMulE = (VLaneSelectE == 3'b001);

  flopenrc #(11+BEATBITLEN+P.VPU_QUEUEDEPTH) contrlregM
    (clk, reset, VectorFlushM, ~StallM,
     {VdFinalE, RegWriteE, VRegWriteE, VALUResultSrcE, VdBeatE, ExecutionUnitResultValidE, BeatValidE, ExecutionUnitOrderE, VMulE},
     {VdFinalM, RegWriteM, VRegWriteM, VALUResultSrcM, BeatM, ExecutionUnitResultValidM, BeatValidM, ExecutionUnitOrderM, VMulM});

  assign VALUResultM = VMulM ? VProductM : VLaneResultM;

  flopenrc #(P.XLEN) pcmreg(clk, reset, VectorFlushM, ~StallM, PCE, PCM);
  flopenrc #(32) instrmreg(clk, reset, VectorFlushM, ~StallM, InstrE, InstrM);

  flopenrc #(P.VPU_INT_BLEN) VALUResultWReg(clk, reset, FlushW, ~StallW, VALUResultM, VIEUResultW);
  flopenrc #(P.VPU_INT_BLEN/8) ByteMaskWReg(clk, reset, FlushW, ~StallW, ByteMaskM, VIEUByteMaskW);

  flopenrc #(P.XLEN) pcwreg(clk, reset, FlushW, ~StallW, PCM, PCW);
  flopenrc #(32) instrwreg(clk, reset, FlushW, ~StallW, InstrM, InstrW);

  flopenrc #(10+BEATBITLEN+P.VPU_QUEUEDEPTH) contrlregW
    (clk, reset, FlushW, ~StallW,
     {VdFinalM, RegWriteM, VRegWriteM, VALUResultSrcM, BeatM, ExecutionUnitResultValidM, BeatValidM, ExecutionUnitOrderM},
     {VIEUVdFinalW, VIEURegWriteW, VIEUVRegWriteW, VALUResultSrcW, VIEUBeatW, ResultValidW, BeatValidW, ExecutionUnitOrderW});

  // write sVRF once: a stalled beat must not write again after its entry commits
  assign VIEUBeatValidW = BeatValidW & ~StallW;
  assign ExecutionUnitResultValidW = ResultValidW & ~StallW;

  assign VIEUResultToScalarW = '0;    // *** fill with the correct result

endmodule
