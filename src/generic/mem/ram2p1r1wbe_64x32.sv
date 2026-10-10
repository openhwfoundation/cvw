///////////////////////////////////////////
// ram2p1r1wbe_64x32.sv
//
// Written:  James Stine james.stine@okstate.edu 28 January 2023
// Modified: David Harris David_Harris@hmc.edu
//
// Purpose: Wrapper that instantiates a 64x32 two-port SRAM macro with bit write enables.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2023-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module ram2p1r1wbe_64x32(
  input  logic          CLKA,
  input  logic          CLKB,
  input  logic          CEBA,
  input  logic          CEBB,
  input  logic          WEBA,
  input  logic          WEBB,
  input  logic [5:0]    AA,
  input  logic [5:0]    AB,
  input  logic [31:0]   DA,
  input  logic [31:0]   DB,
  input  logic [31:0]   BWEBA,
  input  logic [31:0]   BWEBB,
  output logic [31:0]   QA,
  output logic [31:0]   QB
);

   // replace "generic64x32RAM" with "TSDN..64X32.." module from your memory vendor
   //generic64x32RAM sramIP (.CLKA, .CLKB, .CEBA, .CEBB, .WEBA, .WEBB,
   //       .AA, .AB, .DA, .DB, .BWEBA, .BWEBB, .QA, .QB);
  TSDN28HPCPA64X32M4MW sramIP(.CLKA, .CLKB, .CEBA, .CEBB, .WEBA, .WEBB,
    .AA, .AB, .DA, .DB, .BWEBA, .BWEBB, .QA, .QB);
endmodule
