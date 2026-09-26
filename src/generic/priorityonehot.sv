///////////////////////////////////////////
// priorityonehot.sv
//
// Written: tfleming@hmc.edu & jtorrey@hmc.edu 7 April 2021
// Modified: Teo Ene 15 Apr 2021:
//              Temporarily removed parameterized priority encoder for non-parameterized one
//              To get synthesis working quickly
//           Kmacsaigoren@hmc.edu 28 May 2021:
//              Added working version of parameterized priority encoder.
//           David_Harris@Hmc.edu switched to one-hot output
//
// Purpose: Priority circuit producing a 1 in the output in the column where
//          the least significant 1 appears in the input.
//
//  Example:  msb           lsb
//        in  01011101010100000
//        out 00000000000100000
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
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
  input  logic  [N-1:0] a,
  output logic  [N-1:0] y
);

  genvar i;

  assign y[0] = a[0];
  for (i=1; i<N; i++) begin : poh
    assign y[i] = a[i] & ~|a[i-1:0];
  end

endmodule
