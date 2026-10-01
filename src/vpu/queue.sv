///////////////////////////////////////////
// queue.sv
//
// Written: Rose Thompson rose.thompson@skyworksinc.com
// Simplified from spi_fifo.sv
// Created: 17 September 2026
// Modified: 17 September 2026
//
// Purpose: vector queue
//
// Documentation: RISC-V System on Chip Design Volume 2
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University & Skyworks Solutions Inc.
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

module queue  #(parameter DEPTH=3, WIDTH=8)
  (
    input logic              clk, reset,
    input logic              enqueue, dequeue,
    input logic [WIDTH-1:0]  wdata,
    output logic [WIDTH-1:0] rdata,
    output logic             full, empty
   );

  /* Pointer FIFO using design elements from "Simulation and Synthesis Techniques
   for Asynchronous FIFO Design" by Clifford E. Cummings. Namely, DEPTH bit read and write pointers
   are an extra bit larger than address size to determine full/empty conditions.
   Watermark comparisons use 2's complement subtraction between the DEPTH-1 bit pointers,
   which are also used to address memory
   */

  logic [WIDTH-1:0] mem[2**DEPTH];
  logic [DEPTH:0]   rptr, wptr;
  logic [DEPTH:0]   rptrnext, wptrnext;
  logic [DEPTH-1:0] raddr;
  logic [DEPTH-1:0] waddr;
  int               i;


  assign rdata = mem[raddr];
  always_ff @(posedge clk)
    if (reset)
      for(i = 0; i < 2**DEPTH; i++) mem[i] <= '0;
    else if (enqueue & ~full) mem[waddr] <= wdata;

  // write and read are enabled
  always_ff @(posedge clk)
    if (reset) begin
      rptr <= '0;
      wptr <= '0;
      full <= 1'b0;
      empty <= 1'b1;
    end else begin
      if (enqueue) begin
        full <= ({~wptrnext[DEPTH], wptrnext[DEPTH-1:0]} == rptr);
        wptr  <= wptrnext;
        empty <= (wptrnext == rptrnext);
      end
      if (dequeue) begin
        rptr <= rptrnext;
        empty <= (wptrnext == rptrnext);
      end
    end

  assign raddr = rptr[DEPTH-1:0];
  assign rptrnext = rptr + {{(DEPTH){1'b0}}, ~empty};
  assign waddr = wptr[DEPTH-1:0];
  assign wptrnext = wptr + {{(DEPTH){1'b0}}, ~full};
endmodule
