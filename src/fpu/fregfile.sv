///////////////////////////////////////////
// fregfile.sv
//
// Written: David_Harris@hmc.edu 9 January 2021
// Modified: James Stine
//
// Purpose: 3R1W 4-port register file for FPU
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

module fregfile #(parameter FLEN) (
  input logic              clk, reset,
  input logic              we4,             // write enable
  input logic [4:0]        a1, a2, a3, a4,  // addresses
  input logic [FLEN-1:0]   wd4,             // write data
  output logic [FLEN-1:0]  rd1, rd2, rd3    // read data
);

   logic [FLEN-1:0] rf[31:0];
   integer i;

   // three ported register file
   // read three ports combinationally (A1/RD1, A2/RD2, A3/RD3)
   // write fourth port on rising edge of clock (A4/WD4/WE4)
   // write occurs on falling edge of clock

   always_ff @(negedge clk) // or posedge reset)
     if (reset) for(i=0; i<32; i++) rf[i] <= '0;
     else if (we4) rf[a4] <= wd4;

   assign rd1 = rf[a1];
   assign rd2 = rf[a2];
   assign rd3 = rf[a3];

endmodule // regfile
