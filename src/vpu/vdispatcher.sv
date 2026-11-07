///////////////////////////////////////////
// vdispatcher.sv
//
// Written: Rose Thompson rose.thompson@skyworksinc.com
// Created: 1 September 2026
// Modified: 1 September 2026
//
// Purpose: vector dispatcher module
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

module vdispatcher import cvw::*;  #(parameter cvw_t P) (
  input  logic        clk, reset,
  // Decode stage control signals
  input  logic        VectorStallD, VectorFlushD,          // Stall, flush Decode stage
  input  logic        VectorD,                 // This instruction is a vector
  input  logic [4:0]  Vs1D, Vs2D, VdD,
  input  logic [6:0]  lmulDecodedD,
  // EU requirements
  input  logic [2:0]  VEUTypeD,                // type of EU an instruction needs (INT, FP, LSU)
  input  logic [4:0]  VOpClassD,               // execution block requirement for EU
  input  logic [6:0]  VLSModeD,                // addressing modes for load/store
  // hand shaking controls
  output logic [P.VPU_EU-1:0] ControllerValidD,
  input  logic [P.VPU_EU-1:0] ExecutionUnitReadyD,
  output logic MicroOpNotLastD,
  // output micro vector instruction
  output logic MicroVectorD,
  output logic [4:0] Vs1FinalD, Vs2FinalD, VdFinalD
);

  logic        IncrMicroOpD;            // Next micro vector instruction when lmul > 1

  //input  logic        SelectedControllerValidD,

  // The EU selector
  // ExecutionUnitReadyD indicates which EUs can take a new vector instruction this cycle.
  // However not all EUs can take the same instructions.  They may only accept int, float, load/store, fixed,
  // or specific sub categories.
  // The decoder specifies the EU requirements (e.g. type, operation class, addressing mode for load/store).
  // EU selector compares the requirements to the capabilities of each EU.
  // For this initial version All EUs will accept all instructions. *** fix me later.

  // *** move to configuration when EU are instantiated
  // EU capabilities, Index: [EU][capability]
  localparam logic [P.VPU_EU-1:0][2:0]  VEU_TYPES   = '1;   // integer, floating point, memory
  localparam logic [P.VPU_EU-1:0][31:0] VEU_CLASSES = '1;   // operation classes, indexed by VOpClassD
  localparam logic [P.VPU_EU-1:0][6:0]  VEU_MODES   = '1;   // load/store addressing modes

  logic [P.VPU_EU-1:0] SelectedD;
  logic [P.VPU_EU-1:0] EligibleD;          // units that can carry out this instruction
  logic [P.VPU_EU-1:0] AvailableD;         // units that are ready for a new instruction
  logic                AnyExecutionUnitReadyD;
  genvar               i;

  for (i = 0; i < P.VPU_EU; i++) begin : eligibility
    assign EligibleD[i] = |(VEUTypeD & VEU_TYPES[i]) & VEU_CLASSES[i][VOpClassD] &
                          ((VLSModeD & ~VEU_MODES[i]) == 7'b0);
  end

  // Selection mechanism is currently priority encoder.  Should be round robin. *** fix me later.
  assign AvailableD = ExecutionUnitReadyD & EligibleD;
  priorityonehot #(P.VPU_EU) SelectedEUPriority(AvailableD, SelectedD);
  assign AnyExecutionUnitReadyD = |AvailableD;

  lmulsequencer lmulsequencer(.clk, .reset, .VectorStallD, .VectorFlushD,
                                   .VectorD, .Vs1D, .Vs2D, .VdD, .lmulDecodedD,
                                   .AnyExecutionUnitReadyD, .Vs1FinalD, .Vs2FinalD, .VdFinalD,
                              .MicroVectorD, .MicroOpNotLastD);

  assign ControllerValidD = SelectedD & {P.VPU_EU{MicroVectorD}}; // demux to selected EU
  //assign MicroVectorD = |ControllerValidD;

endmodule
