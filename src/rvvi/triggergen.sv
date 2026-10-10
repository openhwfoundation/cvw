///////////////////////////////////////////
// triggergen.sv
//
// Written:  Rose Thompson rose@rosethompson.net 26 June 2024
// Modified:
//
// Purpose: Watches incoming Ethernet frames for a specific trigger frame and pulses an ILA trigger when it arrives.
//
// Documentation:
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module triggergen import cvw::*; (
  input logic clk, reset,
  input logic [31:0] RvviAxiRdata,
  input logic [3:0] RvviAxiRstrb,
  input logic RvviAxiRlast,
  input logic RvviAxiRvalid,
  output logic IlaTrigger);

  typedef enum logic[2:0] {STATE_RST, STATE_COMPARE, STATE_MISMATCH, STATE_TRIGGER, STATE_TRIGGER_DONE} statetype;
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
    if(reset) CurrState <= STATE_RST;
    else      CurrState <= NextState;
  end

  always_comb begin
    case(CurrState)
      STATE_RST: if(RvviAxiRvalid) NextState = STATE_COMPARE;
                 else NextState = STATE_RST;
      STATE_COMPARE: if(RvviAxiRlast) NextState = STATE_RST;
                     else if(Mismatch | Overflow) NextState = STATE_MISMATCH;
                     else if(Threshold & Match) NextState = STATE_TRIGGER;
                     else NextState = STATE_COMPARE;
      STATE_MISMATCH: if(RvviAxiRlast) NextState = STATE_RST;
                      else NextState = STATE_MISMATCH;
      STATE_TRIGGER: if(RvviAxiRlast) NextState = STATE_RST;
                     else NextState = STATE_TRIGGER_DONE;
      STATE_TRIGGER_DONE: if(RvviAxiRlast) NextState = STATE_RST;
                          else NextState = STATE_TRIGGER_DONE;
      default: NextState = STATE_RST;
    endcase
  end

  assign Match = (mem[Counter] == RvviAxiRdataDelay) & (CurrState == STATE_COMPARE) & RvviAxiRvalidDelay;
  assign Overflow = Counter > 4'd4;
  assign Threshold = Counter >= 4'd4;
  assign Mismatch =  (mem[Counter] != RvviAxiRdataDelay) & (CurrState == STATE_COMPARE) & RvviAxiRvalidDelay;
  assign IlaTriggerOneCycle = CurrState == STATE_TRIGGER;
  assign CounterRst = CurrState == STATE_RST;
  assign CounterEn = RvviAxiRvalid;

/* -----\/----- EXCLUDED -----\/-----
  always_ff @(posedge clk) begin
    if(reset) IlaTrigger <= '0;
    else if (IlaTriggerOneCycle) IlaTrigger <= '1;
    else if (IlaTriggerAck) IlaTrigger <= '0;
    else IlaTrigger <= IlaTrigger;
  end
 -----/\----- EXCLUDED -----/\----- */

  // this is a bit hacky, but it works!
  logic [3:0] TriggerCount;
  logic       TriggerReset, TriggerEn;
  counter #(4) triggercounter(clk, reset | TriggerReset, TriggerEn, TriggerCount);
  assign TriggerReset = TriggerCount == 4'd10;
  assign TriggerEn = IlaTriggerOneCycle | (TriggerCount != 4'd0 & TriggerCount < 4'd10);
  assign IlaTrigger = TriggerEn;

endmodule
