///////////////////////////////////////////
// ram2p1r1wbe_128x64.sv
//
// Written:  James Stine james.stine@okstate.edu 28 January 2023
// Modified: Rose Thompson
//
// Purpose: 128x64 two-port SRAM macro wrapper.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2023-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module ram2p1r1wbe_128x64(
  input  logic          CLKA,  // SRAM port A clock
  input  logic          CLKB,  // SRAM port B clock
  input  logic          CEBA,  // SRAM port A chip enable (active low)
  input  logic          CEBB,  // SRAM port B chip enable (active low)
  input  logic          WEBA,  // SRAM port A write enable (active low)
  input  logic          WEBB,  // SRAM port B write enable (active low)
  input  logic [6:0]    AA,    // SRAM port A address
  input  logic [6:0]    AB,    // SRAM port B address
  input  logic [63:0]   DA,    // SRAM port A write data
  input  logic [63:0]   DB,    // SRAM port B write data
  input  logic [63:0]   BWEBA, // SRAM port A bit write enables (active low)
  input  logic [63:0]   BWEBB, // SRAM port B bit write enables (active low)
  output logic [63:0]   QA,    // SRAM port A read data
  output logic [63:0]   QB     // SRAM port B read data
);

   // replace "generic128x64RAM" with "TSDN..128X64.." module from your memory vendor
  TSDN28HPCPA128X64M4FW sramIP (.CLKA, .CLKB, .CEBA, .CEBB, .WEBA, .WEBB,
    .AA, .AB, .DA, .DB, .BWEBA, .BWEBB, .QA, .QB);
  // generic128x64RAM sramIP (.CLKA, .CLKB, .CEBA, .CEBB, .WEBA, .WEBB,
//         .AA, .AB, .DA, .DB, .BWEBA, .BWEBB, .QA, .QB);

endmodule
