///////////////////////////////////////////
// arrs.sv
//
// Written: Rose Thompson rose@rosethompson.net
// Modified: November 12, 2021
//
// Purpose: resets are typically asynchronous but need to be synchronized to
//          a clock to prevent changing in the invalid window clock edge.
//          arrs takes in the asynchronous reset and outputs an asynchronous
//          rising edge, but then syncs the falling edge to the posedge clk.
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

module arrs(
  input  logic  clk,
  input  logic  areset,
  output logic  reset
);

  logic         metaStable;
  logic         resetB;

  always_ff @(posedge clk , posedge areset) begin
    if (areset) begin
      metaStable <= 1'b0;
      resetB <= 1'b0;
    end else begin
      metaStable <= 1'b1;
      resetB <= metaStable;
    end
  end

  assign reset = ~resetB;
endmodule
