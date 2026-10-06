///////////////////////////////////////////
// spill.sv
//
// Written: Rose Thompson rose@rosethompson.net
// Created: 28 January 2022
// Modified: 19 January 2023
//
// Purpose: allows the IFU to make extra memory request if instruction address crosses
//          cache line boundaries or if instruction address without a cache crosses
//          XLEN/8 boundary.
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

module spill import cvw::*;  #(parameter cvw_t P) (
  input logic               clk,
  input logic               reset,
  input logic               StallF, FlushD,
  input logic [P.XLEN-1:0]  PCF,               // 2 byte aligned PC in Fetch stage
  input logic [P.XLEN-1:2]  PCPlus4F,          // PCF + 4
  input logic [P.XLEN-1:0]  PCNextF,           // The next PCF
  input logic [31:0]        InstrRawF,         // Instruction from the IROM, I$, or bus. Used to check if the instruction if compressed
  input logic               IFUCacheBusStallF, // I$ or bus are stalled. Transition to second fetch of spill after the first is fetched
  input logic               ITLBMissOrUpdateAF, // ITLB miss causes HPTW (hardware pagetable walker) walk or update access bit
  input logic               CacheableF,        // Is the instruction from the cache?
  input logic               InstrPageFaultF,   // Page fault on the half currently being fetched
  input logic               InstrAccessFaultF, // Access fault on the half currently being fetched
  output logic [P.XLEN-1:0] PCSpillNextF,      // The next PCF for one of the two memory addresses of the spill
  output logic [P.XLEN-1:0] PCSpillF,          // PCF for one of the two memory addresses of the spill
  output logic              SelSpillNextF,     // During the transition between the two spill operations, the IFU should stall the pipeline
  output logic              SelSpillF,         // Select incremented PC on a spill
  output logic              InstrPageFaultSpillF,   // Page fault on either half of the spilled fetch
  output logic              InstrAccessFaultSpillF, // Access fault on either half of the spilled fetch
  output logic              FirstHalfFaultF,   // The first half of the spilled fetch faulted, so it is the portion to report in xtval
  output logic [31:0]       PostSpillInstrRawF,// The final 32 bit instruction after merging the two spilled fetches into 1 instruction
  output logic              CompressedF);      // The fetched instruction is compressed

  // Spill threshold occurs when all the cache offset PC bits are 1 (except [0]).  Without a cache this is just PCF[1]
  typedef enum logic [1:0]  {STATE_READY, STATE_SPILL} statetype;

  statetype          CurrState, NextState;
  logic [P.XLEN-1:0] PCPlus2NextF, PCPlus2F;
  logic              TakeSpillF;
  logic              SpillF;
  logic              SpillSaveF;
  logic [15:0]       InstrFirstHalfF;
  logic              EarlyCompressedF;
  logic              FirstHalfPageFaultF, FirstHalfAccessFaultF;

  ////////////////////////////////////////////////////////////////////////////////////////////////////
  // PC logic
  ////////////////////////////////////////////////////////////////////////////////////////////////////

  // compute PCF+2 from the raw PC+4
  mux2 #(P.XLEN) pcplus2mux(.d0({PCF[P.XLEN-1:2], 2'b10}), .d1({PCPlus4F, 2'b00}), .s(PCF[1]), .y(PCPlus2NextF));
  // select between PCNextF and PCF+2
  mux2 #(P.XLEN) pcnextspillmux(.d0(PCNextF), .d1(PCPlus2NextF), .s(SelSpillNextF & ~FlushD), .y(PCSpillNextF));
  // select between PCF and PCF+2
  // not required for functional correctness, but improves critical path.  pcspillf ends up on the hptw's ihadr
  // and into the dmmu.  Cutting the path here removes the PC+4 adder.
  flopr #(P.XLEN) pcplus2reg(clk, reset, PCPlus2NextF, PCPlus2F);
  mux2 #(P.XLEN) pcspillmux(.d0(PCF), .d1(PCPlus2F), .s(SelSpillF), .y(PCSpillF));

  ////////////////////////////////////////////////////////////////////////////////////////////////////
  // Detect spill
  ////////////////////////////////////////////////////////////////////////////////////////////////////

  if (P.ICACHE_SUPPORTED) begin
    logic SpillCachedF, SpillUncachedF;
    assign SpillCachedF = &PCF[$clog2(P.ICACHE_LINELENINBITS/32)+1:1];
    assign SpillUncachedF = PCF[1];
    assign SpillF = (CacheableF ? SpillCachedF : SpillUncachedF);
  end else
    assign SpillF = PCF[1];
  // Don't take the spill if there is a stall, TLB miss, or hardware update to the D/A bits
  assign TakeSpillF = SpillF & ~EarlyCompressedF & ~IFUCacheBusStallF & ~ITLBMissOrUpdateAF;

  always_ff @(posedge clk)
    if (reset | FlushD)    CurrState <= STATE_READY;
    else CurrState <= NextState;

  always_comb begin
    case (CurrState)
      STATE_READY: if (TakeSpillF)                NextState = STATE_SPILL;
                   else                           NextState = STATE_READY;
      STATE_SPILL: if(StallF)                     NextState = STATE_SPILL;
                   else                           NextState = STATE_READY;
      default:                                    NextState = STATE_READY;
    endcase
  end

  assign SelSpillF = (CurrState == STATE_SPILL);
  assign SelSpillNextF = (CurrState == STATE_READY & TakeSpillF) | (CurrState == STATE_SPILL & IFUCacheBusStallF);
  assign SpillSaveF = (CurrState == STATE_READY) & TakeSpillF & ~FlushD;

  ////////////////////////////////////////////////////////////////////////////////////////////////////
  // Merge spilled instruction
  ////////////////////////////////////////////////////////////////////////////////////////////////////

  // save the first 2 bytes
  flopenr #(16) SpillInstrReg(clk, reset, SpillSaveF, InstrRawF[15:0], InstrFirstHalfF);

  // Save the fetch fault status of the first half.  The second half is translated and checked at
  // PCF+2 in the next cycle, so without this the first half's fault would be lost whenever the
  // second half fetches cleanly.  Qualifying with SelSpillF drops the latched status on a FlushD,
  // which returns the state machine to STATE_READY.
  flopenr #(2) SpillFaultReg(clk, reset, SpillSaveF, {InstrPageFaultF, InstrAccessFaultF},
                             {FirstHalfPageFaultF, FirstHalfAccessFaultF});
  assign InstrPageFaultSpillF   = InstrPageFaultF   | (SelSpillF & FirstHalfPageFaultF);
  assign InstrAccessFaultSpillF = InstrAccessFaultF | (SelSpillF & FirstHalfAccessFaultF);
  assign FirstHalfFaultF        = SelSpillF & (FirstHalfPageFaultF | FirstHalfAccessFaultF);

  // merge together
  mux2 #(32) postspillmux(InstrRawF, {InstrRawF[15:0], InstrFirstHalfF}, SelSpillF, PostSpillInstrRawF);

  // Need to use always comb to avoid pessimistic x propagation if PostSpillInstrRawF is x
  always_comb
  if (PostSpillInstrRawF[1:0] != 2'b11) CompressedF = 1'b1;
  else CompressedF = 1'b0;
  assign EarlyCompressedF = ~(&InstrRawF[1:0]);

endmodule
