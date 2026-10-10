///////////////////////////////////////////
// ahbcacheinterface.sv
//
// Written: Rose Thompson rose@rosethompson.net
// Created: August 29, 2022
// Modified: 18 January 2023
//
// Purpose: Translates cache bus requests and uncached ieu memory requests into AHB transactions.
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

module ahbcacheinterface import cvw::*; #(
  parameter cvw_t P,
  parameter BEATSPERLINE,  // Number of AHBW words (beats) in cacheline
  parameter AHBWLOGBWPL,   // Log2 of ^
  parameter LINELEN,       // Number of bits in cacheline
  parameter LLENPOVERAHBW, // Number of AHB beats in an LLEN word. AHBW cannot be larger than LLEN. (implementation limitation)
  parameter READ_ONLY_CACHE
)(
  input  logic                   HCLK, HRESETn,          // AHB clock and reset (active low)
  // bus interface controls
  input  logic                   HREADY,                 // AHB ready
  output logic [1:0]             HTRANS,                 // AHB transfer type: 00 IDLE, 10 NONSEQ, 11 SEQ
  output logic                   HWRITE,                 // AHB write (1) or read (0)
  output logic [2:0]             HSIZE,                  // AHB transfer size
  output logic [2:0]             HBURST,                 // AHB burst type
  // bus interface buses
  input  logic [P.AHBW-1:0]      HRDATA,                 // AHB read data
  output logic [P.PA_BITS-1:0]   HADDR,                  // AHB address
  output logic [P.AHBW-1:0]      HWDATA,                 // AHB write data
  output logic [P.AHBW/8-1:0]    HWSTRB,                 // AHB byte write enables

  // cache interface
  input  logic [P.PA_BITS-1:0]   CacheBusAdr,            // Cache line address for bus access
  input  logic [P.LLEN-1:0]      CacheReadDataWordM,     // One word of cache line during a writeback
  input  logic                   CacheableOrFlushCacheM, // Memory operation is cacheable or flushing D$
  input  logic                   Cacheable,              // PMA indicates memory address is cacheable
  input  logic [1:0]             CacheBusRW,             // Cache bus operation: 10 line fetch, 01 line writeback
  output logic                   CacheBusAck,            // Bus operation for the cache completed
  output logic [LINELEN-1:0]     FetchBuffer,            // Data captured from the bus
  output logic [AHBWLOGBWPL-1:0] BeatCount,              // Beat within the cache line in the Address phase
  output logic                   SelBusBeat,             // Select the cache line word from BeatCount rather than PAdr

  // uncached interface
  input  logic [P.PA_BITS-1:0]   PAdr,                   // Physical address
  input  logic [P.LLEN-1:0]      WriteDataM,             // Write data from IEU
  input  logic [1:0]             BusRW,                  // Uncached memory operation: 10 read, 01 write
  input  logic                   BusAtomic,              // Uncached atomic memory operation
  input  logic [2:0]             Size,                   // Access size (log2 bytes)
  input  logic                   BusCMOZero,             // Uncached cbo.zero must write zero to full sized cacheline without going through the cache

  // lsu/ifu interface
  input  logic                   Stall,                  // Pipeline is stalled
  input  logic                   Flush,                  // Pipeline stage flush. Prevents bus transaction from starting
  output logic                   BusStall,               // Bus is busy with an in flight memory operation
  output logic                   BusCommitted);          // Bus is busy with an in flight memory operation and it is not safe to take an interrupt

  localparam              BeatCountThreshold = BEATSPERLINE - 1;      // Largest beat index
  logic [P.PA_BITS-1:0]   LocalHADDR;                                 // Address after selecting between cached and uncached operation
  logic [AHBWLOGBWPL-1:0] BeatCountDelayed;                           // Beat within the cache line in the second (Data) cache stage
  logic                   CaptureEn;                                  // Enable updating the Fetch buffer with valid data from HRDATA
  logic [P.AHBW-1:0]      PreHWDATA;                                  // AHB Address phase write data
  logic [P.PA_BITS-1:0]   PAdrZero;

  genvar                      index;

  // fetch buffer is made of BEATSPERLINE flip-flops
  for (index = 0; index < BEATSPERLINE; index++) begin : fetchbufferbeat
    logic [BEATSPERLINE-1:0] CaptureBeat;
    assign CaptureBeat[index] = CaptureEn & (index == BeatCountDelayed);
    flopen #(P.AHBW) fb(.clk(HCLK), .en(CaptureBeat[index]), .d(HRDATA),
      .q(FetchBuffer[(index+1)*P.AHBW-1:index*P.AHBW]));
  end

  assign PAdrZero = BusCMOZero ? {PAdr[P.PA_BITS-1:$clog2(LINELEN/8)], {$clog2(LINELEN/8){1'b0}}} : PAdr;
  mux2 #(P.PA_BITS) localadrmux(PAdrZero, CacheBusAdr, Cacheable, LocalHADDR);
  assign HADDR = ({{P.PA_BITS-AHBWLOGBWPL{1'b0}}, BeatCount} << $clog2(P.AHBW/8)) + LocalHADDR;

  mux2 #(3) sizemux(.d0(Size), .d1(P.AHBW == 32 ? 3'b010 : 3'b011), .s(Cacheable | BusCMOZero), .y(HSIZE));

  // When AHBW is less than LLEN need extra muxes to select the subword from cache's read data.
  logic [P.AHBW-1:0]          CacheReadDataWordAHB;
  if (LLENPOVERAHBW > 1) begin
    logic [P.AHBW-1:0]          AHBWordSets [(LLENPOVERAHBW)-1:0];
    genvar                     index;
    for (index = 0; index < LLENPOVERAHBW; index++) begin : readdatalinesetsmux
      assign AHBWordSets[index] = CacheReadDataWordM[(index*P.AHBW)+P.AHBW-1: (index*P.AHBW)];
    end
    assign CacheReadDataWordAHB = AHBWordSets[BeatCount[$clog2(LLENPOVERAHBW)-1:0]];
  end else assign CacheReadDataWordAHB = CacheReadDataWordM[P.AHBW-1:0];

  mux2 #(P.AHBW) HWDATAMux(.d0(CacheReadDataWordAHB), .d1(WriteDataM[P.AHBW-1:0]),
    .s(~(CacheableOrFlushCacheM)), .y(PreHWDATA));
  flopen #(P.AHBW) wdreg(HCLK, HREADY, PreHWDATA, HWDATA); // delay HWDATA by 1 cycle per spec

  if (READ_ONLY_CACHE) begin
    assign HWSTRB = '0;
  end else begin // compute byte mask for AHB transaction based on size and address.  AHBW may be different than LLEN
    logic [P.AHBW/8-1:0]          BusByteMaskM;                           // Byte enables within a word. For cache request all 1s

    swbytemask #(P.AHBW) busswbytemask(.Size(HSIZE), .Adr(HADDR[$clog2(P.AHBW/8)-1:0]), .ByteMask(BusByteMaskM), .ByteMaskExtended());
    flopen #(P.AHBW/8) HWSTRBReg(HCLK, HREADY, BusByteMaskM[P.AHBW/8-1:0], HWSTRB);
  end

  buscachefsm #(BeatCountThreshold, AHBWLOGBWPL, READ_ONLY_CACHE, P.BURST_EN) AHBBuscachefsm(
    .HCLK, .HRESETn, .Flush, .BusRW, .BusAtomic, .Stall, .BusCommitted, .BusStall, .CaptureEn, .SelBusBeat,
    .CacheBusRW, .BusCMOZero, .CacheBusAck, .BeatCount, .BeatCountDelayed,
    .HREADY, .HTRANS, .HWRITE, .HBURST);
endmodule
