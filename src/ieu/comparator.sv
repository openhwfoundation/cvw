///////////////////////////////////////////
// comparator.sv
//
// Written: David_Harris@hmc.edu, Sarah.Harris@unlv.edu
// Created: 8 December 2021
// Modified:
//
// Purpose: Branch comparison
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

// This comparator is best
module comparator #(parameter WIDTH=64) (
  input  logic [WIDTH-1:0] a, b,    // Operands
  input  logic             sgnd,    // Signed operands
  output logic [1:0]       flags);  // Output flags: {eq, lt}

  logic             eq, lt;         // Flags: equal (eq), less than (lt)
  logic [WIDTH-1:0] af, bf;         // Operands with msb flipped (inverted) when signed

  // For signed numbers, flip most significant bit
  assign af = {a[WIDTH-1] ^ sgnd, a[WIDTH-2:0]};
  assign bf = {b[WIDTH-1] ^ sgnd, b[WIDTH-2:0]};

  // Behavioral description gives best results
  assign eq = (a == b);            // eq = 1 when operands are equal, 0 otherwise
  assign lt = (af < bf);           // lt = 1 when a less than b (taking signed operands into account)
  assign flags = {eq, lt};
endmodule
