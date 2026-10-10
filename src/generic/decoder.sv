///////////////////////////////////////////
// decoder.sv
//
// Written:  Thomas Fleming tfleming@hmc.edu, Jessica Torrey jtorrey@hmc.edu 7 April 2021
// Modified:
//
// Purpose: Decodes a binary value into a one-hot output.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

module decoder #(parameter BINARY_BITS = 3) (
  input  logic [BINARY_BITS-1:0]      binary,
  output logic [(2**BINARY_BITS)-1:0] onehot
);

  assign onehot = 1 << binary;
endmodule
