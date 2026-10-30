///////////////////////////////////////////
// ram2p1rwbe_128x64.sv
//
// Written: james.stine@okstate.edu 28 January 2023
// Modified:
//
// Purpose: RAM wrapper for instantiating RAM IP
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module ram2p1r1wbe_128x64(
  input  logic          CLKA,
  input  logic          CLKB,
  input  logic          CEBA,
  input  logic          CEBB,
  input  logic          WEBA,
  input  logic          WEBB,
  input  logic [6:0]    AA,
  input  logic [6:0]    AB,
  input  logic [63:0]   DA,
  input  logic [63:0]   DB,
  input  logic [63:0]   BWEBA,
  input  logic [63:0]   BWEBB,
  output logic [63:0]   QA,
  output logic [63:0]   QB
);

   // replace "generic128x64RAM" with "TSDN..128X64.." module from your memory vendor
  TSDN28HPCPA128X64M4FW sramIP (.CLKA, .CLKB, .CEBA, .CEBB, .WEBA, .WEBB,
    .AA, .AB, .DA, .DB, .BWEBA, .BWEBB, .QA, .QB);
  // generic128x64RAM sramIP (.CLKA, .CLKB, .CEBA, .CEBB, .WEBA, .WEBB,
//         .AA, .AB, .DA, .DB, .BWEBA, .BWEBB, .QA, .QB);

endmodule
