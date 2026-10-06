///////////////////////////////////////////
// regfile.sv
//
// Written: David_Harris@hmc.edu, Sarah.Harris@unlv.edu
// Created: 9 January 2021
// Modified:
//
// Purpose: 3-port register file
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

module regfile #(parameter XLEN, E_SUPPORTED) (
  input  logic             clk, reset,
  input  logic             we3,                 // Write enable
  input  logic [4:0]       a1, a2, a3,          // Source registers to read (a1, a2), destination register to write (a3)
  input  logic [XLEN-1:0]  wd3,                 // Write data for port 3
  output logic [XLEN-1:0]  rd1, rd2);           // Read data for ports 1, 2

  localparam NUMREGS = E_SUPPORTED ? 16 : 32;   // only 16 registers in E mode

  logic [XLEN-1:0] rf[NUMREGS-1:1];
  integer i;

  // Three ported register file
  // Read two ports combinationally (a1/rd1, a2/rd2)
  // Write third port on rising edge of clock (a3/wd3/we3)
  // Write occurs on falling edge of clock
  // Register 0 hardwired to 0

  // reset is intended for simulation only, not synthesis
  // can logic be adjusted to not need resettable registers?

  always_ff @(negedge clk)
    if (reset) for(i=1; i<NUMREGS; i++) rf[i] <= '0;
    else       if (we3)                 rf[a3] <= wd3;

  assign rd1 = (a1 != 0) ? rf[a1] : 0;
  assign rd2 = (a2 != 0) ? rf[a2] : 0;
endmodule
