///////////////////////////////////////////
// tlbcam.sv
//
// Written: jtorrey@hmc.edu 16 February 2021
// Modified: kmacsaigoren@hmc.edu 1 June 2021
//            Implemented SV48 on top of SV39. This included adding the SvMode signal input and wally constants
//            Mostly this was to make the cam_lines work.
//
// Purpose: Stores virtual page numbers with cached translations.
//          Determines whether a given virtual page number is in the TLB.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
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

module tlbcam  import cvw::*;  #(parameter cvw_t P,
                                 parameter TLB_ENTRIES = 8, KEY_BITS = 20, SEGMENT_BITS = 10) (
  input  logic                    clk, reset,
  input  logic [P.VPN_BITS-1:0]   VPN,
  input  logic [2:0]              PageTypeWriteVal,
  input  logic                    SV39Mode,
  input  logic                    SV48Mode,
  input  logic                    TLBFlush,
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
    .clk, .reset, .VPN, .SATP_ASID, .SV39Mode, .SV48Mode, .PTE_G(PTE_Gs), .PTE_NAPOT(PTE_NAPOTs), .PageTypeWriteVal, .TLBFlush,
    .WriteEnable(WriteEnables), .PageTypeRead, .Match(Matches));
  assign CAMHit = |Matches & ~TLBFlush;
  or_rows #(TLB_ENTRIES,3) PageTypeOr(PageTypeRead, HitPageType);
endmodule
