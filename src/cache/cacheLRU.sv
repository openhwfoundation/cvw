///////////////////////////////////////////
// cacheLRU.sv
//
// Written: Rose Thompson rose@rosethompson.net
// Created: 20 July 2021
// Modified: 20 January 2023
//
// Purpose: Implements Pseudo LRU. Tested for Powers of 2.
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

module cacheLRU
  #(parameter NUMWAYS = 4, SETLEN = 9, NUMSETS = 128) (
  input  logic                clk,
  input  logic                reset,
  input  logic                InvalidateFlushStage,
  input  logic                CacheEn,         // Enable the cache memory arrays.  Disable hold read data constant
  input  logic [NUMWAYS-1:0]  HitWay,          // Which way is valid and matches PAdr's tag
  input  logic [NUMWAYS-1:0]  ValidWay,        // Which ways for a particular set are valid, ignores tag
  input  logic [SETLEN-1:0]   CacheSetLRU,     // Cache address, the output of the address select mux, NextAdr, PAdr, or FlushAdr
  input  logic [SETLEN-1:0]   PAdr,            // Physical address
  input  logic                LRUWriteEn,      // Update the LRU state
  input  logic                SetValid,        // Set the dirty bit in the selected way and set
  input  logic                InvalidateCache, // Clear all valid bits
  output logic [NUMWAYS-1:0]  VictimWay        // LRU selects a victim to evict
);

  localparam                           LOGNUMWAYS = $clog2(NUMWAYS);

  logic [NUMWAYS-2:0]                  LRUMemory [NUMSETS-1:0];
  logic [NUMWAYS-2:0]                  CurrLRU, NextLRU, ReadLRU, BypassedLRU;
  logic [LOGNUMWAYS-1:0]               HitWayEncoded, Way;
  logic [NUMWAYS-2:0]                  WayExpanded;
  logic                                AllValid;
  logic                                ForwardLRU;

  genvar                               row;

  /* verilator lint_off UNOPTFLAT */
  // Rose: For some reason verilator does not like this.  I checked and it is not a circular path.
  logic [NUMWAYS-2:0]                  LRUUpdate;
  logic [LOGNUMWAYS-1:0] Intermediate [NUMWAYS-2:0];
  /* verilator lint_on UNOPTFLAT */

  logic [NUMWAYS-1:0] FirstZero;
  logic [LOGNUMWAYS-1:0] FirstZeroWay;
  logic [LOGNUMWAYS-1:0] VictimWayEnc;

  binencoder #(NUMWAYS) hitwayencoder(HitWay, HitWayEncoded);

  assign AllValid = &ValidWay;

  ///// Update replacement bits.
  // coverage off
  // Excluded from coverage b/c it is untestable without varying NUMWAYS.
  function integer log2 (integer value);
    int val;
    val = value;
    for (log2 = 0; val > 0; log2 = log2+1)
      val = val >> 1;
    return log2;
  endfunction // log2
  // coverage on

  // On a miss we need to ignore HitWay and derive the new replacement bits with the VictimWay.
  mux2 #(LOGNUMWAYS) WayMuxEnc(HitWayEncoded, VictimWayEnc, SetValid, Way);

  // bit duplication
  // expand HitWay as HitWay[3], {{2}{HitWay[2]}}, {{4}{HitWay[1]}, {{8{HitWay[0]}}, ...
  for(row = 0; row < LOGNUMWAYS; row++) begin
    localparam integer DuplicationFactor = 2**(LOGNUMWAYS-row-1);
    localparam StartIndex = NUMWAYS-2 - DuplicationFactor + 1;
    localparam EndIndex = NUMWAYS-2 - 2 * DuplicationFactor + 2;
    assign WayExpanded[StartIndex : EndIndex] = {{DuplicationFactor}{Way[row]}};
  end

  genvar               node;
  assign LRUUpdate[NUMWAYS-2] = '1;
  for(node = NUMWAYS-2; node >= NUMWAYS/2; node--) begin : enables
    localparam ctr = NUMWAYS - node - 1;
    localparam ctr_depth = log2(ctr);
    localparam lchild = node - ctr;
    localparam rchild = lchild - 1;
    localparam r = LOGNUMWAYS - ctr_depth;

    // the child node will be updated if its parent was updated and
    // the Way bit was the correct value.
    // The if statement is only there for coverage since LRUUpdate[root] is always 1.
    if (node == NUMWAYS-2) begin
      assign LRUUpdate[lchild] = ~Way[r];
      assign LRUUpdate[rchild] = Way[r];
    end else begin
      assign LRUUpdate[lchild] = LRUUpdate[node] & ~Way[r];
      assign LRUUpdate[rchild] = LRUUpdate[node] & Way[r];
    end
  end

  // The root node of the LRU tree will always be selected in LRUUpdate. No mux needed.
  assign NextLRU[NUMWAYS-2] = ~WayExpanded[NUMWAYS-2];
  if (NUMWAYS > 2) mux2 #(1) LRUMuxes[NUMWAYS-3:0](CurrLRU[NUMWAYS-3:0], ~WayExpanded[NUMWAYS-3:0], LRUUpdate[NUMWAYS-3:0], NextLRU[NUMWAYS-3:0]);

  // Compute next victim way.
  for(node = NUMWAYS-2; node >= NUMWAYS/2; node--) begin
    localparam t0 = 2*node - NUMWAYS;
    localparam t1 = t0 + 1;
    assign Intermediate[node] = CurrLRU[node] ? Intermediate[t0] : Intermediate[t1];
  end
  for(node = NUMWAYS/2-1; node >= 0; node--) begin
    localparam int0 = (NUMWAYS/2-1-node)*2;
    localparam int1 = int0 + 1;
    assign Intermediate[node] = CurrLRU[node] ? int1[LOGNUMWAYS-1:0] : int0[LOGNUMWAYS-1:0];
  end

  priorityonehot #(NUMWAYS) FirstZeroEncoder(~ValidWay, FirstZero);
  binencoder #(NUMWAYS) FirstZeroWayEncoder(FirstZero, FirstZeroWay);
  mux2 #(LOGNUMWAYS) VictimMux(FirstZeroWay, Intermediate[NUMWAYS-2], AllValid, VictimWayEnc);
  decoder #(LOGNUMWAYS) decoder (VictimWayEnc, VictimWay);

  // LRU memory must be reset for Questa to run. The reset value does not matter but it is best to be deterministc.
  always_ff @(posedge clk)
    if (reset | (InvalidateCache & ~InvalidateFlushStage))
      for (int set = 0; set < NUMSETS; set++) LRUMemory[set] <= '0; // exclusion-tag: initialize
    else if (CacheEn & LRUWriteEn) LRUMemory[PAdr] <= NextLRU;

  // LRU read path with write forwarding
  assign ReadLRU = LRUMemory[CacheSetLRU];
  assign ForwardLRU = LRUWriteEn & (PAdr == CacheSetLRU);
  mux2 #(NUMWAYS-1) ReadLRUmux(ReadLRU, NextLRU, ForwardLRU, BypassedLRU);
  flop #(NUMWAYS-1) CurrLRUReg(clk, BypassedLRU, CurrLRU);
endmodule
