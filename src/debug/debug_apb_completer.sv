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

module debug_apb_completer import cvw::*; #(parameter cvw_t P) (
  // APB Requester signals
  input  logic                PCLK, PRESETn,
  input  logic                PENABLE,
  input  logic                PSELRegister,
  input  logic                PWRITE,
  input  logic [P.LLEN-1:0]   PWDATA,
  input  logic [15:0]         PADDR,
  // APB Completer signals
  output logic                PREADY,
  output logic [P.LLEN-1:0]   PRDATA,
  output logic                PSLVERR,
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

  logic Exists;

  always_comb begin
    DebugGPREnable = 1'b0;
    DebugCSREnable = 1'b0;
    DebugFPREnable = 1'b0;
    Exists         = 1'b0;
    case (PADDR) inside
      // GPRs
      [16'h1000:16'h100f]: begin
        DebugGPREnable = PENABLE;
        Exists         = 1'b1;
      end

      [16'h1010:16'h101f]: begin
        if (~P.E_SUPPORTED) begin
          DebugGPREnable = PENABLE;
          Exists         = 1'b1;
        end
      end

      // CSRs
      [16'h0000:16'h0fff]: begin
        DebugCSREnable = PENABLE;
        Exists         = 1'b1;
      end

      // FPRs
      [16'h1020:16'h103f]: begin
        if (P.F_SUPPORTED) begin
          DebugFPREnable = PENABLE;
          Exists         = 1'b1;
        end
      end

      default: begin
        DebugGPREnable = 1'b0;
        DebugFPREnable = 1'b0;
        DebugCSREnable = 1'b0;
        Exists         = 1'b0;
      end
    endcase
  end

  assign PSLVERR = PENABLE & (IllegalDebugCSRAccess | ~Exists);

  assign DebugRegAddr = PADDR[11:0];
  assign DebugRegWrite = PENABLE & PSELRegister & PWRITE;
  assign DebugRegWDATA = PWDATA;

  if (P.F_SUPPORTED) begin
    if (P.FLEN < P.LLEN) begin
      mux3 #(P.LLEN) debugregmux(DebugR1D, CSRReadValM, {{(P.LLEN-P.FLEN){1'b0}}, DebugFRD1D}, {DebugFPREnable, DebugCSREnable}, PRDATA);
    end else if (P.XLEN < P.LLEN) begin
      mux3 #(P.LLEN) debugregmux({{(P.LLEN - P.XLEN){1'b0}}, DebugR1D}, {{(P.LLEN - P.XLEN){1'b0}}, CSRReadValM}, DebugFRD1D, {DebugFPREnable, DebugCSREnable}, PRDATA);
    end else begin
      mux3 #(P.LLEN) debugregmux(DebugR1D, CSRReadValM, DebugFRD1D, {DebugFPREnable, DebugCSREnable}, PRDATA);
    end
  end else begin
    mux2 #(P.XLEN) debugregmux(DebugR1D, CSRReadValM, DebugCSREnable, PRDATA);
  end

  // No reason this shouldn't always be ready
  assign PREADY = 1'b1;

endmodule
