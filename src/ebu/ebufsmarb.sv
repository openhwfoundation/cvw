///////////////////////////////////////////
// ebufsmarb.sv
//
// Written:  Rose Thompson rose@rosethompson.net 23 January 2023
// Modified: David Harris
//
// Purpose: Arbitrates the AHB bus between the IFU and LSU, LSU first.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2023-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module ebufsmarb (
  input  logic       HCLK,
  input  logic       HRESETn,
  input  logic       HREADY,

  input  logic       LSUReq,
  input  logic       IFUReq,

  output logic       IFUSave,
  output logic       IFURestore,
  output logic       IFUDisable,
  output logic       IFUSelect,
  output logic       LSUDisable,
  output logic       LSUSelect);

  typedef enum logic [1:0] {IDLE, ARBITRATE} statetype;
  statetype          CurrState, NextState;

  logic              both;                       // Both the LSU and IFU request at the same time
  logic              IFUReqDelay;                // 1 cycle delayed IFU request. Part of arbitration

  ////////////////////////////////////////////////////////////////////////////////////////////////////
  // Arbitration scheme
  // FSM decides if arbitration needed.  Arbitration is held until the LSU stops requesting: the LSU never
  // drives IDLE inside a burst, so the first ready cycle with no LSU request is the data phase of its last
  // transfer (or later), and the IFU's saved address phase can be issued alongside it.
  ////////////////////////////////////////////////////////////////////////////////////////////////////

  assign both = LSUReq & IFUReq;
  flopenl #(.TYPE(statetype)) busreg(HCLK, ~HRESETn, 1'b1, NextState, IDLE, CurrState);
  always_comb
    case (CurrState)
      IDLE:      if (both)                                      NextState = ARBITRATE; // exclusion-tag: arb-idle
                 else                                           NextState = IDLE;
      ARBITRATE: if (HREADY & ~both)                            NextState = IDLE; // exclusion-tag: arb-arbitrate-exit
                 else                                           NextState = ARBITRATE; // exclusion-tag: arb-arbitrate-hold
      default:                                                  NextState = IDLE;
    endcase

  // basic arb always selects LSU when both
  // replace this block for more sophisticated arbitration as needed.
  // Controller 0 (IFU)
  assign IFUSave = CurrState == IDLE & both;
  assign IFURestore = CurrState == ARBITRATE;
  assign IFUDisable = IFURestore;
  assign IFUSelect = (NextState == ARBITRATE) ? 1'b0 : IFUReq; // exclusion-tag: arb-ifuselect
  // Controller 1 (LSU)
  // When both the IFU and LSU request at the same time, the FSM will go into the arbitrate state.
  // Once the LSU request is done the fsm returns to IDLE.  To prevent the LSU from regaining
  // priority and re-issuing the same memory operation, the delayed IFUReqDelay squashes the LSU request.
  // This is necessary because the pipeline is stalled for the entire duration of both transactions,
  // and the LSU memory request will still be active.
  flopr #(1) ifureqreg(HCLK, ~HRESETn, IFUReq, IFUReqDelay);
  assign LSUDisable = (CurrState != ARBITRATE) & IFUReqDelay;
  assign LSUSelect = (NextState == ARBITRATE) ? 1'b1 : LSUReq; // exclusion-tag: arb-lsuselect

endmodule
