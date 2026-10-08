///////////////////////////////////////////
// fdivsqrtfsm.sv
//
// Written: David_Harris@hmc.edu, me@KatherineParry.com, cturek@hmc.edu
// Modified:13 January 2022
//
// Purpose: divsqrt state machine for multi-cycle operations
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

module fdivsqrtfsm import cvw::*;  #(parameter cvw_t P) (
  input  logic                clk, reset,
  input  logic                XInfE, YInfE,
  input  logic                XZeroE, YZeroE,
  input  logic                XNaNE, YNaNE,
  input  logic                FDivStartE, IDivStartE,
  input  logic                XsE, WZeroE,
  input  logic                SqrtE,
  input  logic                StallM, FlushE,
  input  logic                IntDivE,
  input  logic                ISpecialCaseE,
  input  logic [P.DURLEN-1:0] CyclesE,
  output logic                IFDivStartE,
  output logic                FDivBusyE, FDivDoneE,
  output logic                SpecialCaseM
);

  typedef enum logic [1:0] {IDLE, BUSY, DONE} statetype;
  statetype state;

  logic SpecialCaseE, FSpecialCaseE;
  logic [P.DURLEN-1:0] step;

  // FDivStartE and IDivStartE come from fctrl, reflecitng the start of floating-point and possibly integer division
  assign IFDivStartE = (FDivStartE | (IDivStartE & P.IDIV_ON_FPU)) & (state == IDLE) & ~StallM;
  assign FDivDoneE = (state == DONE);
  assign FDivBusyE = (state == BUSY) | IFDivStartE;

  // terminate immediately on special cases
  assign FSpecialCaseE = XZeroE | XInfE  | XNaNE |  (XsE&SqrtE) | (YZeroE | YInfE | YNaNE)&~SqrtE;
  if (P.IDIV_ON_FPU) assign SpecialCaseE = IntDivE ? ISpecialCaseE : FSpecialCaseE;
  else               assign SpecialCaseE = FSpecialCaseE;
  flopenr #(1) SpecialCaseReg(clk, reset, IFDivStartE, SpecialCaseE, SpecialCaseM); // save SpecialCase for checking in fdivsqrtpostproc

  always_ff @(posedge clk) begin
      if (reset | FlushE) begin
          state <= IDLE;
      end else if (IFDivStartE) begin // IFDivStartE implies stat is IDLE
          step <= CyclesE;
          if (SpecialCaseE) state <= DONE;
          else              state <= BUSY;
      end else if (state == BUSY) begin
          if (step == 1 | WZeroE) state <= DONE; // finished steps or terminate early on zero residual
          step <= step - 1;
      end else if (state == DONE) begin // Can't still be stalled in configs tested, but keep this check for paranoia
        if (StallM) state <= DONE; // exclusion-tag: fdivsqrtfsm stallm
        else        state <= IDLE;
      end
  end

endmodule
