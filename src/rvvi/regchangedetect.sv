///////////////////////////////////////////
// regchangedetect.sv
//
// Written:  Rose Thompson rose@rosethompson.net 24 January 2024
// Modified:
//
// Purpose: Detects when a register value differs from its value in the previous cycle.
//
// Documentation:
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-27 Harvey Mudd College & Oklahoma State University
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
