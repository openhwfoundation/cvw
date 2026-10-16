///////////////////////////////////////////
// rom_ahb.sv
//
// Written: David_Harris@hmc.edu 9 January 2021
// Modified:
//
// Purpose: On-chip ROM, external to core
//
// Documentation: RISC-V System on Chip Design
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

  localparam ADDR_WIDTH = $clog2(RANGE/8);
  localparam OFFSET     = $clog2(P.XLEN/8);

  // Never stalls
  assign HREADYRom = 1'b1;
  assign HRESPRom  = 1'b0; // OK

  // single-ported ROM
  rom1p1r #(ADDR_WIDTH, P.XLEN, PRELOAD)
    memory(.clk(HCLK), .ce(1'b1), .addr(HADDR[ADDR_WIDTH+OFFSET-1:OFFSET]), .dout(HREADRom));
endmodule
