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
  input  logic        StallD, FlushD,          // Stall, flush Decode stage
  input  logic        VectorD,                 // This instruction is a vector
  input  logic [4:0]  Vs1D, Vs2D, VdD,
  input  logic [6:0]  lmulDecodedD,
  // EU requirements
  input  logic [2:0]  VEUTypeD,                // type of EU an instruction needs (INT, FP, LSU)
  input  logic [3:0]  VOpClassD,               // execution block requirement for the EU
  input  logic [5:0]  VLSModeD,                // addressing modes for load/store
  // hand shaking controls
  output logic [P.VPU_MAX_EU-1:0] ControllerValidD,
  input  logic [P.VPU_MAX_EU-1:0] ExecutionUnitReadyD,
  // output micro vector instruction
  output logic MicroVectorD,
  output logic [4:0] Vs1FinalD, Vs2FinalD, VdFinalD
);

  logic        IncrMicroOpD;            // Next micro vector instruction when lmul > 1

  //input  logic        SelectedControllerValidD,

  // The EU selector
  // ExecutionUnitReadyD indicates which EUs can take a new vector instruction this cycle.
  // However not all EUs can take the same instructions.  They may only accept int, float, load/store,
  // fixed, or specific sub categories.  The decoder specifies the EU requirements (e.g. datapath,
  // operation class, addressing mode for load/store). The EU selector compares the requirements to the
  // capabilities of each EU.
  // Every unit supports everything today *** fix me later.

  // What each execution unit can carry out
  // *** move these to the configuration when the execution units are instantiated
  localparam logic [P.VPU_MAX_EU*3-1:0]  VEU_TYPES   = '1;   // integer, floating point, memory
  localparam logic [P.VPU_MAX_EU*16-1:0] VEU_CLASSES = '1;   // operation classes, indexed by VOpClassD
  localparam logic [P.VPU_MAX_EU*6-1:0]  VEU_MODES   = '1;   // load/store addressing modes

  logic [P.VPU_MAX_EU-1:0] SelectedD;
  logic [P.VPU_MAX_EU-1:0] EligibleD;          // units that can carry out this instruction
  logic [P.VPU_MAX_EU-1:0] AvailableD;         // and are ready for a new one
  logic                    AnyExecutionUnitReadyD;

  for (genvar i = 0; i < P.VPU_MAX_EU; i++) begin : eligibility
    assign EligibleD[i] = |(VEUTypeD & VEU_TYPES[i*3 +: 3]) & VEU_CLASSES[i*16 + VOpClassD] &
                          ((VLSModeD & ~VEU_MODES[i*6 +: 6]) == 6'b0);
  end

  // Selection mechanism is currently priority encoder.  Should be round robin. *** fix me later.
  assign AvailableD = ExecutionUnitReadyD & EligibleD;
  priorityonehot #(P.VPU_MAX_EU) SelectedEUPriority(AvailableD, SelectedD);
  assign AnyExecutionUnitReadyD = |AvailableD;

  lmulsequencer lmulsequencer(.clk, .reset, .StallD, .FlushD,
                                   .VectorD, .Vs1D, .Vs2D, .VdD, .lmulDecodedD,
                                   .AnyExecutionUnitReadyD, .Vs1FinalD, .Vs2FinalD, .VdFinalD);

  assign ControllerValidD = SelectedD & {P.VPU_MAX_EU{VectorD}}; // demux to selected EU
  assign MicroVectorD = |ControllerValidD;

endmodule
