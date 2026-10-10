///////////////////////////////////////////
// ram2p1r1wbe_2048x64.sv
//
// Written:  James Stine james.stine@okstate.edu 28 January 2023
// Modified: Rose Thompson rose@rosethompson.net
//
// Purpose: Wrapper that instantiates a 2048x64 two-port SRAM macro.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2023-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module ram2p1r1wbe_2048x64(
  input  logic          CLKA,
  input  logic          CLKB,
  input  logic          CEBA,
  input  logic          CEBB,
  input  logic          WEBA,
  input  logic          WEBB,
  input  logic [8:0]    AA,
  input  logic [8:0]    AB,
  input  logic [63:0]   DA,
  input  logic [63:0]   DB,
  input  logic [63:0]   BWEBA,
  input  logic [63:0]   BWEBB,
  output logic [63:0]   QA,
  output logic [63:0]   QB
);

   // replace "generic2048x64RAM" with "TSDN..2048X64.." module from your memory vendor
  TSDN28HPCPA2048X64MMFW sramIP (.CLKA, .CLKB, .CEBA, .CEBB, .WEBA, .WEBB,
    .AA, .AB, .DA, .DB, .BWEBA, .BWEBB, .QA, .QB);
  // generic2048x64RAM sramIP (.CLKA, .CLKB, .CEBA, .CEBB, .WEBA, .WEBB,
//         .AA, .AB, .DA, .DB, .BWEBA, .BWEBB, .QA, .QB);

endmodule
