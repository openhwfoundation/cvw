///////////////////////////////////////////
// instrTrackerTB.sv
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module instrTrackerTB #(parameter XLEN) (
  input  logic            clk, reset, FlushE,
  input  logic [31:0]     InstrF, InstrD,
  input  logic [31:0]     InstrE, InstrM,
  input  logic [31:0]     InstrW,
//  output logic [31:0]     InstrW,
  output string           InstrFName, InstrDName, InstrEName, InstrMName, InstrWName);

  // stage Instr to Writeback for visualization
  // flopr  #(32) InstrWReg(clk, reset, InstrM, InstrW);

  instrNameDecTB #(XLEN) fdec(InstrF, InstrFName);
  instrNameDecTB #(XLEN) ddec(InstrD, InstrDName);
  instrNameDecTB #(XLEN) edec(InstrE, InstrEName);
  instrNameDecTB #(XLEN) mdec(InstrM, InstrMName);
  instrNameDecTB #(XLEN) wdec(InstrW, InstrWName);
endmodule
