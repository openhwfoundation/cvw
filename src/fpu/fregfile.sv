///////////////////////////////////////////
// fregfile.sv
//
// Written:  David Harris David_Harris@hmc.edu 9 January 2021
// Modified: Katherine Parry, James Stine
//
// Purpose: Floating-point register file.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module fregfile #(parameter FLEN, SUPERSCALAR = 1) (
  input  logic            clk, reset,
  input  logic            we4,            // write enable
  input  logic [4:0]      a1, a2, a3, a4, // addresses
  input  logic [4:0]      a5, a6, a7,     // read addresses for slot 1 (superscalar)
  input  logic [FLEN-1:0] wd4,            // write data
  output logic [FLEN-1:0] rd1, rd2, rd3,  // read data
  output logic [FLEN-1:0] rd5, rd6, rd7   // read data for slot 1
);

  logic [FLEN-1:0] rf[31:0];
  integer i;

  // four-ported register file
  // read three ports combinationally (A1/RD1, A2/RD2, A3/RD3)
  // write fourth port on falling edge of clock (A4/WD4/WE4)

  always_ff @(negedge clk)
    if (reset) for (i = 0; i < 32; i++) rf[i] <= '0;
    else if (we4) rf[a4] <= wd4;

  assign rd1 = rf[a1];
  assign rd2 = rf[a2];
  assign rd3 = rf[a3];

  // Slot 1 read ports, built only for a superscalar core
  if (SUPERSCALAR) begin : slot1ports
    assign rd5 = rf[a5];
    assign rd6 = rf[a6];
    assign rd7 = rf[a7];
  end else begin : noslot1ports
    assign rd5 = '0;
    assign rd6 = '0;
    assign rd7 = '0;
  end

endmodule // fregfile
