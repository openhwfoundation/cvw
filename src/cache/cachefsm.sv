///////////////////////////////////////////
// cachefsm.sv
//
// Written: Rose Thompson rose@rosethompson.net
// Created: 25 August 2021
// Modified: 20 January 2023
//
// Purpose: Controller for the cache fsm
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
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

module cachefsm #(parameter READ_ONLY_CACHE = 0) (
  input  logic       clk,
  input  logic       reset,
  // hazard and privilege unit
  input  logic       Stall,             // Stall the cache, preventing new accesses. In-flight access finished but does not return to READY
  input  logic       FlushStage,        // Pipeline flush of second stage (prevent writes and bus operations)
  input  logic       InvalidateFlushStage, // Pipeline flush of second stage (prevent writes and bus operations)
  output logic       CacheCommitted,    // Cache has started bus operation that shouldn't be interrupted
  output logic       CacheStall,        // Cache stalls pipeline during multicycle operation
  // inputs from IEU
  input  logic [1:0] CacheRW,           // [1] Read, [0] Write
  input  logic       FlushCache,        // Flush all dirty lines back to memory
  input  logic       InvalidateCache,   // Clear all valid bits
  input  logic [3:0] CMOpM,             // 0001: cbo.inval; 0010: cbo.flush; 0100: cbo.clean; 1000: cbo.zero
  // Bus controls
  input  logic       CacheBusAck,       // Bus operation completed
  output logic [1:0] CacheBusRW,        // [1] Read (cache line fetch) or [0] write bus (cache line writeback)
  // performance counter outputs
  output logic       CacheMiss,         // Cache miss
  output logic       CacheAccess,       // Cache access

  // cache internals
  input  logic       Hit,          // Exactly 1 way hits
  input  logic       LineDirty,         // The selected line and way is dirty
  input  logic       HitLineDirty,   // The cache hit way is dirty
  input  logic       FlushAdrFlag,      // On last set of a cache flush
  input  logic       FlushWayFlag,      // On the last way for any set of a cache flush
  output logic       SelAdrData,            // [0] SRAM reads from NextAdr, [1] SRAM reads from PAdr
  output logic       SelAdrTag,            // [0] SRAM reads from NextAdr, [1] SRAM reads from PAdr
  output logic       SetValid,          // Set the valid bit in the selected way and set
  output logic       ClearValid,        // Clear the valid bit in the selected way and set
  output logic       SetDirty,          // Set the dirty bit in the selected way and set
  output logic       ClearDirty,        // Clear the dirty bit in the selected way and set
  output logic       SelWriteback,      // Overrides cached tag check to select a specific way and set for writeback
  output logic       LRUWriteEn,        // Update the LRU state
  output logic       SelVictim,         // Overrides HitWay Tag matching.  Selects selects the victim tag/data regardless of hit
  output logic       FlushAdrCntEn,     // Enable the counter for Flush Adr
  output logic       FlushWayCntEn,     // Enable the way counter during a flush
  output logic       FlushCntRst,       // Reset both flush counters
  output logic       SelFetchBuffer,    // Bypass the SRAM for a load hit by directly using the read data from the ahbcacheinterface's FetchBuffer
  output logic       CacheEn            // Enable the cache memory arrays.  Disable hold read data constant
);

  logic              resetDelay;
  logic              AnyUpdateHit, AnyHit;
  logic              AnyMiss;
  logic              FlushFlag;
  logic              CMOWriteback;
  logic              CMOZeroNoEviction;
  logic              StallConditions;

  typedef enum logic [3:0]{STATE_ACCESS, // hit states
                           // miss states
                           STATE_FETCH,
                           STATE_WRITEBACK,
                           STATE_WRITE_LINE,
                           STATE_ADDRESS_SETUP,  // required for back to back reads. structural hazard on writing SRAM
                           // flush cache
                           STATE_FLUSH,
                           STATE_FLUSH_WRITEBACK
                           } statetype;

  statetype CurrState, NextState;

  assign AnyMiss = (CacheRW[0] | CacheRW[1]) & ~Hit & ~InvalidateCache; // exclusion-tag: cache AnyMiss
  assign AnyUpdateHit = (CacheRW[0]) & Hit;                            // exclusion-tag: icache storeAMO1
  assign AnyHit = AnyUpdateHit | (CacheRW[1] & Hit);                  // exclusion-tag: icache AnyUpdateHit
  assign CMOZeroNoEviction = CMOpM[3] & ~LineDirty;   // (hit or miss) with no writeback store zeros now
  assign CMOWriteback = ((CMOpM[1] | CMOpM[2]) & Hit & HitLineDirty) | CMOpM[3] & LineDirty;

  assign FlushFlag = FlushAdrFlag & FlushWayFlag;

  // outputs for the performance counters.
  assign CacheAccess = (|CacheRW) & ((CurrState == STATE_ACCESS & ~Stall & ~FlushStage) | (CurrState == STATE_ADDRESS_SETUP & ~Stall & ~FlushStage)); // exclusion-tag: icache CacheW
  assign CacheMiss = CurrState == STATE_ADDRESS_SETUP & ~Stall & ~FlushStage;

  // special case on reset. When the fsm first exists reset twayhe
  // PCNextF will no longer be pointing to the correct address.
  // But PCF will be the reset vector.
  flop #(1) resetDelayReg(.clk, .d(reset), .q(resetDelay));

  always_ff @(posedge clk)
    if (reset | FlushStage)    CurrState <= STATE_ACCESS;
    else CurrState <= NextState;

  always_comb begin
    NextState = STATE_ACCESS;
    case (CurrState)                                                                                        // exclusion-tag: icache state-case
      STATE_ACCESS:           if(InvalidateCache & ~InvalidateFlushStage)                               NextState = STATE_ACCESS;     // exclusion-tag: dcache InvalidateCheck
                             else if(FlushCache & ~READ_ONLY_CACHE)            NextState = STATE_FLUSH;     // exclusion-tag: icache FLUSHStatement
                             else if(AnyMiss & (READ_ONLY_CACHE | ~LineDirty)) NextState = STATE_FETCH;     // exclusion-tag: icache FETCHStatement
                             else if((AnyMiss | CMOWriteback) & ~READ_ONLY_CACHE) NextState = STATE_WRITEBACK; // exclusion-tag: icache WRITEBACKStatement
                             else if((|CMOpM) & ~CMOWriteback)               NextState = STATE_ADDRESS_SETUP; // any CMO without dirty writeback: stall and re-read SRAM next cycle
                             else                                              NextState = STATE_ACCESS;
      STATE_FETCH:           if(CacheBusAck)                                   NextState = STATE_WRITE_LINE;
                             else                                              NextState = STATE_FETCH;
      STATE_WRITE_LINE:                                                        NextState = STATE_ADDRESS_SETUP;
      STATE_ADDRESS_SETUP:       if(Stall)                                         NextState = STATE_ADDRESS_SETUP;
                             else                                              NextState = STATE_ACCESS;
      // exclusion-tag-start: icache case
      STATE_WRITEBACK:       if(CacheBusAck & ~(|CMOpM[3:1]))                  NextState = STATE_FETCH;
                             else if(CacheBusAck)                              NextState = STATE_ADDRESS_SETUP; // Read_hold lowers CacheStall
                             else                                              NextState = STATE_WRITEBACK;
      // eviction needs a delay as the bus fsm does not correctly handle sending the write command at the same time as getting back the bus ack.
      STATE_FLUSH:           if(LineDirty)                                     NextState = STATE_FLUSH_WRITEBACK;
                             else if (FlushFlag)                               NextState = STATE_ADDRESS_SETUP;
                             else                                              NextState = STATE_FLUSH;
      STATE_FLUSH_WRITEBACK: if(CacheBusAck & ~FlushFlag)                      NextState = STATE_FLUSH;
                             else if(CacheBusAck)                              NextState = STATE_ADDRESS_SETUP;
                             else                                              NextState = STATE_FLUSH_WRITEBACK;
      // exclusion-tag-end: icache case
      default:                                                                 NextState = STATE_ACCESS;
    endcase
  end

  // com back to CPU
  assign CacheCommitted = (CurrState != STATE_ACCESS) & ~(READ_ONLY_CACHE & (CurrState == STATE_ADDRESS_SETUP));
  assign StallConditions =  FlushCache | AnyMiss | (|CMOpM);                            // exclusion-tag: icache FlushCache
  assign CacheStall = (CurrState == STATE_ACCESS & StallConditions) | // exclusion-tag: icache StallStates
                      (CurrState == STATE_FETCH) |
                      (CurrState == STATE_WRITEBACK) |
                      (CurrState == STATE_WRITE_LINE) |  // this cycle writes the sram, must keep stalling so the next cycle can read the next hit/miss unless its a write.
                      (CurrState == STATE_FLUSH) |
                      (CurrState == STATE_FLUSH_WRITEBACK);
  // write enables internal to cache
  assign SetValid = CurrState == STATE_WRITE_LINE |
                    (CurrState == STATE_ACCESS & CMOZeroNoEviction) |
                    (CurrState == STATE_WRITEBACK & CacheBusAck & CMOpM[3]);
  assign ClearValid = (CurrState == STATE_ACCESS & (CMOpM[0] | (CMOpM[2] & ~HitLineDirty))) |
  //assign ClearValid = (CurrState == STATE_ACCESS & (CMOpM[0])) |
                      (CurrState == STATE_WRITEBACK & CMOpM[2] & CacheBusAck);
  assign LRUWriteEn = (((CurrState == STATE_ACCESS & (AnyHit | CMOZeroNoEviction)) |
                       (CurrState == STATE_WRITE_LINE)) & ~FlushStage) |
                      (CurrState == STATE_WRITEBACK & CMOpM[3] & CacheBusAck);
  // exclusion-tag-start: icache flushdirtycontrols
  assign SetDirty = (CurrState == STATE_ACCESS & (AnyUpdateHit | CMOZeroNoEviction)) |         // exclusion-tag: icache SetDirty
                    (CurrState == STATE_WRITE_LINE & (CacheRW[0])) |
                    (CurrState == STATE_WRITEBACK & (CMOpM[3] & CacheBusAck));
  assign ClearDirty = (CurrState == STATE_WRITE_LINE & ~(CacheRW[0])) |   // exclusion-tag: icache ClearDirty
                      (CurrState == STATE_FLUSH & LineDirty) | // This is wrong in a multicore snoop cache protocol.  Dirty must be cleared concurrently and atomically with writeback.  For single core cannot clear after writeback on bus ack and change flushadr.  Clears the wrong set.
  // Flush and eviction controls
                      CurrState == STATE_WRITEBACK & (CMOpM[1] | CMOpM[2]) & CacheBusAck;
  assign SelVictim = (CurrState == STATE_WRITEBACK & ((~CacheBusAck & ~(CMOpM[1] | CMOpM[2])) | (CacheBusAck & CMOpM[3]))) |
                  (CurrState == STATE_ACCESS & ((AnyMiss & LineDirty) | (CMOZeroNoEviction & ~Hit))) |
                  (CurrState == STATE_WRITE_LINE);
  assign SelWriteback = (CurrState == STATE_WRITEBACK & (CMOpM[1] | CMOpM[2] | ~CacheBusAck)) |
                        (CurrState == STATE_ACCESS & AnyMiss & LineDirty);
  // coverage off -item e 1 -fecexprrow 1
  // (state is always FLUSH_WRITEBACK when FlushWayFlag & CacheBusAck)
  assign FlushAdrCntEn = (CurrState == STATE_FLUSH_WRITEBACK & FlushWayFlag & CacheBusAck) |
             (CurrState == STATE_FLUSH & FlushWayFlag & ~LineDirty);
  assign FlushWayCntEn = (CurrState == STATE_FLUSH & ~LineDirty) |
             (CurrState == STATE_FLUSH_WRITEBACK & CacheBusAck);
  assign FlushCntRst = (CurrState == STATE_FLUSH & FlushFlag & ~LineDirty) |
              (CurrState == STATE_FLUSH_WRITEBACK & FlushFlag & CacheBusAck);
  // exclusion-tag-end: icache flushdirtycontrols
  // Bus interface controls
  assign CacheBusRW[1] = (CurrState == STATE_ACCESS & AnyMiss & ~LineDirty) | // exclusion-tag: icache CacheBusRCauses
                         (CurrState == STATE_FETCH & ~CacheBusAck) |
                         (CurrState == STATE_WRITEBACK & CacheBusAck & ~(|CMOpM));

  logic LoadMiss;
  assign LoadMiss = (CacheRW[1]) & ~Hit & ~InvalidateCache; // exclusion-tag: cache AnyMiss

  assign CacheBusRW[0] = (CurrState == STATE_ACCESS & LoadMiss & LineDirty) | // exclusion-tag: icache CacheBusW
                         (CurrState == STATE_WRITEBACK & ~CacheBusAck) |
                         (CurrState == STATE_FLUSH_WRITEBACK & ~CacheBusAck) |
                         (CurrState == STATE_WRITEBACK & (CMOpM[1] | CMOpM[2]) & ~CacheBusAck);

  assign SelAdrData = (CurrState == STATE_ACCESS & (CacheRW[0] | AnyMiss | (|CMOpM))) | // exclusion-tag: icache SelAdrCauses // changes if store delay hazard removed
                  (CurrState == STATE_FETCH) |
                  (CurrState == STATE_WRITEBACK) |
                  (CurrState == STATE_WRITE_LINE) |
                  resetDelay;
  assign SelAdrTag = (CurrState == STATE_ACCESS & (AnyMiss | (|CMOpM))) | // exclusion-tag: icache SelAdrTag // changes if store delay hazard removed
                  (CurrState == STATE_FETCH) |
                  (CurrState == STATE_WRITEBACK) |
                  (CurrState == STATE_WRITE_LINE) |
                  resetDelay;
  assign SelFetchBuffer = CurrState == STATE_WRITE_LINE | CurrState == STATE_ADDRESS_SETUP;
  assign CacheEn = (~Stall | StallConditions) | (CurrState != STATE_ACCESS) | reset | InvalidateCache; // exclusion-tag: dcache CacheEn

endmodule // cachefsm
