///////////////////////////////////////////
// tlbram.sv
//
// Written:  Jessica Torrey jtorrey@hmc.edu, Thomas Fleming tfleming@hmc.edu 16 February 2021
// Modified: David Harris David_Harris@hmc.edu, Kip Macsai-Goren kmacsaigoren@hmc.edu
//
// Purpose: Stores the PTEs of cached translations and reads out the physical page number and permission bits on a hit.
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


module tlbram import cvw::*;  #(parameter cvw_t P,
                                parameter TLB_ENTRIES = 8) (
  input  logic                      clk, reset,
  input  logic [P.XLEN-1:0]         PTE,
  input  logic [TLB_ENTRIES-1:0]    Matches, WriteEnables,
  output logic [P.PPN_BITS-1:0]     PPN,
  output logic [11:0]               PTEAccessBits,
  output logic [TLB_ENTRIES-1:0]    PTE_Gs,
  output logic [TLB_ENTRIES-1:0]    PTE_NAPOTs // entry is in NAPOT mode (N bit set and PPN[3:0] = 1000)
);

  logic [P.XLEN-1:0] RamRead[TLB_ENTRIES-1:0]; // stores the page table entries
  logic [P.XLEN-1:0] PageTableEntry;

  // RAM implemented with array of flops and AND/OR read logic
  tlbramline #(P) tlbramline[TLB_ENTRIES-1:0]
     (.clk, .reset, .re(Matches), .we(WriteEnables),
      .d(PTE), .q(RamRead), .PTE_G(PTE_Gs), .PTE_NAPOT(PTE_NAPOTs));
  or_rows #(TLB_ENTRIES, P.XLEN) PTEOr(RamRead, PageTableEntry);

  // Rename the bits read from the TLB RAM
  assign PTEAccessBits = {PageTableEntry[P.XLEN-1:P.XLEN-4] & {4{P.XLEN == 64}}, PageTableEntry[7:0]}; // for RV64 include N and PBMT bits and OR of reserved bits
  assign PPN = PageTableEntry[P.PPN_BITS+9:10];
endmodule
