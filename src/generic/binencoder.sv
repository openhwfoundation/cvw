///////////////////////////////////////////
// binencoder.sv
//
// Written:  Rose Thompson rose@rosethompson.net 14 November 2022
// Modified:
//
// Purpose: Encodes a one-hot input as a binary index.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2022-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
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
