///////////////////////////////////////////
// roundsign.sv
//
// Written:  Katherine Parry me@KatherineParry.com 3 July 2022
// Modified:
//
// Purpose: Sign of the normalized result.
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

module roundsign(
  input  logic        Xs,     // X sign
  input  logic        Ys,     // Y sign
  input  logic        CvtCs,  // Conversion result sign
  input  logic        FmaSs,  // FMA sum sign
  input  logic        Sqrt,   // Square root operation
  input  logic        FmaOp,  // FMA operation
  input  logic        DivOp,  // Divide or square root operation
  input  logic        CvtOp,  // Conversion operation
  output logic        Ms      // Normalized result sign
);

  logic               Qs;     // divsqrt result sign

  // calculate divsqrt sign
  assign Qs = Xs ^ (Ys & ~Sqrt);

  // Select sign for rounding calculation
  assign Ms = (FmaSs & FmaOp) | (CvtCs & CvtOp) | (Qs & DivOp);

endmodule
