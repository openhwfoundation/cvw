///////////////////////////////////////////
// regchangedetect.sv
//
// Written:  Rose Thompson rose@rosethompson.net 24 January 2024
// Modified:
//
// Purpose: Register change detector.
//
// Documentation:
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module regchangedetect #(parameter XLEN = 64) (
  input  logic            clk, reset,
  input  logic [XLEN-1:0] Value,      // Value to monitor
  output logic            Change);    // Value changed

  logic [XLEN-1:0] ValueD;

  flopr #(XLEN) register(clk, reset, Value, ValueD);
  assign Change = |(Value ^ ValueD);

endmodule
