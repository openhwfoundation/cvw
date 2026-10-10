///////////////////////////////////////////
// fmasign.sv
//
// Written:  Katherine Parry me@KatherineParry.com, David Harris David_Harris@hmc.edu 23 June 2021
// Modified:
//
// Purpose: Compute the FMA product and addend signs and detect effective subtraction.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module fmasign(
  input  logic [2:0]  OpCtrl,     // operation control
  input  logic        Xs, Ys, Zs, // sign of the inputs
  output logic        Ps,         // the product's sign - takes operation into account
  output logic        As,         // aligned addend sign used in fma - takes operation into account
  output logic        InvA        // Effective subtraction: invert addend
);

  assign Ps   = Xs ^ Ys ^ (OpCtrl[1]&~OpCtrl[2]); // product sign.  Negate for FMNADD or FNMSUB
  assign As   = Zs^OpCtrl[0];                     // flip addend sign for subtraction
  assign InvA = As ^ Ps;                          // Effective subtraction when product and addend have opposite signs
endmodule
