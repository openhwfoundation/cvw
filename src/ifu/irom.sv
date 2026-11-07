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

  // The IROM is 32 bits wide for any XLEN, because instructions are 32 bits.  ADDR_WIDTH is the number of
  // address bits of a 32-bit word.
  localparam ADDR_WIDTH = $clog2((P.IROM_RANGE[P.PA_BITS-1:0]+1) >> 2); // IROM_RANGE is a mask (size-1)

  // preload the IROM with a dummy instruction (rom1p1r PRELOAD_ENABLED) so that it synthesizes to something, avoiding having the IEU optimized away because instructions are all 0
  // the testbench replaces these dummy contents with the actual program of interest during simulation
  if (P.ZCA_SUPPORTED) begin : banks
    // With compressed instructions, a 32-bit instruction may start in the upper halfword of a word and end in the
    // next word.  The IROM is two banks interleaved by word: bank 0 holds the even words and bank 1 the odd words.
    // Both read the same row, except that bank 0 reads the next row when the instruction starts in bank 1, so the
    // IROM returns the whole instruction in one fetch.  At the top of the IROM the next row wraps to row 0; the
    // spill logic fetches the second half of an instruction starting in the last halfword of the IROM.
    localparam ROW_WIDTH = ADDR_WIDTH - 1;
    logic [ROW_WIDTH-1:0] Row, RowP1, WrapRow;
    logic [2:1]           AdrD;        // bank and halfword where the instruction starts
    logic [31:0]          Bank0F, Bank1F;

    assign Row = Adr[ADDR_WIDTH+1:3];
    assign RowP1 = Row + 1'b1;
    mux2 #(ROW_WIDTH) wraprowmux(Row, RowP1, Adr[2], WrapRow);
    rom1p1r #(ROW_WIDTH, 32, 1) bank0(.clk, .ce, .addr(WrapRow), .dout(Bank0F));
    rom1p1r #(ROW_WIDTH, 32, 1) bank1(.clk, .ce, .addr(Row), .dout(Bank1F));

    // Pick the instruction starting at the PC's halfword.  Bank 0 follows bank 1 because it read the next row.
    // Adr is the next PCF, not PCF, so the bank and halfword are delayed 1 cycle.
    flopen #(2) AdrReg(clk, ce, Adr[2:1], AdrD);
    mux4 #(32) instrmux(Bank0F, {Bank1F[15:0], Bank0F[31:16]}, Bank1F, {Bank0F[15:0], Bank1F[31:16]}, AdrD, IROMInstrF);
  end else begin : bank
    // Without compressed instructions, every instruction is one word
    rom1p1r #(ADDR_WIDTH, 32, 1) rom(.clk, .ce, .addr(Adr[ADDR_WIDTH+1:2]), .dout(IROMInstrF));
  end
endmodule
