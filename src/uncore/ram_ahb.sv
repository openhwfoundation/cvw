///////////////////////////////////////////
// ram_ahb.sv
//
// Written: David_Harris@hmc.edu 9 January 2021
// Modified:
//
// Purpose: On-chip RAM, external to core, with AHB interface
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

module ram_ahb import cvw::*;  #(parameter cvw_t P,
                                 parameter RANGE = 65535, PRELOAD = 0) (
  input  logic                 HCLK, HRESETn,
  input  logic                 HSELRam,
  input  logic [P.PA_BITS-1:0] HADDR,
  input  logic                 HWRITE,
  input  logic                 HREADY,
  input  logic [1:0]           HTRANS,
  input  logic [P.XLEN-1:0]    HWDATA,
  input  logic [P.XLEN/8-1:0]  HWSTRB,
  output logic [P.XLEN-1:0]    HREADRam,
  output logic                 HRESPRam, HREADYRam
);

  localparam                   ADDR_WIDTH = $clog2(RANGE/8);
  localparam                   OFFSET = $clog2(P.XLEN/8);

  logic [P.XLEN/8-1:0]         ByteMask;
  logic [P.PA_BITS-1:0]        HADDRD, RamAddr;
  logic                        initTrans;
  logic                        memwrite, memwriteD, memread;
  logic                        nextHREADYRam;
  logic                        DelayReady;

  // a new AHB transactions starts when HTRANS requests a transaction,
  // the peripheral is selected, and the previous transaction is completing
  assign initTrans = HREADY & HSELRam & HTRANS[1] ;
  assign memwrite  = initTrans & HWRITE;
  assign memread   = initTrans & ~HWRITE;

  flopenr #(1) memwritereg(HCLK, ~HRESETn, HREADY, memwrite, memwriteD);
  flopenr #(P.PA_BITS)   haddrreg(HCLK, ~HRESETn, HREADY, HADDR, HADDRD);

  // Stall on a read after a write because the RAM can't take both addresses on the same cycle
  assign nextHREADYRam = (~(memwriteD & memread)) & ~DelayReady;
  flopr #(1) readyreg(HCLK, ~HRESETn, nextHREADYRam, HREADYRam);

  assign HRESPRam = 1'b0; // OK

  // On writes or during a wait state, use address delayed by one cycle to sync RamAddr with HWDATA or hold stalled address
  mux2 #(P.PA_BITS) adrmux(HADDR, HADDRD, memwriteD | ~HREADY, RamAddr);

  // single-ported RAM
  ram1p1rwbe #(P.USE_SRAM, RANGE/8, P.XLEN, PRELOAD) memory(.clk(HCLK), .ce(1'b1),
    .addr(RamAddr[ADDR_WIDTH+OFFSET-1:OFFSET]), .we(memwriteD), .din(HWDATA), .bwe(HWSTRB), .dout(HREADRam));

  // use this to add arbitrary latency to ram. Helps test AHB controller correctness
  if(P.RAM_LATENCY > 0) begin
    logic [7:0]       NextCycle, Cycle;
    logic             CntEn, CntRst;
    logic             CycleFlag;

    flopenr #(8) counter (HCLK, ~HRESETn | CntRst, CntEn, NextCycle, Cycle);
    assign NextCycle = Cycle + 1'b1;

    typedef enum      logic  {READY, DELAY} statetype;
    statetype CurrState, NextState;

    always_ff @(posedge HCLK)
      if (~HRESETn)    CurrState <= READY;
      else             CurrState <= NextState;

    always_comb begin
    case(CurrState)
      READY: if(initTrans & ~CycleFlag) NextState = DELAY;
        else                            NextState = READY;
        DELAY: if(CycleFlag)            NextState = READY;
    else                                NextState = DELAY;
      default:                          NextState = READY;
    endcase
    end

    assign CycleFlag = Cycle == P.RAM_LATENCY[7:0];
    assign CntEn = NextState == DELAY;
    assign DelayReady = NextState == DELAY;
    assign CntRst = NextState == READY;
  end else begin
    assign DelayReady = 1'b0;
  end

endmodule
