///////////////////////////////////////////
// zipper.sv
//
// Written: kelvin.tran@okstate.edu, james.stine@okstate.edu
// Created: 9 October 2023
//
// Purpose: RISCV kbitmanip zip operation unit
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
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
