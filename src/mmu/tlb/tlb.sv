///////////////////////////////////////////
// tlb.sv
//
// Written: jtorrey@hmc.edu 16 February 2021
// Modified: kmacsaigoren@hmc.edu 1 June 2021
//            Implemented SV48 on top of SV39. This included adding the SvMode signal,
//            and using it to decide the translate signal and get the virtual page number
//
// Purpose: Translation lookaside buffer
//          Cache of virtural-to-physical address translations
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

/**
 * SV32 specs
 * ----------
 * Virtual address [31:0] (32 bits)
 *    [________________________________]
 *     |--VPN1--||--VPN0--||----OFF---|
 *         10        10         12
 *
 * Physical address [33:0] (34 bits)
 *  [__________________________________]
 *   |---PPN1---||--PPN0--||----OFF---|
 *        12         10         12
 *
 * Page Table Entry [31:0] (32 bits)
 *    [________________________________]
 *     |---PPN1---||--PPN0--|||DAGUXWRV
 *          12         10    ^^
 *                         RSW(2) -- for OS
 */

// The TLB will have 2**ENTRY_BITS total entries
module tlb import cvw::*;  #(parameter cvw_t P,
                             parameter TLB_ENTRIES = 8, ITLB = 0) (
  input logic                      clk, reset,
  input  logic [P.SVMODE_BITS-1:0] SATP_MODE,        // Current address translation mode
  input  logic [P.ASID_BITS-1:0]   SATP_ASID,
  input  logic                     STATUS_MXR, STATUS_SUM, STATUS_MPRV,
  input  logic [1:0]               STATUS_MPP,
  input  logic                     ENVCFG_PBMTE,     // Page-based memory types enabled
  input  logic                     ENVCFG_ADUE,      // HPTW A/D Update enable
  input  logic [1:0]               EffectivePrivilegeModeW,   // Current privilege level of the processeor, accounting for mstatus.MPRV
  input  logic                     ReadAccess,
  input  logic                     WriteAccess,
  input  logic [3:0]               CMOpM,
  input  logic                     DisableTranslation,
  input  logic [P.XLEN-1:0]        VAdr,             // address input before translation (could be physical or virtual)
  input  logic [P.XLEN-1:0]        PTE,              // page table entry to write
  input  logic [2:0]               PageTypeWriteVal,
  input  logic                     TLBWrite,
  input  logic                     TLBFlush,
  output logic [P.PA_BITS-1:0]     TLBPAdr,
  output logic                     TLBMiss,
  output logic                     Translate,
  output logic                     TLBPageFault,
  output logic                     UpdateDA,
  output logic [1:0]               PBMemoryType     // PBMT field of PTE during TLB hit, or 00 otherwise
);

  logic [TLB_ENTRIES-1:0]         Matches, WriteEnables, PTE_Gs, PTE_NAPOTs; // used as the one-hot encoding of WriteIndex
  // Sections of the virtual and physical addresses
  logic [P.VPN_BITS-1:0]          VPN;
  logic [P.PPN_BITS-1:0]          PPN;
  // Sections of the page table entry
  logic [11:0]                    PTEAccessBits;
  logic [2:0]                     HitPageType;
  logic                           CAMHit;
  logic                           TLBHit;
  logic                           SV39Mode;
  logic                           SV48Mode;
  logic                           Misaligned;
  logic                           MegapageMisaligned;
  logic                           PTE_N;         // NAPOT page table entry
  logic                           NAPOT4;        // pte.ppn[3:0] = 1000, indicating 64 KiB continuous NAPOT region

  if(P.XLEN == 32) begin
    assign MegapageMisaligned = |(PPN[9:0]); // must have zero PPN0
    assign Misaligned = (HitPageType == 3'b001) & MegapageMisaligned;
  end else begin // 64-bit
    logic  GigapageMisaligned, TerapageMisaligned, PetapageMisaligned;
    assign PetapageMisaligned = |(PPN[35:0]) & P.SV57_SUPPORTED;  // must have zero PPN3, PPN2, PPN1, PPN0
    assign TerapageMisaligned = |(PPN[26:0]) & P.SV48_SUPPORTED;  // must have zero PPN2, PPN1, PPN0
    assign GigapageMisaligned = |(PPN[17:0]);                     // must have zero PPN1 and PPN0
    assign MegapageMisaligned = |(PPN[8:0]);                      // must have zero PPN0
    assign Misaligned =
              ((HitPageType == 3'b100) & PetapageMisaligned) |
              ((HitPageType == 3'b011) & TerapageMisaligned) |
              ((HitPageType == 3'b010) & GigapageMisaligned) |
              ((HitPageType == 3'b001) & MegapageMisaligned);
  end

  assign VPN = VAdr[P.VPN_BITS+11:12];
  assign NAPOT4 = (PPN[3:0] == 4'b1000); // 64 KiB contiguous region with pte.napot_bits = 4

  tlbcontrol #(P, ITLB) tlbcontrol(.SATP_MODE, .VAdr, .STATUS_MXR, .STATUS_SUM, .STATUS_MPRV, .STATUS_MPP, .ENVCFG_PBMTE, .ENVCFG_ADUE,
    .EffectivePrivilegeModeW, .ReadAccess, .WriteAccess, .CMOpM, .DisableTranslation,
    .PTEAccessBits, .CAMHit, .Misaligned, .NAPOT4,
    .TLBMiss, .TLBHit, .TLBPageFault,
    .UpdateDA, .SV39Mode, .SV48Mode, .Translate, .PTE_N, .PBMemoryType);

  tlblru #(TLB_ENTRIES) lru(.clk, .reset, .TLBWrite, .Matches, .TLBHit, .WriteEnables);
  tlbcam #(P, TLB_ENTRIES, P.VPN_BITS + P.ASID_BITS, P.VPN_SEGMENT_BITS)
    tlbcam(.clk, .reset, .VPN, .PageTypeWriteVal, .SV39Mode, .SV48Mode, .TLBFlush, .WriteEnables, .PTE_Gs, .PTE_NAPOTs,
           .SATP_ASID, .Matches, .HitPageType, .CAMHit);
  tlbram #(P, TLB_ENTRIES) tlbram(.clk, .reset, .PTE, .Matches, .WriteEnables, .PPN, .PTEAccessBits, .PTE_Gs, .PTE_NAPOTs);

  // Replace segments of the virtual page number with segments of the physical
  // page number. For 4 KB pages, the entire virtual page number is replaced.
  // For superpages, some segments are considered offsets into a larger page.
  tlbmixer #(P) Mixer(.VPN, .PPN, .HitPageType, .Offset(VAdr[11:0]), .TLBHit, .PTE_N, .TLBPAdr);

endmodule
