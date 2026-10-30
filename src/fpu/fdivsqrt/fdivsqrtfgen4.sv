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
  input  logic [3:0]        udigit,           // Radix-4 result digit, one-hot {2, 1, -1, -2}; 0 if none hot
  input  logic [P.DIVb+3:0] C, U, UM,         // Digit position marker, partial result, partial result minus 1 ulp (Q4.DIVb, extended)
  output logic [P.DIVb+3:0] F                 // Square root residual adjustment term (Q4.DIVb)
);
  logic [P.DIVb+3:0]        F2, F1, F0, FN1, FN2; // Q4.DIVb

  // Generate for both positive and negative digits
  assign F2  = (~U << 2) & (C << 2);
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
