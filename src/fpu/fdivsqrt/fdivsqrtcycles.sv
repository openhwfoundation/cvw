///////////////////////////////////////////
// fdivsqrtcycles.sv
//
// Written: David_Harris@hmc.edu, me@KatherineParry.com, cturek@hmc.edu, amaiuolo@hmc.edu
// Modified: 18 April 2022
//
// Purpose: Determine number of cycles for divsqrt
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
