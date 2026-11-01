///////////////////////////////////////////
// rom2p2r.sv
//
// Written:  David Harris David_Harris@hmc.edu 1 November 2026
// Modified:
//
// Purpose: ROM with two read ports.  Equivalent to two banks interleaved by word when the ports read
//          adjacent words, as the IROM does.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2022-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module rom2p2r #(parameter ADDR_WIDTH = 8, DATA_WIDTH = 32, PRELOAD_ENABLED = 0)
  (input  logic                  clk,
   input  logic                  ce,
   input  logic [ADDR_WIDTH-1:0] addr1, addr2,
   output logic [DATA_WIDTH-1:0] dout1, dout2
);

  // Core Memory
  bit [DATA_WIDTH-1:0]    ROM [(2**ADDR_WIDTH)-1:0];

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

  always_ff @(posedge clk)
    if (ce) begin
      dout1 <= ROM[addr1];
      dout2 <= ROM[addr2];
    end
endmodule
