///////////////////////////////////////////
// fdivsqrtstage2.sv
//
// Written:  David Harris David_Harris@hmc.edu, Katherine Parry me@KatherineParry.com, Cedar Turek cturek@hmc.edu 29 August 2022
// Modified: Alessandro Maiuolo
//
// Purpose: One radix-2 divide/square root step.
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

module fdivsqrtstage2 import cvw::*; #(parameter cvw_t P) (
  input  logic [P.DIVb+3:0] D, DBar,        // Q4.DIVb
  input  logic [P.DIVb:0]   U, UM,          // U1.DIVb
  input  logic [P.DIVb+3:0] WS, WC,         // Q4.DIVb
  input  logic [P.DIVb+1:0] C,              // Q2.DIVb
  input  logic              SqrtE,
  output logic [P.DIVb+1:0] CNext,          // Q2.DIVb
  output logic [P.DIVb:0]   UNext, UMNext,  // U1.DIVb
  output logic [P.DIVb+3:0] WSNext, WCNext  // Q4.DIVb
);

  logic                     up, un;   // Result digit is +1 or -1 (0 if neither)
  logic [P.DIVb+3:0]        FP, FN;   // Q4.DIVb square root addends for digits +1 and -1
  logic [P.DIVb+3:0]        AP, AN;   // Q4.DIVb addends for digits +1 and -1 in the current mode
  logic [P.DIVb+3:0]        AddIn;    // Q4.DIVb
  logic [P.DIVb+3:0]        WSA, WCA; // Q4.DIVb

  // Quotient Selection logic
  // Given partial remainder, select digit of +1, 0, or -1 (up, uz, un)
  fdivsqrtuslc2 uslc2(.WS(WS[P.DIVb+3:P.DIVb]), .WC(WC[P.DIVb+3:P.DIVb]), .up, .uz(), .un);

  // Sqrt F generation.  Extend C, U, UM to Q4.DIVb
  fdivsqrtfgen2 #(P) fgen2(.C({2'b11, CNext}), .U({3'b000, U}), .UM({3'b000, UM}), .FP, .FN);

  // Choose the addend for each nonzero digit before the digit is known (SqrtE is constant during an operation),
  // so the late digit drives a single AND-OR: -D or D for division, F for square root
  assign AP = SqrtE ? FP : DBar;
  assign AN = SqrtE ? FN : D;
  assign AddIn = ({(P.DIVb+4){up}} & AP) | ({(P.DIVb+4){un}} & AN);

  // Residual Update
  //  WSA, WCA = WS + WC - qD
  csa #(P.DIVb+4) csa(WS, WC, AddIn, up & ~SqrtE, WSA, WCA); // carry in completes the 2's complement of -D for division digit +1
  assign WSNext = WSA << 1;
  assign WCNext = WCA << 1;

  // Shift thermometer code C
  assign CNext = {1'b1, C[P.DIVb+1:1]};

  // Unified On-The-Fly Converter to accumulate result
  fdivsqrtuotfc2 #(P) uotfc2(.up, .un, .C(CNext), .U, .UM, .UNext, .UMNext);
endmodule
