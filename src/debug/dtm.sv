///////////////////////////////////////////
// tap_controller.sv
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
  logic  ClockDR;
  logic  UpdateDR;

  // Instruction Register
  logic [P.DTM_INSTR_WIDTH-1:0]  currentInst;

  // Select outputs
  logic        tdo_dr, tdo_ir, tdo_mux, tdo_delayed;

  // Edge detecting UpdateDR. Avoids cases where UpdateDR is still
  // high for multiple clock cycles.
  logic        UpdateDRSync;
  logic [1:0]  UpdateDRSamples;
  logic        UpdateDRValid;

  // Test Data Register Stuff
  logic [31:0] dtmcs, DTMCSNext;

  logic [P.ABITS + 34 - 1:0] DMINextReg, DMINext, dmi;

  // Debug Module Interface Control
  logic        UpdateDMI;
  logic        UpdateDTMCS;
  logic        DTMHardReset;
  logic        DMIReset;
  logic        Sticky;

  typedef enum logic [1:0] {
    NOP = 2'b00,
    RD  = 2'b01,
    WR  = 2'b10
  } DMIOPW;

  enum logic {IDLE, BUSY} DMIState;

  // Temporarily tying tresetn to resetn. This isn't the way JTAG
  // recommends doing it, but the debug spec and neorv32 seem to
  // imply it's ok to do so.
  tap_controller controller (tck, reset, tms, tdi,
    resetn, enable, select,
    ShiftIR, CaptureIR, ClockIR, UpdateIR,
    ShiftDR, ClockDR, UpdateDR);

  // IR
  inst_reg instructionreg (tck, tdi, resetn,
    ShiftIR, CaptureIR, ClockIR, UpdateIR,
    tdo_ir, currentInst);

  // tdr = Test Data Register
  data_reg #(P) tdr (tck, tdi, resetn, currentInst, ShiftDR, ClockDR, UpdateDR,
    DTMCSNext, dtmcs, DMINext, dmi, tdo_dr);

  // Choose output of tdo
  mux2 #(1) tdomux (tdo_dr, tdo_ir, select, tdo_mux);

  // According to the IEEE 1149.1 JTAG specification, TDO is
  // transmitted on the falling edge.
  flop #(1) tdo_ff (~tck, tdo_mux, tdo_delayed);

  // NOTE: Push the tristate logic for this to the IO cell
  assign tdo = enable ? tdo_delayed : 1'bz;

  // The JTAG-side of the DTM runs on TCK, while the Debug Module (DM)
  // and DMI bus live on our system clock, we need a clean
  // clock-domain crossing (CDC) between them. After updating the DMI
  // register, then it is safe to drive the DMI with the value stored
  // in the DMI data register.
  synchronizer updatesync (clk, UpdateDR, UpdateDRSync);

  always_ff @(posedge clk) begin
    if (reset) begin
      UpdateDRSamples <= 2'b0;
    end else begin
      if (UpdateDRSync) UpdateDRSamples[0] <= 1;
      else UpdateDRSamples[0] <= 0;
      UpdateDRSamples[1] <= UpdateDRSamples[0];
    end
  end

  assign UpdateDRValid = (UpdateDRSamples == 2'b01);
  assign UpdateDTMCS = UpdateDRValid & (currentInst[4:0] == 5'b10000);
  assign UpdateDMI = UpdateDRValid & (currentInst[4:0] == 5'b10001);

  // DTMCS
  always_ff @(posedge clk) begin
    if (reset | ~resetn | DTMHardReset) begin
      DTMHardReset <= 0;
      DMIReset <= 0;
    end else if (UpdateDTMCS) begin
      DMIReset <= dtmcs[17];
      DTMHardReset <= dtmcs[16];
    end else if (DMIReset) begin
      DMIReset <= 0;
    end
  end

  assign DTMCSNext = {11'b0, 3'd4, DTMHardReset, DMIReset, 1'b0, 3'd0, DMINextReg[1:0], P.ABITS, 4'b1};

  // Sticky error
  always_ff @(posedge clk) begin
    if (reset | ~resetn | DMIReset == 1 | DTMHardReset == 1) begin
      Sticky <= 0;
    end else if ((DMIState == BUSY) & (UpdateDMI)) begin
      Sticky <= 1;
    end
  end

  // DMI
  // Based on the Debug Module Interface Signals found in Appendix
  // A.3 of the v1.0 Debug Specification
  always_ff @(posedge clk) begin
    if (reset | ~resetn | DTMHardReset) begin
      DMINextReg[1:0] <= NOP;
      DMIREADY <= 1'b1;
      DMIVALID <= 1'b0;
      DMIState <= IDLE;
    end else begin
      case(DMIState)
        IDLE: begin
          if (UpdateDMI) begin
            DMIADDR <= dmi[P.ABITS+34-1:34];
            DMIDATA <= dmi[33:2];
            DMINextReg[33:2] <= dmi[33:2];
            if ((dmi[1:0] == RD) | (dmi[1:0] == WR)) begin
              DMIOP <= dmi[1:0];
              DMIVALID <= 1'b1;
              DMIState <= BUSY;
            end
          end else begin
            DMIState <= IDLE;
          end
        end
        BUSY: begin
          if (DMIRSPVALID) begin
            DMIOP <= NOP;
            DMIVALID <= 1'b0;
            if (DMIOP == 2'b01) begin
              DMINextReg[33:2] <= DMIRSPDATA;
            end else begin
              DMINextReg[33:2] <= dmi[33:2];
            end
            DMINextReg[1:0] <= DMIRSPOP;
            DMIState <= IDLE;
          end else begin
            DMINextReg[33:2] <= dmi[33:2];
            DMIState <= BUSY;
          end
        end
        default: DMIState <= IDLE;
      endcase
    end
  end

  assign DMINext = {DMIADDR, DMINextReg[33:2], Sticky ? 2'b11 : DMINextReg[1:0]};

endmodule
