///////////////////////////////////////////
// counter.sv
//
// Written: David_Harris@hmc.edu 10 October 2021
// Modified:
//
// Purpose: Counter with reset and enable
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
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

module counter #(parameter WIDTH=8) (
  input  logic             clk, reset, en,
  output logic [WIDTH-1:0] q
);

  logic [WIDTH-1:0] qnext;

  assign qnext = q + 1;
  flopenr #(WIDTH) cntrflop(clk, reset, en, qnext, q);
endmodule
