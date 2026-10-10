///////////////////////////////////////////
//
// Written: me@KatherineParry.com
// Modified: 7/5/2022
// Modified: 2/11/2026 james.stine@okstate.edu/marcus@infinitymdm.dev
//
// Purpose: Leading Zero Counter
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module lzc #(parameter WIDTH = 1) (
  input  logic [WIDTH-1:0]            num,    // number to count the leading zeroes of
  output logic [$clog2(WIDTH+1)-1:0]  ZeroCnt // the number of leading zeroes
);

  integer i;

  always_comb begin
    i = 0;
    // search for leading one
    while ((i < WIDTH) && (!num[WIDTH-1-i])) begin
      i = i + 1;
    end
    ZeroCnt = i[$clog2(WIDTH+1)-1:0];
  end
endmodule
