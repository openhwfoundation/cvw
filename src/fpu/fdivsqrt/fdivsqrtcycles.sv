///////////////////////////////////////////
// fdivsqrtcycles.sv
//
// Written:  David Harris David_Harris@hmc.edu, Katherine Parry me@KatherineParry.com, Cedar Turek cturek@hmc.edu, Alessandro Maiuolo amaiuolo@hmc.edu 18 April 2023
// Modified: Kevin Kim kekim@hmc.edu
//
// Purpose: Compute the number of cycles needed for a floating-point divide, square root, or integer divide.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2023-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module fdivsqrtcycles import cvw::*;  #(parameter cvw_t P) (
  input  logic [P.LOGFLEN-1:0] Nf,          // Number of fractional bits in selected format
  input  logic                 IntDivE,
  input  logic [P.DIVBLEN-1:0] IntResultBitsE,
  output logic [P.DURLEN-1:0]  CyclesE
);

  logic [P.DIVBLEN-1:0] FPResultBitsE, ResultBitsE; // number of fractional (result) bits

  // Cycle logic
  // P.DIVCOPIES = k. P.LOGR = log(R) = r.  P.RK = rk.
  // Integer division needs p fractional + r integer result bits
  // FP Division needs at least Nf fractional bits + 2 guard/round bits and one integer digit (LOG R integer bits) = Nf + 2 + r bits
  // FP Sqrt needs at least Nf fractional bits and 2 guard/round bits.  The integer bit is always initialized to 1 and does not need a cycle.
  // The datapath produces rk bits per cycle, so Cycles = ceil (ResultBitsE / rk)

  /* verilator lint_off WIDTH */
  always_comb begin
    FPResultBitsE = Nf + 2 + P.LOGR; // Nf + two fractional bits for round/guard; integer bit implicit because starting at n=1

    if (P.IDIV_ON_FPU) ResultBitsE = IntDivE ? IntResultBitsE : FPResultBitsE;
    else               ResultBitsE = FPResultBitsE;

    CyclesE = (ResultBitsE-1)/(P.RK) + 1; // ceil (ResultBitsE/rk)
  end
  /* verilator lint_on WIDTH */

endmodule
