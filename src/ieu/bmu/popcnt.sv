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
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
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
