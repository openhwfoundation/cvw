///////////////////////////////////////////
// onehotdecoder.sv
//
// Written: rose@rosethompson.net July 09, 2021
// Modified:
//
// Purpose: Bin to one hot decoder. Power of 2 only.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
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
