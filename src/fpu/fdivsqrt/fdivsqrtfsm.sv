///////////////////////////////////////////
// fdivsqrtfsm.sv
//
// Written:  David Harris David_Harris@hmc.edu, Katherine Parry me@KatherineParry.com, Cedar Turek cturek@hmc.edu 7 July 2022
// Modified:
//
// Purpose: Divide and square root state machine.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2022-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
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

  // FDivStartE and IDivStartE come from fctrl, reflecting the start of floating-point and possibly integer division
  assign IFDivStartE = (FDivStartE | (IDivStartE & P.IDIV_ON_FPU)) & (state == IDLE) & ~StallM;
  assign FDivDoneE = (state == DONE);
  assign FDivBusyE = (state == BUSY) | IFDivStartE;

  // terminate immediately on special cases: X is 0, Inf, or NaN; sqrt of negative X; or divide with Y 0, Inf, or NaN
  assign FSpecialCaseE = XZeroE | XInfE | XNaNE | (XsE & SqrtE) | (YZeroE | YInfE | YNaNE) & ~SqrtE;
  if (P.IDIV_ON_FPU) assign SpecialCaseE = IntDivE ? ISpecialCaseE : FSpecialCaseE;
  else               assign SpecialCaseE = FSpecialCaseE;
  flopenr #(1) SpecialCaseReg(clk, reset, IFDivStartE, SpecialCaseE, SpecialCaseM); // save SpecialCase for checking in fdivsqrtpostproc

  // Reset only when the Execute pipeline register clears (~StallE), so a finished divide held in Execute by
  // StallM keeps its result even if mispredicted (BPWrongE).  StallE = StallM whenever FlushE is asserted
  // (FlushECause masks the divider's own StallECause, and LatestUnstalledE implies ~StallE), so StallM is used.
  always_ff @(posedge clk) begin
    if (reset | FlushE & ~StallM) begin
      state <= IDLE;
    end else if (IFDivStartE) begin // IFDivStartE implies state is IDLE
      step <= CyclesE;
      if (SpecialCaseE) state <= DONE;
      else              state <= BUSY;
    end else if (state == BUSY) begin
      if (step == 1 | WZeroE) state <= DONE; // finished steps or terminate early on zero residual
      step <= step - 1;
    end else if (state == DONE) begin
      if (StallM) state <= DONE;
      else        state <= IDLE;
    end
  end

endmodule
