///////////////////////////////////////////
// DCacheFlushFSM.sv
//
// Written: David Harris David_Harris@hmc.edu and Rose Thompson rose@rosethompson.net
// Modified: 14 June 2023
//
// Purpose: The L1 data cache and any feature L2 or high cache will not necessary writeback all dirty
//          line before the end of test.  Signature based regression tests need to check the L1 data cache
//          in addition to the main memory.  These modules create a shadow memory with a projection of the
//          D$ contents.
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
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

module DCacheFlushFSM import cvw::*; #(parameter cvw_t P)
  (input logic clk,
   input logic start,
   output logic done);

  genvar adr;

  logic [P.XLEN-1:0] ShadowRAM[P.UNCORE_RAM_BASE>>(1+P.XLEN/32):(P.UNCORE_RAM_RANGE+P.UNCORE_RAM_BASE)>>1+(P.XLEN/32)];
  logic         startD;

  if(P.DCACHE_SUPPORTED) begin
    localparam numlines       = P.DCACHE_WAYSIZEINBYTES*8/P.DCACHE_LINELENINBITS;
    localparam numways        = P.DCACHE_NUMWAYS;
    localparam linelen        = P.DCACHE_LINELENINBITS;
    localparam linebytelen    = linelen/8;
    localparam sramlen        = P.CACHE_SRAMLEN;
    localparam cachesramwords = linelen/sramlen;
    localparam numwords       = sramlen/P.XLEN;
    localparam lognumlines    = $clog2(numlines);
    localparam loglinebytelen = $clog2(linebytelen);
    localparam lognumways     = $clog2(numways);
    localparam tagstart       = lognumlines + loglinebytelen;

    genvar               index, way, cacheWord;
    logic [sramlen-1:0]  CacheData  [numways-1:0] [numlines-1:0] [cachesramwords-1:0];
    logic [sramlen-1:0]  cacheline;
    logic [P.XLEN-1:0]    CacheTag   [numways-1:0] [numlines-1:0] [cachesramwords-1:0];
    logic                CacheValid [numways-1:0] [numlines-1:0] [cachesramwords-1:0];
    logic                CacheDirty [numways-1:0] [numlines-1:0] [cachesramwords-1:0];
    logic [P.PA_BITS-1:0] CacheAdr   [numways-1:0] [numlines-1:0] [cachesramwords-1:0];
    for(index = 0; index < numlines; index++) begin
      for(way = 0; way < numways; way++) begin
        for(cacheWord = 0; cacheWord < cachesramwords; cacheWord++) begin
          copyShadow #(.P(P), .tagstart(tagstart),
          .loglinebytelen(loglinebytelen), .sramlen(sramlen))
          copyShadow(.clk,
          .start,
          .tag(testbench.dut.core.lsu.bus.dcache.dcache.CacheWays[way].CacheTagMem.ram.RAM[index][P.PA_BITS-1-tagstart:0]),
          .valid(testbench.dut.core.lsu.bus.dcache.dcache.CacheWays[way].ValidBits[index]),
          .dirty(testbench.dut.core.lsu.bus.dcache.dcache.CacheWays[way].DirtyBits[index]),
                           // these dirty bit selections would be needed if dirty is moved inside the tag array.
          //.dirty(testbench.dut.core.lsu.bus.dcache.dcache.CacheWays[way].dirtyarray.DirtyMem.RAM[index]),
          //.dirty(testbench.dut.core.lsu.bus.dcache.dcache.CacheWays[way].CacheTagMem.RAM[index][P.PA_BITS+tagstart]),
          .data(testbench.dut.core.lsu.bus.dcache.dcache.CacheWays[way].word[cacheWord].wordram.CacheDataMem.ram.RAM[index]),
          .index(index),
          .cacheWord(cacheWord),
          .CacheData(CacheData[way][index][cacheWord]),
          .CacheAdr(CacheAdr[way][index][cacheWord]),
          .CacheTag(CacheTag[way][index][cacheWord]),
          .CacheValid(CacheValid[way][index][cacheWord]),
          .CacheDirty(CacheDirty[way][index][cacheWord]));
        end
      end
    end

    integer i, j, k, l;

    always @(posedge clk) begin
      if (startD) begin
        for(i = 0; i < numlines; i++) begin
          for(j = 0; j < numways; j++) begin
            for(l = 0; l < cachesramwords; l++) begin
              if (CacheValid[j][i][l] & CacheDirty[j][i][l]) begin
                for(k = 0; k < numwords; k++) begin
                  //cacheline = CacheData[j][i][0];
                  // does not work with modelsim
                  // # ** Error: ../testbench/testbench.sv(483): Range must be bounded by constant expressions.
                  // see https://verificationacademy.com/forums/systemverilog/range-must-be-bounded-constant-expressions
                  //ShadowRAM[CacheAdr[j][i][k] >> $clog2(P.XLEN/8)] = cacheline[P.XLEN*(k+1)-1:P.XLEN*k];
                  /* verilator lint_off WIDTHTRUNC */
                  // avoid lint error: address trunc warning for shadowram index
                  ShadowRAM[(CacheAdr[j][i][l] >> $clog2(P.XLEN/8)) + {{{P.PA_BITS-32}{1'b0}}, k}] = CacheData[j][i][l][P.XLEN*k +: P.XLEN];
                  /* verilator lint_on WIDTHTRUNC */
                end
              end
            end
          end
        end
      end
    end
  end
  flop #(1) doneReg1(.clk, .d(start), .q(startD));
  flop #(1) doneReg2(.clk, .d(startD), .q(done));
endmodule

module copyShadow import cvw::*; #(parameter cvw_t P,
  parameter tagstart, loglinebytelen, sramlen)
  (input  logic                       clk,
   input  logic                       start,
   input  logic [P.PA_BITS-1:tagstart] tag,
   input  logic                       valid, dirty,
   input  logic [sramlen-1:0]         data,
   input  logic [32-1:0]              index,
   input  logic [32-1:0]              cacheWord,
   output logic [sramlen-1:0]         CacheData,
   output logic [P.PA_BITS-1:0]        CacheAdr,
   output logic [P.XLEN-1:0]           CacheTag,
   output logic                       CacheValid,
   output logic                       CacheDirty);

  logic [P.XLEN+1:0]               TagExtend;
  logic [P.XLEN+1:0]               IndexExtend;
  logic [P.XLEN+1:0]               CacheWordExtend;
  logic [P.XLEN+1:0]               CacheAdrExtend;

  assign TagExtend = {{{P.XLEN-(P.PA_BITS-tagstart)+2}{1'b0}}, tag};
  assign IndexExtend = {{{P.XLEN-32+2}{1'b0}}, index};
  assign CacheWordExtend = {{{P.XLEN-32+2}{1'b0}}, cacheWord};

  always_ff @(posedge clk) begin
    if(start) begin
      CacheTag = TagExtend[P.XLEN-1:0];
      CacheValid = valid;
      CacheDirty = dirty;
      CacheData = data;
      CacheAdrExtend = (TagExtend << tagstart) + (IndexExtend << loglinebytelen) + (CacheWordExtend << $clog2(sramlen/8));
    end
  end

  assign CacheAdr = CacheAdrExtend[P.PA_BITS-1:0];

endmodule
