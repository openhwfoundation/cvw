///////////////////////////////////////////
// dtim.sv
//
// Written: Rose Thompson rose@rosethompson.net
// Created: 30 January 2022
// Modified: 18 January 2023
//
// Purpose: tightly integrated memory into the LSU.
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

module dtim import cvw::*;  #(parameter cvw_t P) (
  input  logic                 clk, reset,
  input  logic                 FlushW,
  input  logic                 ce,            // Chip Enable.  0: Holds ReadDataWordM
  input  logic [1:0]           MemRWM,        // Read/Write control
  input  logic [P.PA_BITS-1:0] DTIMAdr,       // No stall: Execution stage memory address. Stall: Memory stage memory address
  input  logic [P.LLEN-1:0]    WriteDataM,    // Write data from IEU
  input  logic [P.LLEN/8-1:0]  ByteMaskM,     // Selects which bytes within a word to write
  output logic [P.LLEN-1:0]    ReadDataWordM  // Read data before subword selection
  );

  logic                       we;

  localparam LLENBYTES  = P.LLEN/8;
  // verilator  lint_off WIDTH
  localparam DEPTH      = P.DTIM_RANGE/LLENBYTES;
  // verilator  lint_on WIDTH
  localparam ADDR_WDITH = $clog2(DEPTH);
  localparam OFFSET     = $clog2(LLENBYTES);

  assign we = MemRWM[0]  & ~FlushW;  // have to ignore write if Trap.

  ram1p1rwbe #(.USE_SRAM(P.USE_SRAM), .DEPTH(DEPTH), .WIDTH(P.LLEN))
    ram(.clk, .ce, .we, .bwe(ByteMaskM), .addr(DTIMAdr[ADDR_WDITH+OFFSET-1:OFFSET]), .dout(ReadDataWordM), .din(WriteDataM));
endmodule
