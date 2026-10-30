///////////////////////////////////////////
// fmasign.sv
//
// Written:  Katherine Parry me@KatherineParry.com, David Harris David_Harris@hmc.edu 23 June 2021
// Modified:
//
// Purpose: FMA signs and effective subtraction.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module fmasign(
  input  logic [2:0]  OpCtrl,     // FPU operation control
  input  logic        Xs, Ys, Zs, // X, Y, Z signs
  output logic        Ps,         // Product sign
  output logic        As,         // Aligned addend sign (Z sign adjusted for the operation)
  output logic        InvA        // Invert addend for effective subtraction
);

  assign Ps   = Xs ^ Ys ^ (OpCtrl[1] & ~OpCtrl[2]); // product sign.  Negate for fnmsub (010) or fnmadd (011)
  assign As   = Zs ^ OpCtrl[0];                     // flip addend sign for subtraction
  assign InvA = As ^ Ps;                            // Effective subtraction when product and addend have opposite signs
endmodule
