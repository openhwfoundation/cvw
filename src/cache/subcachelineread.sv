///////////////////////////////////////////
// subcachelineread.sv
//
// Written: Rose Thompson rose@rosethompson.net
// Created: 4 February 2022
// Modified: 20 January 2023
//
// Purpose: Muxes the cache line down to the word size.  Also include possible save/restore registers/muxes.
//
// Documentation: RISC-V System on Chip Design

// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module subcachelineread #(parameter LINELEN, WORDLEN,
  parameter MUXINTERVAL )(     // The number of bits between mux. Set to 16 for I$ to support compressed.  Set to `LLEN for D$
  input  logic [$clog2(LINELEN/8) - $clog2(MUXINTERVAL/8) - 1 : 0] PAdr,       // Physical address
  input  logic [LINELEN-1:0]                     ReadDataLine,// Read data of the whole cacheline
  output logic [WORDLEN-1:0]                     ReadDataWord // read data of selected word.
);

  localparam WORDSPERLINE = LINELEN/MUXINTERVAL;
  localparam PADLEN = WORDLEN-MUXINTERVAL;

  // pad is for icache. Muxing extends over the cacheline boundary.
  logic [LINELEN+(WORDLEN-MUXINTERVAL)-1:0]   ReadDataLinePad;
  logic [WORDLEN-1:0]                         ReadDataLineSets [(LINELEN/MUXINTERVAL)-1:0];

  if (PADLEN > 0) assign ReadDataLinePad = {{PADLEN{1'b0}}, ReadDataLine};
  else            assign ReadDataLinePad = ReadDataLine;

  genvar index;
  for (index = 0; index < WORDSPERLINE; index++) begin : readdatalinesetsmux
    assign ReadDataLineSets[index] = ReadDataLinePad[(index*MUXINTERVAL)+WORDLEN-1 : (index*MUXINTERVAL)];
  end

  // variable input mux
  assign ReadDataWord = ReadDataLineSets[PAdr];
endmodule
