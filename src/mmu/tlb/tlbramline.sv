///////////////////////////////////////////
// tlbramline.sv
//
// Written:  David Harris David_Harris@hmc.edu 4 July 2021
// Modified:
//
// Purpose: One TLB RAM entry with an enabled register and AND-OR read logic.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module tlbramline import cvw::*;  #(parameter cvw_t P)
  (input  logic              clk, reset,
   input  logic              re, we,
   input  logic [P.XLEN-1:0] d,
   output logic [P.XLEN-1:0] q,
   output logic              PTE_G,
   output logic              PTE_NAPOT // entry is in NAPOT mode (N bit set and PPN[3:0] = 1000)
);

   logic [P.XLEN-1:0] line;

  if (P.XLEN == 64) begin // save 7 reserved bits
    // could optimize out N and PBMT from d[63:61] if they aren't supported
    logic [57:0] ptereg;
    logic reserved;
    assign reserved = |d[60:54]; // are any of the reserved bits nonzero?
    flopenr #(58) pteflop(clk, reset, we, {d[63:61], reserved, d[53:0]}, ptereg);
    assign line = {ptereg[57:54], 6'b0, ptereg[53:0]};
  end else // rv32
    flopenr #(P.XLEN) pteflop(clk, reset, we, d, line);

   assign q = re ? line : 0;
   assign PTE_G = line[5]; // send global bit to CAM as part of ASID matching
   assign PTE_NAPOT = P.SVNAPOT_SUPPORTED & line[P.XLEN-1] & (line[13:10] == 4'b1000); // send NAPOT bit to CAM as part of matching lsbs of VPN
endmodule
