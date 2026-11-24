///////////////////////////////////////////
// entropysrc.sv
//
// Written: Sisi Wang siswang@hmc.edu 20 Nov 2026
// Modified:
//
// Purpose: Entropy Source Wrapper Module
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

module entropysrc (
    input logic         clk, reset,
    input logic         ESReady,             // seed slot can accept a word
    output logic        ESValid,             // source has a word; a word moves when ESValid & ESReady
    output logic [15:0] ESBits,              // the word
    output logic        ESBist, ESDead       // source self-testing
);

    entropystub entropystub(
        .clk, .reset, .ESReady, .ESValid, .ESBits, .ESBist, .ESDead
    );

endmodule
