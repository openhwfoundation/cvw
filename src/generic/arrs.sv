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
