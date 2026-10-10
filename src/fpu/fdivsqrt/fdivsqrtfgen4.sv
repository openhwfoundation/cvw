///////////////////////////////////////////
// fdivsqrtfgen4.sv
//
// Written:  David Harris David_Harris@hmc.edu, Katherine Parry me@KatherineParry.com, Cedar Turek cturek@hmc.edu 20 September 2022
// Modified:
//
// Purpose: Generate the radix-4 square root addend F from the selected digit and the partial root.
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

module fdivsqrtfgen4 import cvw::*;  #(parameter cvw_t P) (
  input  logic [3:0]        udigit,           // {2, 1, -1, -2}; all cold for zero
  input  logic [P.DIVb+3:0] C, U, UM,         // Q4.DIVb (extended from shorter forms)
  output logic [P.DIVb+3:0] F                 // Q4.DIVb
);
  logic [P.DIVb+3:0]        F2, F1, F0, FN1, FN2; // Q4.DIVb

  // Generate for both positive and negative digits
  assign F2  = (~U << 2) & (C << 2);              //
  assign F1  = ~(U << 1) & C;
  assign F0  = '0;
  assign FN1 = (UM << 1) | (C & ~(C << 3));
  assign FN2 = (UM << 2) | ((C << 2) & ~(C << 4));

  // Choose which adder input will be used
  always_comb
    if (udigit[3])       F = F2;
    else if (udigit[2])  F = F1;
    else if (udigit[1])  F = FN1;
    else if (udigit[0])  F = FN2;
    else                 F = F0;
endmodule
