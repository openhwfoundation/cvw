///////////////////////////////////////////
// debug.sv
//
// Written: Jacob Pease jacobpease@protonmail.com,
//          James E. Stine james.stine@okstate.edu
// Created: August 12th, 2025
// Modified:
//
// Purpose: An APB Completer for Abstract Access Register Command interface with a Debug Module
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

module debug_apb_completer import cvw::*; #(parameter cvw_t P) (
  // APB Requester signals
  input  logic                DebugPCLK, DebugPRESETn,
  input  logic                DebugPENABLE,
  input  logic                DebugPSELRegister,
  input  logic                DebugPWRITE,
  input  logic [P.LLEN-1:0]   DebugPWDATA,
  input  logic [P.LLEN/8-1:0] DebugPSTRB,
  input  logic [15:0]         DebugPADDR,
  // APB Completer signals
  output logic                DebugPREADY,
  output logic [P.LLEN-1:0]   DebugPRDATA,
  output logic                DebugPSLVERR,
  // Access the three standard types of registers
  output logic                DebugGPREnable,
  output logic                DebugFPREnable,
  output logic                DebugCSREnable,
  // Enable Writes to registers
  output logic [11:0]         DebugRegAddr,
  output logic                DebugRegWrite,
  output logic [P.LLEN-1:0]   DebugRegWDATA,
  // Read values from each set of registers
  input  logic [P.XLEN-1:0]   DebugR1D,
  input  logic [P.FLEN-1:0]   DebugFRD1D,
  input  logic [P.XLEN-1:0]   CSRReadValM,
  // Illegal accesses implying the register does not exist.
  input logic                 IllegalDebugCSRAccess
);

  // This is for APB4 spec compliance. If a custom Debug Module
  // interfaces with this, it will reject partial writes.
  logic GPRAccess, FPRAccess, CSRAccess, Exists;
  logic IllegalPartialWrite, FPRPartialWrite;

  debugregdecode #(P) decode(.RegNO(DebugPADDR), .CSRAccess, .GPRAccess, .FPRAccess);

  assign Exists = GPRAccess | CSRAccess | FPRAccess;
  assign DebugGPREnable = DebugPENABLE & GPRAccess;
  assign DebugCSREnable = DebugPENABLE & CSRAccess;
  assign DebugFPREnable = DebugPENABLE & FPRAccess;

  if (P.F_SUPPORTED) assign FPRPartialWrite = FPRAccess & ~&DebugPSTRB[P.FLEN/8-1:0];
  else               assign FPRPartialWrite = 1'b0;

  assign IllegalPartialWrite = DebugPWRITE & ((GPRAccess | CSRAccess) & ~&DebugPSTRB[P.XLEN/8-1:0] | FPRPartialWrite);

  assign DebugPSLVERR = DebugPENABLE & (IllegalDebugCSRAccess | ~Exists | IllegalPartialWrite);

  assign DebugRegAddr = DebugPADDR[11:0];
  assign DebugRegWrite = DebugPENABLE & DebugPSELRegister & DebugPWRITE & ~DebugPSLVERR;
  assign DebugRegWDATA = DebugPWDATA;

  if (P.F_SUPPORTED) begin
    if (P.FLEN < P.LLEN) begin
      mux3 #(P.LLEN) debugregmux(
        DebugR1D,
        CSRReadValM,
        {{(P.LLEN-P.FLEN){1'b0}}, DebugFRD1D},
        {DebugFPREnable, DebugCSREnable}, // Select
        DebugPRDATA);
    end else if (P.XLEN < P.LLEN) begin
      mux3 #(P.LLEN) debugregmux(
        {{(P.LLEN - P.XLEN){1'b0}}, DebugR1D},
        {{(P.LLEN - P.XLEN){1'b0}}, CSRReadValM},
        DebugFRD1D,
        {DebugFPREnable, DebugCSREnable}, // Select
        DebugPRDATA);
    end else begin
      mux3 #(P.LLEN) debugregmux(DebugR1D, CSRReadValM, DebugFRD1D, {DebugFPREnable, DebugCSREnable}, DebugPRDATA);
    end
  end else begin
    mux2 #(P.XLEN) debugregmux(DebugR1D, CSRReadValM, DebugCSREnable, DebugPRDATA);
  end

  // No reason this shouldn't always be ready
  assign DebugPREADY = 1'b1;

endmodule
