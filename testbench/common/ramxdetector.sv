///////////////////////////////////////////
// ramxdetector.sv
//
// Written: David_Harris@hmc.edu
// Modified: 2 July 2023
//
// Purpose: Detects if the processor is attempting to read uninitialized RAM
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module ramxdetector #(parameter XLEN, LLEN) (
  input  logic            clk,
  input  logic            MemReadM,
  input  logic            LSULoadAccessFaultM,
  input  logic [LLEN-1:0] ReadDataM,
  input  logic [XLEN-1:0] PCM,
  input  logic [31:0]     InstrM,
  input  logic [XLEN-1:0] IEUAdrM,
  input  logic            StallW,
  input  string           InstrMName
);

  always_ff @(posedge clk)
    /* verilator lint_off WIDTHXZEXPAND */
    if (MemReadM & ~LSULoadAccessFaultM & ~StallW & (ReadDataM === 'bx)) begin
      /* verilator lint_on WIDTHXZEXPAND */
      $display("WARNING: Attempting to read from uninitialized RAM.  Processor may go haywire if it uses x value. But this is normal in WALLY-mmu and ExceptionInstr tests.");
      $display("  PCM = %x InstrM = %x (%s), IEUAdrM = %x", PCM, InstrM, InstrMName, IEUAdrM);
      //$stop;
    end

endmodule
