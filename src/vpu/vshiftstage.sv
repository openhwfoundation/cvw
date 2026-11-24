///////////////////////////////////////////
// vshiftstage.sv
//
// Written: David Harris David_Harris@hmc.edu 24 November 2026
// Modified:
//
// Purpose: One stage of the vector shifter: shift each element right by K or pass it through
//
// Documentation: RISC-V System on Chip Design Volume 2
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
////////////////////////////////////////////////////////////////////////////////////////////////

module vshiftstage import cvw::*; #(parameter cvw_t P, parameter K) (
  input  logic [P.ELEN-1:0] Sin,                  // elements entering the stage
  input  logic [P.ELEN-1:0] C,                    // bit K of each element's shift amount, in every bit of the element
  input  logic [P.ELEN-1:0] M,                    // 1 where the bit K above is in the same element
  input  logic [P.ELEN-1:0] F,                    // bits that enter the top of each element: fill or rotated bits
  input  logic [P.ELEN-1:0] GVin, TVin,           // guard and sticky candidates from earlier stages
  output logic [P.ELEN-1:0] Sout,
  output logic [P.ELEN-1:0] GVout, TVout
);
  logic [P.ELEN-1:0] Lo, G;

  // The low K bits of each element shift out; the highest of them is the guard bit if no later stage shifts
  assign Lo = ~(M << K);
  assign G  = Lo & ~(Lo >> 1);

  assign Sout  = (C & ((M & (Sin >> K)) | (~M & F))) | (~C & Sin);
  assign GVout = (C & Sin & G) | (~C & GVin);
  assign TVout = TVin | (C & (GVin | (Sin & Lo & ~G)));
endmodule
