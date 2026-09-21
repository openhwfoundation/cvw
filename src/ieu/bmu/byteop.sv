///////////////////////////////////////////
// byteop.sv
//
// Written: Kevin Kim <kekim@hmc.edu>, kelvin.tran@okstate.edu
// Created: 1 February 2023
// Modified: 29 February 2024
//
// Purpose: RISCV bitmanip byte-wise operation unit
//
// Documentation: RISC-V System on Chip Design
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

module byteop #(parameter WIDTH=32) (
  input  logic [WIDTH-1:0] A,             // Operands
  input  logic             ByteSelect,    // LSB of Immediate
  output logic [WIDTH-1:0] ByteResult);   // rev8, orcb result

  logic [WIDTH-1:0] OrcBResult, Rev8Result;
  genvar i;

  for (i=0;i<WIDTH;i+=8) begin : byteloop
    assign OrcBResult[i+7:i] = {8{|A[i+7:i]}};
    assign Rev8Result[WIDTH-i-1:WIDTH-i-8] = A[i+7:i];
  end

  mux2 #(WIDTH) byteresultmux(Rev8Result, OrcBResult, ByteSelect, ByteResult);
endmodule
