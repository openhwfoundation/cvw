///////////////////////////////////////////
// dmicdc.sv
//
// Written: Jacob Pease jacobpease@protonmail.com
// Created: November 9th, 2026
// Modified:
//
// Purpose: Two-phase (toggle) bundled-data clock-domain crossing
//          between the TCK-side DTM and the clk-side Debug Module
//          Interface (DMI, Debug Spec v1.0 Appendix A.3).
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
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


// Only one 1-bit toggle crosses in each direction. The request and
// response payloads are held stable in their source domain while the
// toggle is in flight, so they are sampled directly by the other
// domain without synchronizers (bundled data). One request may be in
// flight at a time; Busy is high from launch until the response
// is delivered to TCK (it is low in the RspValid cycle).
//
// Request:  TCK: ReqToggle flips  -> clk: DMIVALID one-cycle pulse
// Response: clk: AckToggle flips on DMIRSPVALID -> TCK: RspValid pulse
//
// Reset: TCK may not run while reset is asserted (the testbench and
// most probes park it), so the TCK-side handshake flops reset
// asynchronously on TckReset, like the TAP controller does. The
// clk-side flops reset synchronously on reset. Both sides must be
// reset together or the toggles disagree and the crossing sticks busy
// or sends a phantom request. TckReset should therefore be the system
// reset, not the TAP's Test-Logic-Reset or dtmhardreset.

module dmicdc #(parameter ABITS = 7) (
  // TCK domain (DTM side)
  input  logic                tck,
  input  logic                TckReset,     // asynchronous; see above
  input  logic                ReqSend,      // one-TCK-cycle strobe to launch a request
  input  logic [ABITS+34-1:0] dmi,          // scanned {address, data, op}; sampled on launch
  output logic                Busy,         // request in flight
  output logic                RspValid,     // one-TCK-cycle pulse when the response arrives
  output logic [31:0]         RspData,
  output logic [1:0]          RspOp,

  // clk domain (DM side)
  input  logic                clk,
  input  logic                reset,

  // DMI REQUEST
  output logic [ABITS-1:0]    DMIADDR,
  output logic [31:0]         DMIDATA,
  output logic [1:0]          DMIOP,
  output logic                DMIREADY,
  output logic                DMIVALID,

  // DMI RESPONSE
  input  logic [31:0]         DMIRSPDATA,
  input  logic [1:0]          DMIRSPOP,
  /* verilator lint_off UNUSEDSIGNAL */
  input  logic                DMIRSPREADY,  // unused: the DM doesn't backpressure for now
  /* verilator lint_on UNUSEDSIGNAL */
  input  logic                DMIRSPVALID
);

  // TCK domain
  logic                ReqLaunch;
  logic                ReqToggle;
  logic [ABITS+34-1:0] ReqHold;
  logic                AckToggleTck, AckToggleTckPrev;


  // clk domain
  logic ReqToggleClk, ReqToggleClkPrev;
  logic AckToggle, AckToggleNext;

  ///////////////////////////////////////////
  // Request: TCK -> clk
  ///////////////////////////////////////////

  // Launch only when idle. The payload register is written on the
  // same edge the toggle flips, and is held until the response returns.
  assign ReqLaunch = ReqSend & ~Busy;

  always_ff @(posedge tck, posedge TckReset)
    if (TckReset)       ReqToggle <= 1'b0;
    else if (ReqLaunch) ReqToggle <= ~ReqToggle;

  // Payload (hold) register. No reset: the DM only samples it on
  // DMIVALID, which can't occur until after a launch has loaded it.
  flopen #(ABITS+34) reqholdreg (tck, ReqLaunch, dmi, ReqHold);
  assign {DMIADDR, DMIDATA, DMIOP} = ReqHold;

  // Synchronize the toggle into clk, then edge detect it into a
  // one-cycle DMIVALID pulse. clk runs during reset, so these flush to
  // the reset value of ReqToggle without needing a reset of their own.
  synchronizer reqsync       (clk, ReqToggle, ReqToggleClk);
  flop #(1)    reqtoggleprev (clk, ReqToggleClk, ReqToggleClkPrev);

  assign DMIVALID = ReqToggleClk ^ ReqToggleClkPrev;

  // The CDC can always take a response; the DM answers the cycle after
  // DMIVALID and never applies backpressure.
  assign DMIREADY = 1'b1;

  ///////////////////////////////////////////
  // Response: clk -> TCK
  ///////////////////////////////////////////

  // Capture the response and flip the ack toggle on the same edge.
  // The response register holds until the next DMIRSPVALID, which
  // cannot occur before TCK has seen this ack and launched again.
  assign AckToggleNext = ~AckToggle;

  flopenr #(1) acktogglereg (clk, reset, DMIRSPVALID, AckToggleNext, AckToggle);
  flopen #(34) rspdatareg   (clk, DMIRSPVALID,
                             {DMIRSPDATA, DMIRSPOP},
                             {RspData, RspOp});

  // Synchronize the ack toggle into TCK, then edge detect it into a
  // one-cycle RspValid pulse. These reset asynchronously because TCK
  // may be stopped during reset.
  synchronizerar acksync       (tck, TckReset, AckToggle, AckToggleTck);
  flopar #(1)    acktoggleprev (tck, TckReset, AckToggleTck, AckToggleTckPrev);

  assign RspValid = AckToggleTck ^ AckToggleTckPrev;
  assign Busy     = ReqToggle ^ AckToggleTck;

endmodule
