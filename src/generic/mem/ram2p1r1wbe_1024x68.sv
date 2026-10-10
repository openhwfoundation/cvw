///////////////////////////////////////////
// ram2p1r1wbe_1024x68.sv
//
// Written:  James Stine james.stine@okstate.edu 28 January 2023
// Modified: David Harris David_Harris@hmc.edu
//
// Purpose: Wrapper that instantiates a 1024x68 two-port SRAM macro with bit write enables.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2023-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module ram2p1r1wbe_1024x68(
  input  logic          CLKA,
  input  logic          CLKB,
  input  logic          CEBA,
  input  logic          CEBB,
  input  logic          WEBA,
  input  logic          WEBB,
  input  logic [9:0]    AA,
  input  logic [9:0]    AB,
  input  logic [67:0]   DA,
  input  logic [67:0]   DB,
  input  logic [67:0]   BWEBA,
  input  logic [67:0]   BWEBB,
  output logic [67:0]   QA,
  output logic [67:0]   QB
);

   // replace "generic1024x68RAM" with "TSDN..1024X68.." module from your memory vendor
   //generic1024x68RAM sramIP (.CLKA, .CLKB, .CEBA, .CEBB, .WEBA, .WEBB,
   //         .AA, .AB, .DA, .DB, .BWEBA, .BWEBB, .QA, .QB);
  TSDN28HPCPA1024X68M4MW sramIP(.CLKA, .CLKB, .CEBA, .CEBB, .WEBA, .WEBB,
    .AA, .AB, .DA, .DB, .BWEBA, .BWEBB, .QA, .QB);

endmodule
