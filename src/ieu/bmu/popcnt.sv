///////////////////////////////////////////
// popccnt.sv
// Written: Kevin Kim <kekim@hmc.edu>
// Modified: 2/4/2023
//
// Purpose: Population Count
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module popcnt #(parameter WIDTH = 32) (
  input  logic [WIDTH-1:0]        num,    // number to count total ones
  output logic [$clog2(WIDTH):0]  PopCnt  // the total number of ones
);

  logic [$clog2(WIDTH):0] sum;

  always_comb begin
    sum = '0;
    for (int i=0;i<WIDTH;i++) begin : loop
      sum = (num[i]) ? sum + 1 : sum;
    end
  end

  assign PopCnt = sum;
endmodule
