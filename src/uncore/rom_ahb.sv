///////////////////////////////////////////
// rom_ahb.sv
//
// Written:  David Harris David_Harris@hmc.edu 9 January 2021
// Modified: Rose Thompson
//
// Purpose: On-chip ROM on AHB.
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

module rom_ahb import cvw::*; #(parameter cvw_t P,
                                parameter RANGE = 65535, PRELOAD = 0) (
  input  logic                 HCLK, HRESETn,      // AHB clock and reset (active low)
  input  logic                 HSELRom,            // AHB select for ROM
  input  logic [P.PA_BITS-1:0] HADDR,              // AHB address
  input  logic                 HREADY,             // AHB ready
  input  logic [1:0]           HTRANS,             // AHB transfer type: 00 IDLE, 10 NONSEQ, 11 SEQ
  output logic [P.XLEN-1:0]    HREADRom,           // AHB read data from ROM
  output logic                 HRESPRom, HREADYRom // AHB response and ready from ROM
);

  localparam ADDR_WIDTH = $clog2((RANGE+1)/64'(P.XLEN/8)); // RANGE is a mask (size-1); depth is in XLEN-bit words
  localparam OFFSET     = $clog2(P.XLEN/8);

  // Never stalls
  assign HREADYRom = 1'b1;
  assign HRESPRom  = 1'b0; // OK

  // single-ported ROM
  rom1p1r #(ADDR_WIDTH, P.XLEN, PRELOAD)
    memory(.clk(HCLK), .ce(1'b1), .addr(HADDR[ADDR_WIDTH+OFFSET-1:OFFSET]), .dout(HREADRom));
endmodule
