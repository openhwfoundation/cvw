///////////////////////////////////////////
// roundsign.sv
//
// Written:  Katherine Parry me@KatherineParry.com 3 July 2022
// Modified:
//
// Purpose: Select the sign of the normalized result according to the operation.
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

module roundsign(
  input logic         Xs,     // x sign
  input logic         Ys,     // y sign
  input logic         CvtCs,  // convert result sign
  input logic         FmaSs,  // fma sum sign
  input logic         Sqrt,   // sqrt oppertion? (when using divsqrt unit)
  input logic         FmaOp,  // is fma operation
  input logic         DivOp,  // is divsqrt operation
  input logic         CvtOp,  // is cvt operation
  output logic        Ms      // normalized result sign
);

  logic               Qs;     // divsqrt result sign

  // calculate divsqrt sign
  assign Qs = Xs^(Ys&~Sqrt);

  // Select sign for rounding calculation
  assign Ms = (FmaSs&FmaOp) | (CvtCs&CvtOp) | (Qs&DivOp);

endmodule
