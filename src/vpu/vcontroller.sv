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
  input logic                         VectorStallD, VectorFlushD, // Stall, flush Decode stage
  input logic                         StallW,
  input logic [31:0]                  InstrD,                     // Instruction in Decode stage
  input logic                         VectorD,                    // This instruction is a vector
  // CSR state
  input logic [1:0]                   STATUS_VS,                  // vector (VS) field in status register
  input logic [P.XLEN-1:0]            VTYPED,                     // vtype, forwarded from an older vset still in flight

  // Decode stage outputs
  output logic [4:0]                  Vs1FinalD, Vs2FinalD,       // Vector Source 1 and 2
  output logic [4:0]                  VdFinalD,                   // Vector Destination read (overwrite)
  output logic                        VMD,                        // 0 = mask enabled, 1 mask disabled
  output logic [5:0]                  Funct6D,
  output logic [2:0]                  Funct3D,
  output logic                        VWriteIntD,                 // writes integer register
  output logic                        VWriteFPD,                  // writes floating-point register
  output logic                        VRegWriteD,
  output logic [1:0]                  VALUSrcAD,
  output logic                        VALUSrcBD,
  output logic                        VALUResultSrcD,
  output logic [2:0]                  VALUSelectD,
  output logic                        VSubD,
  output logic [1:0]                  VLaneSelectD,               // vlane result: 00 valu, 01 vmul, 10 move, 11 shift
  output logic [1:0]                  VShiftSelectD,              // vlane shift: 00 sll, 10 srl, 11 sra
  output logic                        IllegalVPUInstrD,
  // vset controls, sent to vconfig
  output logic                        VsetD,                      // vsetvli, vsetivli, or vsetvl
  output logic                        VsetvlD,                    // vsetvl: vtype comes from rs2 rather than an immediate
  output logic                        VsetivliD,                  // vsetivli: AVL is the uimm5 in the rs1 field
  output logic [10:0]                 VTYPEImmD,                  // zero-extended vtype immediate for vsetvli / vsetivli
  // hand shaking controls
  output logic [P.VPU_EU-1:0]     ControllerValidD,
  input logic [P.VPU_EU-1:0]      ExecutionUnitReadyD,
  output logic [P.VPU_QUEUEDEPTH-1:0] ExecutionUnitOrderD [P.VPU_EU-1:0],
  input logic [P.VPU_QUEUEDEPTH-1:0]  ExecutionUnitOrderW [P.VPU_EU-1:0],
  input logic [P.VPU_EU-1:0]      ExecutionUnitResultValidW,
  output logic [P.VPU_EU-1:0]     ControllerWBReadyW,
  output logic                        VPUFrontEndBusyD
);

  logic        MicroVectorD;
  logic [4:0]  Vs1D, Vs2D;               // Vector Source 1 and 2
  logic [4:0]  VdD;                      // Vector Destination read (overwrite)
  logic [3:0]  MicroOpsD;                // micro-ops in the instruction: registers in the LMUL group, 1 for fractional LMUL
  logic        MicroOpNotLastD;
  logic        VHazardStallD;             // wait for all older vector instructions to write back

  logic [2:0]  VEUTypeD;                  // type of EU an instruction needs (INT, FP, LSU)
  logic [4:0]  VOpClassD;                 // execution block requirement for EU
  logic [5:0]  VLSModeD;                  // addressing modes for load/store
  logic        VReductionD;               // instr is a reduction op
  logic [2:0]  VdEEWD, Vs2EEWD, Vs1EEWD;  // log2(EEW) of Vd/Vs2/Vs1, 000 = 1b (mask)

  // Micro-ops from LMUL in vtype; fractional LMUL fits in one register
  always_comb
    case (VTYPED[2:0])
      3'b001:  MicroOpsD = 4'd2; // m2
      3'b010:  MicroOpsD = 4'd4; // m4
      3'b011:  MicroOpsD = 4'd8; // m8
      default: MicroOpsD = 4'd1; // m1, mf2, mf4, mf8
    endcase


  vdecoder #(P) vdecoder(.clk, .reset, .VectorStallD, .VectorFlushD,
                         .InstrD, .STATUS_VS, .VTYPED, .Vs1D, .Vs2D, .VdD, .VMD,
                         .Funct6D, .Funct3D, .VWriteIntD, .VWriteFPD, .VRegWriteD,
                         .VEUTypeD, .VOpClassD, .VLSModeD, .VReductionD,
                         .VdEEWD, .Vs2EEWD, .Vs1EEWD,
                         .VALUSrcAD, .VALUSrcBD, .VALUResultSrcD, .VALUSelectD, .VSubD, .VLaneSelectD,
                         .VShiftSelectD, .IllegalVPUInstrD,
                         .VsetD, .VsetvlD, .VsetivliD, .VTYPEImmD);

  // Only dispatch a vector instruction that will actually execute.  A flushed (wrong-path) or illegal instruction in
  // Decode must not reach an EU or the order queue: its result would arrive in Writeback with a cleared order tag that
  // never matches the queue head, so the EU waits forever for writeback and VPUBackEndBusyE stalls the pipeline.
  logic        DispatchVectorD;
  assign DispatchVectorD = VectorD & ~VectorFlushD & ~IllegalVPUInstrD;

  vdispatcher #(P) vdispatcher(.clk, .reset, .VectorStallD, .VectorFlushD,
                               .VectorD(DispatchVectorD), .Vs1D, .Vs2D, .VdD, .VEUTypeD, .VOpClassD, .VLSModeD,
                               .ControllerValidD, .ExecutionUnitReadyD,
                               .MicroVectorD, .Vs1FinalD, .Vs2FinalD, .VdFinalD, .MicroOpsD,
                               .MicroOpNotLastD, .VHazardD(~InstrOrderQueueEmptyD), .VHazardStallD);

  // The controller must track the program order of vector instruction because they may finish out-of-order.
  // A queue records the issue order.  The queue is peaked to check for the next instruction to remove from the
  // queue when an instruction completes.  It is dequeued to commit.  Since only 1 vector instruction isussed
  // at a time the only match is guaranteed to the be the next instruction in program order.

  // MicroVectorD indicates when a new micro op is created by the dispatcher.  Use this to enqueue a new instruction into
  // queue.  A counter tracks the order.  The max number of entries = pipeline depth from Decode to Writeback (4) x
  // the number of Execution Units. = 4E. The bit width is clog2(4E). Note this queue can be converted into a scoreboard
  // or active list for out-of-order completion in a future implementation.


  logic [P.VPU_QUEUEDEPTH - 1 : 0 ] OrderD;
  logic [P.VPU_EU - 1 : 0 ] MatchW;
  logic [P.VPU_QUEUEDEPTH - 1 : 0 ]    HeadOrderW;
  logic                         AnyMatchW;
  logic                         InstrOrderQueueFullD;
  logic                         InstrOrderQueueEmptyD;

  queue #(P.VPU_QUEUEDEPTH, P.VPU_QUEUEDEPTH) InstrOrderQueue(.clk, .reset, .enqueue(MicroVectorD & ~VectorStallD), .dequeue(AnyMatchW & ~StallW),
                                                  .wdata(OrderD), .rdata(HeadOrderW), .full(InstrOrderQueueFullD), .empty(InstrOrderQueueEmptyD));

  counter #(P.VPU_QUEUEDEPTH) ordercounter(clk, reset, MicroVectorD & ~VectorStallD, OrderD);

  genvar i;
  for (i = 0; i < P.VPU_EU; i++) begin
    assign MatchW[i] = (HeadOrderW == ExecutionUnitOrderW[i]) & ExecutionUnitResultValidW[i];  // *** two missing inputs
    assign ControllerWBReadyW[i] = MatchW[i];
    assign ExecutionUnitOrderD[i] = OrderD;
  end

  assign AnyMatchW = | MatchW;

  assign VPUFrontEndBusyD = InstrOrderQueueFullD | MicroOpNotLastD | (VWriteIntD & ~VsetD & ~InstrOrderQueueEmptyD) | VHazardStallD; // *** add other terms here, ie if the dispatcher cannot an issue instruction and it stalls decoder stage


endmodule
