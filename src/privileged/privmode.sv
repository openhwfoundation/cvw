///////////////////////////////////////////
// privmode.sv
//
// Written:  David Harris David_Harris@hmc.edu 12 May 2022
// Modified:
//
// Purpose: Tracks the current privilege mode and updates it on traps and returns.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2022-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module privmode import cvw::*;  #(parameter cvw_t P) (
  input  logic             clk, reset,
  input  logic             StallW,
  input  logic             TrapM,               // Trap
  input  logic             mretM, sretM,        // return instruction
  input  logic             DelegateM,           // trap delegated to supervisor mode
  input  logic [1:0]       STATUS_MPP,          // machine trap previous privilege mode
  input  logic             STATUS_SPP,          // supervisor trap previous privilege mode
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
      else                             NextPrivilegeModeM = PrivilegeModeW;
    end

    flopenl #(2) privmodereg(clk, reset, ~StallW, NextPrivilegeModeM, P.M_MODE, PrivilegeModeW);
  end else begin  // only machine mode supported
    assign NextPrivilegeModeM = P.M_MODE;
    assign PrivilegeModeW = P.M_MODE;
  end
endmodule
