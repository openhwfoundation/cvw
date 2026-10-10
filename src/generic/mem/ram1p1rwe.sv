///////////////////////////////////////////
// ram1p1rwe.sv
//
// Written:  Alec Vercruysse avercruysse@hmc.edu 4 April 2023
// Modified: Rose Thompson rose@rosethompson.net, David Harris David_Harris@hmc.edu
//
// Purpose: Single-port RAM with a word write enable and a synchronous read, used for read-only cache ways.
//          Coverage is turned off for (ce & we): read-only caches never have we=1 with ce=0.
//
// Documentation:
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2023-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
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
