///////////////////////////////////////////
// privmode.sv
//
// Written: David_Harris@hmc.edu 12 May 2022
// Modified:
//
// Purpose: Track privilege mode.  Change on traps and returns.
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
////////////////////////////////////////////////////////////////////////////////////////////////

module privmode import cvw::*;  #(parameter cvw_t P) (
  input  logic             clk, reset,
  input  logic             StallW,
  input  logic             TrapM,               // Trap
  input  logic             mretM, sretM,        // return instruction
  input  logic             DelegateM,           // trap delegated to supervisor mode
  input  logic [1:0]       STATUS_MPP,          // machine trap previous privilege mode
  input  logic             STATUS_SPP,          // supervisor trap previous privilege mode
  input  logic [1:0]       DebugPrivilegeMode,  // Privilege mode from DCSR.prv
  input  logic             DebugSetPrivMode,    // Enable using the Privilege Mode from the DCSR
  output logic [1:0]       NextPrivilegeModeM,  // next privilege mode, used when updating STATUS CSR on a trap
  output logic [1:0]       PrivilegeModeW       // current privilege mode
);

  if (P.U_SUPPORTED) begin : privmode
    // PrivilegeMode FSM
    always_comb begin
      if (TrapM) begin // Change privilege based on DELEG registers (see 3.1.8)
        if (P.S_SUPPORTED & DelegateM) NextPrivilegeModeM = P.S_MODE;
        else                           NextPrivilegeModeM = P.M_MODE;
      end else if (mretM)              NextPrivilegeModeM = STATUS_MPP;
      else     if (sretM)              NextPrivilegeModeM = {1'b0, STATUS_SPP};
      else     if (DebugSetPrivMode)   NextPrivilegeModeM = DebugPrivilegeMode;
      else                             NextPrivilegeModeM = PrivilegeModeW;
    end

    flopenl #(2) privmodereg(clk, reset, ~StallW | DebugSetPrivMode, NextPrivilegeModeM, P.M_MODE, PrivilegeModeW);
  end else begin  // only machine mode supported
    assign NextPrivilegeModeM = P.M_MODE;
    assign PrivilegeModeW = P.M_MODE;
  end
endmodule
