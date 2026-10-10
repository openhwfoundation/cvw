///////////////////////////////////////////
// or_rows.sv
//
// Written:  David Harris David_Harris@hmc.edu 13 July 2021
// Modified: Rose Thompson rose@rosethompson.net
//
// Purpose: ORs the rows of a two-dimensional array into a single row.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
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
