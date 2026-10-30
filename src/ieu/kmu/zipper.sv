///////////////////////////////////////////
// zipper.sv
//
// Written: kelvin.tran@okstate.edu, james.stine@okstate.edu
// Created: 9 October 2023
//
// Purpose: RISCV kbitmanip zip operation unit
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module zipper #(parameter WIDTH=64) (
  input  logic [WIDTH-1:0] A,
  input  logic             ZipSelect,
  output logic [WIDTH-1:0] ZipResult
);

  logic [WIDTH-1:0]       zip, unzip;
  genvar                  i;

  for (i=0; i<WIDTH/2; i+=1) begin : loop
    assign zip[2*i]           = A[i];
    assign zip[2*i + 1]       = A[i + WIDTH/2];
    assign unzip[i]           = A[2*i];
    assign unzip[i + WIDTH/2] = A[2*i + 1];
  end

  mux2 #(WIDTH) ZipMux(zip, unzip, ZipSelect, ZipResult);
endmodule
