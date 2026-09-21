//////////////////////////////////////////////////////////////////////
// trigger.sv
//
// Written:  Jacob Pease jacobpease@protonmail.com
//           James E. Stine james.stine@okstate.edu
// Created:  12 March 2026
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

module trigger import cvw::*;  #(parameter cvw_t P) (
  input logic               clk, reset,
  input logic               CSRTrigWriteM,
  input logic [P.XLEN-1:0]  CSRWriteValM,
  input logic [11:0]        CSRAdrM,
  output logic [P.XLEN-1:0] CSRTrigReadValM,
  output logic              IllegalCSRTrigAccessM,
  input logic [P.XLEN-1:0]  PCM,
  input logic               InstrValid,
  input logic [1:0]         PrivilegeModeW,
  input logic               DebugMode,
  input logic               DebugResume,
  input logic               BreakpointFaultM,
  output logic              TriggerHalt
);

  localparam TSELECT = 12'h7a0;
  localparam TDATA1  = 12'h7a1;
  localparam TDATA2  = 12'h7a2;
  localparam TINFO   = 12'h7a4;

  always_comb begin
    if (DebugMode == 1 | PrivilegeModeW == P.M_MODE) begin
      case (CSRAdrM)
        TSELECT: begin
          CSRTrigReadValM = '0;
          IllegalCSRTrigAccessM = 1'b0;
        end

        TDATA1: begin
          CSRTrigReadValM = '0;
          IllegalCSRTrigAccessM = 1'b0;
        end

        TDATA2: begin
          CSRTrigReadValM = '0;
          IllegalCSRTrigAccessM = 1'b0;
        end

        TINFO: begin
          CSRTrigReadValM = '0;
          IllegalCSRTrigAccessM = 1'b0;
        end

        default: begin
          CSRTrigReadValM = '0;
          IllegalCSRTrigAccessM = 1'b1;
        end

      endcase
    end else begin
      CSRTrigReadValM = '0;
      IllegalCSRTrigAccessM = 1'b1;
    end
  end

  assign TriggerHalt = 1'b0;
endmodule
