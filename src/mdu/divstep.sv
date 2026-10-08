///////////////////////////////////////////
// intdivrestoringstep.sv
//
// Written: David_Harris@hmc.edu 2 October 2021
// Modified:
//
// Purpose: Radix-2 restoring integer division step.  k steps are used in div
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
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
