///////////////////////////////////////////
// galoismultinverse8.sv
//
// Written:  Kelvin Tran kelvin.tran@okstate.edu, James Stine james.stine@okstate.edu 20 February 2024
// Modified:
//
// Purpose: GF(2^8) reduction for AES InvMixColumns.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module galoismultinverse8(
  input  logic [10:0] a,
  output logic [7:0]  y
);

  logic [7:0] temp0, temp1;

  // Reduce bits 10:8 of an 11-bit product: x^8, x^9, x^10 mod the AES polynomial are 0x1B, 0x36, 0x6C
  assign temp0 = a[8]  ? (a[7:0] ^ 8'b00011011) : a[7:0];
  assign temp1 = a[9]  ? (temp0  ^ 8'b00110110) : temp0;
  assign y     = a[10] ? (temp1  ^ 8'b01101100) : temp1;
endmodule
