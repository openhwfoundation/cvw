///////////////////////////////////////////
// zbkx.sv
//
// Written:  Kelvin Tran kelvin.tran@okstate.edu, James Stine james.stine@okstate.edu 1 February 2024
// Modified: David Harris
//
// Purpose: Zbkx xperm4 and xperm8.
//          xperm8 uses the xperm4 nibble lookups: byte i of xperm8 is nibbles 2*idx and 2*idx+1,
//          so nibble j looks up {B[8(j/2) +: L-1], j%2} and is zeroed if the byte index is out of range.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module zbkx #(parameter WIDTH=32) (
  input  logic [WIDTH-1:0] A, B,
  input  logic             ZBKXSelect,   // 1: xperm4, 0: xperm8
  output logic [WIDTH-1:0] ZBKXResult
);
  localparam L = $clog2(WIDTH/4);        // nibble index width
  genvar j;
  for (j = 0; j < WIDTH/4; j++) begin : nib
    logic [L-1:0] Idx;
    logic         Zero;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [WIDTH-1:0] Lookup;     // only the low nibble is used
    /* verilator lint_on UNUSEDSIGNAL */
    assign Idx  = ZBKXSelect ? B[4*j +: L] : {B[8*(j/2) +: L-1], 1'(j % 2)};
    // out of range: xperm8 byte index >= WIDTH/8, or xperm4 nibble index >= WIDTH/4 (possible only on RV32)
    if (L < 4) begin : x4range
      assign Zero = ZBKXSelect ? |B[4*j+L +: 4-L] : |(B[8*(j/2) +: 8] >> (L-1));
    end else begin : x4inrange
      assign Zero = ~ZBKXSelect & |(B[8*(j/2) +: 8] >> (L-1));
    end
    assign Lookup = A >> {Idx, 2'b0};
    assign ZBKXResult[4*j +: 4] = Zero ? 4'b0 : Lookup[3:0];
  end
endmodule
