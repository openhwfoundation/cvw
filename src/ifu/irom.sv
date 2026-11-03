///////////////////////////////////////////
// irom.sv
//
// Written:  Rose Thompson rose@rosethompson.net 30 January 2022
// Modified: David Harris
//
// Purpose: Instruction ROM.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2022-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module irom import cvw::*; #(parameter cvw_t P) (
  input  logic              clk,
  input  logic              ce,        // Chip Enable.  0: Holds IROMInstrF constant
  input  logic [P.XLEN-1:0] Adr,       // PCSpillNextF
  output logic [31:0]       IROMInstrF // Instruction read data
);

  localparam XLENBYTES = {{P.PA_BITS-32{1'b0}}, P.XLEN/8}; // XLEN/8, adjusted for width
  localparam ADDR_WIDTH = $clog2((P.IROM_RANGE[P.PA_BITS-1:0]+1)/XLENBYTES); // IROM_RANGE is a mask (size-1)
  localparam OFFSET = $clog2(XLENBYTES);

  localparam WORDS = P.IROM_LINELEN / P.XLEN;             // XLEN words in an IROM line
  localparam LINEOFFSET = $clog2(P.IROM_LINELEN/8);        // byte offset bits in a line
  localparam LINEADR_WIDTH = ADDR_WIDTH - $clog2(WORDS);   // line address bits

  logic [P.IROM_LINELEN-1:0] IROMLineF;
  logic [LINEOFFSET-1:1]     HalfwordD;
  logic [P.IROM_LINELEN+15:0] ShiftedLineF;

  // preload IROM with the FPGA bootloader by default so that it synthesizes to something, avoiding having the IEU optimized away because instructions are all 0
  // the testbench replaces these dummy contents with the actual program of interest during simulation
  rom1p1rline #(LINEADR_WIDTH, P.XLEN, WORDS, 1) rom(.clk, .ce, .addr(Adr[ADDR_WIDTH+OFFSET-1:LINEOFFSET]), .dout(IROMLineF));

  // Select the instruction from the line.  Adr is the next PCF, not PCF, so the offset is delayed 1 cycle.
  // A 32-bit instruction in the last halfword of the line returns its first half in the lower 2 bytes;
  // the spill logic fetches the next line and merges the two halves.
  flopen #(LINEOFFSET-1) HalfwordReg(clk, ce, Adr[LINEOFFSET-1:1], HalfwordD);
  assign ShiftedLineF = {16'b0, IROMLineF} >> {HalfwordD, 4'b0};
  assign IROMInstrF = ShiftedLineF[31:0];
endmodule
