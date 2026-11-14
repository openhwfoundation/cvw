///////////////////////////////////////////
// vlsuif.sv
//
// Written: eoinoconnell04@gmail.com
// Created: 3 November 2026
// Modified: 3 November 2026
//
// Purpose: vector load/store unit interface. Currently a stub that ties off its outputs.
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

module vlsuif import cvw::*;  #(parameter cvw_t P)
  (
  input logic                         clk,
  input logic                         reset,
  input logic                         VectorStallE, StallM, StallW,   // stall signals (from HZU)
  input logic                         VectorFlushE, VectorFlushM, FlushW, // flush signals (from HZU)
  input logic [P.XLEN-1:0]            R1D,                            // rs1 base address, read in Decode
  input logic [2:0]                   VWidthD,                        // width field InstrD[14:12]: element size

  input logic [4:0]                   VdFinalD,

  input logic                         ValidD,                         // valid signal from the controller that there is a new operation
  output logic                        ReadyD,                         // ready signal from VLSUIF to controller that it can accept a new operation
  input logic [P.VPU_QUEUEDEPTH-1:0]  ExecutionUnitOrderD,            // program-order tag assigned by the controller

  // result to the sVRF: one beat per instruction for now
  output logic [P.VPU_QUEUEDEPTH-1:0] ExecutionUnitOrderW,            // sVRF entry (order tag) of the result
  output logic                        BeatValidW,                     // result beat is valid
  output logic                        LastBeatW,                      // last beat: the sVRF entry is complete
  output logic [$clog2((P.VLEN/P.ELEN) + 1)-1:0] BeatW,               // beat number of the result
  output logic [P.VPU_INT_BLEN-1:0]   VResultW,                       // result beat (load data)
  output logic [4:0]                  VdW,                            // destination vector register
  output logic                        VRegWriteW,                     // write the vregfile at commit (loads only)

  input logic [1:0]                   VMemRWD,                        // vector memory read/write: [1] = read, [0] = write

  // datapath from vregfile
  input logic [P.VLEN-1:0]            Vs3D,                           // store data (vs3)

  // to/from the LSU
  output logic [1:0]                  VMemRWE, VMemRWM,               // Memory read/write (to LSU): [1] = read, [0] = write
  output logic [P.VLEN-1:0]           VWriteDataM,                    // Data to be written to memory (to LSU)
  output logic [P.XLEN-1:0]           VEUAdrE,                        // Memory address (to LSU)
  output logic [P.XLEN-1:0]           VEUAdrM,                        // Memory address (to LSU)
  output logic [2:0]                  VSizeM,                         // Memory size (to LSU), values 0-6 cover 1, 2, 4, 8, 16, 32, 64 bytes; 7 is reserved
  input logic [P.VLEN-1:0]            VReadDataM                      // Read data (from LSU)
);

  logic [1:0]                   VMemRWW;
  logic [4:0]                   VdE, VdM;
  logic [P.VLEN-1:0]            VWriteDataE;
  logic [P.VPU_QUEUEDEPTH-1:0]  OrderE, OrderM;

  // log2(element bytes) from the width field: 000 = e8, 101 = e16, 110 = e32, 111 = e64
  // *** TODO: only element 0 (one LLEN access) is transferred for now
  logic [2:0] VSizeD, VSizeE;
  always_comb
    case (VWidthD)
      3'b101:  VSizeD = 3'd1;
      3'b110:  VSizeD = 3'd2;
      3'b111:  VSizeD = 3'd3;
      default: VSizeD = 3'd0;
    endcase
  flopenrc #(3) vsizeereg(clk, reset, VectorFlushE, ~VectorStallE, VSizeD, VSizeE);
  flopenrc #(3) vsizemreg(clk, reset, VectorFlushM, ~StallM, VSizeE, VSizeM);
  assign ReadyD = 1'b1; // *** TODO: This is a placeholder value, need to implement a ready signal for the LSU interface

  // memory read/write control and destination register travel with the instruction to writeback
  flopenrc #(2) vmemrwereg(clk, reset, VectorFlushE, ~VectorStallE, VMemRWD & {2{ValidD}}, VMemRWE);
  flopenrc #(2) vmemrwmreg(clk, reset, VectorFlushM, ~StallM, VMemRWE, VMemRWM);
  flopenrc #(2) vmemrwwreg(clk, reset, FlushW, ~StallW, VMemRWM, VMemRWW);

  flopenrc #(5) vdereg(clk, reset, VectorFlushE, ~VectorStallE, VdFinalD, VdE);
  flopenrc #(5) vdmreg(clk, reset, VectorFlushM, ~StallM, VdE, VdM);
  flopenrc #(5) vdwreg(clk, reset, FlushW, ~StallW, VdM, VdW);

  // order tag travels with the instruction and selects its sVRF entry
  flopenrc #(P.VPU_QUEUEDEPTH) ordereg(clk, reset, VectorFlushE, ~VectorStallE, ExecutionUnitOrderD, OrderE);
  flopenrc #(P.VPU_QUEUEDEPTH) ordermreg(clk, reset, VectorFlushM, ~StallM, OrderE, OrderM);
  flopenrc #(P.VPU_QUEUEDEPTH) orderwreg(clk, reset, FlushW, ~StallW, OrderM, ExecutionUnitOrderW);

  // both loads and stores occupy an order-queue entry, so both must complete their sVRF entry to commit;
  // only loads write the vregfile.  Single beat: beat 0 is also the last beat.
  // *** TODO: beats above 0 are not written, so the rest of vd holds stale sVRF data
  assign BeatValidW = |VMemRWW;
  assign LastBeatW  = BeatValidW;
  assign BeatW      = '0;
  assign VRegWriteW = VMemRWW[1];

  // address flops: the scalar E stage is flushed for vector instructions, so carry rs1 from Decode here
  flopenrc #(P.XLEN) adrereg(clk, reset, VectorFlushE, ~VectorStallE, R1D, VEUAdrE);
  flopenrc #(P.XLEN) adrreg(clk, reset, VectorFlushM, ~StallM, VEUAdrE, VEUAdrM);

  // write data flops (D -> E -> M); single beat, so assumes VLEN == VPU_LSU_BLEN for now
  flopenrc #(P.VLEN) vwriteereg(clk, reset, VectorFlushE, ~VectorStallE, Vs3D, VWriteDataE);
  flopenrc #(P.VLEN) vwritemreg(clk, reset, VectorFlushM, ~StallM, VWriteDataE, VWriteDataM);

  // read data flop (M -> W): the low beat of the load data
  flopenrc #(P.VPU_INT_BLEN) vreaddatawreg(clk, reset, FlushW, ~StallW, VReadDataM[P.VPU_INT_BLEN-1:0], VResultW);

endmodule
