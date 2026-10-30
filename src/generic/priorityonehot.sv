///////////////////////////////////////////
// priorityonehot.sv
//
// Written:  Thomas Fleming tfleming@hmc.edu, Jessica Torrey jtorrey@hmc.edu 7 April 2021
// Modified: David Harris David_Harris@hmc.edu, Kip Macsai-Goren kmacsaigoren@hmc.edu, Madeleine Masser-Frye, Teo Ene
//
// Purpose: One-hot marking of the least significant 1.
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
// OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
///////////////////////////////////////////

module priorityonehot #(parameter N = 8) (
  input  logic [N-1:0] a, // Input
  output logic [N-1:0] y  // One-hot: lowest set bit of a
);

  genvar i;

  assign y[0] = a[0];
  for (i = 1; i < N; i++) begin : poh
    assign y[i] = a[i] & ~|a[i-1:0];
  end

endmodule
