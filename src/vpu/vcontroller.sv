///////////////////////////////////////////
// vcontroller.sv
//
// Written: Rose Thompson rose.thompson@skyworksinc.com
// Created: 31 August 2026
// Modified: 31 August 2026
//
// Purpose: vector controller module
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

module vcontroller import cvw::*;  #(parameter cvw_t P) (
  input  logic        clk, reset,
  // Decode stage control signals
  input  logic        StallD, FlushD,          // Stall, flush Decode stage
  input  logic [31:0] InstrD,                  // Instruction in Decode stage
  input  logic  VectorD,                       // This instruction is a vector
  // CSR state
  input  logic [1:0] STATUS_VS,                // vector context status
  input  logic [P.XLEN-1:0] VTYPE_REGW,        // vtype (vill)

  // Decode stage outputs
  output logic [4:0] Vs1FinalD, Vs2FinalD,               // Vector Source 1 and 2
  output logic [4:0] VdFinalD,                      // Vector Destination read (overwrite)
  output logic VmD,                            // 0 = mask enabled, 1 mask disabled
  output logic [5:0] Funct6D,
  output logic [2:0] Funct3D,
  output logic VWriteIntD,
  output logic VWriteFPD,
  output logic VRegWriteD,
  output logic [1:0] VALUSrcAD,
  output logic VALUSrcBD,
  output logic VALUResultD,
  output logic IllegalVPUInstrD,
  // vset controls, sent to vconfig
  output logic        VsetD,                 // vsetvli, vsetivli, or vsetvl
  output logic        VsetvlD,               // vsetvl: vtype comes from rs2 rather than an immediate
  output logic        VsetivliD,             // vsetivli: AVL is the uimm5 in the rs1 field
  output logic [10:0] VTYPEImmD,             // zero-extended vtype immediate for vsetvli / vsetivli
  // hand shaking controls
  output logic [P.VPU_MAX_EU-1:0] ControllerValidD,
  input  logic [P.VPU_MAX_EU-1:0] ExecutionUnitReadyD
);

  logic        MicroVectorD;
  logic [4:0]  Vs1D, Vs2D;               // Vector Source 1 and 2
  logic [4:0]  VdD;                      // Vector Destination read (overwrite)
  logic [6:0]  lmulDecodedD;

  logic [2:0]  VEUTypeD;                  // type of EU an instruction needs (INT, FP, LSU)
  logic [3:0]  VOpClassD;                 // execution block requirement for the EU
  logic [5:0]  VLSModeD;                  // addressing modes for load/store
  logic        VReductionD;               // instr is a reduction op
  logic [1:0]  VdEEWD, Vs1EEWD, Vs2EEWD;  // effective element width of Vd/Vs1/Vs2
  logic [2:0]  VLSEEWD;                   // effective element width of load/store
  //logic [2:0]  lmulD;                  // *** should be set by vset* instruction

  assign lmulDecodedD = 7'b0001_000; // m1


  vdecoder #(P) vdecoder(.clk, .reset, .StallD, .FlushD,
                         .InstrD, .STATUS_VS, .VTYPE_REGW, .Vs1D, .Vs2D, .VdD, .VmD,
                         .Funct6D, .Funct3D, .VWriteIntD, .VWriteFPD, .VRegWriteD,
                         .VEUTypeD, .VOpClassD, .VLSModeD, .VReductionD,
                         .VdEEWD, .Vs1EEWD, .Vs2EEWD, .VLSEEWD,
                         .VALUSrcAD, .VALUSrcBD, .VALUResultD, .IllegalVPUInstrD,
                         .VsetD, .VsetvlD, .VsetivliD, .VTYPEImmD);

  vdispatcher #(P) vdispatcher(.clk, .reset, .StallD, .FlushD,
                               .VectorD, .Vs1D, .Vs2D, .VdD, .VEUTypeD, .VOpClassD, .VLSModeD,
                               .ControllerValidD, .ExecutionUnitReadyD,
                               .MicroVectorD, .Vs1FinalD, .Vs2FinalD, .VdFinalD, .lmulDecodedD);

endmodule
