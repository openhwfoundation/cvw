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
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
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
