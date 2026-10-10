///////////////////////////////////////////
// onehotdecoder.sv
//
// Written:  Rose Thompson rose@rosethompson.net 9 July 2021
// Modified:
//
// Purpose: Decodes a binary value into a one-hot output; the output width must be a power of 2.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module onehotdecoder #(parameter WIDTH = 2) (
  input  logic [WIDTH-1:0]    bin,
  output logic [2**WIDTH-1:0] decoded
);

  always_comb begin
    decoded = '0;
    decoded[bin] = 1'b1;
  end

endmodule
