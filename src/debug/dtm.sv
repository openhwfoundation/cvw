///////////////////////////////////////////
// dtm.sv
//
// Written: Jacob Pease jacobpease@protonmail.com,
//          James E. Stine james.stine@okstate.edu
// Created: August 1st, 2025
// Modified:
//
// Purpose: Debug Transport Module
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-25 Harvey Mudd College & Oklahoma State University
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

//`include "debug.vh"
module dtm import cvw::*; #(parameter cvw_t P) (
  input logic         clk,
  input logic         reset,
  input logic         tck,
  input logic         tms,
  input logic         tdi,
  output logic        tdo,

  // DMI REQUEST
  output logic [6:0]  DMIADDR,
  output logic [31:0] DMIDATA,
  output logic [1:0]  DMIOP,
  output logic        DMIREADY,
  output logic        DMIVALID,

  // DMI RESPONSE
  input logic [31:0]  DMIRSPDATA,
  input logic [1:0]   DMIRSPOP,
  input logic         DMIRSPREADY,
  input logic         DMIRSPVALID
);

  // Tap Controller stuff
  logic  resetn;
  logic  enable;
  logic  select;
  logic  ShiftIR;
  logic  CaptureIR;
  logic  ClockIR;
  logic  UpdateIR;
  logic  ShiftDR;
  logic  CaptureDR;
  logic  ClockDR;
  logic  UpdateDR;

  // Instruction Register
  logic [P.DTM_INSTR_WIDTH-1:0]  CurrentInst;

  // Select outputs
  logic        tdo_dr, tdo_ir, tdo_mux, tdo_delayed;

  // CDC -------------------------------------------------------------
  // DMI scan decode (TCK domain)
  logic        CaptureDMI;
  logic        UpdateDMI;
  logic        UpdateDTMCS;

  // TCK side of the DMI clock-domain crossing
  logic        ReqSend;
  logic        Busy;
  logic        RspValid;
  logic [31:0] RspData;
  logic [1:0]  RspOp;
  logic        Discard;
  logic        RspDeliver;
  logic [31:0] NextData;

  // Test Data Register Stuff
  logic [31:0] dtmcs, DTMCSNext;

  logic [P.DTM_ABITS + 34 - 1:0] DMINextReg, DMINext, dmi;

  // Debug Module Interface Control
  logic        DTMHardReset;
  logic        DMIReset;
  logic        Sticky;

  logic [1:0]  DMIStatus;

  typedef enum logic [1:0] {
    NOP = 2'b00,
    RD  = 2'b01,
    WR  = 2'b10
  } DMIOPW;

  // Temporarily tying tresetn to resetn. This isn't the way JTAG
  // recommends doing it, but the debug spec and neorv32 seem to
  // imply it's ok to do so.
  tap_controller controller (tck, reset, tms, tdi,
    resetn, enable, select,
    ShiftIR, CaptureIR, ClockIR, UpdateIR,
    ShiftDR, CaptureDR, ClockDR, UpdateDR);

  // IR
  inst_reg instructionreg (.tck, .tdi, .resetn,
    .ShiftIR, .CaptureIR, .ClockIR, .UpdateIR,
    .tdo(tdo_ir), .instreg(CurrentInst));

  // tdr = Test Data Register
  data_reg #(P) tdr (tck, tdi, resetn, CurrentInst, ShiftDR, ClockDR, UpdateDR,
    DTMCSNext, dtmcs, DMINext, dmi, tdo_dr);

  // Choose output of tdo
  mux2 #(1) tdomux (tdo_dr, tdo_ir, select, tdo_mux);

  // According to the IEEE 1149.1 JTAG specification, TDO is
  // transmitted on the falling edge.
  flop #(1) tdo_ff (~tck, tdo_mux, tdo_delayed);

  // NOTE: Push the tristate logic for this to the IO cell
  assign tdo = enable ? tdo_delayed : 1'bz;

  // The whole DTM runs on TCK. Only the DMI request and response
  // cross into the system clock domain, through a two-phase
  // bundled-data handshake (dmicdc). The DM side sees the
  // DMIVALID/DMIRSPVALID interface (Debug Spec Appendix A.3) and is
  // unaware of the clock domain crossing.

  // CaptureDR comes from the TAP controller. UpdateDR is high for
  // exactly one TCK cycle, and dmi still holds the scanned value then.
  assign CaptureDMI  = CaptureDR & (CurrentInst[4:0] == 5'b10001);
  assign UpdateDMI   = UpdateDR  & (CurrentInst[4:0] == 5'b10001);
  assign UpdateDTMCS = UpdateDR  & (CurrentInst[4:0] == 5'b10000);

  // Launch a DMI access on Update-DR for a read or write, unless the
  // sticky busy error is set. Busy can't be high here: a scan that
  // captured busy has already set Sticky. dmicdc also gates on ~Busy.
  assign ReqSend = UpdateDMI & ~Sticky & ((dmi[1:0] == RD) | (dmi[1:0] == WR));

  dmicdc #(P.DTM_ABITS) cdc (.tck, .TckReset(reset), .ReqSend, .dmi,
    .Busy, .RspValid, .RspData, .RspOp,
    .clk, .reset,
    .DMIADDR, .DMIDATA, .DMIOP, .DMIREADY, .DMIVALID,
    .DMIRSPDATA, .DMIRSPOP, .DMIRSPREADY, .DMIRSPVALID);

  // DTMCS
  always_ff @(posedge tck) begin
    if (reset | ~resetn | DTMHardReset) begin
      DTMHardReset <= 0;
      DMIReset <= 0;
    end else if (UpdateDTMCS) begin
      DTMHardReset <= dtmcs[17];
      DMIReset <= dtmcs[16];
    end else if (DMIReset) begin
      DMIReset <= 0;
    end
  end

  assign DTMCSNext = {11'b0, 3'd4, DTMHardReset, DMIReset, 1'b0, 3'd0, DMIStatus, P.DTM_ABITS, 4'b1};

  // Sticky busy error: set when a scan captures dmi while an access is in flight
  always_ff @(posedge tck) begin
    if (reset | ~resetn | DMIReset | DTMHardReset) begin
      Sticky <= 0;
    end else if (CaptureDMI & Busy) begin
      Sticky <= 1;
    end
  end

  // An access in flight can't be cancelled across the crossing. After
  // dtmhardreset or Test-Logic-Reset, drop its response when it arrives.
  // Cleared whenever nothing is in flight (Busy also drops in the
  // RspValid cycle), which also initializes it on the first TCK edge.
  always_ff @(posedge tck) begin
    if (~Busy) begin
      Discard <= 0;
    end else if (~resetn | DTMHardReset) begin
      Discard <= 1;
    end
  end

  // DMI result captured by the next scan. Update-DR records the address
  // and data scanned in; the response then replaces the data for a read
  // and sets the status. The response is also passed straight to
  // Capture-DR in the RspValid cycle, which saves a TCK cycle of
  // busy. Based on the Debug Module Interface Signals found in
  // Appendix A.3 of the v1.0 Debug Specification.
  // DMIOP is dmicdc's held request op, stable until the next launch.
  assign RspDeliver = RspValid & ~Discard;
  assign NextData   = (DMIOP == RD) ? RspData : DMINextReg[33:2];

  always_ff @(posedge tck or posedge reset) begin
    if (reset | ~resetn | DTMHardReset) begin
      DMINextReg <= '0;
    end else if (RspDeliver) begin
      DMINextReg[33:0] <= {NextData, RspOp};
    end else if (UpdateDMI & ~Sticky & ~Busy) begin
      DMINextReg[P.DTM_ABITS+34-1:2] <= dmi[P.DTM_ABITS+34-1:2];
    end
  end

  assign DMIStatus = (Sticky | Busy) ? 2'b11 : RspDeliver ? RspOp : DMINextReg[1:0];
  assign DMINext   = {DMINextReg[P.DTM_ABITS+34-1:34], RspDeliver ? NextData : DMINextReg[33:2], DMIStatus};

endmodule
