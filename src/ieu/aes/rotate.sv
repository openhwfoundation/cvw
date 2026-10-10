///////////////////////////////////////////
// rotate.sv
//
// Written: ryan.swann@okstate.edu, james.stine@okstate.edu
// Created: 20 February 2024
//
// Purpose: rotate a by shamt
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module rotate #(parameter WIDTH=32) (
   input  logic [WIDTH-1:0]        a,
   input  logic [$clog2(WIDTH)-1:0] shamt,
   output logic [WIDTH-1:0]        y
);

   assign y = (a << shamt) | (a >> (WIDTH-shamt));
endmodule
