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

module regfile #(parameter XLEN, E_SUPPORTED, ZACAS_SUPPORTED) (
  input  logic             clk, reset,
  input  logic             we3, we3p,           // Write enable for normal and pair
  input  logic [4:0]       a1, a2, a3,          // Read a1 and a2 (amocas borrows a2 for its compare operand); write a3
  input  logic [XLEN-1:0]  wd3,                 // Write data for port 3
  input  logic [XLEN-1:0]  wd3h,                // Upper half write data for port 3 pair
  output logic [XLEN-1:0]  rd1, rd2,            // Read data for ports 1, 2
  output logic [XLEN*2-1:0] rd2p                // Pair read through the a2 port, for Zacas pair operands
);
  localparam NUMREGS = E_SUPPORTED ? 16 : 32;   // only 16 registers in E mode

  if (ZACAS_SUPPORTED) begin : pairedrf
    // Zacas needs register pairs, so hold the registers as pairs.  It also needs a third operand
    // (rd, the compare value), which the controller obtains by stalling a cycle and reusing a2.
    logic [XLEN*2-1:0] rf[NUMREGS/2-1:0]; // organize as pairs, with half as many entries
    logic [XLEN*2-1:0] rd1p, rd2p_raw;    // the two pairs read, before x0 masking and half selection
    logic [3:0]        a1p, a2p, a3p; // pair addresses
    integer i;

    // Read two ports combinationally (a1/rd1, a2/rd2 with its pair), write one port (a3) on the
    // falling edge of the clock.  Register 0 is hardwired to 0.
    // reset is intended for simulation only, not synthesis

    // A pair address drops the low bit of the register number; the low bit picks the half
    assign a1p = a1[4:1];
    assign a2p = a2[4:1];
    assign a3p = a3[4:1];

    // Two read ports: one pair is read for a1 and one for a2, and everything else is selection.
    // The pair forms require an even register, so dropping a2's low bit names the intended pair.
    assign rd1p = rf[a1p];
    assign rd2p_raw = rf[a2p];
    assign rd2p = (a2 == 0) ? '0 : rd2p_raw; // a source pair starting at x0 reads as all zeros

    // Write the whole pair for a pair write, otherwise only the addressed half
    always_ff @(negedge clk)
      if (reset)                   for (i=0; i<NUMREGS/2; i++) rf[i] <= '0;
      else if (we3p & (a3 != 0))   rf[a3p] <= {wd3h, wd3};
      else if (we3  & (a3 != 0))
        if (a3[0])                 rf[a3p][XLEN*2-1:XLEN] <= wd3;
        else                       rf[a3p][XLEN-1:0]      <= wd3;

    // Select the half the register number names, forcing x0 to read as zero
    assign rd1 = (a1 == 0) ? '0 : (a1[0] ? rd1p[XLEN*2-1:XLEN] : rd1p[XLEN-1:0]);
    assign rd2 = (a2 == 0) ? '0 : (a2[0] ? rd2p_raw[XLEN*2-1:XLEN] : rd2p_raw[XLEN-1:0]);
  end else begin : simplerf
    logic [XLEN-1:0] rf[NUMREGS-1:1];
    integer i;

    // Three ported register file
    // Read two ports combinationally (a1/rd1, a2/rd2)
    // Write third port on falling edge of clock (a3/wd3/we3)
    // Register 0 hardwired to 0

    // reset is intended for simulation only, not synthesis
    // can logic be adjusted to not need resettable registers?

    always_ff @(negedge clk)
      if (reset) for (i=1; i<NUMREGS; i++) rf[i] <= '0;
      else       if (we3)                  rf[a3] <= wd3;

    assign rd1 = (a1 != 0) ? rf[a1] : 0;
    assign rd2 = (a2 != 0) ? rf[a2] : 0;
    assign rd2p = '0; // not used without Zacas
  end
endmodule
