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
  input  logic              up, uz,     // Result digit is +1 or 0
  input  logic [P.DIVb+3:0] C, U, UM,   // Digit position marker, partial result, partial result minus 1 ulp (Q4.DIVb, extended)
  output logic [P.DIVb+3:0] F           // Square root residual adjustment term (Q4.DIVb)
);
  logic [P.DIVb+3:0]        FP, FN, FZ;  // Q4.DIVb

  // Generate for both positive and negative quotient digits
  assign FP = ~(U << 1) & C;
  assign FN = (UM << 1) | (C & ~(C << 2));
  assign FZ = '0;

  always_comb     // Choose which adder input will be used
    if (up)       F = FP;
    else if (uz)  F = FZ;
    else          F = FN;
endmodule
