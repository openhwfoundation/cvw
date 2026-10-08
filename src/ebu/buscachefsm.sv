///////////////////////////////////////////
// busfsm.sv
//
// Written: Rose Thompson rose@rosethompson.net
// Created: December 29, 2021
// Modified: 18 January 2023
//
// Purpose: Controller for cache to AHB bus interface
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

// HCLK and clk must be the same clock!
module buscachefsm #(
  parameter BeatCountThreshold,                      // Largest beat index
  parameter AHBWLOGBWPL,                             // Log2 of BEATSPERLINE
  parameter READ_ONLY_CACHE,                         // 1 for read-only instruction cache
  parameter BURST_EN                                 // burst mode supported
)(
  input  logic                   HCLK,
  input  logic                   HRESETn,

  // IEU interface
  input  logic                   Stall,              // Core pipeline is stalled
  input  logic                   Flush,              // Pipeline stage flush. Prevents bus transaction from starting
  input  logic [1:0]             BusRW,              // Uncached memory operation read/write control: 10: read, 01: write
  input  logic                   BusAtomic,          // Uncache atomic memory operation
  input  logic                   BusCMOZero,         // Uncached cbo.zero must write zero to full sized cacheline without going through the cache
  output logic                   BusStall,           // Bus is busy with an in flight memory operation
  output logic                   BusCommitted,       // Bus is busy with an in flight memory operation and it is not safe to take an interrupt

  // ahb cache interface locals.
  output logic                   CaptureEn,          // Enable updating the Fetch buffer with valid data from HRDATA

  // cache interface
  input  logic [1:0]             CacheBusRW,         // Cache bus operation, 01: writeback, 10: fetch
  output logic                   CacheBusAck,        // Handshack to $ indicating bus transaction completed

  // lsu interface
  output logic [AHBWLOGBWPL-1:0] BeatCount,          // Beat position within the cache line in the Address Phase
  output logic [AHBWLOGBWPL-1:0] BeatCountDelayed,   // Beat within the cache line in the second (Data) cache stage
  output logic                   SelBusBeat,         // Tells the cache to select the word from ReadData or WriteData from BeatCount rather than PAdr

  // BUS interface
  input  logic                   HREADY,             // AHB peripheral ready
  output logic [1:0]             HTRANS,             // AHB transaction type, 00: IDLE, 10 NON_SEQ, 11 SEQ
  output logic                   HWRITE,             // AHB 0: Read operation 1: Write operation
  output logic [2:0]             HBURST              // AHB burst length
);

  typedef enum logic [2:0] {ADR_PHASE, DATA_PHASE, ATOMIC_READ_DATA_PHASE, ATOMIC_PHASE, MEM3, CACHE_FETCH, CACHE_WRITEBACK} busstatetype;
  typedef enum logic [1:0] {AHB_IDLE = 2'b00, AHB_BUSY = 2'b01, AHB_NONSEQ = 2'b10, AHB_SEQ = 2'b11} ahbtranstype;

  busstatetype CurrState, NextState;

  logic [AHBWLOGBWPL-1:0] NextBeatCount;
  logic                   FinalBeatCount;
  logic [2:0]             LocalBurstType;
  logic                   BeatCntEn;
  logic                   BeatCntReset;
  logic                   CacheAccess;
  logic                   BusWrite;

  assign BusWrite = (CacheBusRW[0] | BusCMOZero) & ~READ_ONLY_CACHE;

  always_ff @(posedge HCLK)
    if (~HRESETn | Flush) CurrState <= ADR_PHASE;
    else                  CurrState <= NextState;

  always_comb begin
      case(CurrState)
        ADR_PHASE: if (HREADY & |BusRW)                               NextState = DATA_PHASE;             // exclusion-tag: buscachefsm HREADY0
                   else if (HREADY & BusWrite & ~READ_ONLY_CACHE)     NextState = CACHE_WRITEBACK;        // exclusion-tag: buscachefsm HREADY1
                   else if (HREADY & CacheBusRW[1])                   NextState = CACHE_FETCH;            // exclusion-tag: buscachefsm HREADYread
                   else                                               NextState = ADR_PHASE;
        DATA_PHASE:  if(HREADY & BusAtomic & ~READ_ONLY_CACHE)        NextState = ATOMIC_READ_DATA_PHASE; // exclusion-tag: buscachefsm HREADY2
                     else if(HREADY & ~BusAtomic)                     NextState = MEM3; // exclusion-tag: buscachefsm HREADY3
                     else                                             NextState = DATA_PHASE;
        ATOMIC_READ_DATA_PHASE: if(HREADY)                            NextState = ATOMIC_PHASE;           // exclusion-tag: buscachefsm AtomicReadData
                    else                                              NextState = ATOMIC_READ_DATA_PHASE; // exclusion-tag: buscachefsm AtomicElse
        ATOMIC_PHASE: if(HREADY)                                      NextState = MEM3;                   // exclusion-tag: buscachefsm AtomicPhase
                      else                                            NextState = ATOMIC_PHASE;           // exclusion-tag: buscachefsm AtomicWait
        MEM3:        if(Stall)                                        NextState = MEM3;
                     else                                             NextState = ADR_PHASE;
        CACHE_FETCH: if(HREADY & FinalBeatCount & CacheBusRW[0])      NextState = CACHE_WRITEBACK;  // exclusion-tag: buscachefsm FetchWriteback
                     else if(HREADY & FinalBeatCount & CacheBusRW[1]) NextState = CACHE_FETCH;      // exclusion-tag: buscachefsm FetchWait
                     else if(HREADY & FinalBeatCount & ~|CacheBusRW)  NextState = ADR_PHASE;
                     else                                             NextState = CACHE_FETCH;
        CACHE_WRITEBACK:  if(HREADY & FinalBeatCount & CacheBusRW[0]) NextState = CACHE_WRITEBACK; // exclusion-tag: buscachefsm WritebackWriteback
                     else if(HREADY & FinalBeatCount & CacheBusRW[1]) NextState = CACHE_FETCH;     // exclusion-tag: buscachefsm HREADY4
                     else if(HREADY & FinalBeatCount & BusCMOZero)    NextState = MEM3;            // exclusion-tag: buscachefsm HREADY5
                     else if(HREADY & FinalBeatCount & ~|CacheBusRW)  NextState = ADR_PHASE;       // exclusion-tag: buscachefsm HREADY6
                     else                                             NextState = CACHE_WRITEBACK; // exclusion-tag: buscachefsm WritebackWriteback2
        default:                                                      NextState = ADR_PHASE;
      endcase
  end

  // IEU, LSU, and IFU controls
  // Used to store data from data phase of AHB.
  flopenr #(AHBWLOGBWPL) BeatCountReg(HCLK, ~HRESETn | BeatCntReset, BeatCntEn, NextBeatCount, BeatCount);
  flopenr #(AHBWLOGBWPL) BeatCountDelayedReg(HCLK, ~HRESETn | BeatCntReset, BeatCntEn, BeatCount, BeatCountDelayed);
  assign NextBeatCount = BeatCount + 1'b1;

  assign FinalBeatCount = BeatCountDelayed == BeatCountThreshold[AHBWLOGBWPL-1:0];
  assign BeatCntEn = (((NextState == CACHE_WRITEBACK | NextState == CACHE_FETCH) & HREADY & ~Flush) |
                     (NextState == ADR_PHASE & |CacheBusRW & HREADY)) & ~Flush;
  assign BeatCntReset = NextState == ADR_PHASE;

  assign CaptureEn = (CurrState == DATA_PHASE & BusRW[1] & ~Flush) | (CurrState == CACHE_FETCH & HREADY);
  assign CacheAccess = CurrState == CACHE_FETCH | CurrState == CACHE_WRITEBACK;

  assign BusStall = (CurrState == ADR_PHASE & ((|BusRW) | (|CacheBusRW) | BusCMOZero)) |
                    (CurrState == DATA_PHASE) |
                    (CurrState == ATOMIC_PHASE) |
                    (CurrState == ATOMIC_READ_DATA_PHASE) |
                    (CurrState == CACHE_FETCH & ~FinalBeatCount) |
                    (CurrState == CACHE_WRITEBACK & ~FinalBeatCount);

  assign BusCommitted = (CurrState != ADR_PHASE) & ~(READ_ONLY_CACHE & CurrState == MEM3);

  // AHB bus interface
  assign HTRANS = (CurrState == ADR_PHASE & HREADY & ((|BusRW) | (|CacheBusRW) | BusCMOZero) & ~Flush) |
                  (CurrState == ATOMIC_READ_DATA_PHASE) |
                  (CacheAccess & FinalBeatCount & |CacheBusRW & HREADY & ~Flush) ? AHB_NONSEQ : // if we have a pipelined request
                  (CacheAccess & |BeatCount) ? (BURST_EN ? AHB_SEQ : AHB_NONSEQ) : AHB_IDLE;

  assign HWRITE = (((BusRW[0] & ~BusAtomic) | BusWrite & ~Flush) | (CurrState == ATOMIC_READ_DATA_PHASE & BusAtomic) |
                  (CurrState == CACHE_WRITEBACK & |BeatCount)) & ~READ_ONLY_CACHE;
  assign HBURST = BURST_EN & ((|CacheBusRW & ~Flush) | (CacheAccess & |BeatCount)) ? LocalBurstType : 3'b0;

  always_comb begin
    case(BeatCountThreshold)
      0:        LocalBurstType = 3'b000;
      3:        LocalBurstType = 3'b011; // INCR4
      7:        LocalBurstType = 3'b101; // INCR8
      15:       LocalBurstType = 3'b111; // INCR16
      default:  LocalBurstType = 3'b001; // INCR without end.
    endcase
  end

  // communication to cache
  assign CacheBusAck = (CacheAccess & HREADY & FinalBeatCount & ~BusCMOZero);
  assign SelBusBeat = (CurrState == ADR_PHASE & (BusRW[0] | BusWrite)) |
                      (CurrState == DATA_PHASE & BusRW[0]) |
                      (CurrState == ATOMIC_PHASE & BusRW[0]) |
                      (CurrState == ATOMIC_READ_DATA_PHASE & BusRW[0]) |
                      (CurrState == CACHE_WRITEBACK) |
                      (CurrState == CACHE_FETCH);

endmodule
