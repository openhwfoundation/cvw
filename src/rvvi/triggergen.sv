///////////////////////////////////////////
// triggergen.sv
//
// Written: Rose Thompson rose@rosethompson.net
// Created: June 26, 2024
// Modified: June 26, 2024
//
// Purpose: Scans for specific ethernet frame to generate an ila trigger.
//
// Documentation:
//
// A component of the CORE-V-WALLY configurable RISC-V project.
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

module triggergen import cvw::*; (
  input  logic        clk, reset,
  input  logic [31:0] RvviAxiRdata,
  input  logic [3:0]  RvviAxiRstrb,
  input  logic        RvviAxiRlast,
  input  logic        RvviAxiRvalid,
  output logic        IlaTrigger);

  typedef enum logic [2:0] {STATE_RST, STATE_COMPARE, STATE_MISMATCH, STATE_TRIGGER, STATE_TRIGGER_DONE} statetype;
(* mark_debug = "true" *)  statetype CurrState, NextState;

  logic [31:0] mem [4:0];
  logic [2:0]  Counter;
  logic        CounterEn, CounterRst;
  logic [31:0] RvviAxiRdataDelay;
  logic [3:0]  RvviAxiRstrbDelay;
  logic        RvviAxiRvalidDelay;
  logic        Match, Overflow, Mismatch, Threshold;
  logic        IlaTriggerOneCycle;

  assign mem[0] = 32'h1111_6843; // dst mac [31:0]
  assign mem[1] = 32'h1654_4502; // src mac [15:0], dst mac [47:32]
  assign mem[2] = 32'h8f54_0000; // src mac [47:16]
  assign mem[3] = 32'h7274_005c; // "rt", ether type 005c
  assign mem[4] = 32'h6e69_6769; // "igin" (trigin)

  flopenr #(32) rvviaxirdatareg(clk, reset, RvviAxiRvalid, RvviAxiRdata, RvviAxiRdataDelay);
  flopenr #(4) rvviaxirstrbreg(clk, reset, RvviAxiRvalid, RvviAxiRstrb, RvviAxiRstrbDelay);
  flopr #(1) rvviaxirvalidreg(clk, reset, RvviAxiRvalid, RvviAxiRvalidDelay);

  counter #(3) counter(clk, CounterRst, CounterEn, Counter);

  always_ff @(posedge clk) begin
    if (reset) CurrState <= STATE_RST;
    else      CurrState <= NextState;
  end

  always_comb begin
    case (CurrState)
      STATE_RST: if (RvviAxiRvalid) NextState = STATE_COMPARE;
                 else NextState = STATE_RST;
      STATE_COMPARE: if (RvviAxiRlast) NextState = STATE_RST;
                     else if (Mismatch | Overflow) NextState = STATE_MISMATCH;
                     else if (Threshold & Match) NextState = STATE_TRIGGER;
                     else NextState = STATE_COMPARE;
      STATE_MISMATCH: if (RvviAxiRlast) NextState = STATE_RST;
                      else NextState = STATE_MISMATCH;
      STATE_TRIGGER: if (RvviAxiRlast) NextState = STATE_RST;
                     else NextState = STATE_TRIGGER_DONE;
      STATE_TRIGGER_DONE: if (RvviAxiRlast) NextState = STATE_RST;
                          else NextState = STATE_TRIGGER_DONE;
      default: NextState = STATE_RST;
    endcase
  end

  assign Match = (mem[Counter] == RvviAxiRdataDelay) & (CurrState == STATE_COMPARE) & RvviAxiRvalidDelay;
  assign Overflow = Counter > 4'd4;
  assign Threshold = Counter >= 4'd4;
  assign Mismatch = (mem[Counter] != RvviAxiRdataDelay) & (CurrState == STATE_COMPARE) & RvviAxiRvalidDelay;
  assign IlaTriggerOneCycle = CurrState == STATE_TRIGGER;
  assign CounterRst = CurrState == STATE_RST;
  assign CounterEn = RvviAxiRvalid;

  // this is a bit hacky, but it works!
  logic [3:0] TriggerCount;
  logic       TriggerReset, TriggerEn;
  counter #(4) triggercounter(clk, reset | TriggerReset, TriggerEn, TriggerCount);
  assign TriggerReset = TriggerCount == 4'd10;
  assign TriggerEn = IlaTriggerOneCycle | (TriggerCount != 4'd0 & TriggerCount < 4'd10);
  assign IlaTrigger = TriggerEn;

endmodule
