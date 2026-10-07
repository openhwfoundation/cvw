///////////////////////////////////////////
// data_reg.sv
//
// Written: Jacob Pease jacobpease@protonmail.com,
//          James E. Stine james.stine@okstate.edu
// Created: August 4th, 2025
// Modified:
//
// Purpose: Test Data Registers in the Debug Transport Module.
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

module data_reg import cvw::*; #(parameter cvw_t P) (
  input logic                         tck,
  input logic                         tdi,
  input logic                         resetn,
  input logic [P.DTM_INSTR_WIDTH-1:0] currentInst,
  input logic                         ShiftDR, ClockDR, UpdateDR,
  input logic [31:0]                  dtmcs_next,
  output logic [31:0]                 dtmcs,
  input logic [P.ABITS + 34 - 1:0]    dmi_next,
  output logic [P.ABITS + 34 - 1:0]   dmi,
  output logic                        tdo
);

  logic        tdo_idcode;
  logic        tdo_dtmcs;
  logic        tdo_dmi;
  logic        tdo_bypass;

  // CV-Wally marchid is 0x24
  // https://github.com/riscv/riscv-isa-manual/blob/main/marchid.md
  // OpenHW JEDEC 0x1002ac05 (mfg: 0x602 (Open HW Group), part: 0x002a, ver: 0x1)

  typedef enum logic [4:0] {
    BYPASS = 5'b11111,
    IDCODE = 5'b00001,
    DTMCS  = 5'b10000,
    DMIREG = 5'b10001
  } DTMINST;

  // ID Code
  idreg #(32) idcode(tck, tdi, resetn, P.JEDEC, ShiftDR, ClockDR, tdo_idcode);

  // DTMCS TODO (JACOB): Debug Spec Section 6.1.4
  internalreg #(32) dtmcsreg(tck, tdi, resetn, dtmcs_next, {11'b0, 3'd4, 6'd0, 2'b0, P.ABITS, 4'b1},
  ShiftDR, ClockDR, dtmcs, tdo_dtmcs);

  // DMI
  internalreg #(P.ABITS + 34) dmireg(tck, tdi, resetn, dmi_next, {(P.ABITS + 34){1'b0}},
  ShiftDR, ClockDR, dmi, tdo_dmi);


  // BYPASS DR implementation.  IEEE 1149.1 describes the DR as being
  // clocked during Capture-DR and Shift-DR; here ClockDR is implemented
  // as a clock enable on TCK rather than as a gated clock.  When ShiftDR=0
  // the bypass register captures 0; when ShiftDR=1 it shifts TDI to TDO.
  always_ff @(posedge tck, negedge resetn) begin
    if (~resetn) tdo_bypass <= 0;
    else if (ClockDR & currentInst == BYPASS) tdo_bypass <= tdi & ShiftDR;
  end

  // Mux data register output based on current instruction
  always_comb begin
    case (currentInst)
      IDCODE  : tdo = tdo_idcode;
      DTMCS   : tdo = tdo_dtmcs;
      DMIREG  : tdo = tdo_dmi;
      BYPASS  : tdo = tdo_bypass; // OpenOCD bug: doesn't change to IDCODE before trying to read the IDCODE, then crashes.
      default : tdo = tdo_bypass; // Bypass instruction 11111 and 00000
    endcase
  end
endmodule
