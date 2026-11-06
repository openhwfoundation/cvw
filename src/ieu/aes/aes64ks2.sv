///////////////////////////////////////////
// aes64ks2.sv
//
// Written:  Ryan Swann ryan.swann@okstate.edu, James Stine james.stine@okstate.edu 20 February 2024
// Modified: David Harris
//
// Purpose: AES key schedule step aes64ks2.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module aes64ks2(
  input  logic [63:0]  rs2,
  input  logic [63:32] rs1,
  output logic [63:0]  result
);

  logic [31:0]         w0, w1;

  assign w0 = rs1[63:32] ^ rs2[31:0];
  assign w1 = w0 ^ rs2[63:32];
  assign result = {w1, w0};
endmodule
