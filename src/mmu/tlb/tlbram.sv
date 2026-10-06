///////////////////////////////////////////
// tlbram.sv
//
// Written: jtorrey@hmc.edu & tfleming@hmc.edu 16 February 2021
// Modified:
//
// Purpose: Stores page table entries of cached address translations.
//          Outputs the physical page number and access bits of the current
//          virtual address on a TLB hit.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
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
