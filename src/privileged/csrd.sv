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
  input logic               clk, reset,
  input logic               DebugHaltReq, DebugResumeReq,
  input logic               CSRDWriteM,
  input logic [P.XLEN-1:0]  CSRWriteValM,
  input logic [11:0]        CSRAdrM,
  input logic               InstrValid,
  input logic               InstrValidE,
  output logic [P.XLEN-1:0] CSRDReadValM,
  input logic [1:0]         PrivilegeModeW,

  output logic              DebugMode,
  input logic [P.XLEN-1:0]  NextValidPCE, PCM,
  output logic              IllegalCSRDAccessM,
  output logic              DebugResume, DebugHaltFlush, DebugResumeFlush,
  output logic              DebugUseDPC,
  output [P.XLEN-1:0]       DPC_REGW,
  output logic              DebugHaveReset,
  input logic               DebugHaveResetAck,
  input logic               DebugResetHaltReq,
  input logic               BreakpointFaultM,
  output logic              DebugEBreakM,
  output logic              DebugEBreakS,
  output logic              DebugEBreakU,
  input logic [P.XLEN-1:0]  IEUAdrM,
  input logic               PCSrcE,
  input logic               FlushM,
  input logic               StallM,
  input logic               StallW,
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

  typedef enum logic {RUNNING, HALTED} dbg_state_e;
  dbg_state_e state, state_n;

  // ResumeAck state definitions
  typedef enum logic [1:0] {RESACKLOW, RESACKCLEAR, RESACKHIGH} resack_state_e;
  resack_state_e resack_state, next_resack_state;

  logic                     NextHalt;

  // Write Enables
  logic                     WriteDCSR;
  logic                     WriteDPC;
  logic                     WriteCause;

  // Need this for resuming
  logic                     DPCset;
  logic                     PCSrcM;

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

  logic                     ResetHaltReqCondition;
  logic                     ResetHaltReqEnable;
  logic                     ResetHaltReqValid;

   // debug specification 4.9.1, 0x7b0
  localparam dcsrwidth = ($bits(ebreakm) + $bits(ebreaks) + $bits(ebreaku) +
    $bits(stepie) + $bits(stopcount) + $bits(cause) + $bits(step) + $bits(prv));

  logic [dcsrwidth-1:0]     DCSRWriteValM;
  logic [dcsrwidth-1:0]     DCSR_REGW;

  logic [P.XLEN-1:0]        DPCWriteValM;

  logic [2:0]               NextCause;  // Cause of halt

  // This signal indicates we are in the middle of a step. Used as an
  // enable signal for the halting state machine
  logic Stepping;

  //
  logic PrivModeSet;

  // Ebreak handling signals
  assign BreakpointM = BreakpointFaultM & ebreakm & PrivilegeModeW == P.M_MODE;
  assign BreakpointS = BreakpointFaultM & ebreaks & PrivilegeModeW == P.S_MODE;
  assign BreakpointU = BreakpointFaultM & ebreaku & PrivilegeModeW == P.U_MODE;
  assign ebreak = BreakpointM | BreakpointS | BreakpointU;
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

  assign NextHalt = (state_n == HALTED & state == RUNNING);
  assign WriteDCSR = CSRDWriteM & (CSRAdrM == DCSR) | NextHalt;
  assign WriteDPC = CSRDWriteM & (CSRAdrM == DPC) | NextHalt;

  // Need to revisit this, as there is already a PCSrcM register in
  // the branch predictor.
  flopenrc #(1) PCSrcMReg (clk, reset, FlushM, ~StallM, PCSrcE, PCSrcM);

  assign DCSRWriteValM = CSRDWriteM & ~NextHalt ?
                         {CSRWriteValM[15], CSRWriteValM[13], CSRWriteValM[12], CSRWriteValM[11], CSRWriteValM[10],
                          CSRWriteValM[8:6], CSRWriteValM[2], CSRWriteValM[1:0]} :
                         {ebreakm, ebreaks, ebreaku, stepie, stopcount, NextCause, step, PrivilegeModeW};

  // DPC Mux. Selects the correct DPC based on program execution.
  always_comb begin
    if (CSRDWriteM & DebugMode) begin
      DPCWriteValM = CSRWriteValM;
    end else if (DebugHaltReq & NextHalt | ebreak) begin
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

  ////////////////////////////////////////////////////////////////////
  // CSRs
  ////////////////////////////////////////////////////////////////////

  flopenr #(dcsrwidth) DCSRreg(clk, reset, WriteDCSR, DCSRWriteValM, DCSR_REGW);
  flopenr #(P.XLEN) DPCreg(clk, reset, WriteDPC, DPCWriteValM, DPC_REGW);

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
  // Halt FSM
  ////////////////////////////////////////////////////////////////////

  always_ff @(posedge clk) begin
    if (reset) begin
      state <= RUNNING;
    end else if (DebugHaltReq | DebugResumeReq | Stepping | ebreak | ResetHaltReqEnable) begin // Using the requests as enables
      state <= state_n;
    end else begin
      state <= state;
    end
  end

  // StallW must be allowed to go low before halting. When stepping
  // into a stalled instruction, including StallW in the cases below
  // ensures that the correct instruction reaches the WriteBack stage.
  always_comb begin
    case (state)
      RUNNING: begin
        if (DebugHaltReq & InstrValid & ~StallW) state_n = HALTED;
        else if (ebreak) state_n = HALTED;
        else if (step & InstrValid & ~DebugResume & ~StallW) state_n = HALTED;
        else if (ResetHaltReqValid) state_n = HALTED;
        else state_n = RUNNING;
        end
      HALTED: begin
        if (DebugResumeReq) state_n = RUNNING;
        else state_n = HALTED;
        end
      default: state_n = RUNNING;
    endcase
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      Stepping <= 1'b0;
    end else if (step & DebugResumeReq) begin
      Stepping <= 1'b1;
    end else if (InstrValid & ~StallW) begin
      // StallW must be low before we can reset Stepping. This
      // waits for anything stalling the pipeline to finish so that
      // the instruction in the Memory stage proceeds to the
      // Writeback.
      Stepping <= 1'b0;
    end
  end

  assign DebugMode = (state == HALTED);

  // Flush before Halt while still running
  assign DebugHaltFlush = NextHalt;
  //assign DebugResumeFlush = (state == HALTED) & (state_n == RUNNING);
  assign DebugUseDPC = DebugHaltFlush | DebugResumeFlush | DebugResume;

  // Flush after halt when running again.
  always_ff @(posedge clk) begin
    if (reset) begin
      DebugResumeFlush <= 0;
    end else begin
      DebugResumeFlush <= (state == HALTED) & (state_n == RUNNING);
    end
  end

  // -----------------------------------------------------------------
  // Priv mode control
  // -----------------------------------------------------------------

  always_ff @(posedge clk) begin
    if (reset) begin
      PrivModeSet <= 1'b0;
    end else if (state_n != HALTED) begin
      PrivModeSet <= 1'b0;
    end else if ((state == HALTED) & CSRDWriteM
                 & (CSRWriteValM[1:0] != prv) & (CSRAdrM == DCSR)) begin
      PrivModeSet <= 1'b1;
    end
  end

  assign DebugSetPrivMode = PrivModeSet & (state_n == RUNNING & state == HALTED);

  // -----------------------------------------------------------------
  // Reset Halt Request management
  // -----------------------------------------------------------------

  assign ResetHaltReqCondition = DebugResetHaltReq & DebugHaveReset;
  assign ResetHaltReqValid = ResetHaltReqCondition & InstrValidE;
  assign ResetHaltReqEnable = ResetHaltReqCondition & NextHalt;

  // -----------------------------------------------------------------------------
  // DebugResume: internal pulse when leaving HALTED.
  // Needs to be delayed so StallF can be low
  // -----------------------------------------------------------------------------

  always_ff @(posedge clk) begin
    if (reset) begin
      DebugResume <= 0;
    end else begin
      DebugResume <= (state == HALTED) & (state_n == RUNNING) & DPCset;
    end
  end

   // -----------------------------------------------------------------------------
   // DPCset: track whether DPC was explicitly written while halted (optional).
   // Clear when leaving HALTED. Set on CSR write to DPC while HALTED.
   // -----------------------------------------------------------------------------

   always_ff @(posedge clk) begin
      if (reset) begin
         DPCset <= 1'b0;
      end else if (state_n != HALTED) begin
         DPCset <= 1'b0;
      end else if ((state == HALTED) & CSRDWriteM & (CSRAdrM == DPC)) begin
         DPCset <= 1'b1;
      end
   end

   // -----------------------------------------------------------------------------
   // Halt cause: latch on entry into HALTED.
   // (This avoids combinational ambiguity and “wrong cause” when multiple signals
   //  overlap.)
   // -----------------------------------------------------------------------------

   // See Section 4.9 of Debug Specification 1.0 (Access: R)
   // 000: No cause - Reset
   // 001: ebreak
   // 010: trigger
   // 011: haltreg
   // 100: step
   // 101: resethaltreq
   // 110: group (no groups implemented)
   // 111: other (refer to extcause)

   always_comb begin
      NextCause = '0;
    if (DebugHaltReq) begin
      NextCause = 3'd3;
    end else if (ebreak) begin
      NextCause = 3'd1;
    end else if (step & InstrValid) begin
      NextCause = 3'd4;
    end else if (ResetHaltReqEnable) begin
      NextCause = 3'd5;
    end else begin
      NextCause = '0;
    end
  end

  // -----------------------------------------------------------------------------
  // DebugHaveReset
  // -----------------------------------------------------------------------------

  always_ff @(posedge clk) begin
    if (reset) begin
      DebugHaveReset <= 1'b1;
    end else if (DebugHaveResetAck) begin
      DebugHaveReset <= 1'b0;
    end
  end

endmodule
