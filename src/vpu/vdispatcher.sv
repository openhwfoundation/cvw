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
  input  logic        StallVectorD, FlushVectorD,          // Stall, flush Decode stage
  input  logic        VectorD,                 // This instruction is a vector
  input  logic [4:0]  Vs1D, Vs2D, VdD,
  input  logic [6:0]  lmulDecodedD,
  // hand shaking controls
  output logic [P.VPU_MAX_EU-1:0] ControllerValidD,
  input  logic [P.VPU_MAX_EU-1:0] ExecutionUnitReadyD,
  output logic LMULExpansionD,
  // output micro vector instruction
  output logic MicroVectorD,
  output logic [4:0] Vs1FinalD, Vs2FinalD, VdFinalD
);

  logic        IncrMicroOpD;            // Next micro vector instruction when lmul > 1

  //input  logic        SelectedControllerValidD,

  // The EU selector
  // ExecutionUnitReadyD indications which EUs can take a new vector instruction this cycle
  // However not all EUs can take the same instructions.  They may only accept int, float, load/store, fixed,
  // or specific sub categories.
  // For this initial version All EUs will accept all instructions. *** fix me later.
  // Selection mechanism is currently priority encoder.  Should be round robin. *** fix me later.

  logic [P.VPU_MAX_EU-1:0] SelectedD;
  logic                    AnyExecutionUnitReadyD;

  priorityonehot #(P.VPU_MAX_EU) SelectedEUPriority(ExecutionUnitReadyD, SelectedD);
  //assign AnyExecutionUnitReadyD = |ExecutionUnitReadyD;
  // *** for now just first 2 EUs
  assign AnyExecutionUnitReadyD = ExecutionUnitReadyD[0] | ExecutionUnitReadyD[1];

  lmulsequencer lmulsequencer(.clk, .reset, .StallVectorD, .FlushVectorD,
                                   .VectorD, .Vs1D, .Vs2D, .VdD, .lmulDecodedD,
                                   .AnyExecutionUnitReadyD, .Vs1FinalD, .Vs2FinalD, .VdFinalD,
                              .MicroVectorD, .LMULExpansionD);

  assign ControllerValidD = SelectedD & {P.VPU_MAX_EU{MicroVectorD}}; // demux to selected EU
  //assign MicroVectorD = |ControllerValidD;

endmodule
