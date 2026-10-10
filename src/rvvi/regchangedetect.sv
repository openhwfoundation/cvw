///////////////////////////////////////////
// regchangedetect.sv
//
// Written: Rose Thompson rose@rosethompson.net
// Created: 24 January 2024
// Modified: 24 January 2024
//
// Purpose:
//
// Documentation:
//
// A component of the CORE-V-WALLY configurable RISC-V project.
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module regchangedetect #(parameter XLEN = 64) (
  input clk, reset,
  input logic [XLEN-1:0] Value,
  output logic           Change);

  logic [XLEN-1:0]           ValueD;

  flopr #(XLEN) register(clk, reset, Value, ValueD);
  assign Change = |(Value ^ ValueD);

endmodule
