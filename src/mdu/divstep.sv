///////////////////////////////////////////
// divstep.sv
//
// Written:  David Harris David_Harris@hmc.edu 2 October 2021
// Modified:
//
// Purpose: One radix-2 step of the restoring integer divider.
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

module divstep #(parameter XLEN) (
  input  logic [XLEN-1:0] W,     // Residual in
  input  logic [XLEN-1:0] XQ,    // bits of dividend X and quotient Q in
  input  logic [XLEN-1:0] DAbsB, // complement of absolute value of divisor D (for subtraction)
  output logic [XLEN-1:0] WOut,  // Residual out
  output logic [XLEN-1:0] XQOut  // bits of dividend and quotient out: discard one bit of X, append one bit of Q
);

  logic [XLEN-1:0] WShift;       // Shift W left by one bit, bringing in most significant bit of X
  logic [XLEN-1:0] WPrime;       // WShift - D, for comparison and possible result
  logic qi, qib;                  // Quotient digit and its complement

  assign {WShift, XQOut} = {W[XLEN-2:0], XQ, qi};  // shift W and X/Q left, insert quotient bit at bottom
  adder #(XLEN+1) wdsub({1'b0, WShift}, {1'b1, DAbsB}, {qib, WPrime}); // effective subtractor, carry out determines quotient bit
  assign qi = ~qib;
  mux2 #(XLEN) wrestoremux(WShift, WPrime, qi, WOut); // if quotient is zero, restore W
endmodule
