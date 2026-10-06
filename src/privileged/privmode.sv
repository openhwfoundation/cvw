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
// https://github.com/openhwfoundation/cvw
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
  input  logic             VSSTATUS_SPP,        // virtual supervisor trap previous privilege mode
  input  logic             MSTATUS_MPV,         // from mstatus
  input  logic             HSTATUS_SPV,         // from hstatus
  input  logic             TrapToVSM,           // resolved trap target
  output logic [1:0]       NextPrivilegeModeM,  // next privilege mode, used when updating STATUS CSR on a trap
  output logic [1:0]       PrivilegeModeW,      // current privilege mode
  output logic             VirtModeW            // current V
);

  if (P.U_SUPPORTED) begin : privmode
    // PrivilegeMode FSM
    always_comb begin
      if (TrapM) begin // Change privilege based on DELEG registers (see 3.1.8)
        if (P.S_SUPPORTED & DelegateM) NextPrivilegeModeM = P.S_MODE;
        else                           NextPrivilegeModeM = P.M_MODE;
      end else if (mretM)              NextPrivilegeModeM = STATUS_MPP;
      else if (sretM) begin
        if (P.H_SUPPORTED)             NextPrivilegeModeM = {1'b0, (VirtModeW ? VSSTATUS_SPP : STATUS_SPP)};
        else                           NextPrivilegeModeM = {1'b0, STATUS_SPP};
      end

      else                             NextPrivilegeModeM = PrivilegeModeW;
    end

    flopenl #(2) privmodereg(clk, reset, ~StallW, NextPrivilegeModeM, P.M_MODE, PrivilegeModeW);
  end else begin  // only machine mode supported
    assign NextPrivilegeModeM = P.M_MODE;
    assign PrivilegeModeW = P.M_MODE;
  end

  if (P.H_SUPPORTED) begin:virtmode
    logic NextVirtModeM;
    always_comb begin
      NextVirtModeM = VirtModeW;
      if (TrapM)
        NextVirtModeM = TrapToVSM;
      else if (mretM)
        NextVirtModeM = (STATUS_MPP != P.M_MODE) & MSTATUS_MPV;
      else if (sretM & ~VirtModeW)
        NextVirtModeM = HSTATUS_SPV;
    end

    flopenr #(1) virtmodereg(clk, reset, ~StallW, NextVirtModeM, VirtModeW);
  end else begin
    assign VirtModeW     = 1'b0;
  end
endmodule
