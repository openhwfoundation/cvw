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
  input logic                         clk, reset,
  // Decode stage control signals
  input logic                         StallVectorD, FlushVectorD, // Stall, flush Decode stage
  input logic                         StallW,
  input logic [31:0]                  InstrD,                     // Instruction in Decode stage
  input logic                         VectorD,                    // This instruction is a vector

  // Decode stage outputs
  output logic [4:0]                  Vs1FinalD, Vs2FinalD,       // Vector Source 1 and 2
  output logic [4:0]                  VdFinalD,                   // Vector Destination read (overwrite)
  output logic                        VMD,                        // 0 = mask enabled, 1 mask disabled
  output logic [5:0]                  Funct6D,
  output logic [2:0]                  Funct3D,
  output logic                        RegWriteD,
  output logic                        VRegWriteD,
  output logic [1:0]                  VALUSrcAD,
  output logic                        VALUSrcBD,
  output logic                        VALUResultSrcD,
  output logic                        IllegalVPUInstrD,
  // hand shaking controls
  output logic [P.VPU_MAX_EU-1:0]     ControllerValidD,
  input logic [P.VPU_MAX_EU-1:0]      ExecutionUnitReadyD,
  output logic [P.VPU_QUEUEDEPTH-1:0] ExecutionUnitOrderD [P.VPU_MAX_EU-1:0],
  input logic [P.VPU_QUEUEDEPTH-1:0]  ExecutionUnitOrderW [P.VPU_MAX_EU-1:0],
  input logic [P.VPU_MAX_EU-1:0]      ExecutionUnitResultValidW,
  output logic [P.VPU_MAX_EU-1:0]     ControllerWBReadyW,
  output logic                        VPUFrontEndBusyD
);

  logic        MicroVectorD;
  logic [4:0]  Vs1D, Vs2D;               // Vector Source 1 and 2
  logic [4:0]  VdD;                      // Vector Destination read (overwrite)
  logic [6:0]  lmulDecodedD;
  logic        LMULExpansionD;

  //logic [2:0]  lmulD;                  // *** should be set by vset* instruction

  assign lmulDecodedD = 7'b0100_000; // m4


  vdecoder #(P) vdecoder(.clk, .reset, .StallVectorD, .FlushVectorD,
                         .InstrD, .Vs1D, .Vs2D, .VdD, .VMD,
                         .Funct6D, .Funct3D, .RegWriteD, .VRegWriteD,
                         .VALUResultSrcD, .VALUSrcAD, .VALUSrcBD, .IllegalVPUInstrD);

  vdispatcher #(P) vdispatcher(.clk, .reset, .StallVectorD, .FlushVectorD,
                               .VectorD, .Vs1D, .Vs2D, .VdD, .ControllerValidD, .ExecutionUnitReadyD,
                               .MicroVectorD, .Vs1FinalD, .Vs2FinalD, .VdFinalD, .lmulDecodedD,
                               .LMULExpansionD);

  // The controller must track the program order of vector instruction because they may finish out-of-order.
  // A queue records the issue order.  The queue is peaked to check for the next instruction to remove from the
  // queue when an instruction completes.  It is dequeued to commit.  Since only 1 vector instruction isussed
  // at a time the only match is guaranteed to the be the next instruction in program order.

  // MicroVectorD indicates when a new micro op is created by the dispatcher.  Use this to enqueue a new instruction into
  // queue.  A counter tracks the order.  The max number of entries = pipeline depth from Decode to Writeback (4) x
  // the number of Execution Units. = 4E. The bit width is clog2(4E). Note this queue can be converted into a scoreboard
  // or active list for out-of-order completion in a future implementation.


  logic [P.VPU_QUEUEDEPTH - 1 : 0 ] OrderD;
  logic [P.VPU_MAX_EU - 1 : 0 ] MatchW;
  logic [P.VPU_QUEUEDEPTH - 1 : 0 ]    HeadOrderW;
  logic                         AnyMatchW;
  logic                         InstrOrderQueueFullD;

  queue #(P.VPU_QUEUEDEPTH, P.VPU_QUEUEDEPTH) InstrOrderQueue(.clk, .reset, .enqueue(MicroVectorD & ~StallVectorD), .dequeue(AnyMatchW & ~StallW),
                                                  .wdata(OrderD), .rdata(HeadOrderW), .full(InstrOrderQueueFullD), .empty());

  counter #(P.VPU_QUEUEDEPTH) ordercounter(clk, reset, MicroVectorD, OrderD);

  genvar i;
  for (i = 0; i < P.VPU_MAX_EU; i++) begin
    assign MatchW[i] = (HeadOrderW == ExecutionUnitOrderW[i]) & ExecutionUnitResultValidW[i];  // *** two missing inputs
    assign ControllerWBReadyW[i] = MatchW[i];
    assign ExecutionUnitOrderD[i] = OrderD;
  end

  assign AnyMatchW = | MatchW;

  assign VPUFrontEndBusyD = InstrOrderQueueFullD | LMULExpansionD; // *** add other terms here, ie if the dispatcher cannot an issue instruction and it stalls decoder stage


endmodule
