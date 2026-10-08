///////////////////////////////////////////
// ram2p1rwbe_64x32.sv
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
