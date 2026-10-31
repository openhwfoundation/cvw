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

module debug_apb_requester import cvw::*; #(parameter cvw_t P) (
  input  logic                 clk, reset,
  input  logic [31:0]          NextCommand,
  input  logic [31:0]          Command,
  input  logic [31:0]          Data0,
  input  logic [31:0]          Data1,
  input  logic                 StartCommand,
  input  logic                 CommandWrite,
  output logic                 ValidCommand,
  output logic                 ValidSize,
  output logic                 AARException,
  output logic                 DebugPCLK, DebugPRESETn,
  output logic                 DebugPENABLE,
  output logic                 DebugPSELRegister,
  output logic                 DebugPSELMemory,
  output logic                 DebugPWRITE,
  output logic [P.LLEN-1:0]    DebugPWDATA,
  output logic [P.LLEN/8-1:0]  DebugPSTRB,
  output logic [15:0]          DebugPADDR,
  input  logic                 DebugPREADY,
  input  logic [P.LLEN-1:0]    DebugPRDATA,
  input  logic                 DebugPSLVERR
);

  // Phases
  logic Idle;
  logic Setup;
  logic Access;

  // NextCommand
  logic [7:0] NextCMDType;
  logic [2:0] NextAARSize;
  logic [15:0] NextRegNO;

  // Comand fields
  logic [7:0]  CMDType;
  logic [2:0]  AARSize;
  logic        AARPostIncrement;
  logic        PostExec;
  logic        Transfer;
  logic        Write;
  logic [15:0] RegNO;

  // Decoding for rejecting certain register sizes
  logic NextFPR;

  // APB Phases
  typedef enum logic [1:0] {IDLE, SETUP, ACCESS} busstatetype;
  busstatetype CurrState, NextState;

  // NextCommand unpacking
  assign NextCMDType      = NextCommand[31:24];
  assign NextAARSize      = NextCommand[22:20];
  assign NextRegNO        = NextCommand[15:0];

  // Command unpacking
  assign CMDType          = Command[31:24];
  assign AARSize          = Command[22:20];
  assign AARPostIncrement = Command[19];
  assign PostExec         = Command[18];
  assign Transfer         = Command[17];
  assign Write            = Command[16];
  assign RegNO            = Command[15:0];


  assign DebugPCLK = clk;
  assign DebugPRESETn = ~reset;

  // -----------------------------------------------------------------
  // APB State Machine
  // -----------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (reset) begin
      CurrState <= IDLE;
    end else begin
      CurrState <= NextState;
    end
  end

  always_comb begin
    case (CurrState)
      IDLE: begin
        if (StartCommand) NextState = SETUP;
        else              NextState = IDLE;
      end

      SETUP: begin
        NextState = ACCESS;
      end

      ACCESS: begin
        if (DebugPREADY) NextState = IDLE;
        else        NextState = ACCESS;
      end

      default: NextState = IDLE;
    endcase
  end

  // -----------------------------------------------------------------
  // Bus assignments
  // -----------------------------------------------------------------

  assign Idle   = (CurrState == IDLE);
  assign Setup  = (CurrState == SETUP);
  assign Access = (CurrState == ACCESS);

  assign DebugPSELRegister = ~Idle & (CMDType == 8'h00);
  assign DebugPSELMemory   = ~Idle & (CMDType == 8'h02);
  assign DebugPWRITE       = ~Idle & Write;

  assign DebugPENABLE = Access;

  // APB4 Compliance
  assign DebugPSTRB = DebugPWRITE ? '1 : '0;

  if (P.LLEN > 32) begin
    assign DebugPWDATA = AARSize == 3'd2 ? {32'h0, Data0} : {Data1, Data0};
  end else begin
    assign DebugPWDATA = Data0;
  end

  assign DebugPADDR = RegNO;

  assign ValidCommand = CommandWrite & (NextCMDType == 8'd0);

  debugregdecode #(P) nextdecode(.RegNO(NextRegNO), .CSRAccess(), .GPRAccess(), .FPRAccess(NextFPR));
  assign ValidSize = CommandWrite & ((NextAARSize == 3'd2)
      | (NextAARSize == 3'd3 & (NextFPR ? P.D_SUPPORTED : (P.XLEN == 64)))
      | (NextAARSize == 3'd4 & NextFPR & P.Q_SUPPORTED));

  // CMDErr for non-existent registers. Gets registered into
  // AbstractCS upon DebugPREADY
  assign AARException = DebugPENABLE & DebugPREADY & DebugPSLVERR;

endmodule
