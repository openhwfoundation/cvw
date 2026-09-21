///////////////////////////////////////////
// tlbcamline.sv
//
// Written: tfleming@hmc.edu & jtorrey@hmc.edu 6 April 2021
// Modified: kmacsaigoren@hmc.edu 1 June 2021
//            Implemented SV48 on top of SV39. This included adding SvMode input signal and the wally constants
//            Mostly this was done to make the PageNumberMixer work.
//
// Purpose: CAM line for the translation lookaside buffer (TLB)
//          Determines whether a virtual page number matches the stored key.
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

module tlbcamline import cvw::*;  #(parameter cvw_t P,
                                    parameter KEY_BITS = 20, SEGMENT_BITS = 10) (
  input  logic                  clk, reset,
  input  logic [P.VPN_BITS-1:0]  VPN, // The requested page number to compare against the key
  input  logic [P.ASID_BITS-1:0] SATP_ASID,
  input  logic                  SV39Mode,
  input  logic                  SV48Mode,
  input  logic                  WriteEnable,  // Write a new entry to this line
  input  logic                  PTE_G,
  input  logic                  PTE_NAPOT,  // entry is in NAPOT mode (N bit set and PPN[3:0] = 1000)
  input  logic [2:0]            PageTypeWriteVal,
  input  logic                  TLBFlush,   // Flush this line (set valid to 0)
  output logic [2:0]            PageTypeRead,
  output logic                  Match
);

  // PageTypeRead is a key for a tera, giga, mega, or kilopage.
  // PageType == 3'b000 --> kilopage
  // PageType == 3'b001 --> megapage
  // PageType == 3'b010 --> gigapage
  // PageType == 3'b011 --> terapage
  // PageType == 3'b100 --> petapage
  // This entry has KEY_BITS for the key plus one valid bit.
  logic                Valid;
  logic [KEY_BITS-1:0] Key;
  logic [2:0]          PageType;

  // Split up key and query into sections for each page table level.
  logic [P.ASID_BITS-1:0] Key_ASID;
  logic [SEGMENT_BITS-1:0] Key0, Key1, Query0, Query1;
  logic MatchASID, MatchNAPOT, Match0, Match1, Match2, Match3, Match4;

  assign Key_ASID = Key[KEY_BITS-1:KEY_BITS-P.ASID_BITS];
  assign MatchASID = (SATP_ASID == Key_ASID) | PTE_G;

  // Calculate a match against a segment of the key based on the input vpn and the page type.
  // For example, a petapage in SV57 only cares about VPN[4], so VPN[0], VPN[1], VPN[2], and VPN[3]
  // should automatically match.

  // segment 0
  assign Key0   = Key[SEGMENT_BITS-1:0];
  assign Query0 = VPN[SEGMENT_BITS-1:0];
  // In Svnapot, if N bit is set and bottom 4 bits of PPN = 1000, then these bits don't need to match
  assign MatchNAPOT = P.SVNAPOT_SUPPORTED & PTE_NAPOT & (Query0[SEGMENT_BITS-1:4] == Key0[SEGMENT_BITS-1:4]);
  assign Match0 = (Query0 == Key0) | (PageType > 3'd0) | MatchNAPOT; // always match for megapage or larger

  // segment 1
  assign Key1   = Key[2*SEGMENT_BITS-1:SEGMENT_BITS];
  assign Query1 = VPN[2*SEGMENT_BITS-1:SEGMENT_BITS];
  assign Match1 = (Query1 == Key1) | (PageType > 3'd1); // always match for gigapage or larger

  if (P.SV39_SUPPORTED) begin : segment2
    logic [SEGMENT_BITS-1:0] Key2, Query2;
    assign Key2   = Key[3*SEGMENT_BITS-1:2*SEGMENT_BITS];
    assign Query2 = VPN[3*SEGMENT_BITS-1:2*SEGMENT_BITS];
    assign Match2 = (Query2 == Key2) | (PageType > 3'd2);  // always match for terapage or larger
  end else assign Match2 = 1'b1;

  if (P.SV48_SUPPORTED) begin : segment3
    logic [SEGMENT_BITS-1:0] Key3, Query3;
    assign Key3   = Key[4*SEGMENT_BITS-1:3*SEGMENT_BITS];
    assign Query3 = VPN[4*SEGMENT_BITS-1:3*SEGMENT_BITS];
    assign Match3 = (Query3 == Key3) | (PageType > 3'd3) | SV39Mode; // always match in SV39 mode or for petapage
  end else assign Match3 = 1'b1;

  if (P.SV57_SUPPORTED) begin : segment4
    logic [SEGMENT_BITS-1:0] Key4, Query4;
    assign Key4   = Key[5*SEGMENT_BITS-1:4*SEGMENT_BITS];
    assign Query4 = VPN[5*SEGMENT_BITS-1:4*SEGMENT_BITS];
    assign Match4 = (Query4 == Key4) | SV39Mode | SV48Mode; // always match in SV39/SV48 mode
  end else assign Match4 = 1'b1;

  assign Match = Match0 & Match1 & Match2 & Match3 & Match4 & MatchASID & Valid;

  // On a write, update the type of the page referred to by this line.
  flopenr #(3) pagetypeflop(clk, reset, WriteEnable, PageTypeWriteVal, PageType);
  assign PageTypeRead = PageType & {3{Match}};

  // On a write, set the valid bit high and update the stored key.
  // On a flush, zero the valid bit and leave the key unchanged.
  flopenr #(1) validbitflop(clk, reset, WriteEnable | TLBFlush, ~TLBFlush, Valid);
  flopenr #(KEY_BITS) keyflop(clk, reset, WriteEnable, {SATP_ASID, VPN}, Key);
endmodule
