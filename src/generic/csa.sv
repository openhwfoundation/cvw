///////////////////////////////////////////
// csa.sv
//
// Written: Katherine Parry and David_Harris@hmc.edu 21 August 2022
// Modified:
//
// Purpose: 3:2 carry-save adder
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module csa #(parameter N=16) (
  input  logic [N-1:0] x, y, z,
  input  logic         cin,
  output logic [N-1:0] s, c
);

  // This block adds x, y, z, and cin to produce
  // a result s / c in carry-save redundant form.
  // cin is just added to the least significant bit
  // s + c = x + y + z + cin

  assign s = x ^ y ^ z;
  assign c = {x[N-2:0] & (y[N-2:0] | z[N-2:0]) | (y[N-2:0] & z[N-2:0]), cin};
endmodule
