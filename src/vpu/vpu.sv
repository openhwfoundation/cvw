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
  input logic                       StallVectorD, StallVectorE, StallM, StallW,             // stall signals (from HZU)
  input logic                       FlushVectorD, FlushVectorE, FlushVectorM, FlushW, // flush signals (from HZU)
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
  // Memory stage
  // TODO *** Cannot use decoded control from IEU because the there are overlapping vector instructions?
  output logic [P.VPU_LSU_BLEN-1:0] VWriteDataM,                                // Data to be written to memory (to LSU)
  output logic [P.XLEN-1:0]         VEUAdrM ,                                   // Data to be written to memory (to LSU)
  input logic [P.VPU_LSU_BLEN-1:0]  VReadDataM ,                                // Read data (from LSU)
  output logic                      IllegalVPUInstrD,                           // Is the instruction an illegal fpu instruction (to IFU)
  // Writeback stage
  output logic [P.XLEN-1:0]         VIEUFPResultFinalW                          // Int or FP result for X or F regs.
);

  logic [4:0] Vs1FinalD, Vs2FinalD;               // Vector Source 1 and 2
  logic [4:0] VdFinalD;                      // Vector Destination read (overwrite)
  logic       VMD;                            // 0 = mask enabled; 1 mask disabled
  logic [5:0] Funct6D;
  logic [2:0] Funct3D;
  logic       RegWriteD;
  logic       VRegWriteD;
  logic [1:0] VALUSrcAD;
  logic       VALUSrcBD;
  logic       VALUResultSrcD;
  logic [P.VLEN-1:0] VRD1D, VRD2D, VRD3D;
  logic [P.VLEN-1:0] v0D;
  logic [P.VLEN-1:0] VResultFinalW;

  logic [P.VLEN-1:0] VIEUResultW [P.VPU_INT_EU-1:0];
  logic [P.XLEN-1:0] VIEUResultToScalarW [P.VPU_INT_EU-1:0];

  //logic       IllegalVPUInstrD;

  logic [P.VPU_MAX_EU-1:0] ControllerValidD;
  logic [P.VPU_MAX_EU-1:0] ExecutionUnitReadyD;
  logic [P.VPU_MAX_EU-1:0] ControllerWBReadyW;
  logic [P.VPU_MAX_EU-1:0] ExecutionUnitResultValidW;
  logic [P.VPU_QUEUEDEPTH-1:0] ExecutionUnitOrderW [P.VPU_MAX_EU-1:0];
  logic [P.VPU_QUEUEDEPTH-1:0] ExecutionUnitOrderD [P.VPU_MAX_EU-1:0];

  logic            VRegWriteW, RegWriteW;
  logic [4:0]      VdFinalW;
  genvar i;

  logic [P.VPU_MAX_EU-1:0] VIEURegWriteW, VIEUVRegWriteW;
  logic [4:0]              VIEUVdFinalW [P.VPU_MAX_EU-1:0];

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
  // the VPU must be delayed to ensure inorder commit.  StallVectorE, StallM, and StallW need to post pone the progress of
  // vector instruction progress under this condiction.


  vcontroller #(P) vcontroller(.clk, .reset, .StallVectorD, .FlushVectorD, .StallW,
                               .InstrD, .VectorD, .Vs1FinalD, .Vs2FinalD, .VdFinalD,
                               .VMD, .Funct6D, .Funct3D, .RegWriteD, .VRegWriteD, .VALUSrcAD, .VALUSrcBD,
                               .VALUResultSrcD, .IllegalVPUInstrD, .ControllerValidD, .ExecutionUnitReadyD,
                               .ExecutionUnitOrderD, .ExecutionUnitOrderW, .ControllerWBReadyW, .ExecutionUnitResultValidW,
                               .VPUFrontEndBusyD);



  vregfile #(P.VLEN) vregfile(clk, reset, VRegWriteW, Vs1FinalD, Vs2FinalD, VdFinalD, VdFinalW,
                              VResultFinalW, VRD1D, VRD2D, VRD3D, v0D);


  for(i = 0; i < P.VPU_INT_EU; i++) begin : vieu
    vieu #(P) vieu(.clk, .reset, .StallVectorE, .StallM, .StallW, .FlushVectorE, .FlushVectorM, .FlushW,
                   .ControllerWBReadyW(ControllerWBReadyW[i]), .ExecutionUnitResultValidW(ExecutionUnitResultValidW[i]),
                   .InstrD, .PCD, .ExecutionUnitOrderD(ExecutionUnitOrderD[i]), .ExecutionUnitOrderW(ExecutionUnitOrderW[i]),
                   .ControllerValidD(ControllerValidD[i]), .ExecutionUnitReadyD(ExecutionUnitReadyD[i]), .VMD, .Funct3D, .Funct6D,
                   .VdFinalD, .RegWriteD, .VRegWriteD, .VALUSrcAD, .VALUSrcBD, .VALUResultSrcD,
                   .VRD1D, .VRD2D, .VRD3D, .v0D, .ForwardedSrcAE, .ForwardedSrcBE, .VIEUResultToScalarW(VIEUResultToScalarW[i]),
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
  or_rows #(P.VPU_MAX_EU, 5) VdAOMux(.a(VIEUVdFinalW), .y(VdFinalW));
  //or_rows #(P.VPU_INT_EU, 5) RdAOMux(.a(VIEURegWriteW), .y(VRdFinalW));
  assign VRegWriteW = | VIEUVRegWriteW;
  assign RegWriteW = | VIEURegWriteW;


  assign VPUBackEndBusyE = (~&ExecutionUnitReadyD) & ~VPUFrontEndBusyD;

endmodule
