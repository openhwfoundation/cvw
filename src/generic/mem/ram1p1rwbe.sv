///////////////////////////////////////////
// ram1p1rwbe.sv
//
// Written:  Rose Thompson rose@rosethompson.net 3 May 2021
// Modified: David Harris David_Harris@hmc.edu, James Stine james.stine@okstate.edu, Jacob Pease jacobpease@protonmail.com
//
// Purpose: Single-port RAM with byte write enables and a synchronous read, built from a behavioral array or SRAM macros.
//
// Documentation:
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

// WIDTH is number of bits in one "word" of the memory, DEPTH is number of such words

module ram1p1rwbe import cvw::*; #(parameter USE_SRAM=0, DEPTH=64, WIDTH=44, PRELOAD_ENABLED=0) (
  input logic                     clk,
  input logic                     ce,
  input logic [$clog2(DEPTH)-1:0] addr,
  input logic [WIDTH-1:0]         din,
  input logic                     we,
  input logic [(WIDTH-1)/8:0]     bwe,
  output logic [WIDTH-1:0]        dout
);

  ///////////////////////////////////////////////////////////////////////////////
  // TRUE SRAM macro
  ///////////////////////////////////////////////////////////////////////////////
  if ((USE_SRAM == 1) & (WIDTH == 128) & (DEPTH == 64)) begin // Cache data subarray
    genvar index;
    // 64 x 128-bit SRAM
    logic [WIDTH-1:0] BitWriteMask;
    for (index=0; index < WIDTH; index++)
      assign BitWriteMask[index] = bwe[index/8];
    ram1p1rwbe_64x128 sram1A (.CLK(clk), .CEB(~ce), .WEB(~we),
      .A(addr), .D(din),
      .BWEB(~BitWriteMask), .Q(dout));

  end else if ((USE_SRAM == 1) & (WIDTH == 44)  & (DEPTH == 64)) begin // RV64 cache tag
    genvar index;
    // 64 x 44-bit SRAM
    logic [WIDTH-1:0] BitWriteMask;
    for (index=0; index < WIDTH; index++)
      assign BitWriteMask[index] = bwe[index/8];
    ram1p1rwbe_64x44 sram1B (.CLK(clk), .CEB(~ce), .WEB(~we),
      .A(addr), .D(din),
      .BWEB(~BitWriteMask), .Q(dout));

  end else if ((USE_SRAM == 1) & (WIDTH == 22)  & (DEPTH == 64)) begin // RV32 cache tag
    genvar index;
    // 64 x 22-bit SRAM
    logic [WIDTH-1:0] BitWriteMask;
    for (index=0; index < WIDTH; index++)
      assign BitWriteMask[index] = bwe[index/8];
    ram1p1rwbe_64x22 sram1B (.CLK(clk), .CEB(~ce), .WEB(~we),
      .A(addr), .D(din),
      .BWEB(~BitWriteMask), .Q(dout));

    ///////////////////////////////////////////////////////////////////////////////
    // READ first SRAM model
    ///////////////////////////////////////////////////////////////////////////////
  end else begin : ram
    bit [WIDTH-1:0] RAM[DEPTH-1:0];

    // if (PRELOAD_ENABLED) begin
    //   initial begin
    //     RAM[0] = 64'h00600100d2e3ca40;
    //   end
    // end

    `ifdef VERILATOR
      import "DPI-C" function string getenvval(input string env_name);
    `endif

    initial
      if (PRELOAD_ENABLED) begin
        if (WIDTH == 64) begin
          `ifdef VERILATOR
            // because Verilator doesn't automatically accept $WALLY from shell
            static string WALLY_DIR = getenvval("WALLY");
            $readmemh({WALLY_DIR,"/fpga/src/data.mem"}, RAM, 0);  // load boot RAM for FPGA
          `else
            $readmemh({"$WALLY/fpga/src/data.mem"}, RAM, 0);  // load boot RAM for FPGA
          `endif
        end else begin // put something in the RAM so it is not optimized away
        RAM[0] = 'h00002197;
        end
      end

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
    if(WIDTH >= 8) begin
      integer i;
      always @(posedge clk)
        if (ce & we)
          for(i = 0; i < WIDTH/8; i++)
            if(bwe[i]) RAM[addr][i*8 +: 8] <= din[i*8 +: 8];
    end

    if (WIDTH%8 != 0) // handle msbs if width not a multiple of 8
      always @(posedge clk)
        if (ce & we & bwe[WIDTH/8])
          RAM[addr][WIDTH-1:WIDTH-WIDTH%8] <= din[WIDTH-1:WIDTH-WIDTH%8];
  end

endmodule
