///////////////////////////////////////////
// tlbcam.sv
//
// Written:  Jessica Torrey jtorrey@hmc.edu 16 February 2021
// Modified: David Harris, Kip Macsai-Goren kmacsaigoren@hmc.edu, Thomas Fleming, Ayesha Anwaar
//
// Purpose: TLB virtual page number CAM.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module tlbcam import cvw::*; #(parameter cvw_t P,
                               parameter TLB_ENTRIES = 8, KEY_BITS = 20, SEGMENT_BITS = 10) (
  input  logic                    clk, reset,
  input  logic [P.VPN_BITS-1:0]   VPN,              // Virtual page number
  input  logic [2:0]              PageTypeWriteVal, // Page type to write to TLB
  input  logic                    SV39Mode,         // Translation mode is Sv39
  input  logic                    SV48Mode,         // Translation mode is Sv48
  input  logic                    TLBFlush,         // Invalidate TLB entries (ASID-specific flush preserves global entries)
  input  logic                    TLBFlushAll,      // Flush global (G = 1) entries too
  input  logic [TLB_ENTRIES-1:0]  WriteEnables,     // One-hot TLB entry to write
  input  logic [TLB_ENTRIES-1:0]  PTE_Gs,           // Global bits of all TLB entries
  input  logic [TLB_ENTRIES-1:0]  PTE_NAPOTs,       // NAPOT mode bits of all TLB entries
  input  logic [P.ASID_BITS-1:0]  SATP_ASID,        // satp.ASID
  input  logic                    TLBWrite,         // A PTE is being written into the TLB
  input  logic                    WritePTE_G,       // G bit of the PTE being written
  input  logic                    WritePTE_NAPOT,   // The PTE being written is a NAPOT entry
  output logic [TLB_ENTRIES-1:0]  Matches,          // One-hot TLB entry that matches
  output logic [2:0]              HitPageType,      // Page type of the matching TLB entry
  output logic                    CAMHit            // A TLB entry matches the virtual page number
);

  logic [2:0] PageTypeRead [TLB_ENTRIES-1:0];

  // TLB_ENTRIES CAM lines, each of which will independently consider
  // whether the requested virtual address is a match. Each line stores the
  // original virtual page number from when the address was written, regardless
  // of page type. However, matches are determined based on a subset of the
  // page number segments.

  tlbcamline #(P, KEY_BITS, SEGMENT_BITS) camlines[TLB_ENTRIES-1:0](
    .clk, .reset, .VPN, .SATP_ASID, .SV39Mode, .SV48Mode, .PTE_G(PTE_Gs), .PTE_NAPOT(PTE_NAPOTs), .PageTypeWriteVal, .TLBFlush, .TLBFlushAll,
    .WriteEnable(WriteEnables), .TLBWrite, .WritePTE_G, .WritePTE_NAPOT, .PageTypeRead, .Match(Matches));
  assign CAMHit = |Matches & ~TLBFlush;
  or_rows #(TLB_ENTRIES, 3) PageTypeOr(PageTypeRead, HitPageType);
endmodule
