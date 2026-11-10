///////////////////////////////////////////
// vpu.sv
//
// Written: Rose Thompson rose.thompson@skyworksinc.com
// Modified: 8/24/2026
//
// Purpose: Vector Processing Unit
//
// Documentation: RISC-V System on Chip Design Vol. 2
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University & Skyworks Solutions Inc
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

module vpu import cvw::*;  #(parameter cvw_t P) (
  input logic                       clk,
  input logic                       reset,
  // Hazards
  input logic                       VectorStallD, VectorStallE, StallM, StallW,             // stall signals (from HZU)
  input logic                       VectorFlushD, VectorFlushE, VectorFlushM, FlushW, // flush signals (from HZU)
  input logic                       StallE, FlushE, FlushM,                     // scalar pipeline, carries vset (from HZU)
  output logic                      VPUFrontEndBusyD,                           // Stall the decode stage (To HZU)
  output logic                      VPUBackEndBusyE,


  // TODO ***
  // Add CSRs between priv and VPU

  // Decode stage
  input logic [31:0]                InstrD,                                     // instruction (from IFU)
  input logic [P.XLEN-1:0]          PCD,                                        // Decode stage instruction address

  input logic                       VectorD,                                    // This instruction is a vector
  // Execute state
  input logic [P.XLEN-1:0]          ForwardedSrcAE, ForwardedSrcBE,             // Integer/FP input for convert, move (from IEU)
  input logic [P.XLEN-1:0]          R1D, R2D,                                   // Scalar rs1/rs2 read in Decode
  output logic                      VWriteIntE,                                 // vset writes vl to rd (to IEU)
  // Memory stage
  // TODO *** Cannot use decoded control from IEU because the there are overlapping vector instructions?
  output logic [P.VPU_LSU_BLEN-1:0] VWriteDataM,                                // Data to be written to memory (to LSU)
  output logic [P.XLEN-1:0]         VEUAdrM ,                                   // Data to be written to memory (to LSU)
  input logic [P.VPU_LSU_BLEN-1:0]  VReadDataM ,                                // Read data (from LSU)
  output logic [P.XLEN-1:0]         VIntResM,                                   // vl for rd (to IEU)
  output logic                      IllegalVPUInstrD,                           // Is the instruction an illegal fpu instruction (to IFU)
  // Writeback stage
  output logic [P.XLEN-1:0]         VIEUFPResultFinalW,                         // Int or FP result for X or F regs
  // CSR state
  input logic [1:0]                 STATUS_VS,                                  // vector (VS) field in status register
  input logic [P.XLEN-1:0]          VTYPE_REGW,                                 // vtype
  input logic [P.XLEN-1:0]          VL_REGW,                                    // vl
  // CSR updates from vset
  output logic                      WriteVLVTYPEM,                              // vset writes vl and vtype
  output logic [P.XLEN-1:0]         NewVLM,
  output logic [7:0]                NewVTYPEM,
  output logic                      NewVILLM,
  output logic                      ClearVSTARTM                                // vector instruction resets vstart
);

  // vector floating point datapath parameters FP extracted from P
  /* verilator lint_off UNUSEDPARAM */ // FP is unused until the vector floating point unit is instantiated
  `include "vfpu-parameter-defs.vh"
  /* verilator lint_on UNUSEDPARAM */

  logic [4:0] Vs1FinalD, Vs2FinalD;               // Vector Source 1 and 2
  logic [4:0] VdFinalD;                      // Vector Destination read (overwrite)
  logic       VMD;                            // 0 = mask enabled; 1 mask disabled
  logic [5:0] Funct6D;
  logic [2:0] Funct3D;
  logic       VWriteIntD;                     // writes integer register
  logic       VWriteFPD;                      // writes floating-point register *** wire to FPU
  logic       VRegWriteD;
  logic [1:0] VALUSrcAD;
  logic       VALUSrcBD;
  logic       VALUResultSrcD;
  logic [2:0] VALUSelectD;
  logic       VSubD;
  logic [1:0] VLaneSelectD;                   // vlane result select
  logic [1:0] VShiftSelectD;                  // vlane shift: 00 sll, 10 srl, 11 sra
  logic        VsetD;                         // vsetvli, vsetivli, or vsetvl
  logic        VsetvlD;                       // vsetvl (vtype from rs2)
  logic        VsetivliD;                     // vsetivli (AVL from the uimm5)
  logic [10:0] VTYPEImmD;                     // vtype immediate
  logic [P.XLEN-1:0] VTYPED;                  // vtype seen by Decode, forwarded from an older vset
  logic [P.XLEN-1:0] VLD;                     // vl seen by Decode, forwarded from an older vset  *** not used yet
  logic [P.VLEN-1:0] VRD1D, VRD2D, VRD3D;
  logic [P.VLEN-1:0] v0D;
  logic [P.VLEN-1:0] VResultFinalW;

  logic [P.VLEN-1:0] VIEUResultW [P.VPU_INT_EU-1:0];
  logic [P.XLEN-1:0] VIEUResultToScalarW [P.VPU_INT_EU-1:0];

  //logic       IllegalVPUInstrD;

  logic [P.VPU_EU-1:0] ControllerValidD;
  logic [P.VPU_EU-1:0] ExecutionUnitReadyD;
  logic [P.VPU_EU-1:0] ControllerWBReadyW;
  logic [P.VPU_EU-1:0] ExecutionUnitResultValidW;
  logic [P.VPU_QUEUEDEPTH-1:0] ExecutionUnitOrderW [P.VPU_EU-1:0];
  logic [P.VPU_QUEUEDEPTH-1:0] ExecutionUnitOrderD [P.VPU_EU-1:0];

  logic            VRegWriteW, RegWriteW;
  logic [4:0]      VdFinalW;
  genvar i;

  logic [P.VPU_EU-1:0] VIEURegWriteW, VIEUVRegWriteW;
  logic [4:0]              VIEUVdFinalW [P.VPU_EU-1:0];

  // divide into control and data path

  // decoder inputs
  // InstrD and VectorD
  // outputs the controls and a valid for this specific vector instruction

  // some of the comments shall move to the hazard unit when implemented.
  // the controller directs this vector instruction to a vector Execution Unit (EU) and reads the VRF.
  // If all the EUs are currently operating on an instruction and cannot take a new instruction, then
  // the controller waits by asserting VPUFrontEndBusyD.
  // VPUFrontEndBusyD is used by the hazard unit to stall the front end.
  // When transitioning from scalar to vector instructions, if the scalar takes a long time such as div or load miss,
  // the VPU must be delayed to ensure inorder commit.  VectorStallE, StallM, and StallW need to post pone the progress of
  // vector instruction progress under this condiction.


  vcontroller #(P) vcontroller(.clk, .reset, .VectorStallD, .VectorFlushD, .StallW,
                               .InstrD, .VectorD, .STATUS_VS, .VTYPED, .Vs1FinalD, .Vs2FinalD, .VdFinalD,
                               .VMD, .Funct6D, .Funct3D, .VWriteIntD, .VWriteFPD, .VRegWriteD, .VALUSrcAD, .VALUSrcBD,
                               .VALUResultSrcD, .VALUSelectD, .VSubD, .VLaneSelectD, .VShiftSelectD,
                               .IllegalVPUInstrD, .VsetD, .VsetvlD, .VsetivliD, .VTYPEImmD,
                               .ControllerValidD, .ExecutionUnitReadyD,
                               .ExecutionUnitOrderD, .ExecutionUnitOrderW, .ControllerWBReadyW, .ExecutionUnitResultValidW,
                               .VPUFrontEndBusyD);



  vregfile #(P.VLEN) vregfile(clk, reset, VRegWriteW, Vs1FinalD, Vs2FinalD, VdFinalD, VdFinalW,
                              VResultFinalW, VRD1D, VRD2D, VRD3D, v0D);


  for(i = 0; i < P.VPU_INT_EU; i++) begin : vieu
    vieu #(P) vieu(.clk, .reset, .VectorStallE, .StallM, .StallW, .VectorFlushE, .VectorFlushM, .FlushW,
                   .ControllerWBReadyW(ControllerWBReadyW[i]), .ExecutionUnitResultValidW(ExecutionUnitResultValidW[i]),
                   .InstrD, .PCD, .ExecutionUnitOrderD(ExecutionUnitOrderD[i]), .ExecutionUnitOrderW(ExecutionUnitOrderW[i]),
                   .ControllerValidD(ControllerValidD[i]), .ExecutionUnitReadyD(ExecutionUnitReadyD[i]), .VMD, .Funct3D, .Funct6D,
                   .VdFinalD, .RegWriteD(VWriteIntD), .VRegWriteD, .VALUSrcAD, .VALUResultSrcD, .VALUSelectD, .VSubD, .VLaneSelectD,
                   .VShiftSelectD,
                   .VRD1D, .VRD2D, .VRD3D, .v0D, .R1D, .VIEUResultToScalarW(VIEUResultToScalarW[i]),
                   .VIEUResultW(VIEUResultW[i]), .VIEURegWriteW(VIEURegWriteW[i]), .VIEUVRegWriteW(VIEUVRegWriteW[i]),
                   .VIEUVdFinalW(VIEUVdFinalW[i]));
  end

  for(i = 0; i < P.VPU_LSU_EU; i++) begin : vlsuif
    // *** add LSU IF
    assign ExecutionUnitReadyD[i+P.VPU_INT_EU] = '1;
    assign VWriteDataM = '0;
    assign VEUAdrM = '0;
    assign ExecutionUnitResultValidW[i+P.VPU_INT_EU] = '0;


    //assign VIEUResultToScalarW[i+P.VPU_INT_EU] = '0;
    //assign VIEUResultW[i+P.VPU_INT_EU] = '0;
    assign VIEURegWriteW[i+P.VPU_INT_EU] = '0;
    assign VIEUVRegWriteW[i+P.VPU_INT_EU] = '0;
    assign VIEUVdFinalW[i+P.VPU_INT_EU] =  '0;
  end

  for(i = 0; i < P.VPU_FP_EU; i++) begin : vfpeu
    // *** add FPU
    //vfpeu #(P) vfpeu
    assign ExecutionUnitReadyD[i+P.VPU_INT_EU+P.VPU_LSU_EU] = '1;
    assign ExecutionUnitResultValidW[i+P.VPU_INT_EU+P.VPU_LSU_EU] = '0;

    //assign VIEUResultToScalarW[i+P.VPU_INT_EU+P.VPU_LSU_EU] = '0;
    //assign VIEUResultW[i+P.VPU_INT_EU+P.VPU_LSU_EU] = '0;
    assign VIEURegWriteW[i+P.VPU_INT_EU+P.VPU_LSU_EU] = '0;
    assign VIEUVRegWriteW[i+P.VPU_INT_EU+P.VPU_LSU_EU] = '0;
    assign VIEUVdFinalW[i+P.VPU_INT_EU+P.VPU_LSU_EU] =  '0;

  end



  // the controller must select the correct EU to write back into the VRF so that instructions commit inorder.

  or_rows #(P.VPU_INT_EU, P.VLEN) VEUResultAOMux(.a(VIEUResultW), .y(VResultFinalW));
  or_rows #(P.VPU_INT_EU, P.XLEN) VIEUFPResultAOMux(.a(VIEUResultToScalarW), .y(VIEUFPResultFinalW));
  or_rows #(P.VPU_EU, 5) VdAOMux(.a(VIEUVdFinalW), .y(VdFinalW));
  //or_rows #(P.VPU_INT_EU, 5) RdAOMux(.a(VIEURegWriteW), .y(VRdFinalW));
  assign VRegWriteW = | VIEUVRegWriteW;
  assign RegWriteW = | VIEURegWriteW;


  assign VPUBackEndBusyE = (~&ExecutionUnitReadyD) & ~VPUFrontEndBusyD;

  // vset runs in the scalar pipeline; vconfig computes vl and vtype in Execute and forwards vtype to Decode
  // vmv.x.s, vcpop.m, vfirst.m write rd: once the VPU has drained, the result is computed in Decode and carried down the
  // scalar pipeline to rd like vl from vset.  vmv.x.s reads element 0 of vs2 and sign-extends it from SEW; SEW > XLEN
  // keeps the low XLEN bits.  *** vcpop.m and vfirst.m need their own result; only vmv.x.s is computed here
  logic              VUnaryWriteIntD, VUnaryWriteIntE, VUnaryWriteIntM, VsetWriteIntE;
  logic [63:0]       Element0D;
  logic [P.XLEN-1:0] VUnaryResE, VUnaryResM;

  assign VUnaryWriteIntD = VWriteIntD & ~VsetD & ~IllegalVPUInstrD;

  always_comb
    case (VTYPED[4:3])
      2'b00:   Element0D = {{56{VRD2D[7]}},  VRD2D[7:0]};
      2'b01:   Element0D = {{48{VRD2D[15]}}, VRD2D[15:0]};
      2'b10:   Element0D = {{32{VRD2D[31]}}, VRD2D[31:0]};
      default: Element0D = 64'(signed'(VRD2D[P.ELEN-1:0]));
    endcase

  flopenrc #(1+P.XLEN) VUnaryEReg(clk, reset, FlushE, ~StallE, {VUnaryWriteIntD, Element0D[P.XLEN-1:0]}, {VUnaryWriteIntE, VUnaryResE});
  flopenrc #(1+P.XLEN) VUnaryMReg(clk, reset, FlushM, ~StallM, {VUnaryWriteIntE, VUnaryResE},             {VUnaryWriteIntM, VUnaryResM});

  vconfig #(P) vconfig(.clk, .reset, .StallE, .FlushE, .StallM, .FlushM,
                       .VsetD, .VsetvlD, .VsetivliD, .VTYPEImmD, .Rs1D(InstrD[19:15]), .RdD(InstrD[11:7]), .VTYPED, .VLD,
                       .ForwardedSrcAE, .ForwardedSrcBE, .VWriteIntE(VsetWriteIntE), .VTYPE_REGW, .VL_REGW,
                       .WriteVLVTYPEM, .NewVLM, .NewVTYPEM, .NewVILLM);

  assign VWriteIntE = VsetWriteIntE | VUnaryWriteIntE;
  mux2 #(P.XLEN) vintresmux(NewVLM, VUnaryResM, VUnaryWriteIntM, VIntResM);

  // TODO: every vector instruction resets vstart; only vset, which reaches the scalar Memory stage, does so for now
  assign ClearVSTARTM = WriteVLVTYPEM;

endmodule
