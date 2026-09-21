///////////////////////////////////////////
// tlbmixer.sv
//
// Written: David Harris and kmacsaigoren@hmc.edu 7 June 2021
// Modified:
//
//
// Purpose: Takes two page numbers and replaces segments of the first page
//          number with segments from the second, based on the page type.
//          NOTE: this DOES NOT include the 12 bit offset, which is the same no matter the translation mode or page type.
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

module tlbmixer import cvw::*;  #(parameter cvw_t P) (
  input  logic [P.VPN_BITS-1:0] VPN,
  input  logic [P.PPN_BITS-1:0] PPN,
  input  logic [2:0]            HitPageType,
  input  logic [11:0]           Offset,
  input  logic                  TLBHit,
  input  logic                  PTE_N,         // NAPOT page table entry
  output logic [P.PA_BITS-1:0]  TLBPAdr
);

  localparam EXTRA_BITS = P.PPN_BITS - P.VPN_BITS;
  logic [P.PPN_BITS-1:0] ZeroExtendedVPN;
  logic [P.PPN_BITS-1:0] PageNumberMask;
  logic [P.PPN_BITS-1:0] PPNMixed, PPNMixed2;

  // produce PageNumberMask with 1s where virtual page number bits should be untranslaetd for superpages
  if (P.XLEN == 32)
    // kilopage: 22 bits of PPN, 0 bits of VPN
    // megapage: 12 bits of PPN, 10 bits of VPN
    mux2 #(22) pnm(22'h000000, 22'h0003FF, HitPageType[0], PageNumberMask);
  else
    if (P.SV57_SUPPORTED)
      // petapage: 8  bits of PPN, 36 bits of VPN
      // terapage: 17 bits of PPN, 27 bits of VPN
      // gigapage: 26 bits of PPN, 18 bits of VPN
      // megapage: 35 bits of PPN, 9 bits of VPN
      // kilopage: 44 bits of PPN, 0 bits of VPN
      mux5 #(44) pnm(44'h00000000000, 44'h000000001FF, 44'h0000003FFFF, 44'h00007FFFFFF,44'h00FFFFFFFFF, HitPageType, PageNumberMask);
    else if (P.SV48_SUPPORTED)
      // terapage: 17 bits of PPN, 27 bits of VPN
      // gigapage: 26 bits of PPN, 18 bits of VPN
      // megapage: 35 bits of PPN, 9 bits of VPN
      // kilopage: 44 bits of PPN, 0 bits of VPN
      mux4 #(44) pnm(44'h00000000000, 44'h000000001FF, 44'h0000003FFFF, 44'h00007FFFFFF, HitPageType[1:0], PageNumberMask);
    else // SV39 only
      // gigapage: 26 bits of PPN, 18 bits of VPN
      // megapage: 35 bits of PPN, 9 bits of VPN
      // kilopage: 44 bits of PPN, 0 bits of VPN
      mux3 #(44) pnm(44'h00000000000, 44'h000000001FF, 44'h0000003FFFF, HitPageType[1:0], PageNumberMask);

  // merge low segments of VPN with high segments of PPN decided by the pagetype.
  if (P.PPN_BITS > P.VPN_BITS)
    assign ZeroExtendedVPN = {{EXTRA_BITS{1'b0}}, VPN}; // forces the VPN to be the same width as PPN.
  else
    assign ZeroExtendedVPN = VPN[P.PPN_BITS-1:0];

  assign PPNMixed = PPN | ZeroExtendedVPN & PageNumberMask; // low bits of PPN are already zero

  // In Svnapot, when N=1, use bottom bits of VPN for contiugous translations
  if (P.SVNAPOT_SUPPORTED) begin
    // 64 KiB contiguous NAPOT translations supported
    logic [3:0] PPNMixedBot;
    mux2 #(4) napotmux(PPNMixed[3:0], VPN[3:0], PTE_N, PPNMixedBot);
    assign PPNMixed2 = {PPNMixed[P.PPN_BITS-1:4], PPNMixedBot};

    /* // Generalized NAPOT implementation supporting various sized contiguous regions
    // This would also require a priority encoder in the tlbcam
    // Not yet tested
    logic [8:0] NAPOTMask, NAPOTPN, PPNMixedBot;
    always_comb begin
      casez(PPN[8:0])
        9'b100000000: NAPOTMask = 9'b111111111;
        9'b?10000000: NAPOTMask = 9'b011111111;
        9'b??1000000: NAPOTMask = 9'b001111111;
        9'b???100000: NAPOTMask = 9'b000111111;
        9'b????10000: NAPOTMask = 9'b000011111;
        9'b?????1000: NAPOTMask = 9'b000001111;
        9'b??????100: NAPOTMask = 9'b000000111;
        9'b???????10: NAPOTMask = 9'b000000011;
        9'b????????1: NAPOTMask = 9'b000000001;
        default:      NAPOTMask = 9'b000000000;
      endcase
    end
    // check malformed NAPOT PPN, which should cause page fault
    // Replace PPN with VPN in lower bits of page number based on mask
    assign NAPOTPN = VPN & NAPOTMask | PPN & ~NAPOTMask;
    mux2 #(9) napotmux(PPNMixed[8:0], NAPOTPN, PTE_N, PPNMixedBot);
    assign PPNMixed2 = {PPNMixed[PPN_BITS-1:9], PPNMixedBot}; */

  end else begin // no Svnapot
    assign PPNMixed2 = PPNMixed;
  end

  // Output the hit physical address if translation is currently on.
  // Provide physical address of zero if not TLBHits, to cause segmentation error if miss somehow percolated through signal
  assign TLBPAdr = TLBHit ? {PPNMixed2, Offset} : 0;

endmodule
