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
  input  logic                 clk,
  input  logic                 reset,
  // Hazards
  input  logic                 StallD, StallE, StallM, StallW,      // stall signals (from HZU)
  input  logic                 FlushD, FlushE, FlushM, FlushW,      // flush signals (from HZU)
  output logic                 VPUFrontEndBusyD,                    // Stall the decode stage (To HZU)
  // Decode stage
  input  logic [31:0]          InstrD,                             // instruction (from IFU)
  input  logic VectorD,                                            // This instruction is a vector
  // Execute state
  input  logic [P.XLEN-1:0]    ForwardedSrcAE, ForwardedSrcBE,     // Integer/FP input for convert, move (from IEU)
  output logic                 VWriteIntE,                         // writes integer register rd (to IEU)
  // Memory stage
  // TODO *** Cannot use decoded control from IEU because the there are overlapping vector instructions?
  output logic [P.VPU_LSU_BLEN-1:0]    VWriteDataM [P.VPU_LSU_EU-1:0],          // Data to be written to memory (to LSU)
  output logic [P.XLEN-1:0]            VEUAdrM     [P.VPU_LSU_EU-1:0],          // Data to be written to memory (to LSU)
  input  logic [P.VPU_LSU_BLEN-1:0]    VReadDataM  [P.VPU_LSU_EU-1:0], // Read data (from LSU)
  output logic [P.XLEN-1:0]    VIntResM,                           // Integer result for rd
  output logic                 IllegalVPUInstrD,                   // Is the instruction an illegal vector instruction (to IFU)
  // Writeback stage
  output logic [P.XLEN-1:0] VIEUFPResultW,                           // Int or FP result for X or F regs.
  // CSR state
  input  logic [1:0]        STATUS_VS,
  input  logic [P.XLEN-1:0] VTYPE_REGW,
  input  logic [P.XLEN-1:0] VL_REGW,
  // CSR updates
  output logic              WriteVLVTYPEM,                           // vset writes vl and vtype
  output logic [P.XLEN-1:0] NewVLM,
  output logic [7:0]        NewVTYPEM,
  output logic              NewVILLM,
  output logic              VRegWriteM,                              // instruction writes a vector register
  output logic              ClearVSTARTM                             // vector instruction resets vstart
);

  logic [4:0] Vs1FinalD, Vs2FinalD;               // Vector Source 1 and 2
  logic [4:0] VdFinalD;                      // Vector Destination read (overwrite)
  logic       VmD;                            // 0 = mask enabled; 1 mask disabled
  logic [5:0] Funct6D;
  logic [2:0] Funct3D;
  logic       VWriteIntD;
  logic       VWriteFPD;                      // writes to fd  *** wire to the FPU
  logic       VRegWriteD;
  logic [1:0] VALUSrcAD;
  logic       VALUSrcBD;
  logic       VALUResultD;
  logic        VsetD;                       // vsetvli, vsetivli, or vsetvl
  logic        VsetvlD;                     // vsetvl (vtype from rs2)
  logic        VsetivliD;                   // vsetivli (AVL from the uimm5)
  logic [10:0] VTYPEImmD;                   // vtype immediate

  logic [P.VPU_MAX_EU-1:0] ControllerValidD;
  logic [P.VPU_MAX_EU-1:0] ExecutionUnitReadyD;



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
  // the VPU must be delayed to ensure inorder commit.  StallE, StallM, and StallW need to post pone the progress of
  // vector instruction progress under this condiction.


  vcontroller #(P) vcontroller(.clk, .reset, .StallD, .FlushD,
                               .InstrD, .VectorD, .STATUS_VS, .VTYPE_REGW, .Vs1FinalD, .Vs2FinalD, .VdFinalD,
                               .VmD, .Funct6D, .Funct3D, .VWriteIntD, .VWriteFPD, .VRegWriteD, .VALUSrcAD, .VALUSrcBD, .VALUResultD,
                               .IllegalVPUInstrD,
                               .VsetD, .VsetvlD, .VsetivliD, .VTYPEImmD,
                               .ControllerValidD, .ExecutionUnitReadyD);

  vdatapath #(P) vdatapath(.clk, .reset, .StallD, .StallE, .StallM, .StallW, .FlushD, .FlushE, .FlushM, .FlushW,
                           .ControllerValidD, .ExecutionUnitReadyD, .Vs1FinalD, .Vs2FinalD, .VdFinalD, .VmD, .Funct6D, .Funct3D,
                           .VWriteIntD, .VRegWriteD, .VALUSrcAD, .VALUSrcBD, .VALUResultD, .IllegalVPUInstrD,
                           .ForwardedSrcAE, .ForwardedSrcBE, .VWriteDataM, .VEUAdrM, .VReadDataM, .VIEUFPResultW);

  // **** add EUs here. Remove this code
  assign ExecutionUnitReadyD = '1;

  logic VectorE, VRegWriteE;
  flopenrc #(2) VectorEReg (clk, reset, FlushE, ~StallE, {VectorD, VRegWriteD}, {VectorE, VRegWriteE});
  flopenrc #(2) VectorMReg (clk, reset, FlushM, ~StallM, {VectorE, VRegWriteE}, {ClearVSTARTM, VRegWriteM});

  logic              VsetE, VsetvlE, VsetivliE;
  logic [4:0]        Rs1E, RdE;
  logic [10:0]       VTYPEImmE;

  flopenrc #(3)  VsetEReg     (clk, reset, FlushE, ~StallE, {VsetD, VsetvlD, VsetivliD},
                                                            {VsetE, VsetvlE, VsetivliE});
  flopenrc #(5)  Rs1EReg      (clk, reset, FlushE, ~StallE, InstrD[19:15], Rs1E);
  flopenrc #(5)  RdEReg       (clk, reset, FlushE, ~StallE, InstrD[11:7],  RdE);
  flopenrc #(11) VTYPEImmEReg (clk, reset, FlushE, ~StallE, VTYPEImmD,     VTYPEImmE);

  // TODO: vset fusion and forwarding not done yet, vconfig in E/M for initial vset implementation
  vconfig #(P) vconfig(.clk, .reset, .StallM, .FlushM,
                       .VsetE, .VsetvlE, .VsetivliE, .Rs1E, .RdE, .VTYPEImmE,
                       .ForwardedSrcAE, .ForwardedSrcBE, .VL_REGW,
                       .WriteVLVTYPEM, .NewVLM, .NewVTYPEM, .NewVILLM);

  // TODO: vmv.x.s, vcpop.m and vfirst.m also write rd, only enabling rf write for vset instructions for now
  assign VWriteIntE = VsetE;
  assign VIntResM   = NewVLM;

  // TODO: vcontroller also needs to drive VPUFrontEndBusyD when all the EUs are busy
  assign VPUFrontEndBusyD = VectorD & (VsetE | WriteVLVTYPEM);  // stall vset for now

endmodule
