///////////////////////////////////////////
// atomic.sv
//
// Written: Rose Thompson rose@rosethompson.net
// Created: 31 January 2022
// Modified: 18 January 2023
//
// Purpose: Wrapper for amoalu and lrsc
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
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

module atomic import cvw::*; #(parameter cvw_t P) (
  input  logic                 clk,            // Clock
  input  logic                 reset,          // Reset
  input  logic                 StallW,         // Stall Writeback stage
  input  logic [P.XLEN-1:0]    ReadDataM,      // Read data from memory in Memory stage
  input  logic [P.XLEN-1:0]    IHWriteDataM,   // IEU or HPTW write data
  input  logic [P.PA_BITS-1:0] PAdrM,          // Physical memory address
  input  logic [6:0]           LSUFunct7M,     // IEU or HPTW AMO operation
  input  logic [2:0]           LSUFunct3M,     // IEU or HPTW memory operation size and signedness
  input  logic [1:0]           LSUAtomicM,     // IEU or HPTW atomic operation: 10 AMO, 01 LR/SC
  input  logic [1:0]           PreLSURWM,      // IEU or HPTW memory read/write: [1] read, [0] write
  input  logic                 LSUFlushW,      // Flush the memory operation: FlushW, HPTW replay, or its own fault
  output logic [P.XLEN-1:0]    IMAWriteDataM,  // IEU, HPTW, or AMO write data
  output logic                 SquashSCW,      // Store conditional failed; do not write the register file
  output logic [1:0]           LSURWM          // Memory read/write after LR/SC squash: [1] read, [0] write
);

  logic [P.XLEN-1:0]          AMOResultM;
  logic                       MemReadM;

  // AMO ALU
  if (P.ZAAMO_SUPPORTED) begin
    amoalu #(P) amoalu(.ReadDataM, .IHWriteDataM, .LSUFunct7M, .LSUFunct3M, .AMOResultM);
    mux2 #(P.XLEN) wdmux(IHWriteDataM, AMOResultM, LSUAtomicM[1], IMAWriteDataM);
  end else
    assign IMAWriteDataM = IHWriteDataM;

  // LRSC unit
  if (P.ZALRSC_SUPPORTED) begin
    assign MemReadM = PreLSURWM[1] & ~LSUFlushW;
    lrsc #(P) lrsc(.clk, .reset, .StallW, .MemReadM, .PreLSURWM, .LSUAtomicM, .PAdrM, .SquashSCW, .LSURWM);
  end else begin
    assign SquashSCW = 0;
    assign LSURWM = PreLSURWM;
  end

endmodule
