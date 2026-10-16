///////////////////////////////////////////
// ram2p1rwbe_1024x68.sv
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
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

module ram2p1r1wbe_1024x68(
  input  logic          CLKA,  // SRAM port A clock
  input  logic          CLKB,  // SRAM port B clock
  input  logic          CEBA,  // SRAM port A chip enable (active low)
  input  logic          CEBB,  // SRAM port B chip enable (active low)
  input  logic          WEBA,  // SRAM port A write enable (active low)
  input  logic          WEBB,  // SRAM port B write enable (active low)
  input  logic [9:0]    AA,    // SRAM port A address
  input  logic [9:0]    AB,    // SRAM port B address
  input  logic [67:0]   DA,    // SRAM port A write data
  input  logic [67:0]   DB,    // SRAM port B write data
  input  logic [67:0]   BWEBA, // SRAM port A bit write enables (active low)
  input  logic [67:0]   BWEBB, // SRAM port B bit write enables (active low)
  output logic [67:0]   QA,    // SRAM port A read data
  output logic [67:0]   QB     // SRAM port B read data
);

  // replace "generic1024x68RAM" with "TSDN..1024X68.." module from your memory vendor
  // generic1024x68RAM sramIP (.CLKA, .CLKB, .CEBA, .CEBB, .WEBA, .WEBB,
  //          .AA, .AB, .DA, .DB, .BWEBA, .BWEBB, .QA, .QB);
  TSDN28HPCPA1024X68M4MW sramIP(.CLKA, .CLKB, .CEBA, .CEBB, .WEBA, .WEBB,
    .AA, .AB, .DA, .DB, .BWEBA, .BWEBB, .QA, .QB);

endmodule
