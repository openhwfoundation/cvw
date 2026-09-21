///////////////////////////////////////////
// prioritythermometer.sv
//
// Written: tfleming@hmc.edu & jtorrey@hmc.edu 7 April 2021
//           David_Harris@Hmc.edu switched to one-hot output
//
// Purpose: Priority circuit producing a thermometer code output.
//          with 1's in all the least significant bits of the output
//          until the column where the least significant 1 occurs in the input.
//
//  Example:  msb           lsb
//        in  01011101010100000
//        out 00000000000011111
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

module prioritythermometer #(parameter N = 8) (
  input  logic  [N-1:0] a,
  output logic  [N-1:0] y
);

  // Carefully crafted so design compiler will synthesize into a fast tree structure
  //  Rather than linear.

  // create thermometer code mask
  genvar i;
  assign y[0] = ~a[0];
  for (i=1; i<N; i++) begin : therm
    assign y[i] = y[i-1] & ~a[i];
  end
endmodule
