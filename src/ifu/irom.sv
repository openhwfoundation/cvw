///////////////////////////////////////////
// irom.sv
//
// Written: Rose Thompson rose@rosethompson.net
// Created: 30 January 2022
// Modified: 18 January 2023
//
// Purpose: simple instruction ROM
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

module irom import cvw::*;  #(parameter cvw_t P) (
  input logic              clk,
  input logic              ce,        // Chip Enable.  0: Holds IROMInstrF constant
  input logic [P.XLEN-1:0] Adr,       // PCNextFSpill
  output logic [31:0]      IROMInstrF // Instruction read data
);

  localparam XLENBYTES = {{P.PA_BITS-32{1'b0}}, P.XLEN/8}; // XLEN/8, adjusted for width
  localparam ADDR_WDITH = $clog2(P.IROM_RANGE[P.PA_BITS-1:0]/XLENBYTES);
  localparam OFFSET = $clog2(XLENBYTES);

  logic [P.XLEN-1:0] IROMInstrFFull;
  logic [31:0]       RawIROMInstrF;
  logic [2:1]        AdrD;

  // preload IROM with the FPGA bootloader by default so that it synthesizes to something, avoiding having the IEU optimized away because instructions are all 0
  // the testbench replaces these dummy contents with the actual program of interest during simulation
  rom1p1r #(ADDR_WDITH, P.XLEN, 1) rom(.clk, .ce, .addr(Adr[ADDR_WDITH+OFFSET-1:OFFSET]), .dout(IROMInstrFFull));
  if (P.XLEN == 32) assign RawIROMInstrF = IROMInstrFFull;
  else              begin
  // IROM is aligned to XLEN words, but instructions are 32 bits.  Select between the two
  // haves.  Adr is the Next PCF not PCF so we delay 1 cycle.
    flopen #(1) AdrReg2(clk, ce, Adr[2], AdrD[2]);
    assign RawIROMInstrF = AdrD[2] ? IROMInstrFFull[63:32] : IROMInstrFFull[31:0];
  end
  // If the memory address is aligned to 2 bytes return the upper 2 bytes in the lower 2 bytes.
  // The spill logic will handle merging the two together.
  if (P.ZCA_SUPPORTED) begin
    flopen #(1) AdrReg1(clk, ce, Adr[1], AdrD[1]);
    assign IROMInstrF = AdrD[1] ? {16'b0, RawIROMInstrF[31:16]} : RawIROMInstrF;
  end else
    assign IROMInstrF = RawIROMInstrF;
endmodule
