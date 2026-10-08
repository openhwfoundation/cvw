///////////////////////////////////////////
// or_rows.sv
//
// Written: David_Harris@hmc.edu 13 July 2021
// Modified:
//
// Purpose: Perform OR across a 2-dimensional array of inputs to produce a 1-D array of outputs
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

// perform an OR of all the rows in an array, producing one output for each column
// equivalent to assign y = a.or
module or_rows #(parameter ROWS = 8, COLS=2) (
  input  var logic [COLS-1:0] a[ROWS-1:0],
  output     logic [COLS-1:0] y
  );

  genvar row;

  if(ROWS == 1)
    assign y = a[0];
  else begin
    /* verilator lint_off UNOPTFLAT */
    logic [COLS-1:0] mid[ROWS-1:1];

    assign mid[1] = a[0] | a[1];
    for (row=2; row < ROWS; row++)
      assign mid[row] = mid[row-1] | a[row];
    assign y = mid[ROWS-1];
    /* verilator lint_on UNOPTFLAT */
  end
endmodule
