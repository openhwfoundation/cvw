///////////////////////////////////////////
// regfile.sv
//
// Written:  David Harris David_Harris@hmc.edu, Sarah Harris Sarah.Harris@unlv.edu 9 January 2021
// Modified: Noah Boorstin
//
// Purpose: Integer register file.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module regfile #(parameter XLEN, E_SUPPORTED, LATCH_BASED, SUPERSCALAR = 1) (
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

  // Three ported register file, or six ported for dual issue (SUPERSCALAR)
  // Read two ports combinationally (a1/rd1, a2/rd2), plus a4/rd4 and a5/rd5 for slot 1
  // Write a3/wd3/we3 (and a6/wd6/we6 for slot 1) in the second half of the cycle, so a read in the
  // same cycle sees the new value
  // Register 0 hardwired to 0
  // Without SUPERSCALAR the slot 1 ports are not built: this is the original three-ported register file.

  // Slot 1 is the later instruction in program order, so when both ports target the same register,
  // which the issue logic permits, slot 1's value wins.

  // reset is intended for simulation only, not synthesis
  // can logic be adjusted to not need resettable registers?

  if (LATCH_BASED) begin : regs
    // Each register is a row of latches, transparent while clk is low and the register is written.
    // This replaces a flop and a write-enable mux per bit with one latch.  A clock gate per register,
    // clocked by ~clk, opens the latches; wd3 (and wd6) come from Writeback-stage flops, so they are
    // stable while clk is low.
    logic [NUMREGS-1:1] WriteEn, WriteClk, Write1;
    for (genvar r = 1; r < NUMREGS; r++) begin : rows
      assign Write1[r]  = SUPERSCALAR & we6 & (a6 == r);          // slot 1 writes this register
      assign WriteEn[r] = reset | we3 & (a3 == r) | Write1[r];
      clockgate cg(.clk(~clk), .en(WriteEn[r]), .gclk(WriteClk[r]));
    end
    always_latch
      for (i=1; i<NUMREGS; i++) if (WriteClk[i]) rf[i] = reset ? '0 : Write1[i] ? wd6 : wd3;
  end else if (SUPERSCALAR) begin : regs
    always_ff @(negedge clk)
      if (reset) for (i=1; i<NUMREGS; i++) rf[i] <= '0;
      else begin
        if (we3) rf[a3] <= wd3;
        if (we6) rf[a6] <= wd6;                                   // second, so slot 1 wins
      end
  end else begin : regs
    always_ff @(negedge clk)
      if (reset) for (i=1; i<NUMREGS; i++) rf[i] <= '0;
      else       if (we3)                  rf[a3] <= wd3;
  end

  assign rd1 = (a1 != 0) ? rf[a1] : 0;
  assign rd2 = (a2 != 0) ? rf[a2] : 0;
  if (SUPERSCALAR) begin : slot1read
    assign rd4 = (a4 != 0) ? rf[a4] : 0;
    assign rd5 = (a5 != 0) ? rf[a5] : 0;
  end else begin : noslot1read
    assign rd4 = '0;
    assign rd5 = '0;
  end
endmodule
