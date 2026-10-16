///////////////////////////////////////////
// priorityaomux.sv
//
// Written: Rose Thompson rose@rosethompson.net
// Created: 24 January 2024
// Modified: 24 January 2024
//
// Purpose: priority AND-OR MUX.
//
// Documentation:
//
// A component of the CORE-V-WALLY configurable RISC-V project.
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

module priorityaomux #(parameter ROWS = 8, COLS = 64) (
  input  logic [ROWS-1:0]     Sel,          // Row selects; lowest asserted row has priority
  input  var logic [COLS-1:0] A [ROWS-1:0], // Data inputs, one per row
  output logic [COLS-1:0]     Y,            // Selected data
  output logic [ROWS-1:0]     SelPriority); // One-hot select of the highest-priority asserted Sel bit

  logic [COLS-1:0]           AMasked [ROWS-1:0];
  genvar                     index;

  priorityonehot #(ROWS) priorityonehot(Sel, SelPriority);
  for (index = 0; index < ROWS; index = index + 1) begin
    assign AMasked[index] = SelPriority[index] ? A[index] : '0;
  end
  or_rows #(ROWS, COLS) or_rows(AMasked, Y);

endmodule
