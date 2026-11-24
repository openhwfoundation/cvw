///////////////////////////////////////////
// fdivsqrtfgen4.sv
//
// Written:  David Harris David_Harris@hmc.edu, Katherine Parry me@KatherineParry.com, Cedar Turek cturek@hmc.edu 20 September 2022
// Modified:
//
// Purpose: Radix-4 square root addend generation.
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

module fdivsqrtfgen4 import cvw::*; #(parameter cvw_t P) (
  input  logic [P.DIVb+3:0] C, U, UM,         // Q4.DIVb (extended from shorter forms)
  output logic [P.DIVb+3:0] F2, F1, FN1, FN2  // Q4.DIVb F for digits 2, 1, -1, -2 (F is 0 for digit 0)
);

  // Generate for both positive and negative digits
  assign F2  = (~U << 2) & (C << 2);
  assign F1  = ~(U << 1) & C;
  assign FN1 = (UM << 1) | (C & ~(C << 3));
  assign FN2 = (UM << 2) | ((C << 2) & ~(C << 4));

endmodule
