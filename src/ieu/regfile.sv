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

module regfile #(parameter XLEN, E_SUPPORTED, LATCH_BASED) (
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
  // Write third port in the second half of the cycle (a3/wd3/we3), so a read in the same cycle sees the new value
  // Register 0 hardwired to 0

  // reset is intended for simulation only, not synthesis
  // can logic be adjusted to not need resettable registers?

  if (LATCH_BASED) begin : regs
    // Each register is a row of latches, transparent while clk is low and the register is written.
    // This replaces a flop and a write-enable mux per bit with one latch.  A clock gate per register,
    // clocked by ~clk, opens the latches; wd3 comes from a Writeback-stage flop, so it is stable while clk is low.
    logic [NUMREGS-1:1] WriteEn, WriteClk;
    logic [XLEN-1:0]    WriteData;
    for (genvar r = 1; r < NUMREGS; r++) begin : rows
      assign WriteEn[r] = reset | we3 & (a3 == r);
      clockgate cg(.clk(~clk), .en(WriteEn[r]), .gclk(WriteClk[r]));
    end
    assign WriteData = reset ? '0 : wd3;
    always_latch
      for (i=1; i<NUMREGS; i++) if (WriteClk[i]) rf[i] = WriteData;
  end else begin : regs
    always_ff @(negedge clk)
      if (reset) for (i=1; i<NUMREGS; i++) rf[i] <= '0;
      else       if (we3)                  rf[a3] <= wd3;
  end

  assign rd1 = (a1 != 0) ? rf[a1] : 0;
  assign rd2 = (a2 != 0) ? rf[a2] : 0;
endmodule
