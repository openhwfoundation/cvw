///////////////////////////////////////////
// tlbcam.sv
//
// Written:  Jessica Torrey jtorrey@hmc.edu 16 February 2021
// Modified: David Harris David_Harris@hmc.edu, Kip Macsai-Goren kmacsaigoren@hmc.edu, Thomas Fleming tfleming@hmc.edu, Ayesha Anwaar ayesha.anwaar2005@gmail.com
//
// Purpose: Content-addressable memory of TLB virtual page numbers that determines whether a translation hits.
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

module tlbcam  import cvw::*;  #(parameter cvw_t P,
                                 parameter TLB_ENTRIES = 8, KEY_BITS = 20, SEGMENT_BITS = 10) (
  input  logic                    clk, reset,
  input  logic [P.VPN_BITS-1:0]   VPN,
  input  logic [2:0]              PageTypeWriteVal,
  input  logic                    SV39Mode,
  input  logic                    SV48Mode,
  input  logic                    TLBFlush,
  input  logic                    TLBFlushAll,  // Flush global (G=1) entries too
  input  logic [TLB_ENTRIES-1:0]  WriteEnables,
  input  logic [TLB_ENTRIES-1:0]  PTE_Gs,
  input  logic [TLB_ENTRIES-1:0]  PTE_NAPOTs,  // entry is in NAPOT mode (N bit set and PPN[3:0] = 1000)
  input  logic [P.ASID_BITS-1:0]  SATP_ASID,
  output logic [TLB_ENTRIES-1:0]  Matches,
  output logic [2:0]              HitPageType,
  output logic                    CAMHit
);

  logic [2:0] PageTypeRead [TLB_ENTRIES-1:0];

  // TLB_ENTRIES CAM lines, each of which will independently consider
  // whether the requested virtual address is a match. Each line stores the
  // original virtual page number from when the address was written, regardless
  // of page type. However, matches are determined based on a subset of the
  // page number segments.

  tlbcamline #(P, KEY_BITS, SEGMENT_BITS) camlines[TLB_ENTRIES-1:0](
    .clk, .reset, .VPN, .SATP_ASID, .SV39Mode, .SV48Mode, .PTE_G(PTE_Gs), .PTE_NAPOT(PTE_NAPOTs), .PageTypeWriteVal, .TLBFlush, .TLBFlushAll,
    .WriteEnable(WriteEnables), .PageTypeRead, .Match(Matches));
  assign CAMHit = |Matches & ~TLBFlush;
  or_rows #(TLB_ENTRIES,3) PageTypeOr(PageTypeRead, HitPageType);
endmodule
