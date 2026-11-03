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

  input logic [4:0]                   VdD,
  output logic [4:0]                  VdW,                            // destination vector register (to vregfile)
  output logic                        ValidW,                         // writeback control: load data valid (to vregfile)

  input logic                         VWrite,                         // temporary signal to indicate a vector write operation is in progress
  input logic                         VRead,                          // temporary signal to indicate a vector read operation is in progress

  // datapath from vregfile
  input logic [P.VLEN-1:0]            Vs3D,                           // store data (vs3)

  // to/from the LSU
  output logic [P.VPU_LSU_BLEN-1:0]   VWriteDataM,                    // Data to be written to memory (to LSU)
  output logic [P.XLEN-1:0]           VEUAdrE,                        // Memory address (to LSU)
  output logic [P.XLEN-1:0]           VEUAdrM,                        // Memory address (to LSU)
  output logic [2:0]                  VSizeM,                         // Memory size (to LSU), values 0-6 cover 1, 2, 4, 8, 16, 32, 64 bytes; 7 is reserved
  input logic [P.VPU_LSU_BLEN-1:0]    VReadDataM,                     // Read data (from LSU)

  // result to the vregfile
  output logic [P.VLEN-1:0]           VReadDataW                      // Read data (to vregfile)
);

  logic              VReadE, VReadM, VReadW;
  logic [4:0]        VdE, VdM;
  logic [P.VLEN-1:0] Vs3E;

  assign VSizeM = 3'b110;

  // read control and destination register travel with the instruction to writeback
  flopr #(1) vreadE(clk, reset, VRead, VReadE);
  flopr #(1) vreadM(clk, reset, VReadE, VReadM);
  flopr #(1) vreadW(clk, reset, VReadM, VReadW);

  flopr #(5) vdE(clk, reset, VdD, VdE);
  flopr #(5) vdM(clk, reset, VdE, VdM);
  flopr #(5) vdW(clk, reset, VdM, VdW);

  assign ValidW = VReadW;

  // address flop
  assign VEUAdrE = ForwardedSrcAE;
  flopr #(P.XLEN) adrreg(clk, reset, VEUAdrE, VEUAdrM);

  // write data flops (D -> E -> M); single beat, so assumes VLEN == VPU_LSU_BLEN for now
  flopr #(P.VLEN) vwriteE(clk, reset, Vs3D, Vs3E);
  flopr #(P.VPU_LSU_BLEN) vwriteM(clk, reset, Vs3E, VWriteDataM);

  // read data flop (M -> W); single beat, so assumes VLEN == VPU_LSU_BLEN for now
  flopr #(P.VLEN) vreaddataW(clk, reset, VReadDataM, VReadDataW);

endmodule
