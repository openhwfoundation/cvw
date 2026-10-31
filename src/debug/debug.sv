///////////////////////////////////////////
// debug.sv
//
// Written: Jacob Pease jacobpease@protonmail.com,
//          James E. Stine james.stine@okstate.edu
// Created: August 12th, 2025
// Modified:
//
// Purpose: The Debug Module (DM)
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

module debug import cvw::*; #(parameter cvw_t P) (
  input  logic                 clk,
  input  logic                 reset,

  // CPU Signals
  output logic                 DebugNDMReset,
  output logic                 DebugHaltReq,
  output logic                 DebugResumeReq,
  input  logic                 DebugMode,

  // DMI REQUEST
  input  logic [6:0]           DMIADDR,
  input  logic [31:0]          DMIDATA,
  input  logic [1:0]           DMIOP,
  input  logic                 DMIREADY,
  input  logic                 DMIVALID,

  // DMI RESPONSE
  output logic [31:0]          DMIRSPDATA,
  output logic [1:0]           DMIRSPOP,
  output logic                 DMIRSPREADY,
  output logic                 DMIRSPVALID,

  // APB Requester interface
  output logic                 DebugPCLK, DebugPRESETn,
  output logic                 DebugPENABLE,
  output logic                 DebugPSELRegister,
  output logic                 DebugPSELMemory,
  output logic                 DebugPWRITE,
  output logic [P.LLEN-1:0]    DebugPWDATA,
  output logic [P.LLEN/8-1:0]  DebugPSTRB,
  output logic [15:0]          DebugPADDR,

  // APB Completer interface
  input  logic                 DebugPREADY,
  input  logic [P.LLEN-1:0]    DebugPRDATA,
  input  logic                 DebugPSLVERR,

  // Run State
  input  logic                 DebugHaveReset,
  output logic                 DebugHaveResetAck,
  output logic                 DebugResetHaltReq
);

  typedef enum logic [6:0] {
    DATA0 = 7'h04,
    DATA1 = 7'h05,
    DATA2 = 7'h06,
    DATA3 = 7'h07,
    DATA4 = 7'h08,
    DATA5 = 7'h09,
    DATA6 = 7'h0a,
    DATA7 = 7'h0b,
    DATA8 = 7'h0c,
    DATA9 = 7'h0d,
    DATA10 = 7'h0e,
    DATA11 = 7'h0f,
    DMCONTROL = 7'h10,
    DMSTATUS = 7'h11,
    HARTINFO = 7'h12,
    HALTSUM0 = 7'h40,
    HALTSUM1 = 7'h13,
    COMMAND  = 7'h17,
    ABSTRACTCS = 7'h16,
    ABSTRACTAUTO = 7'h18
  } DMADDR;

  typedef enum logic [1:0] {
    NOP = 2'b00,
    RD  = 2'b01,
    WR  = 2'b10
  } DMIOPW;

  logic      InitRequest;

  // Registers
  logic [31:0] DMControl;
  logic [31:0] DMStatus;
  logic [31:0] Data0;
  logic [31:0] Data1;
  logic [31:0] AbstractCS;
  logic [31:0] Command;

  logic [31:0] NextCommand;

  // DMControl fields
  logic        HartReset;
  logic        SetResetHaltReq;
  logic        ClrResetHaltReq;

  // DMStatus fields
  logic        NDMResetPending;

  // AbstractCS fields
  logic [4:0] ProgBufSize;
  logic        Busy;
  logic        RelaxedPriv;
  logic [2:0]  CMDErr;
  logic [3:0]  DataCount;

  // Resume Ack States and Signals
  typedef enum logic [1:0] {RESACKLOW, RESACKCLEAR, RESACKHIGH} resack_state_e;
  resack_state_e resack_state, next_resack_state;
  logic AllResumeAck;
  logic AnyResumeAck;

  logic AllRunning;
  logic AnyRunning;
  logic AllHalted;
  logic AnyHalted;

  logic ReadRequest;
  logic WriteRequest;

  logic StartCommand;
  logic ValidSize;
  logic AARException;
  logic NewCommand;

  logic DMActive;

  // For Data register reads.
  logic ReadRegister;

  // Resume request pulse state machine
  typedef enum logic {RESUMEREQIDLE, RESUMEREQUEST} ResumeReqState;
  ResumeReqState CurrResumeReq;
  ResumeReqState NextResumeReq;

  // Halt request pulse state machine
  typedef enum logic [1:0] {HALTREQIDLE, HALTREQUEST, WAITFORCLEAR} HaltReqState;
  HaltReqState CurrHaltReq;
  HaltReqState NextHaltReq;

  // Abstract Access Register Command signals
  logic ValidCommand;
  logic NextDebugCSREnable;
  logic NextDebugGPREnable;
  logic NextDebugFPREnable;

  logic CommandWrite;
  logic AccessRegCmd;
  logic [15:0] RegNO;

  // Abstract Commands:
  // 0: Access Register Command
  // 1: Quick Access
  // 2: Access Memory Command

  // --------------------------------------------------------------------------
  // DMI Interface with Registers
  // --------------------------------------------------------------------------
  assign InitRequest = ((DMIOP == RD) | (DMIOP == WR)) & DMIVALID;
  assign ReadRequest = DMIOP == RD & DMIVALID;
  assign WriteRequest = DMIOP == WR & DMIVALID;

  always_ff @(posedge clk) begin
    if (reset) begin
      DMIRSPVALID <= 1'b0;
    end else if (InitRequest) begin
      DMIRSPVALID <= 1'b1;
    end else if (DMIRSPVALID) begin
      DMIRSPVALID <= 1'b0;
    end
  end

  // Reading Registers
  always_ff @(posedge clk) begin
    if (reset) begin
      DMIRSPREADY <= 1'b1;
      DMIRSPDATA <= '0;
      DMIRSPOP <= 2'b0;
      DMIRSPREADY <= 1'b1;
      DMIRSPDATA <= '0;
      DMIRSPOP <= 2'b0;
    end else if (ReadRequest) begin
      case(DMIADDR[6:0])
        DATA0: DMIRSPDATA <= Data0;
        DATA1: begin
          if (P.LLEN == 64) begin
            DMIRSPDATA <= Data1;
          end else begin
            DMIRSPDATA <= '0;
          end
        end

        DMCONTROL: begin
          DMIRSPDATA[31] <= 1'b0; // Always should read haltrequest as zero
          DMIRSPDATA[30:0] <= DMControl[30:0];
        end

        DMSTATUS: begin
          DMIRSPDATA <= {NDMResetPending,
                         DMStatus[30:20],
                         DebugHaveReset, DebugHaveReset,
                         AnyResumeAck, AnyResumeAck,
                         DMStatus[15:12],
                         AllRunning, AnyRunning, AllHalted, AnyHalted,
                         DMStatus[7:0]};
        end

        ABSTRACTCS: DMIRSPDATA <= AbstractCS;
        default: DMIRSPDATA <= 32'b0;
      endcase
    end
  end

  // ----------------------------------------------------------------
  // Writes to registers
  // ----------------------------------------------------------------

  // DMControl
  always_ff @(posedge clk) begin
    if (reset) begin
      DMControl <= '0;
    end else if (WriteRequest & (DMIADDR == DMCONTROL)) begin
      DMControl <= DMControl;
      if (DebugHaltReq) begin
        DMControl[31]    <= DMIDATA[31];
        // Can't write another resume request
        DMControl[29:28] <= DMIDATA[29:28];
        DMControl[3:0]   <= DMIDATA[3:0];
      end else begin
        DMControl <= {DMIDATA[31], 1'b0, DMIDATA[29:28], 24'b0, DMIDATA[3:0]};
      end
    end
  end

  // DMStatus — Debug Module Status (read-only) section 3.14.1
  //
  // Bit fields:
  // [31:25] 0                  — Reserved
  // [24]    ndmresetpending    — NDM reset is in progress (or was requested)
  // [23]    stickyunavail      — Per-hart unavail bits are sticky
  // [22]    impebreak          — Implicit ebreak after Program Buffer
  // [21:20] 0                  — Reserved
  // [19]    allhavereset       — All selected harts have been reset (not yet acked)
  // [18]    anyhavereset       — At least one selected hart has been reset (not yet acked)
  // [17]    allresumeack       — All selected harts have acknowledged their last resume
  // [16]    anyresumeack       — At least one selected hart has acknowledged its last resume
  // [15]    allnonexistent     — All selected harts do not exist
  // [14]    anynonexistent     — At least one selected hart does not exist
  // [13]    allunavail         — All selected harts are unavailable
  // [12]    anyunavail         — At least one selected hart is unavailable
  // [11]    allrunning         — All selected harts are running
  // [10]    anyrunning         — At least one selected hart is running
  // [9]     allhalted          — All selected harts are halted
  // [8]     anyhalted          — At least one selected hart is halted
  // [7]     authenticated      — Authentication has passed (or is not required)
  // [6]     authbusy           — Authentication module is busy
  // [5]     hasresethaltreq    — Halt-on-reset request is implemented
  // [4]     confstrptrvalid    — Configuration string pointer is valid
  // [3:0]   version            — Debug Module version (0=none, 1=0.11, 2=0.13, 3=1.0)
  always_ff @(posedge clk) begin
    if (reset) begin
      DMStatus <= {14'b0, 2'b11, 8'b0, 1'b1, 1'b0, 1'b1, 1'b0, 4'b11}; // ResumeAck's start high
    end else if (WriteRequest & (DMIADDR == DMCONTROL)) begin
      // Force AllResumeAck and AnyResumeAck low if
      // we're writing to ResumeReq p. 28.
      if (DMIDATA[30]) DMStatus[17:16] <= 2'b0;
    end
  end

  // Data Registers, used as arguments for writing to registers and
  // for storing results read from registers. ReadRegister contains
  // the condition from the APB bus, used for Abstract Access Register
  // commands, to write to the data register from the core
  assign ReadRegister = DebugPENABLE & DebugPREADY & ~Command[16];

  // Data[0]
  always_ff @(posedge clk) begin
    if (reset) begin
      Data0 <= '0;
    end else begin
      Data0 <= Data0;
      if (WriteRequest & (DMIADDR == DATA0)) begin
        Data0 <= DMIDATA;
      end else if (ReadRegister) begin
        Data0 <= DebugPRDATA[31:0];
      end
    end
  end

  // Data[1] -- only need this for configurations that have 64 bit registers.
  if (P.LLEN == 64 | P.D_SUPPORTED) begin
    always_ff @(posedge clk) begin
      if (reset) begin
        Data1 <= '0;
      end else begin
        Data1 <= Data1;
        if (WriteRequest & (DMIADDR == DATA1)) begin
          Data1 <= DMIDATA;
        end else if (ReadRegister & (Command[22:20] == 3'd3)) begin
          Data1 <= DebugPRDATA[63:32];
        end
      end
    end
  end

  // Command
  always_ff @(posedge clk) begin
    if (reset) begin
      Command <= '0;
    end else if (WriteRequest & (DMIADDR == COMMAND)) begin
      Command <= DMIDATA;
    end
  end

  // AbstractCS
  always_ff @(posedge clk) begin
    if (reset) begin
      // Number of data registers
      AbstractCS <= P.LLEN > 32 ? 32'h0000_0002 : 32'h000_0001;
    end else if (WriteRequest & (DMIADDR == ABSTRACTCS)) begin
      AbstractCS[11] <= DMIDATA[11]; // RelaxedPriv
      AbstractCS[10:8] <= DMIDATA[8] == 1'b1 ? 3'b0 : AbstractCS[10:8];
    end else if (WriteRequest & (DMIADDR == COMMAND)) begin
      AbstractCS[10:8] <= AbstractCS[10:8] == 3'b0 ? CMDErr : AbstractCS[10:8];
    end else if (DebugPENABLE & DebugPREADY & AARException) begin
      AbstractCS[10:8] <= CMDErr;
    end
  end

  // --------------------------------------------------------------------------
  // Halt FSM
  // --------------------------------------------------------------------------

  always_ff @(posedge clk) begin
    if (reset) begin
      CurrResumeReq <= RESUMEREQIDLE;
    end else begin
      CurrResumeReq <= NextResumeReq;
    end
  end

  logic ResumeReqWrite;
  // DMControl: don't store the W1 bits (30 resumereq, 28 ackhavereset)
  assign ResumeReqWrite = WriteRequest & (DMIADDR == DMCONTROL) & DMIDATA[30] & ~DMIDATA[31];

  // TODO: This is wrong. Resume Request is a W1 field, meaning only a
  // write of 1 should have any effect. This means that this should be
  // cleared when the HART is running not upon DMControl[30] being
  // given a 0.
  always_comb begin
    case(CurrResumeReq)
      RESUMEREQIDLE: begin
        if (ResumeReqWrite & DebugMode) NextResumeReq = RESUMEREQUEST;
        else NextResumeReq = RESUMEREQIDLE;
      end

      RESUMEREQUEST: begin
        if (~DebugMode) NextResumeReq = RESUMEREQIDLE;
        else NextResumeReq = RESUMEREQUEST;
      end

      default: NextResumeReq = RESUMEREQIDLE;
    endcase
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      CurrHaltReq <= HALTREQIDLE;
    end else begin
      CurrHaltReq <= NextHaltReq;
    end
  end

  always_comb begin
    case(CurrHaltReq)
      HALTREQIDLE: begin
        if (DMControl[31] & ~DebugMode) NextHaltReq = HALTREQUEST;
        else NextHaltReq = HALTREQIDLE;
      end

      HALTREQUEST: begin
        if (DebugMode) NextHaltReq = WAITFORCLEAR;
        else NextHaltReq = HALTREQUEST;
      end

      WAITFORCLEAR: begin
        if (~DMControl[31]) NextHaltReq = HALTREQIDLE;
        else NextHaltReq = WAITFORCLEAR;
      end

      default: NextHaltReq = HALTREQIDLE;
    endcase
  end

  assign DebugResumeReq = (CurrResumeReq == RESUMEREQUEST);
  assign DebugHaltReq = (CurrHaltReq == HALTREQUEST) & DMActive;

  // Not implemented, but left here in the case more than one hart is
  // implemented as a reminder.
  assign HartReset = 1'b0;

  //assign DebugHaveResetAck = DMControl[28];
  assign DebugHaveResetAck = WriteRequest & (DMIADDR == DMCONTROL) & DMIDATA[28];
  assign DebugNDMReset = DMControl[1];
  assign DMActive = DMControl[0];

  // Writes to these bits should be ignored if an abstract command is
  // executing. This isn't a problem when only Abstract Register is
  // implemented but could be a problem with Quick Access and Abstract
  // Memory commands. 3.14.2
  assign SetResetHaltReq = DMControl[3];
  assign ClrResetHaltReq = DMControl[2];

  // With Multi-hart, this needs to become a vector
  always_ff @(posedge clk) begin
    if (reset | ClrResetHaltReq) begin
      DebugResetHaltReq <= 1'b0;
    end else if (SetResetHaltReq) begin
      DebugResetHaltReq <= 1'b1;
    end
  end

  // DMStatus signals
  assign NDMResetPending = DebugNDMReset;

  // Single hart for now. When more harts are added, expand to vectors.
  assign AllRunning = ~DebugMode;
  assign AnyRunning = AllRunning;
  assign AllHalted  = DebugMode;
  assign AnyHalted  = AllHalted;

  // -----------------------------------------------------------------------------
  // ResumeAck: resumeack handshake.
  // Set when resume is accepted; clear when debugger drops ResumeReq.
  // (This matches common OpenOCD expectations better than a 1-cycle pulse.)
  // -----------------------------------------------------------------------------

  always_ff @(posedge clk) begin
    if (reset) begin
      resack_state <= RESACKLOW;
    end else begin
      resack_state <= next_resack_state;
    end
  end

  always_comb begin
    case(resack_state)
      RESACKLOW: begin
        if (DebugResumeReq) next_resack_state = RESACKCLEAR;
        else next_resack_state = RESACKLOW;
      end

      RESACKCLEAR: begin
        if (~DebugMode) next_resack_state = RESACKHIGH;
        else next_resack_state = RESACKCLEAR;
      end

      RESACKHIGH: begin
        if (DebugResumeReq) next_resack_state = RESACKCLEAR;
        else next_resack_state = RESACKHIGH;
      end

      default: next_resack_state = RESACKCLEAR;
    endcase
  end

  // This allows a momentary clear right after receiving a ResumeRequest
  assign AnyResumeAck = (resack_state == RESACKHIGH);

  // ------------------------------------------------------------------
  // RISC-V Debug Specification v1.0 Access Register Commands
  // Decodes abstract register-access commands from the Debug Module
  // COMMAND register (Section 3.7.1.1).  Supports GPR, FPR, and CSR
  // accesses through the abstract command interface.
  // ------------------------------------------------------------------

  assign CommandWrite = WriteRequest & (DMIADDR == COMMAND);

  assign NextCommand = DMIDATA;
  assign StartCommand = CommandWrite & DMIRSPREADY & ~|CMDErr & ~|AbstractCS[10:8] & DMActive & DebugMode;

  debug_apb_requester #(P) debug_apb(.clk, .reset,
    .NextCommand, .Command, .StartCommand, .CommandWrite, .Data0, .Data1,
    .ValidCommand, .ValidSize, .AARException,
    .DebugPCLK, .DebugPRESETn, .DebugPENABLE,
    .DebugPSELRegister, .DebugPSELMemory,
    .DebugPWRITE, .DebugPWDATA, .DebugPSTRB, .DebugPADDR,
    .DebugPREADY, .DebugPRDATA, .DebugPSLVERR
  );

  always_comb begin
    CMDErr = 3'd0;
    if (CommandWrite | DebugPREADY) begin
      if (~DebugMode)                      CMDErr = 3'd4;
      else if (AARException)               CMDErr = 3'd3;
      else if (~ValidCommand | ~ValidSize) CMDErr = 3'd2;
      else                                 CMDErr = 3'd0;
    end
  end
endmodule
