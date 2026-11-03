///////////////////////////////////////////
// rom1p1rline.sv
//
// Written:  David Harris David_Harris@hmc.edu 1 November 2026
// Modified:
//
// Purpose: Single-port ROM that reads a line of WORDS words.  The contents are held as words,
//          so the ROM preloads from a memory file of words like rom1p1r.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2022-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module rom1p1rline #(parameter ADDR_WIDTH = 8, DATA_WIDTH = 32, WORDS = 4, PRELOAD_ENABLED = 0) (
  input  logic                        clk,
  input  logic                        ce,
  input  logic [ADDR_WIDTH-1:0]       addr,  // line address
  output logic [WORDS*DATA_WIDTH-1:0] dout
);

  localparam WORDBITS = $clog2(WORDS);  // 0 for a line of one word

  // Core Memory
  bit [DATA_WIDTH-1:0] ROM [(2**(ADDR_WIDTH+WORDBITS))-1:0];

  `ifdef VERILATOR
    import "DPI-C" function string getenvval(input string env_name);
  `endif

  initial
    if (PRELOAD_ENABLED) begin
      if (DATA_WIDTH == 64) begin
        `ifdef VERILATOR
          // because Verilator doesn't automatically accept $WALLY from shell
          static string WALLY_DIR = getenvval("WALLY");
          $readmemh({WALLY_DIR, "/fpga/src/boot.mem"}, ROM, 0);  // load boot ROM for FPGA
        `else
          $readmemh({"$WALLY/fpga/src/boot.mem"}, ROM, 0);  // load boot ROM for FPGA
        `endif
      end else begin // put something in the ROM so it is not optimized away
        ROM[0] = 'h00002197;
      end
    end

  // WORDS is a power of 2
  for (genvar i = 0; i < WORDS; i++) begin : word
    logic [ADDR_WIDTH+WORDBITS-1:0] WordAdr;
    assign WordAdr = (ADDR_WIDTH+WORDBITS)'(addr) * (ADDR_WIDTH+WORDBITS)'(WORDS) + (ADDR_WIDTH+WORDBITS)'(i);
    always_ff @(posedge clk)
      if (ce) dout[i*DATA_WIDTH +: DATA_WIDTH] <= ROM[WordAdr];
  end
endmodule
