///////////////////////////////////////////
// binencoder.sv
//
// Written: rose@rosethompson.net November 14, 2022
//
// Purpose: one-hot to binary encoding.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
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

module binencoder #(parameter N = 8) (
  input  logic [N-1:0]         A,   // one-hot input
  output logic [$clog2(N)-1:0] Y    // binary-encoded output
);

  integer                      index;

  // behavioral description
  // this is coded as a priority encoder
  // consider redesigning to take advanteage of one-hot nature of input
  always_comb  begin
    Y = '0;
    for(index = 0; index < N; index++)
      if(A[index] == 1'b1) Y = index[$clog2(N)-1:0];
  end

endmodule
