///////////////////////////////////////////
// tlblru.sv
//
// Written:  Thomas Fleming tfleming@hmc.edu, Jessica Torrey jtorrey@hmc.edu 16 February 2021
// Modified: David Harris David_Harris@hmc.edu, Kip Macsai-Goren kmacsaigoren@hmc.edu
//
// Purpose: Pseudo-LRU replacement policy that selects the next TLB entry to write.
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

module tlblru #(parameter TLB_ENTRIES = 8) (
  input  logic                    clk, reset,
  input  logic                    TLBWrite,
  input  logic [TLB_ENTRIES-1:0]  Matches,
  input  logic                    TLBHit,
  output logic [TLB_ENTRIES-1:0]  WriteEnables
);

  logic [TLB_ENTRIES-1:0]         RUBits, RUBitsNext, RUBitsAccessed;
  logic [TLB_ENTRIES-1:0]         WriteLines;
  logic [TLB_ENTRIES-1:0]         AccessLines; // One-hot encodings of which line is being accessed
  logic                           AllUsed;  // High if the next access causes all RU bits to be 1

  // Find the first line not recently used
  priorityonehot #(TLB_ENTRIES) nru(.a(~RUBits), .y(WriteLines));

  // Track recently used lines, updating on a CAM Hit or TLB write
  assign WriteEnables = WriteLines & {(TLB_ENTRIES){TLBWrite}};
  assign AccessLines = TLBWrite ? WriteLines : Matches;
  assign RUBitsAccessed = AccessLines | RUBits;
  assign AllUsed = &RUBitsAccessed; // if all recently used, then clear to none
  assign RUBitsNext = AllUsed ? 0 : RUBitsAccessed;
  flopenr #(TLB_ENTRIES) lrustate(clk, reset, (TLBHit | TLBWrite), RUBitsNext, RUBits);
endmodule
