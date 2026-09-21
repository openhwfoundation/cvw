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
  input  logic              clk,
  input  logic              reset,

  // CPU Signals
  output logic              DebugNDMReset,
  output logic              DebugHaltReq,
  output logic              DebugResumeReq,
  input  logic              DebugMode,
  output logic              DebugGPREnable,
  output logic              DebugCSREnable,
  output logic              DebugFPREnable,

  // DMI REQUEST
  input  logic [6:0]         DMIADDR,
  input  logic [31:0]        DMIDATA,
  input  logic [1:0]         DMIOP,
  input  logic               DMIREADY,
  input  logic               DMIVALID,

  // DMI RESPONSE
  output logic [31:0]       DMIRSPDATA,
  output logic [1:0]        DMIRSPOP,
  output logic              DMIRSPREADY,
  output logic              DMIRSPVALID,

  // Reading and Writing Registers
  input  logic [P.LLEN-1:0] DebugRegRDATA,
  output logic [P.LLEN-1:0] DebugRegWDATA,
  output logic [11:0]       DebugRegAddr,
  output logic              DebugRegWrite,

  // Run State
  input  logic              DebugHaveReset,
  output logic              DebugHaveResetAck,
  output logic              DebugResetHaltReq
);

  // Available CSRs
  // This is based on the current configuration. All possible CSR
  // addresses are stored here in localparams and certain addresses
  // are included in the cases, if they are supported.

  // Machine CSRs
  localparam MVENDORID     = 16'h0F11;
  localparam MARCHID       = 16'h0F12;
  localparam MIMPID        = 16'h0F13;
  localparam MHARTID       = 16'h0F14;
  localparam MCONFIGPTR    = 16'h0F15;
  localparam MSTATUS       = 16'h0300;
  localparam MISA_ADR      = 16'h0301;
  localparam MEDELEG       = 16'h0302;
  localparam MIDELEG       = 16'h0303;
  localparam MIE           = 16'h0304;
  localparam MTVEC         = 16'h0305;
  localparam MCOUNTEREN    = 16'h0306;
  localparam MENVCFG       = 16'h030A;
  localparam MSTATUSH      = 16'h0310;
  localparam MENVCFGH      = 16'h031A;
  localparam MCOUNTINHIBIT = 16'h0320;
  localparam MSCRATCH      = 16'h0340;
  localparam MEPC          = 16'h0341;
  localparam MCAUSE        = 16'h0342;
  localparam MTVAL         = 16'h0343;
  localparam MIP           = 16'h0344;
  localparam PMPCFG0       = 16'h03A0;
  // .. up to 15 more at consecutive addresses
  localparam PMPADDR0      = 16'h03B0;
  // ... up to 63 more at consecutive addresses
  /* verilator lint_off UNUSEDPARAM */
  localparam TSELECT       = 16'h07A0;
  localparam TDATA1        = 16'h07A1;
  localparam TDATA2        = 16'h07A2;
  localparam TDATA3        = 16'h07A3;
  localparam TINFO         = 16'h07A4;
  localparam DCSR          = 16'h07B0;
  localparam DPC           = 16'h07B1;
  localparam DSCRATCH0     = 16'h07B2;
  localparam DSCRATCH1     = 16'h07B3;

  // Supervisor CSRs
  localparam SSTATUS    = 16'h0100;
  localparam SIE        = 16'h0104;
  localparam STVEC      = 16'h0105;
  localparam SCOUNTEREN = 16'h0106;
  localparam SENVCFG    = 16'h010A;
  localparam SSCRATCH   = 16'h0140;
  localparam SEPC       = 16'h0141;
  localparam SCAUSE     = 16'h0142;
  localparam STVAL      = 16'h0143;
  localparam SIP        = 16'h0144;
  localparam STIMECMP   = 16'h014D;
  localparam STIMECMPH  = 16'h015D;
  localparam SATP       = 16'h0180;

  // User CSRs
  localparam FFLAGS = 16'h0001;
  localparam FRM    = 16'h0002;
  localparam FCSR   = 16'h0003;

  // Counter CSRs
  localparam MHPMCOUNTERBASE  = 16'h0B00;
  localparam MTIME            = 16'h0B01;               // this is a memory-mapped register; no such CSR exists, and access should faul;
  localparam MHPMCOUNTERHBASE = 16'h0B80;
  localparam MTIMEH           = 16'h0B81;               // this is a memory-mapped register; no such CSR exists, and access should fault
  localparam MHPMEVENTBASE    = 16'h0323;
  localparam MHPMEVENTLAST    = 16'h033F;
  localparam HPMCOUNTERBASE   = 16'h0C00;
  localparam HPMCOUNTERHBASE  = 16'h0C80;
  localparam TIME             = 16'h0C01;
  localparam TIMEH            = 16'h0C81;

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

  logic [31:0] NextDMControl;
  logic [31:0] NextDMStatus;
  logic [31:0] NextAbstractCS;
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

  // Abstract Register signals
  logic [7:0]  CMDType;
  logic [2:0]  AARSize;
  logic [2:0]  NextAARSize;
  logic        AARPostIncrement;

  logic        ReadRequest;
  logic        WriteRequest;

  logic StartCommand;
  logic NextValid;
  logic ValidSize;

  logic DMActive;

  // For Data register reads.
  logic ReadRegister;

  // Resume request pulse state machine
  typedef enum logic [1:0] {RESUMEREQIDLE, RESUMEREQUEST, RESUMEWAITCLEAR} ResumeReqState;
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
      DMIRSPVALID <= NextValid;
    end else if (DMIRSPVALID) begin
      DMIRSPVALID <= 1'b0;
    end
  end

  always_comb begin
    if (ReadRequest) begin
      NextValid = 1'b1;
    end else if (WriteRequest) begin
      case(DMIADDR[6:0])
        COMMAND: begin
          NextValid = ~|AbstractCS[10:8] ? StartCommand : 1'b1;
        end
        default: NextValid = 1'b1;
      endcase
    end else begin
      NextValid = 1'b0;
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
          DMIRSPDATA[31] <= 1'b0;
          DMIRSPDATA[30:0] <= DMControl[30:0];
        end

        DMSTATUS: begin
          // Might need a separate always_comb for every register.
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
  /*
    These contain complicated enable logic. Conditions that happen based
    on state can cause these to change outside of DMI transactions.

    In order to not confuse synthesis, these are placed in their own
    behavioral blocks. The enable logic is now clear for all of these
    registers.
    */

  // DMControl
  always_ff @(posedge clk) begin
    if (reset) begin
      DMControl <= '0;
    end else if (WriteRequest & (DMIADDR == DMCONTROL)) begin
      DMControl <= DMControl;
      if (DebugHaltReq) begin
        DMControl <= {DMIDATA[31], 1'b0, DMIDATA[29:28], 24'b0, DMIDATA[3:0]};
      end else begin
        DMControl <= {DMIDATA[31:28], 24'b0, DMIDATA[3:0]};
      end
    end
  end

  // DMStatus
  // This doesn't get updated on writes to DMStatus because it's a read only register.
  always_ff @(posedge clk) begin
    if (reset) begin
      DMStatus <= {14'b0, 2'b11, 8'b0, 1'b1, 1'b0, 1'b1, 1'b0, 4'b11}; // ResumeAck's start high
    end else if (WriteRequest & (DMIADDR == DMCONTROL)) begin
      // Force AllResumeAck and AnyResumeAck low if
      // we're writing to ResumeReq p. 28. There will
      // always be at least 1 cycle of latency after
      // receving the ResumeReq
      if (DMIDATA[30]) DMStatus <= {DMStatus[31:18], 2'b0, DMStatus[15:0]};
    end
  end

  // Data Registers, used as arguments for writing to registers and
  // for storing results read from registers.
  assign ReadRegister = StartCommand & ~Command[16];

  // Data[0]
  always_ff @(posedge clk) begin
    if (reset) begin
      Data0 <= '0;
    end else begin
      Data0 <= Data0;
      if (WriteRequest & (DMIADDR == DATA0)) begin
        Data0 <= DMIDATA;
      end else if (ReadRegister) begin
        Data0 <= DebugRegRDATA[31:0];
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
        end else if (ReadRegister) begin
          Data1 <= DebugRegRDATA[63:32];
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
      AbstractCS <= {AbstractCS[31:12],
                     DMIDATA[11], // RelaxedPriv
                     DMIDATA[8] == 1'b1 ? 3'b0 : AbstractCS[10:8], // CMDErr -> R/W1C
                     AbstractCS[7:0]}; // Only RelaxedPriv and CMDErr are writeable
    end else if (WriteRequest & (DMIADDR == COMMAND)) begin
      AbstractCS <= {AbstractCS[31:11], AbstractCS[10:8] == 3'b0 ? CMDErr : AbstractCS[10:8], AbstractCS[7:0]};
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

  always_comb begin
    case(CurrResumeReq)
      RESUMEREQIDLE: begin
        if (DMControl[30] & DebugMode) NextResumeReq = RESUMEREQUEST;
        else NextResumeReq = RESUMEREQIDLE;
      end

      RESUMEREQUEST: begin
        if (~DebugMode) NextResumeReq = RESUMEWAITCLEAR;
        else NextResumeReq = RESUMEREQUEST;
      end

      RESUMEWAITCLEAR: begin
        if (~DMControl[30]) NextResumeReq = RESUMEREQIDLE;
        else NextResumeReq = RESUMEWAITCLEAR;
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

  assign DebugHaveResetAck = DMControl[28];
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

  // --------------------------------------------------------------------------
  // Abstract Command FSM
  // --------------------------------------------------------------------------

  enum logic [1:0] {IDLE, BUSY, ERRORWAIT, ERRORBUSY} AbstractState;

  // Abstract Command FSM
  always_ff @(posedge clk) begin
    if (reset) begin
      AbstractState <= IDLE;
    end else begin
      case(AbstractState)
        IDLE: begin
          if (Command[31:24] == 8'b0) begin
            AbstractState <= IDLE; // Reading and writing to registers should be immediate.
          end else begin
            AbstractState <= BUSY; // This would be for Quick Access or Memory Access conditions
          end
        end

        BUSY: begin
          // To be implemented; necessary for abstract memory
        end

        ERRORWAIT: begin

        end

        ERRORBUSY: begin

        end
        default: AbstractState <= IDLE;
      endcase
    end
  end

  assign AARSize = Command[22:20];
  assign DebugRegWrite = Command[16] & StartCommand & DebugMode;

  // Covering both 32 bit and 64 bit architectures.
  if (P.LLEN > 32) begin
    assign DebugRegWDATA = AARSize == 3'd2 ? {32'h0, Data0} : {Data1, Data0};
  end else begin
    assign DebugRegWDATA = Data0;
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      StartCommand <= 0;
      DebugRegAddr <= '0;
      DebugCSREnable <= 0;
      DebugFPREnable <= 0;
      DebugGPREnable <= 0;
    end else begin
      StartCommand <= DMIVALID & DMIRSPREADY & (DMIADDR == COMMAND) & ~|CMDErr & DMActive & DebugMode;
      DebugRegAddr <= DMIDATA[11:0];
      DebugGPREnable <= NextDebugGPREnable & DebugMode;
      DebugFPREnable <= NextDebugFPREnable & DebugMode;
      DebugCSREnable <= NextDebugCSREnable & DebugMode;
    end
  end

  // ------------------------------------------------------------------
  // RISC-V Debug Specification v1.0 Access Register Commands
  // Decodes abstract register-access commands from the Debug Module
  // COMMAND register (Section 3.7.1.1).  Supports GPR, FPR, and CSR
  // accesses through the abstract command interface.
  // ------------------------------------------------------------------
  // verilator lint_off WIDTH

  assign RegNO = DMIDATA[15:0];

  always_comb begin
    ValidCommand         = 0;
    NextDebugGPREnable   = 0;
    NextDebugFPREnable   = 0;
    NextDebugCSREnable   = 0;

    if (DMIADDR == COMMAND) begin
      case (RegNO) inside
        // GPRs
        // [16'h1000:16'h101f]: begin
        //   ValidCommand       = 1;
        //   NextDebugGPREnable = 1;
        // end

        [16'h1000:16'h100f]: begin
          ValidCommand       = 1;
          NextDebugGPREnable = 1;
        end

        //
        [16'h1010:16'h101f]: begin
          if (~P.E_SUPPORTED) begin
            ValidCommand       = 1;
            NextDebugGPREnable = 1;
          end
        end

        // FPRs
        [16'h1020:16'h103f]: begin
          if (P.F_SUPPORTED) begin
            ValidCommand       = 1;
            NextDebugFPREnable = 1;
          end
        end

        // ------------------------------------------------------------------
        // Machine CSRs (unconditional portion)
        // ------------------------------------------------------------------
        MVENDORID, MARCHID, MIMPID, MHARTID, MCONFIGPTR,
          MSTATUS, MISA_ADR, MIE, MTVEC, MCOUNTINHIBIT,
          MSCRATCH, MEPC, MCAUSE, MTVAL, MIP: begin
            ValidCommand       = 1;
            NextDebugCSREnable = 1;
          end

        MIDELEG, MEDELEG: begin
          if (P.S_SUPPORTED) begin
            ValidCommand = 1;
            NextDebugCSREnable = 1;
          end
        end

        // Conditional Machine CSRs
        MSTATUSH: begin
          if (P.XLEN == 32) begin
            ValidCommand       = 1;
            NextDebugCSREnable = 1;
          end
        end

        MENVCFG, MCOUNTEREN: begin
          if (P.U_SUPPORTED) begin
            ValidCommand       = 1;
            NextDebugCSREnable = 1;
          end
        end

        MENVCFGH: begin
          if (P.U_SUPPORTED & P.XLEN == 32) begin
            ValidCommand       = 1;
            NextDebugCSREnable = 1;
          end
        end

        [PMPADDR0:PMPADDR0 + P.PMP_ENTRIES - 1]: begin
          ValidCommand       = 1;
          NextDebugCSREnable = 1;
        end

        [PMPCFG0:PMPCFG0 + P.PMP_ENTRIES/4 - 1]: begin
          if (!(P.XLEN == 64 && DMIDATA[0] != 0)) begin
            ValidCommand       = 1;
            NextDebugCSREnable = 1;
          end
        end

        // ------------------------------------------------------------------
        // Supervisor CSRs
        // ------------------------------------------------------------------
        SSTATUS, STVEC, SIP, SIE, SSCRATCH,
          SEPC, SCAUSE, STVAL, SCOUNTEREN, SENVCFG: begin
            if (P.S_SUPPORTED) begin
              ValidCommand       = 1;
              NextDebugCSREnable = 1;
            end
          end

        // Remaining conditional Supervisor CSRs
        SATP: begin
          if (P.VIRTMEM_SUPPORTED) begin
            ValidCommand       = 1;
            NextDebugCSREnable = 1;
          end
        end

        STIMECMP: begin
          if (P.SSTC_SUPPORTED) begin
            ValidCommand       = 1;
            NextDebugCSREnable = 1;
          end
        end

        STIMECMPH: begin
          if (P.SSTC_SUPPORTED && P.XLEN == 32) begin
            ValidCommand       = 1;
            NextDebugCSREnable = 1;
          end
        end

        // User floating-point CSRs
        FFLAGS, FRM, FCSR: begin
          if (P.F_SUPPORTED) begin
            ValidCommand       = 1;
            NextDebugCSREnable = 1;
          end
        end

        TIME: begin
          if (P.ZICNTR_SUPPORTED) begin
            ValidCommand       = 1;
            NextDebugCSREnable = 1;
          end
        end

        // Counter CSRs
        TIMEH: begin
          if (P.ZICNTR_SUPPORTED & P.XLEN == 32) begin
            ValidCommand       = 1;
            NextDebugCSREnable = 1;
          end
        end

        [MHPMEVENTBASE:MHPMEVENTLAST]: begin
          if (P.ZICNTR_SUPPORTED) begin
            ValidCommand       = 1;
            NextDebugCSREnable = 1;
          end
        end

        // Performance counter CSRs
        [MHPMCOUNTERBASE:MHPMCOUNTERBASE + P.COUNTERS - 1]: begin
          if (P.ZICNTR_SUPPORTED & RegNO != MTIME) begin
            ValidCommand = 1;
            NextDebugCSREnable = 1;
          end
        end

        [HPMCOUNTERBASE:HPMCOUNTERBASE + P.COUNTERS - 1]: begin
          if (P.ZICNTR_SUPPORTED) begin
            ValidCommand       = 1;
            NextDebugCSREnable = 1;
          end
        end

        [MHPMCOUNTERHBASE:MHPMCOUNTERHBASE + P.COUNTERS - 1]: begin
          if (P.ZICNTR_SUPPORTED & (RegNO != MTIMEH) & P.XLEN == 32) begin
            ValidCommand       = 1;
            NextDebugCSREnable = 1;
          end
        end

        [HPMCOUNTERHBASE:HPMCOUNTERHBASE + P.COUNTERS - 1]: begin
          if (P.ZICNTR_SUPPORTED & P.XLEN == 32) begin
            ValidCommand       = 1;
            NextDebugCSREnable = 1;
          end
        end

        // Debug CSRs
        DCSR, DPC: begin
            ValidCommand       = 1;
            NextDebugCSREnable = 1;
          end

        TSELECT, TDATA1, TDATA2, TINFO: begin
          if (P.TRIG_SUPPORTED) begin
            ValidCommand       = 1;
            NextDebugCSREnable = 1;
          end
        end

        default: ;
      endcase
    end
  end
  // verilator lint_on WIDTH

  assign CommandWrite  = WriteRequest & (DMIADDR == COMMAND);
  assign AccessRegCmd  = CommandWrite & (DMIDATA[31:24] == 8'd0);

  assign NextAARSize   = DMIDATA[22:20];
  assign ValidSize     = (NextAARSize == 3'd2)
                       | (NextAARSize == 3'd3 & (P.XLEN == 64 | (NextDebugFPREnable & P.D_SUPPORTED)))
                       | (NextAARSize == 3'd4 & NextDebugFPREnable & P.Q_SUPPORTED);

  always_comb begin
    CMDErr = 3'd0;
    if (CommandWrite) begin
      if (~DebugMode)                    CMDErr = 3'd4;
      else if (~AccessRegCmd)            CMDErr = 3'd2;
      else if (~ValidCommand)            CMDErr = 3'd3;
      else if (~ValidSize)               CMDErr = 3'd2;
    end
  end
endmodule
