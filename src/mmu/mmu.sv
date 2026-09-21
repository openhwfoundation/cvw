///////////////////////////////////////////
// mmu.sv
//
// Written: david_harris@hmc.edu and kmacsaigoren@hmc.edu 4 June 2021
// Modified:
//
// Purpose: Memory management unit, including TLB, PMA, PMP
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

module mmu import cvw::*;  #(parameter cvw_t P,
                             parameter TLB_ENTRIES = 8, IMMU = 0) (
  input  logic                 clk, reset,
  input  logic [P.XLEN-1:0]    SATP_REGW,          // Current value of satp CSR (from privileged unit)
  input  logic                 STATUS_MXR,         // Status CSR: make executable page readable
  input  logic                 STATUS_SUM,         // Status CSR: Supervisor access to user memory
  input  logic                 STATUS_MPRV,        // Status CSR: modify machine privilege
  input  logic [1:0]           STATUS_MPP,         // Status CSR: previous machine privilege level
  input  logic                 ENVCFG_PBMTE,       // Page-based memory types enabled
  input  logic                 ENVCFG_ADUE,        // HPTW A/D Update enable
  input  logic [1:0]           PrivilegeModeW,     // Current privilege level of the processeor
  input  logic                 DisableTranslation, // virtual address translation disabled during D$ flush and HPTW walk that use physical addresses
  input  logic [P.XLEN+1:0]    VAdr,               // virtual/physical address from IEU or physical address from HPTW
  input  logic [1:0]           Size,               // access size: 00 = 8 bits, 01 = 16 bits, 10 = 32 bits , 11 = 64 bits
  input  logic [P.XLEN-1:0]    PTE,                // page table entry
  input  logic [2:0]           PageTypeWriteVal,   // page type
  input  logic                 TLBWrite,           // write TLB entry
  input  logic                 TLBFlush,           // Invalidate all TLB entries
  output logic [P.PA_BITS-1:0] PhysicalAddress,    // PAdr when no translation, or translated VAdr (TLBPAdr) when there is translation
  output logic                 TLBMiss,            // Miss TLB
  output logic                 Cacheable,          // PMA indicates memory address is cacheable
  output logic                 Idempotent,         // PMA indicates memory address is idempotent
  output logic                 SelTIM,             // Select a tightly integrated memory
  // Faults
  output logic                 InstrAccessFaultF, LoadAccessFaultM, StoreAmoAccessFaultM, // access fault sources
  output logic                 InstrPageFaultF, LoadPageFaultM, StoreAmoPageFaultM,       // page fault sources
  output logic                 UpdateDA,                                                  // page fault due to setting dirty or access bit
  output logic                 LoadMisalignedFaultM, StoreAmoMisalignedFaultM,            // misaligned fault sources
  // PMA checker signals
  input  logic [3:0]           CMOpM,                                                     // Cache management instructions
  input  logic                 AtomicAccessM, ExecuteAccessF, WriteAccessM, ReadAccessM,  // access type
  input var logic [7:0]        PMPCFG_ARRAY_REGW[P.PMP_ENTRIES-1:0],                      // PMP configuration
  input var logic [P.PA_BITS-3:0] PMPADDR_ARRAY_REGW[P.PMP_ENTRIES-1:0]                   // PMP addresses
);

  logic [P.PA_BITS-1:0]        TLBPAdr;                  // physical address for TLB
  logic                        PMAInstrAccessFaultF;     // Instruction access fault from PMA
  logic                        PMPInstrAccessFaultF;     // Instruction access fault from PMP
  logic                        PMALoadAccessFaultM;      // Load access fault from PMA
  logic                        PMPLoadAccessFaultM;      // Load access fault from PMP
  logic                        PMAStoreAmoAccessFaultM;  // Store or AMO access fault from PMA
  logic                        PMPStoreAmoAccessFaultM;  // Store or AMO access fault from PMP
  logic                        DataMisalignedM;          // load or store misaligned
  logic                        Translate;                // Translation occurs when virtual memory is active and DisableTranslation is off
  logic                        TLBPageFault;             // Page fault from TLB
  logic                        ReadNoAmoAccessM;         // Read that is not part of atomic operation causes Load faults.  Otherwise StoreAmo faults
  logic [1:0]                  PBMemoryType;             // PBMT field of PTE during TLB hit, or 00 otherwise
  logic                        AtomicMisalignedCausesAccessFaultM; // Misaligned atomics are not handled by hardware even with ZICCLSM, so it throws an access fault instead of misaligned with ZICCLSM
  logic [1:0]                  EffectivePrivilegeModeW;  // Effective privilege mode accounting for MPRV
  logic                        MisalignedAllowedM;       // System can throw misaligned if ZICCLSM is not supported, or access is uncachable and TLB has found the entry.

  // Get Effective Privilege Mode
  // for DLB, when mstatus.MPRV=1, use mstatus.MPP rather than the current privilege mode
  assign EffectivePrivilegeModeW = IMMU ? PrivilegeModeW : (STATUS_MPRV ? STATUS_MPP : PrivilegeModeW);

  // only instantiate TLB if Virtual Memory is supported
  if (P.VIRTMEM_SUPPORTED) begin : tlb
    logic ReadAccess, WriteAccess;
    assign ReadAccess = ExecuteAccessF | ReadAccessM; // execute also acts as a TLB read.  Execute and Read are never active for the same MMU, so safe to mix pipestages
    assign WriteAccess = WriteAccessM;
    tlb #(.P(P), .TLB_ENTRIES(TLB_ENTRIES), .ITLB(IMMU)) tlb(
          .clk, .reset,
          .SATP_MODE(SATP_REGW[P.XLEN-1:P.XLEN-P.SVMODE_BITS]),
          .SATP_ASID(SATP_REGW[P.ASID_BASE+P.ASID_BITS-1:P.ASID_BASE]),
          .VAdr(VAdr[P.XLEN-1:0]), .STATUS_MXR, .STATUS_SUM, .STATUS_MPRV, .STATUS_MPP, .ENVCFG_PBMTE, .ENVCFG_ADUE,
          .EffectivePrivilegeModeW, .ReadAccess, .WriteAccess, .CMOpM,
          .DisableTranslation, .PTE, .PageTypeWriteVal,
          .TLBWrite, .TLBFlush, .TLBPAdr, .TLBMiss,
          .Translate, .TLBPageFault, .UpdateDA, .PBMemoryType);
  end else begin : tlb // just pass address through as physical
    assign Translate    = 1'b0;
    assign TLBMiss      = 1'b0;
    assign TLBPageFault = 1'b0;
    assign PBMemoryType = 2'b00;
    assign UpdateDA     = 1'b0;
    assign TLBPAdr      = '0;
  end

  // If translation is occurring, select translated physical address from TLB
  // the lower 12 bits are the page offset. These are never changed from the original
  // non translated address.
  mux2 #(P.PA_BITS-12) addressmux(VAdr[P.PA_BITS-1:12], TLBPAdr[P.PA_BITS-1:12], Translate, PhysicalAddress[P.PA_BITS-1:12]);
  assign PhysicalAddress[11:0] = VAdr[11:0];

  ///////////////////////////////////////////
  // Check physical memory accesses
  ///////////////////////////////////////////

  pmachecker #(P) pmachecker(.PhysicalAddress, .Size, .CMOpM,
    .AtomicAccessM, .ExecuteAccessF, .WriteAccessM, .ReadAccessM, .PBMemoryType,
    .Cacheable, .Idempotent, .SelTIM,
    .PMAInstrAccessFaultF, .PMALoadAccessFaultM, .PMAStoreAmoAccessFaultM);

  if (P.PMP_ENTRIES > 0) begin : pmp
    pmpchecker #(P) pmpchecker(.PhysicalAddress, .EffectivePrivilegeModeW,
      .PMPCFG_ARRAY_REGW, .PMPADDR_ARRAY_REGW,
      .ExecuteAccessF, .WriteAccessM, .ReadAccessM, .Size, .CMOpM,
      .PMPInstrAccessFaultF, .PMPLoadAccessFaultM, .PMPStoreAmoAccessFaultM);
  end else begin
    assign PMPInstrAccessFaultF     = 1'b0;
    assign PMPStoreAmoAccessFaultM  = 1'b0;
    assign PMPLoadAccessFaultM      = 1'b0;
  end

  assign ReadNoAmoAccessM  = ReadAccessM & ~WriteAccessM;// AMO causes StoreAmo rather than Load fault

  // Misaligned faults
  always_comb // exclusion-tag: immu-wordaccess
    case(Size)
      2'b00:  DataMisalignedM = 1'b0;              // lb, sb, lbu
      2'b01:  DataMisalignedM = VAdr[0];           // lh, sh, lhu
      2'b10:  DataMisalignedM = VAdr[1] | VAdr[0]; // lw, sw, flw, fsw, lwu
      2'b11:  DataMisalignedM = |VAdr[2:0];        // ld, sd, fld, fsd
    endcase

  // When ZICCLSM_SUPPORTED, misaligned cacheable loads and stores are handled in hardware so they do not throw a misaligned fault
  // When ZICCLSM_SUPPORTED, misaligned uncachable accesses are lower priority than page and access faults, so must wait for TLB to resolve
  // When ZICCLSM is not supported, misaligned accesses always fault, with higher priority than access or page fault
  assign MisalignedAllowedM       = ~P.ZICCLSM_SUPPORTED | (~Cacheable & ~TLBMiss); // should a misaligned access fault?
  assign LoadMisalignedFaultM     = DataMisalignedM & ReadNoAmoAccessM & MisalignedAllowedM;
  assign StoreAmoMisalignedFaultM = DataMisalignedM & WriteAccessM & MisalignedAllowedM; // Store and AMO both assert WriteAccess

  // a misaligned Atomic causes an access fault rather than a misaligned fault if a misaligned load/store is handled in hardware
  // this is subtle - see privileged spec 3.6.3.3
  assign AtomicMisalignedCausesAccessFaultM = DataMisalignedM & AtomicAccessM & (P.ZICCLSM_SUPPORTED & Cacheable);

  // Access faults
  // If TLB miss and translating we want to not have faults from the PMA and PMP checkers.
  assign InstrAccessFaultF    = (PMAInstrAccessFaultF    | PMPInstrAccessFaultF)    & ~TLBMiss;
  assign LoadAccessFaultM     = (PMALoadAccessFaultM     | PMPLoadAccessFaultM     | AtomicMisalignedCausesAccessFaultM & ReadNoAmoAccessM)     & ~TLBMiss;
  assign StoreAmoAccessFaultM = (PMAStoreAmoAccessFaultM | PMPStoreAmoAccessFaultM | AtomicMisalignedCausesAccessFaultM & WriteAccessM) & ~TLBMiss;

  // Specify which type of page fault is occurring
  assign InstrPageFaultF    = TLBPageFault & ExecuteAccessF;
  assign LoadPageFaultM     = TLBPageFault & ReadNoAmoAccessM;
  assign StoreAmoPageFaultM = TLBPageFault & (WriteAccessM | (|CMOpM));
endmodule
