///////////////////////////////////////////
// entropysrc.sv
//
// Written: Sisi Wang siswang@hmc.edu 20 Nov 2026
// Modified:
//
// Purpose: A stub entropy source for simulation
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software
// is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
// OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
///////////////////////////////////////////

//  fake entropy source for simulation:
//  every few clock cycles it offers the next number from a counter as a 16-bit "entropy" word

module entropystub (
    input  logic        clk, reset,
    input  logic        ESReady,         // seed slot can accept a word
    output logic        ESValid,         // a word is on offer
    output logic [15:0] ESBits,          // the word
    output logic        ESBist, ESDead   // never asserted by the stub(
);
    localparam logic [2:0] GAP = 3'd4;
    logic [15:0] word;
    logic [2:0] count;

    assign ESValid = (count == 3'd0);
    assign ESBits  = word;
    assign ESBist  = 1'b0;
    assign ESDead  = 1'b0;

    always_ff @(posedge clk)
        if (reset)                  begin word <= '0;           count <= GAP; end
        else if (ESValid & ESReady) begin word <= word + 16'd1; count <= GAP; end  // word taken: next word, restart gap
        else if (count != 3'd0)           count <= count - 3'd1;                   // gap counts down; then hold until taken

endmodule
