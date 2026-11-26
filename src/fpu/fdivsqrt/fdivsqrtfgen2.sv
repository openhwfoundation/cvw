///////////////////////////////////////////
// fdivsqrtfgen2.sv
//
// Written:  David Harris David_Harris@hmc.edu, Katherine Parry me@KatherineParry.com, Cedar Turek cturek@hmc.edu 20 September 2022
// Modified:
//
// Purpose: Radix-2 square root addend generation.
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

module fdivsqrtfgen2 import cvw::*; #(parameter cvw_t P) (
  input  logic [P.DIVb+3:0] C, U, UM,   // Q4.DIVb (extended from shorter forms)
  output logic [P.DIVb+3:0] FP, FN      // Q4.DIVb F for digits +1 and -1 (F is 0 for digit 0)
);

  // Generate for both positive and negative quotient digits
  assign FP = ~(U << 1) & C;
  assign FN = (UM << 1) | (C & ~(C << 2));

endmodule
