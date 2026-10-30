///////////////////////////////////////////
// aesinvsbox64.sv
//
// Written:  Ryan Swann ryan.swann@okstate.edu, James Stine james.stine@okstate.edu 20 February 2024
// Modified: David Harris
//
// Purpose: AES inverse S-boxes for a 64-bit word.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module aesinvsbox64(
  input  logic [63:0] a, // Input
  output logic [63:0] y  // Output
);

  // inverse substitution boxes for each byte of the 64-bit doubleword
  aesinvsbox8 sbox0(a[7:0],   y[7:0]);
  aesinvsbox8 sbox1(a[15:8],  y[15:8]);
  aesinvsbox8 sbox2(a[23:16], y[23:16]);
  aesinvsbox8 sbox3(a[31:24], y[31:24]);
  aesinvsbox8 sbox4(a[39:32], y[39:32]);
  aesinvsbox8 sbox5(a[47:40], y[47:40]);
  aesinvsbox8 sbox6(a[55:48], y[55:48]);
  aesinvsbox8 sbox7(a[63:56], y[63:56]);
endmodule
