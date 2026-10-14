//////////////////////////////////////////////////////////////////////
// csrd.sv
//
// Written:  Jacob Pease jacobpease@protonmail.com
//           James E. Stine james.stine@okstate.edu
// Created:  19 September 2025
// Modified: 1 March 2026
//
// Purpose: Debug Control and Status Registers
//          See RISC-V Privileged Mode Specification 20190608
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
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
//////////////////////////////////////////////////////////////////////

module csrd import cvw::*;  #(parameter cvw_t P) (
  input  logic              clk, reset,
  input  logic              CSRDWriteM,
  input  logic [11:0]       CSRAdrM,
  input  logic [P.XLEN-1:0] CSRWriteValM,
  input  logic              PCSrcM, FlushM, StallM,
  input  logic [P.XLEN-1:0] NextValidPCE,
  input  logic [P.XLEN-1:0] IEUAdrM, PCM,
  input  logic [1:0]        PrivilegeModeW,
  input  logic              DebugMode,
  input  logic              DebugHaltReq, DebugResumeReq,
  input  logic              DebugResetHaltReq,
  input  logic              BreakpointFaultM,
  input  logic              NextHalt, NextResume,
  input  logic              DebugHalted, DebugRunning,
  input  logic [2:0]        NextHaltCause,
  input  logic              DebugEBreak,
  output logic [P.XLEN-1:0] CSRDReadValM,
  output logic              IllegalCSRDAccessM,
  output logic [P.XLEN-1:0] DPC_REGW,
  output logic              DebugEBreakM,
  output logic              DebugEBreakS,
  output logic              DebugEBreakU,
  output logic              DebugStepIE,
  output logic              DebugStep,
  output logic [1:0]        DebugPrivilegeMode,
  output logic              DebugSetPrivMode,
  output logic              DebugStopCounters
);

  localparam                DCSR = 12'h7B0;
  localparam                DPC = 12'h7B1;
  localparam                DSCRATCH0 = 12'h7B2;
  localparam                DSCRATCH1 = 12'h7B3;

  // EBreak
  logic                     ebreak;
  logic                     BreakpointM;
  logic                     BreakpointS;
  logic                     BreakpointU;

  // DCSR Fields
  logic [3:0]               debugver;
  logic [2:0]               extcause;  // Irrelevant -> unimplemented
  logic                     cetrig;    // Not implemented
  logic                     pelp;      // Not implemented
  logic                     ebreakvs;  // Not implemented
  logic                     ebreakvu;  // Not implemented
  logic                     ebreakm;   // implemented
  logic                     ebreaks;   // implemented
  logic                     ebreaku;   // implemented
  logic                     stepie;    // implemented
  logic                     stopcount; // implemented
  logic                     stoptime;  // Hardcoded to 0, but should implement at some point
  logic [2:0]               cause;     // Implemented. Cause of halt
  logic                     v;         // Not implemented - related to virtualization
  logic                     mprven;    // See note...
  logic                     nmip;      // Non-maskable interrupt. Tying to 0
  logic                     step;      // Implemented
  logic [1:0]               prv;       // Implemented. Privilege Mode at halt. Set so mode changes when resumed.

  // NOTE: When set to 0, mprven allows MPRV to be ignored while in
  // DebugMode. This can be added later. For now, tying it to 1
  // implies that MPRV takes effect if it is set, thus DebugMode can't
  // alter it's behavior. Since I haven't changed anything related to
  // privileged modes, I'm setting this to 1 temporarily, implying
  // that the privilege mode always takes effect.

  // debug specification 4.9.1, 0x7b0
  localparam dcsrwidth = ($bits(ebreakm) + $bits(ebreaks) + $bits(ebreaku) +
    $bits(stepie) + $bits(stopcount) + $bits(cause) + $bits(step) + $bits(prv));

  // Write enables
  logic                     WriteDCSR;
  logic                     WriteDPC;

  // Register values
  logic [dcsrwidth-1:0]     DCSRWriteValM;
  logic [dcsrwidth-1:0]     DCSR_REGW;
  logic [P.XLEN-1:0]        DPCWriteValM;

  // Detect writes to Priv Mode for the purpose of changing the
  // privileged mode upon resume
  logic PrivModeSet;

  // Ebreak handling signals
  assign DebugEBreakM = ebreakm;
  assign DebugEBreakS = ebreaks;
  assign DebugEBreakU = ebreaku;

  // Read only and unimplemented DCSR Fields
  assign debugver = 4'b0100; // version 1.0
  assign extcause = 3'd0;
  assign cetrig = 0;
  assign pelp = 0;
  assign ebreakvs = 0;
  assign ebreakvu = 0;
  // assign stopcount = 0;
  assign stoptime = 0;
  assign v = 0;
  assign mprven = 1;
  assign nmip = 0;

  ////////////////////////////////////////////////////////////////////
  // CSR Writes
  ////////////////////////////////////////////////////////////////////
  // Need to revisit this, as there is already a PCSrcM register in
  // the branch predictor.

  // Write enables for each register.
  assign WriteDCSR = CSRDWriteM & (CSRAdrM == DCSR) | NextHalt;
  assign WriteDPC  = CSRDWriteM & (CSRAdrM == DPC) | NextHalt;

  assign DCSRWriteValM = CSRDWriteM & ~NextHalt ?
                         {CSRWriteValM[15], CSRWriteValM[13], CSRWriteValM[12], CSRWriteValM[11], CSRWriteValM[10],
                          CSRWriteValM[8:6], CSRWriteValM[2], CSRWriteValM[1:0]} :
                         {ebreakm, ebreaks, ebreaku, stepie, stopcount, NextHaltCause, step, PrivilegeModeW};

  // DPC Mux. Selects the correct DPC based on program execution.
  always_comb begin
    if (CSRDWriteM & DebugMode) begin
      DPCWriteValM = CSRWriteValM;
    end else if (DebugHaltReq & NextHalt | DebugEBreak) begin
      DPCWriteValM = PCM;
    end else if (step & NextHalt) begin
      if (PCSrcM) begin
        // If this is a branch, jump, or jalr, DPC will point to the
        // actual next valid instruction.
        DPCWriteValM = IEUAdrM;
      end else begin
        // The fallthrough address PC + 4/2 is not in the memory
        // stage. So the CPU has to figure out what the next valid PC
        // is.
        DPCWriteValM = NextValidPCE;
      end
    end else begin
      DPCWriteValM = CSRWriteValM;
    end
  end

  flopenr #(dcsrwidth) DCSRreg(clk, reset, WriteDCSR, DCSRWriteValM, DCSR_REGW);
  flopenr #(P.XLEN) DPCreg(clk, reset, WriteDPC, DPCWriteValM, DPC_REGW);

  ////////////////////////////////////////////////////////////////////
  // CSRs
  ////////////////////////////////////////////////////////////////////

  assign ebreakm = DCSR_REGW[dcsrwidth-1];
  assign ebreaks = DCSR_REGW[dcsrwidth-2];
  assign ebreaku = DCSR_REGW[dcsrwidth-3];
  assign stepie = DCSR_REGW[dcsrwidth-4];
  assign stopcount = DCSR_REGW[dcsrwidth-5];
  assign cause = DCSR_REGW[dcsrwidth-6:dcsrwidth-8];
  assign step = DCSR_REGW[2];
  assign prv = DCSR_REGW[1:0];

  // Step Controls
  assign DebugStepIE = stepie;
  assign DebugStep = step;
  assign DebugStopCounters = stopcount & DebugMode;

  // Privilege mode controls
  assign DebugPrivilegeMode = prv;

  // CSR Reads
  // verilator lint_off WIDTH
  always_comb begin
    if (DebugMode == 0) begin // Debug Spec p.
      IllegalCSRDAccessM = 1'b1;
      CSRDReadValM = '0;
    end else begin
      IllegalCSRDAccessM = 1'b0;
      case (CSRAdrM)
        DCSR: begin
          if (P.XLEN == 32'd64) begin
            CSRDReadValM = {32'd0, debugver, 1'b0, extcause, 4'd0, cetrig, pelp, ebreakvs, ebreakvu,
                           ebreakm, 1'b0, ebreaks, ebreaku, stepie, stopcount, stoptime,
                           cause, v, mprven, nmip, step, prv};
          end else begin
            CSRDReadValM = {debugver, 1'b0, extcause, 4'd0, cetrig, pelp, ebreakvs, ebreakvu,
                           ebreakm, 1'b0, ebreaks, ebreaku, stepie, stopcount, stoptime,
                           cause, v, mprven, nmip, step, prv};
          end
        end

        DPC: CSRDReadValM = DPC_REGW;

        default:  begin
          CSRDReadValM = '0;
          IllegalCSRDAccessM = 1'b1;
        end
      endcase
    end
  end
  // verilator lint_on WIDTH

  ////////////////////////////////////////////////////////////////////
  // Using prv to override the current privileged mode from the
  // debugger.
  ////////////////////////////////////////////////////////////////////
  always_ff @(posedge clk) begin
    if (reset) begin
      PrivModeSet <= 1'b0;
    end else if (NextResume) begin
      PrivModeSet <= 1'b0;
    end else if (DebugMode & CSRDWriteM
                 & (CSRWriteValM[1:0] != prv) & (CSRAdrM == DCSR)) begin
      PrivModeSet <= 1'b1;
    end
  end

  assign DebugSetPrivMode = PrivModeSet & NextResume;

endmodule
