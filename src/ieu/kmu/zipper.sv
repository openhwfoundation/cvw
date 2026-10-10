///////////////////////////////////////////
// zipper.sv
//
// Written:  Kelvin Tran kelvin.tran@okstate.edu, James Stine james.stine@okstate.edu 9 October 2023
// Modified:
//
// Purpose: Bit interleave (zip) and deinterleave (unzip) for Zbkb.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2023-27 Harvey Mudd College & Oklahoma State University
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
