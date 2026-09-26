///////////////////////////////////////////
// cacheway
//
// Written: Rose Thompson rose@rosethompson.net
// Created: 7 July 2021
// Modified: 20 January 2023
//
// Purpose: Storage and read/write access to data cache data, tag valid, dirty, and replacement.
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

module cacheway import cvw::*; #(parameter cvw_t P,
                  parameter PA_BITS, NUMSETS=512, LINELEN = 256, TAGLEN = 26,
                  OFFSETLEN = 5, INDEXLEN = 9, READ_ONLY_CACHE = 0) (
  input  logic                        clk,
  input  logic                        reset,
  input  logic                        FlushStage,     // Pipeline flush of second stage (prevent writes and bus operations)
  input  logic                        InvalidateFlushStage,     // Pipeline flush of second stage (prevent writes and bus operations)
  input  logic                        CacheEn,        // Enable the cache memory arrays.  Disable hold read data constant
  input  logic [$clog2(NUMSETS)-1:0]  CacheSetData,       // Cache address, the output of the address select mux, NextAdr, PAdr, or FlushAdr
  input  logic [$clog2(NUMSETS)-1:0]  CacheSetTag,       // Cache address, the output of the address select mux, NextAdr, PAdr, or FlushAdr
  input  logic [PA_BITS-1:0]          PAdr,           // Physical address
  input  logic [LINELEN-1:0]          LineWriteData,  // Final data written to cache (D$ only)
  input  logic                        SetValid,       // Set the valid bit in the selected way and set
  input  logic                        ClearValid,     // Clear the valid bit in the selected way and set
  input  logic                        SetDirty,       // Set the dirty bit in the selected way and set
  input  logic                        SelVictim,      // Overrides HitWay Tag matching.  Selects selects the victim tag/data regardless of hit
  input  logic                        ClearDirty,     // Clear the dirty bit in the selected way and set
  input  logic                        FlushCache,       // [0] Use SelAdr, [1] SRAM reads/writes from FlushAdr
  input  logic                        VictimWay,      // LRU selected this way as victim to evict
  input  logic                        FlushWay,       // This way is selected for flush and possible writeback if dirty
  input  logic                        InvalidateCache,// Clear all valid bits
  input  logic [LINELEN/8-1:0]        LineByteMask,   // Final byte enables to cache (D$ only)

  output logic [LINELEN-1:0]          ReadDataLineWay,// This way's read data if valid
  output logic                        HitWay,         // This way hits
  output logic                        ValidWay,       // This way is valid
  output logic                        HitDirtyWay,    // The hit way is dirty
  output logic                        DirtyWay   ,    // The selected way is dirty
  output logic [TAGLEN-1:0]           TagWay);        // This way's tag if valid

  logic [NUMSETS-1:0]                ValidBits;
  logic [NUMSETS-1:0]                DirtyBits;
  logic [LINELEN-1:0]                 ReadDataLine;
  logic [TAGLEN-1:0]                  ReadTag;
  logic                               Dirty;
  logic                               SelecteDirty;
  logic                               SelectedWriteWordEn;
  logic [LINELEN/8-1:0]               FinalByteMask;
  logic                               SetValidEN, ClearValidEN;
  logic                               SetValidWay;
  logic                               ClearValidWay;
  logic                               SetDirtyWay;
  logic                               ClearDirtyWay;
  logic                               SelectedWay;
  logic                               InvalidateCacheDelay;

  if (!READ_ONLY_CACHE) begin : flushlogic
    mux2 #(1) seltagmux(VictimWay, FlushWay, FlushCache, SelecteDirty);
    mux3 #(1) selectedmux(HitWay, FlushWay, VictimWay, {SelVictim, FlushCache}, SelectedWay);
    // FlushWay is part of a one hot way selection. Must clear it if FlushWay not selected.
    // coverage off -item e 1 -fecexprrow 3
    // nonzero ways will never see FlushCache=0 while FlushWay=1 since FlushWay only advances on a subset of FlushCache assertion cases.
  end else begin : flushlogic // no flush operation for read-only caches.
    assign SelecteDirty = VictimWay;
  mux2 #(1) selectedwaymux(HitWay, SelecteDirty, SelVictim , SelectedWay);
  end



  /////////////////////////////////////////////////////////////////////////////////////////////
  // Write Enable demux
  /////////////////////////////////////////////////////////////////////////////////////////////

  assign SetValidWay = SetValid & SelectedWay;
  assign ClearValidWay = ClearValid & SelectedWay;                             // exclusion-tag: icache ClearValidWay
  assign SetDirtyWay = SetDirty & SelectedWay;                                 // exclusion-tag: icache SetDirtyWay
  assign ClearDirtyWay = ClearDirty & SelectedWay;
  assign SelectedWriteWordEn = (SetValidWay | SetDirtyWay) & ~FlushStage;  // exclusion-tag: icache SelectedWiteWordEn
  assign SetValidEN = SetValidWay & ~FlushStage;                           // exclusion-tag: cache SetValidEN
  assign ClearValidEN = ClearValidWay & ~FlushStage;                       // exclusion-tag: cache ClearValidEN

  // If writing the whole line set all write enables to 1, else only set the correct word.
  assign FinalByteMask = SetValidWay ? '1 : LineByteMask; // OR

  /////////////////////////////////////////////////////////////////////////////////////////////
  // Tag Array
  /////////////////////////////////////////////////////////////////////////////////////////////

  ram1p1rwe #(.USE_SRAM(P.USE_SRAM), .DEPTH(NUMSETS), .WIDTH(TAGLEN)) CacheTagMem(.clk, .ce(CacheEn),
    .addr(CacheSetTag), .dout(ReadTag),
    .din(PAdr[PA_BITS-1:OFFSETLEN+INDEXLEN]), .we(SetValidEN));

  // AND portion of distributed tag multiplexer
  assign TagWay = SelectedWay ? ReadTag : 0; // AND part of AOMux
  assign HitDirtyWay = Dirty & ValidWay;
  assign DirtyWay = SelecteDirty & HitDirtyWay;                               // exclusion-tag: icache DirtyWay
  assign HitWay = ValidWay & (ReadTag == PAdr[PA_BITS-1:OFFSETLEN+INDEXLEN]) & ~InvalidateCacheDelay; // exclusion-tag: dcache HitWay

  flopenrc #(1) InvalidateCacheReg(clk, 1'b0, InvalidateFlushStage, 1'b1, InvalidateCache, InvalidateCacheDelay);

  /////////////////////////////////////////////////////////////////////////////////////////////
  // Data Array
  /////////////////////////////////////////////////////////////////////////////////////////////

  genvar               words;

  localparam           NUMSRAM = LINELEN/P.CACHE_SRAMLEN;
  localparam           SRAMLENINBYTES = P.CACHE_SRAMLEN/8;

  for (words = 0; words < NUMSRAM; words++) begin : word
    if (READ_ONLY_CACHE) begin : wordram // no byte-enable needed for i$.
      ram1p1rwe #(.USE_SRAM(P.USE_SRAM), .DEPTH(NUMSETS), .WIDTH(P.CACHE_SRAMLEN)) CacheDataMem(.clk, .ce(CacheEn), .addr(CacheSetData),
      .dout(ReadDataLine[P.CACHE_SRAMLEN*(words+1)-1:P.CACHE_SRAMLEN*words]),
      .din(LineWriteData[P.CACHE_SRAMLEN*(words+1)-1:P.CACHE_SRAMLEN*words]),
      .we(SelectedWriteWordEn));
    end else begin : wordram // D$ needs byte enables
     ram1p1rwbe #(.USE_SRAM(P.USE_SRAM), .DEPTH(NUMSETS), .WIDTH(P.CACHE_SRAMLEN)) CacheDataMem(.clk, .ce(CacheEn), .addr(CacheSetData),
      .dout(ReadDataLine[P.CACHE_SRAMLEN*(words+1)-1:P.CACHE_SRAMLEN*words]),
      .din(LineWriteData[P.CACHE_SRAMLEN*(words+1)-1:P.CACHE_SRAMLEN*words]),
      .we(SelectedWriteWordEn), .bwe(FinalByteMask[SRAMLENINBYTES*(words+1)-1:SRAMLENINBYTES*words]));
     end
  end

  // AND portion of distributed read multiplexers
  assign ReadDataLineWay = SelectedWay ? ReadDataLine : '0;  // AND part of AO mux.

  /////////////////////////////////////////////////////////////////////////////////////////////
  // Valid Bits
  /////////////////////////////////////////////////////////////////////////////////////////////

  always_ff @(posedge clk) begin // Valid bit array,
    if (reset) ValidBits        <= '0;
    if (CacheEn) begin
      ValidWay <= ValidBits[CacheSetTag];
      if(InvalidateCache & ~InvalidateFlushStage)    ValidBits <= '0; // exclusion-tag: dcache invalidateway
      else if (SetValidEN) ValidBits[CacheSetData] <= SetValidWay;
      else if (ClearValidEN) ValidBits[CacheSetData] <= '0; // exclusion-tag: icache ClearValidBits
    end
  end

  /////////////////////////////////////////////////////////////////////////////////////////////
  // Dirty Bits
  /////////////////////////////////////////////////////////////////////////////////////////////

  // Dirty bits
  if (!READ_ONLY_CACHE) begin : dirty
    always_ff @(posedge clk) begin
      // reset is optional.  Consider merging with TAG array in the future.
      //if (reset) DirtyBits <= {NUMSETS{1'b0}};
      if (CacheEn) begin
        Dirty <= DirtyBits[CacheSetTag];
        if ((SetDirtyWay | ClearDirtyWay) & ~FlushStage) begin
          DirtyBits[CacheSetData] <= SetDirtyWay; // exclusion-tag: cache UpdateDirty
          if (CacheSetData == CacheSetTag) Dirty <= SetDirtyWay;
          else Dirty <= DirtyBits[CacheSetTag];
        end
      end
    end
  end else assign Dirty = 1'b0;
endmodule
