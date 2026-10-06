///////////////////////////////////////////
// ebufsmarb.sv
//
// Written: Rose Thompson rose@rosethompson.net
// Created: 23 January 2023
// Modified: 23 January 2023
//
// Purpose: Arbitrates requests from instruction and data streams
//          LSU has priority.
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

module ebufsmarb (
  input  logic       HCLK,
  input  logic       HRESETn,
  input  logic [2:0] HBURST,
 //  AHB burst length

  input  logic       HREADY,

  input  logic       LSUReq,
  input  logic       IFUReq,

  output logic       IFUSave,
  output logic       IFURestore,
  output logic       IFUDisable,
  output logic       IFUSelect,
  output logic       LSUDisable,
  output logic       LSUSelect);

  typedef enum       logic [1:0] {IDLE, ARBITRATE} statetype;
  statetype          CurrState, NextState;

  logic              both;                       // Both the LSU and IFU request at the same time
  logic              IFUReqDelay;                    // 1 cycle delayed IFU request. Part of arbitration
  logic              FinalBeat, FinalBeatD;      // Indicates the last beat of a burst
  logic              BeatCntEn;
  logic [3:0]        BeatCount;                  // Position within a burst transfer
  logic              BeatCntReset;
  logic [3:0]        Threshold;                  // Number of beats derived from HBURST

  ////////////////////////////////////////////////////////////////////////////////////////////////////
  // Arbitration scheme
  // FSM decides if arbitration needed.  Arbitration is held until the last beat of
  // a burst is completed.
  ////////////////////////////////////////////////////////////////////////////////////////////////////

  assign both = LSUReq & IFUReq;
  flopenl #(.TYPE(statetype)) busreg(HCLK, ~HRESETn, 1'b1, NextState, IDLE, CurrState);
  always_comb
    case (CurrState)
      IDLE:      if (both)                                      NextState = ARBITRATE;
                 else                                           NextState = IDLE;
      ARBITRATE: if (HREADY & FinalBeatD & ~both)               NextState = IDLE;
                 else                                           NextState = ARBITRATE;
      default:                                                  NextState = IDLE;
    endcase

  // basic arb always selects LSU when both
  // replace this block for more sophisticated arbitration as needed.
  // Controller 0 (IFU)
  assign IFUSave = CurrState == IDLE & both;
  assign IFURestore = CurrState == ARBITRATE;
  assign IFUDisable = IFURestore;
  assign IFUSelect = (NextState == ARBITRATE) ? 1'b0 : IFUReq;
  // Controller 1 (LSU)
  // When both the IFU and LSU request at the same time, the FSM will go into the arbitrate state.
  // Once the LSU request is done the fsm returns to IDLE.  To prevent the LSU from regaining
  // priority and re-issuing the same memory operation, the delayed IFUReqDelay squashes the LSU request.
  // This is necessary because the pipeline is stalled for the entire duration of both transactions,
  // and the LSU memory request will still be active.
  flopr #(1) ifureqreg(HCLK, ~HRESETn, IFUReq, IFUReqDelay);
  //assign LSUDisable = (CurrState != ARBITRATE) & (IFUReqDelay & ~(HREADY & FinalBeatD));
  assign LSUDisable = (CurrState != ARBITRATE) & IFUReqDelay;
  assign LSUSelect = (NextState == ARBITRATE) ? 1'b1: LSUReq;

  ////////////////////////////////////////////////////////////////////////////////////////////////////
  // Burst mode logic
  ////////////////////////////////////////////////////////////////////////////////////////////////////

  assign BeatCntReset = NextState == IDLE;
  assign FinalBeat = (BeatCount == Threshold); // Detect when we are waiting on the final access.
  // Counting the beats in the EBU is only necessary when both the LSU and IFU request concurrently.
  // LSU has priority. HREADY serves double duty during a burst transaction.  It indicates when the
  // beat completes and when the transaction finishes.  However there is nothing external to
  // differentiate them.  The EBU counts the HREADY beats so it knows when to switch to the IFU's
  // request.
  assign BeatCntEn = (NextState == ARBITRATE) & HREADY;
  counter #(4) BeatCounter(HCLK, ~HRESETn | BeatCntReset | FinalBeat, BeatCntEn, BeatCount);

  // Used to store data from data phase of AHB.
  flopenr #(1) FinalBeatReg(HCLK, ~HRESETn | BeatCntReset, BeatCntEn, FinalBeat, FinalBeatD);

  // unlike the bus fsm in lsu/ifu, we need to derive the number of beats from HBURST, Threshold = num beats - 1.
  //  HBURST[2:1] Beats  threshold
  //  00          1      0
  //  01          4      3
  //  10          8      7
  //  11          16     15
  always_comb
    if (HBURST[2:1] == 2'b00) Threshold = 4'b0000;
    else                      Threshold = ('d2 << HBURST[2:1]) - 'd1;
endmodule
