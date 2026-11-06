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

  // preload IROM with the FPGA bootloader by default so that it synthesizes to something, avoiding having the IEU optimized away because instructions are all 0
  // the testbench replaces these dummy contents with the actual program of interest during simulation
  if (P.ZCA_SUPPORTED) begin : banks
    // With compressed instructions, a 32-bit instruction may start in the last halfword of a word and end in the
    // next word.  The IROM is two banks interleaved by word: bank 0 holds the even words and bank 1 the odd words.
    // Both read the same row, except that bank 0 reads the next row when the instruction starts in bank 1, so the
    // IROM returns the whole instruction in one fetch.  At the top of the IROM the next row wraps to row 0; the
    // spill logic fetches the second half of an instruction starting in the last halfword of the IROM.
    localparam ROW_WIDTH = ADDR_WIDTH - 1;
    logic [ROW_WIDTH-1:0] Row, Bank0Row;
    logic                 BankD;       // bank of the word holding the first half
    logic [OFFSET-1:1]    HalfwordD;   // halfword offset of the instruction in that word
    logic [P.XLEN-1:0]    Bank0F, Bank1F;
    logic [2*P.XLEN-1:0]  WordsF;      // the word holding the first half and the next word

    assign Row = Adr[ADDR_WIDTH+OFFSET-1:OFFSET+1];
    mux2 #(ROW_WIDTH) bank0rowmux(Row, Row + 1'b1, Adr[OFFSET], Bank0Row);
    rom1p1r #(ROW_WIDTH, P.XLEN, 1) bank0(.clk, .ce, .addr(Bank0Row), .dout(Bank0F));
    rom1p1r #(ROW_WIDTH, P.XLEN, 1) bank1(.clk, .ce, .addr(Row), .dout(Bank1F));

    // Adr is the next PCF, not PCF, so the bank and offset are delayed 1 cycle.
    flopen #(OFFSET) AdrReg(clk, ce, Adr[OFFSET:1], {BankD, HalfwordD});
    mux2 #(2*P.XLEN) wordsmux({Bank1F, Bank0F}, {Bank0F, Bank1F}, BankD, WordsF);
    assign IROMInstrF = WordsF[{1'b0, HalfwordD, 4'b0} +: 32]; // starting at the halfword offset
  end else begin : bank
    // Without compressed instructions, every instruction is in one word
    logic [P.XLEN-1:0] IROMWordF;

    rom1p1r #(ADDR_WIDTH, P.XLEN, 1) rom(.clk, .ce, .addr(Adr[ADDR_WIDTH+OFFSET-1:OFFSET]), .dout(IROMWordF));
    if (P.XLEN == 32) assign IROMInstrF = IROMWordF;
    else begin
      // IROM is aligned to XLEN words, but instructions are 32 bits.  Select between the two
      // halves.  Adr is the Next PCF not PCF so we delay 1 cycle.
      logic AdrD2;
      flopen #(1) AdrReg2(clk, ce, Adr[2], AdrD2);
      assign IROMInstrF = AdrD2 ? IROMWordF[63:32] : IROMWordF[31:0];
    end
  end
endmodule
