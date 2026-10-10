///////////////////////////////////////////
// priorityaomux.sv
//
// Written:  Rose Thompson rose@rosethompson.net 24 January 2024
// Modified:
//
// Purpose: AND-OR multiplexer that selects the row with the lowest-index asserted select bit.
//
// Documentation:
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module priorityaomux #(parameter ROWS = 8, COLS = 64) (
  input logic [ROWS-1:0]  Sel,
  input                   var logic [COLS-1:0] A [ROWS-1:0],
  output logic [COLS-1:0] Y,
  output logic [ROWS-1:0] SelPriority);

  logic [COLS-1:0]           AMasked [ROWS-1:0];
  genvar                     index;

  priorityonehot #(ROWS) priorityonehot(Sel, SelPriority);
  for(index = 0; index < ROWS; index = index + 1) begin
    assign AMasked[index] = SelPriority[index] ? A[index] : '0;
  end
  or_rows #(ROWS, COLS) or_rows(AMasked, Y);

endmodule
