///////////////////////////////////////////
// clockgate.sv
//
// Written:  David Harris David_Harris@hmc.edu 1 November 2026
// Modified:
//
// Purpose: Integrated clock gate.  gclk follows clk while en is asserted.  en is captured by a latch
//          that is transparent while clk is low, so gclk cannot glitch while clk is high.
//          A technology library's clock-gating cell can replace this module in synthesis.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module clockgate (
  input  logic clk, en,
  output logic gclk
);

  logic EnLatched;

  always_latch
    if (~clk) EnLatched = en;

  assign gclk = clk & EnLatched;
endmodule
