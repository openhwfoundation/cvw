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

module irom import cvw::*;  #(parameter cvw_t P) (
  input  logic              clk,
  input  logic              ce,        // Chip Enable.  0: Holds IROMInstrF constant
  input  logic [P.XLEN-1:0] Adr,       // PCSpillNextF
  output logic [31:0]       IROMInstrF // Instruction read data
);

  localparam XLENBYTES = {{P.PA_BITS-32{1'b0}}, P.XLEN/8}; // XLEN/8, adjusted for width
  localparam ADDR_WDITH = $clog2((P.IROM_RANGE[P.PA_BITS-1:0]+1)/XLENBYTES); // IROM_RANGE is a mask (size-1)
  localparam OFFSET = $clog2(XLENBYTES);

  logic [ADDR_WDITH-1:0] WordAdr;
  logic [P.XLEN-1:0]     IROMWordF, IROMNextWordF;

  // preload IROM with the FPGA bootloader by default so that it synthesizes to something, avoiding having the IEU optimized away because instructions are all 0
  // the testbench replaces these dummy contents with the actual program of interest during simulation
  // The second port reads the next word, as two banks interleaved by word would.  It is used only with compressed instructions.
  assign WordAdr = Adr[ADDR_WDITH+OFFSET-1:OFFSET];
  rom2p2r #(ADDR_WDITH, P.XLEN, 1) rom(.clk, .ce, .addr1(WordAdr), .addr2(WordAdr + 1'b1), .dout1(IROMWordF), .dout2(IROMNextWordF));

  // Adr is the next PCF, not PCF, so the offset of the instruction in the word is delayed 1 cycle.
  if (P.ZCA_SUPPORTED) begin
    // A 32-bit instruction that crosses into the next word comes out whole, so the IROM never spills
    logic [2*P.XLEN-1:0] IROMWordsF;
    logic [OFFSET-1:1]   HalfwordD;
    flopen #(OFFSET-1) HalfwordReg(clk, ce, Adr[OFFSET-1:1], HalfwordD);
    assign IROMWordsF = {IROMNextWordF, IROMWordF};
    assign IROMInstrF = IROMWordsF[{1'b0, HalfwordD, 4'b0} +: 32]; // halfword offset, in bits
  end else if (P.XLEN == 32) assign IROMInstrF = IROMWordF;
  else begin
    // IROM is aligned to XLEN words, but instructions are 32 bits.  Select between the two halves.
    logic AdrD2;
    flopen #(1) AdrReg2(clk, ce, Adr[2], AdrD2);
    assign IROMInstrF = AdrD2 ? IROMWordF[63:32] : IROMWordF[31:0];
  end
endmodule
