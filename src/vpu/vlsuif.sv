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
  input logic [P.XLEN-1:0]            ForwardedSrcAE,                 // rs1 base address

  input logic [4:0]                   VdFinalD,
  output logic [4:0]                  VdW,                            // destination vector register (to vregfile)
  output logic                        ValidW,                         // writeback control: load data valid (to vregfile)
  input logic                         ReadyW,                         // writeback control: load data ready (from vregfile)

  input logic                         ValidD,                         // valid signal from the controller that there is a new operation
  output logic                        ReadyD,                         // ready signal from VLSUIF to controller that it can accept a new operation
  input logic [P.VPU_QUEUEDEPTH-1:0]  ExecutionUnitOrderD,            // program-order tag assigned by the controller
  output logic [P.VPU_QUEUEDEPTH-1:0] ExecutionUnitOrderW,            // order tag returned to the controller for in-order commit
  output logic                        VRegWriteW,                     // write the vregfile (loads only)

  input logic [1:0]                   VMemRWD,                        // vector memory read/write: [1] = read, [0] = write

  // datapath from vregfile
  input logic [P.VLEN-1:0]            Vs3D,                           // store data (vs3)

  // to/from the LSU
  output logic [1:0]                  VMemRWE, VMemRWM,               // Memory read/write (to LSU): [1] = read, [0] = write
  output logic [P.VLEN-1:0]           VWriteDataM,                    // Data to be written to memory (to LSU)
  output logic [P.XLEN-1:0]           VEUAdrE,                        // Memory address (to LSU)
  output logic [P.XLEN-1:0]           VEUAdrM,                        // Memory address (to LSU)
  output logic [2:0]                  VSizeM,                         // Memory size (to LSU), values 0-6 cover 1, 2, 4, 8, 16, 32, 64 bytes; 7 is reserved
  input logic [P.VLEN-1:0]            VReadDataM,                     // Read data (from LSU)

  // result to the vregfile
  output logic [P.VLEN-1:0]           VReadDataW                      // Read data (to vregfile)
);

  logic [1:0]                   VMemRWW;
  logic [4:0]                   VdE, VdM, PreVdW;
  logic [P.VLEN-1:0]            VWriteDataE, PreVReadDataW;
  logic [P.VPU_QUEUEDEPTH-1:0]  OrderE, OrderM;

  assign VSizeM = 3'b110; // *** TODO: This is a placeholder value, need to accomodate multiple element sizes
  assign ReadyD = 1'b1; // *** TODO: This is a placeholder value, need to implement a ready signal for the LSU interface

  // memory read/write control and destination register travel with the instruction to writeback
  flopr #(2) vmemrwereg(clk, reset, VMemRWD & {2{ValidD}}, VMemRWE);
  flopr #(2) vmemrwmreg(clk, reset, VMemRWE, VMemRWM);
  flopr #(2) vmemrwwreg(clk, reset, VMemRWM, VMemRWW);

  flopr #(5) vdereg(clk, reset, VdFinalD, VdE);
  flopr #(5) vdmreg(clk, reset, VdE, VdM);
  flopr #(5) vdwreg(clk, reset, VdM, PreVdW);

  // order tag travels with the instruction so the controller can match it against the head of the order queue
  flopr #(P.VPU_QUEUEDEPTH) ordereg(clk, reset, ExecutionUnitOrderD, OrderE);
  flopr #(P.VPU_QUEUEDEPTH) ordermreg(clk, reset, OrderE, OrderM);
  flopr #(P.VPU_QUEUEDEPTH) orderwreg(clk, reset, OrderM, ExecutionUnitOrderW);

  // both loads and stores occupy an order-queue entry, so both must report valid to be dequeued;
  // only loads write the vregfile
  assign ValidW     = |VMemRWW;
  assign VRegWriteW = ReadyW & VMemRWW[1];

  // address flop
  assign VEUAdrE = ForwardedSrcAE;
  flopr #(P.XLEN) adrreg(clk, reset, VEUAdrE, VEUAdrM);

  // write data flops (D -> E -> M); single beat, so assumes VLEN == VPU_LSU_BLEN for now
  flopr #(P.VLEN) vwriteereg(clk, reset, Vs3D, VWriteDataE);
  flopr #(P.VLEN) vwritemreg(clk, reset, VWriteDataE, VWriteDataM);

  // read data flop (M -> W); single beat, so assumes VLEN == VPU_LSU_BLEN for now
  flopr #(P.VLEN) vreaddatawreg(clk, reset, VReadDataM, PreVReadDataW);

  // AND part of the AO-muxes in vpu: drive zero unless the controller selected this EU this cycle
  assign VdW        = ReadyW ? PreVdW        : '0;
  assign VReadDataW = ReadyW ? PreVReadDataW : '0;

endmodule
