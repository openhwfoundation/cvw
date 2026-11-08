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

module regfile #(parameter XLEN, E_SUPPORTED, SUPERSCALAR = 1) (
  input  logic             clk, reset,
  input  logic             we3, we6,            // Write enables for slot 0 (port 3) and slot 1 (port 6)
  input  logic [4:0]       a1, a2, a3,          // Source registers to read (a1, a2), destination register to write (a3)
  input  logic [4:0]       a4, a5, a6,          // Slot 1 (superscalar): read a4/a5, write a6
  input  logic [XLEN-1:0]  wd3, wd6,            // Write data for ports 3 and 6
  output logic [XLEN-1:0]  rd1, rd2,            // Read data for ports 1, 2
  output logic [XLEN-1:0]  rd4, rd5);           // Read data for ports 4, 5 (slot 1)

  localparam NUMREGS = E_SUPPORTED ? 16 : 32;   // only 16 registers in E mode

  logic [XLEN-1:0] rf[NUMREGS-1:1];
  integer i;

  // Six ported register file for dual issue
  // Read four ports combinationally: slot 0 (a1/rd1, a2/rd2) and slot 1 (a4/rd4, a5/rd5)
  // Write two ports on falling edge of clock (a3/wd3/we3 for slot 0, a6/wd6/we6 for slot 1)
  // Register 0 hardwired to 0

  // reset is intended for simulation only, not synthesis
  // can logic be adjusted to not need resettable registers?

  // Slot 1 is the later instruction in program order, so it is written second and wins when both
  // ports target the same register, which the issue logic permits.
  // Without SUPERSCALAR the slot 1 ports are not built: this is the original three-ported register file.
  if (SUPERSCALAR) begin : dualport
    always_ff @(negedge clk)
      if (reset) for (i=1; i<NUMREGS; i++) rf[i] <= '0;
      else begin
        if (we3) rf[a3] <= wd3;
        if (we6) rf[a6] <= wd6;
      end
    assign rd4 = (a4 != 0) ? rf[a4] : 0;
    assign rd5 = (a5 != 0) ? rf[a5] : 0;
  end else begin : singleport
    always_ff @(negedge clk)
      if (reset) for (i=1; i<NUMREGS; i++) rf[i] <= '0;
      else if (we3) rf[a3] <= wd3;
    assign rd4 = '0;
    assign rd5 = '0;
  end

  assign rd1 = (a1 != 0) ? rf[a1] : 0;
  assign rd2 = (a2 != 0) ? rf[a2] : 0;
endmodule
