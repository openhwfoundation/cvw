///////////////////////////////////////////
// ram1p1rwe.sv
// 1 port sram.
//
// Written: avercruysse@hmc.edu (Modified from ram1p1rwbe, by rose@rosethompson.net)
// Created: 04 April 2023
//
// Purpose: ram1p1wre, but without byte-enable. Used for icache data.
//          Be careful using this module, since coverage is turned off for (ce & we).
//          In read-only caches, we never get (we=1, ce=0), so this waiver is needed.
//
// Documentation:
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
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

// WIDTH is number of bits in one "word" of the memory, DEPTH is number of such words

module ram1p1rwe import cvw::* ; #(parameter USE_SRAM=0, DEPTH=64, WIDTH=44) (
  input logic                     clk,
  input logic                     ce,
  input logic [$clog2(DEPTH)-1:0] addr,
  input logic [WIDTH-1:0]         din,
  input logic                     we,
  output logic [WIDTH-1:0]        dout
);

  //////////////////////////////////////////////////////////////////////////////
  // TRUE SRAM macro
  //////////////////////////////////////////////////////////////////////////////
  if ((USE_SRAM == 1) & (WIDTH == 128) & (DEPTH == 64)) begin // Cache data subarray
    // 64 x 128-bit SRAM
    ram1p1rwbe_64x128 sram1A (.CLK(clk), .CEB(~ce), .WEB(~we),
      .A(addr), .D(din),
      .BWEB('0), .Q(dout));

  end else if ((USE_SRAM == 1) & (WIDTH == 44)  & (DEPTH == 64)) begin // RV64 cache tag
    // 64 x 44-bit SRAM
    ram1p1rwbe_64x44 sram1B (.CLK(clk), .CEB(~ce), .WEB(~we),
      .A(addr), .D(din),
      .BWEB('0), .Q(dout));

  end else if ((USE_SRAM == 1) & (WIDTH == 22)  & (DEPTH == 64)) begin // RV32 cache tag
    // 64 x 22-bit SRAM
    ram1p1rwbe_64x22 sram1 (.CLK(clk), .CEB(~ce), .WEB(~we),
      .A(addr), .D(din),
      .BWEB('0), .Q(dout));

    //////////////////////////////////////////////////////////////////////////////
    // READ first SRAM model
    //////////////////////////////////////////////////////////////////////////////
  end else begin : ram
    // Vivado is not implementing this as block ram for some reason.
    // The version with byte write enables it correctly infers block ram.

    bit [WIDTH-1:0]               RAM[DEPTH-1:0];

    // Combinational read: register address and read after clock edge
    logic [$clog2(DEPTH)-1:0] addrd;
    flopen #($clog2(DEPTH)) adrreg(clk, ce, addr, addrd);
    assign dout = RAM[addrd];

    /*      // Alternate read logic reads the old contents of mem[addr].  Increases setup time and adds dout reg, but reduces clk to q
     always_ff @(posedge clk)
     if(ce) dout <= mem[addr]; */

    // Write divided into part for bytes and part for extra msbs
    // Questa sim version 2022.3_2 does not allow multiple drivers for RAM when using always_ff.
    // Therefore these always blocks use the older always @(posedge clk)
    always @(posedge clk)
      // coverage off
      // ce only goes low when cachefsm is in READY state and Flush is asserted.
      // for read-only caches, we only goes high in the STATE_WRITE_LINE cachefsm state.
      // so we can never get we=1, ce=0 for I$.
      if (ce & we)
        // coverage on
        RAM[addr] <= din;
  end
endmodule
