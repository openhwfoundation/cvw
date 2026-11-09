///////////////////////////////////////////
// mmu.sv
//
// Written:  David Harris David_Harris@hmc.edu, Kip Macsai-Goren kmacsaigoren@hmc.edu 4 June 2021
// Modified: Rose Thompson, Muhammad Zain
//
// Purpose: Memory management unit: TLB, PMA, and PMP checks.
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

module mmu import cvw::*; #(parameter cvw_t P,
                            parameter TLB_ENTRIES = 8, IMMU = 0) (
  input  logic                     clk, reset,
  input  logic [P.XLEN-1:0]        SATP_REGW,          // Current value of satp CSR (from privileged unit)
  input  logic                     STATUS_MXR,         // Status CSR: make executable page readable
  input  logic                     STATUS_SUM,         // Status CSR: Supervisor access to user memory
  input  logic                     STATUS_MPRV,        // Status CSR: modify machine privilege
  input  logic [1:0]               STATUS_MPP,         // Status CSR: previous machine privilege level
  input  logic                     ENVCFG_PBMTE,       // Page-based memory types enabled
  input  logic                     ENVCFG_ADUE,        // HPTW A/D Update enable
  input  logic [1:0]               MSECCFG_PMM,        // Pointer mask config bits from CSR
  input  logic [1:0]               MENVCFG_PMM,        // Pointer mask config bits from CSR
  input  logic [1:0]               SENVCFG_PMM,        // Pointer mask config bits from CSR
  input  logic [1:0]               MemRWM,             // Memory stage memory read/write decode for pointermask control
  input  logic [3:0]               CMOpMUngated,       // Ungated CMOpM used to apply pointer mask
  input  logic [1:0]               PrivilegeModeW,     // Current privilege level of the processor
  input  logic                     DisableTranslation, // virtual address translation disabled during D$ flush and HPTW walk that use physical addresses
  input  logic [P.XLEN+1:0]        VAdr,               // virtual/physical address from IEU or physical address from HPTW
  input  logic [2:0]               Size,               // access size: 000 = 8 bits, 001 = 16 bits, 010 = 32 bits, 011 = 64 bits, 100 = 128 bits
  input  logic [P.XLEN-1:0]        PTE,                // page table entry
  input  logic [2:0]               PageTypeWriteVal,   // page type
  input  logic                     TLBWrite,           // write TLB entry
  input  logic                     TLBFlush,           // Invalidate all TLB entries (ASID-specific preserves global)
  input  logic                     TLBFlushAll,        // sfence.vma rs2 = x0: flush every ASID and global (G=1) entries too
  input  logic                     TLBFlushVA,         // sfence.vma rs1 != x0: flush only entries whose page holds VAdr
  input  logic [P.ASID_BITS-1:0]   TLBFlushASID,       // sfence.vma rs2 ASID
  output logic [P.PA_BITS-1:0]     PhysicalAddress,    // PAdr when no translation, or translated VAdr (TLBPAdr) when there is translation
  output logic                     TLBMiss,            // Miss TLB
  output logic                     Cacheable,          // PMA indicates memory address is cacheable
  output logic                     Idempotent,         // PMA indicates memory address is idempotent
  output logic                     SelTIM,             // Select a tightly integrated memory
  // Faults
  output logic                     InstrAccessFaultF, LoadAccessFaultM, StoreAmoAccessFaultM, // access fault sources
  output logic                     InstrPageFaultF, LoadPageFaultM, StoreAmoPageFaultM,       // page fault sources
  output logic                     UpdateDA,                                                  // TLB hit needs to set the dirty or access bit
  output logic                     LoadMisalignedFaultM, StoreAmoMisalignedFaultM,            // misaligned fault sources
  // PMA checker signals
  input  logic [3:0]               CMOpM,                                                     // Cache management instructions
  input  logic                     AtomicAccessM, ExecuteAccessF, WriteAccessM, ReadAccessM,  // access type
  input  var logic [7:0]           PMPCFG_ARRAY_REGW[P.PMP_ENTRIES-1:0],                      // PMP configuration
  input  var logic [P.PA_BITS-3:0] PMPADDR_ARRAY_REGW[P.PMP_ENTRIES-1:0],                     // PMP addresses
  output logic                     PointerMaskApplicable, PMLen16Sel                          // Pointer masking signals
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
  logic                        MisalignedCausesAccessFaultM; // Misaligned access throws an access fault instead of a misaligned fault
  logic                        CrossesGranuleM;          // Misaligned access crosses a 16-byte boundary, so Zama16b does not make it atomic
  logic [1:0]                  EffectivePrivilegeModeW;  // Effective privilege mode accounting for MPRV
  logic                        MisalignedFaultAllowedM;  // System can throw misaligned if ZICCLSM is not supported, or access is uncachable, idempotent, and TLB has found the entry.
  logic                        PAOutOfRange;             // Untranslated address has nonzero bits above PA_BITS
  logic [P.XLEN+1:0]           MaskedVAdr;               // VAdr with pointer masking applied (PMLEN 16 configurations)

  // Get Effective Privilege Mode
  // for DTLB, when mstatus.MPRV=1, use mstatus.MPP rather than the current privilege mode
  assign EffectivePrivilegeModeW = IMMU ? PrivilegeModeW : (STATUS_MPRV ? STATUS_MPP : PrivilegeModeW);
  // Pointer masking applies only to data accesses
  if (P.ZPM_SUPPORTED & ~IMMU) begin : pm
    pointermask #(P) pointermask(.MSECCFG_PMM, .MENVCFG_PMM, .SENVCFG_PMM, .EffectivePrivilegeModeW,
                                .STATUS_MXR, .MemRWM, .CMOpMUngated, .PointerMaskApplicable, .PMLen16Sel);
  end else begin
    assign PointerMaskApplicable = 1'b0;
    assign PMLen16Sel            = 1'b0;
  end

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
          .TLBWrite, .TLBFlush, .TLBFlushAll, .TLBFlushVA, .TLBFlushASID, .PointerMaskApplicable,
          .PMLen16Sel, .TLBPAdr, .TLBMiss,
          .Translate, .TLBPageFault, .UpdateDA, .PBMemoryType);
  end else begin : notlb // just pass address through as physical
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
  // With PMLEN 16, the masked bits include physical address bits, so an untranslated address that pointer
  // masking applies to is zero extended from bit 47 (PMLEN 16) or 56 (PMLEN 7).  Without PMLEN 16, the masked
  // bits are all above PA_BITS, so only the PAOutOfRange check below needs to ignore them.
  // Page-table walks and D$ flushes (DisableTranslation) are implicit accesses, which pointer masking does not apply to.
  /*
  if (P.XLEN == 64 & P.ZPM_SUPPORTED & P.PMLEN16_SUPPORTED)
    assign MaskedVAdr = (PointerMaskApplicable & ~DisableTranslation) ? (PMLen16Sel ? {18'b0, VAdr[47:0]} : {9'b0, VAdr[56:0]}) : VAdr;
  else
    assign MaskedVAdr = VAdr;
  */
  mux2 #(P.PA_BITS-12) addressmux(VAdr[P.PA_BITS-1:12], TLBPAdr[P.PA_BITS-1:12], Translate, PhysicalAddress[P.PA_BITS-1:12]);
  assign PhysicalAddress[11:0] = VAdr[11:0];

  // An untranslated address is a physical address, so bits XLEN-1:PA_BITS must be zero.  Otherwise it is outside
  // the physical address space rather than an alias of a lower address, and the PMA checker raises an access fault.
  // Translated addresses come from the PPN and always fit; RV32 addresses are narrower than PA_BITS.
  // With pointer masking, the masked bits are ignored: with PMLEN 16 MaskedVAdr is already zero extended, and
  // with PMLEN 7 only bits 56:PA_BITS are checked when the mask applies.
  if (P.XLEN > P.PA_BITS) begin
    //if (P.ZPM_SUPPORTED & ~P.PMLEN16_SUPPORTED & ~IMMU) assign PAOutOfRange = ~Translate & (PointerMaskApplicable ? |VAdr[56:P.PA_BITS] : |VAdr[P.XLEN-1:P.PA_BITS]);
                                                        assign PAOutOfRange = ~Translate & (|VAdr[P.XLEN-1:P.PA_BITS]);
  end else                                              assign PAOutOfRange = 1'b0;

  ///////////////////////////////////////////
  // Check physical memory accesses
  ///////////////////////////////////////////

  pmachecker #(P) pmachecker(.PhysicalAddress, .PAOutOfRange, .Size, .CMOpM,
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

  assign ReadNoAmoAccessM = ReadAccessM & ~WriteAccessM; // AMO causes StoreAmo rather than Load fault

  // Misaligned faults
  always_comb // exclusion-tag: immu-wordaccess
    case (Size)
      3'b000:  begin DataMisalignedM = 1'b0;              CrossesGranuleM = 1'b0;        end // lb, sb, lbu // exclusion-tag: mmu-size-byte
      3'b001:  begin DataMisalignedM = VAdr[0];           CrossesGranuleM = &VAdr[3:1];  end // lh, sh, lhu // exclusion-tag: mmu-size-half
      3'b010:  begin DataMisalignedM = VAdr[1] | VAdr[0]; CrossesGranuleM = &VAdr[3:2];  end // lw, sw, flw, fsw, lwu
      3'b011:  begin DataMisalignedM = |VAdr[2:0];        CrossesGranuleM = VAdr[3];     end // ld, sd, fld, fsd // exclusion-tag: mmu-size-double
      3'b100:  begin DataMisalignedM = |VAdr[3:0];        CrossesGranuleM = 1'b1;        end // flq, fsq, amocas.q: a misaligned 16-byte access always crosses // exclusion-tag: mmu-size-quad
      default: begin DataMisalignedM = 1'b0;              CrossesGranuleM = 1'b0;        end // no other sizes exist
    endcase

  // When ZICCLSM_SUPPORTED, misaligned cacheable loads and stores are handled in hardware so they do not throw a misaligned fault
  // When ZICCLSM_SUPPORTED, misaligned uncachable accesses are lower priority than page and access faults, so must wait for TLB to resolve
  // When ZICCLSM_SUPPORTED, misaligned atomics take an access fault instead (below), whatever the region
  // When ZICCLSM is not supported, misaligned accesses always fault, with higher priority than access or page fault
  assign MisalignedFaultAllowedM  = ~P.ZICCLSM_SUPPORTED | (~Cacheable & ~TLBMiss & Idempotent & ~AtomicAccessM); // should a misaligned access fault?
  assign LoadMisalignedFaultM     = DataMisalignedM & ReadNoAmoAccessM & MisalignedFaultAllowedM;
  assign StoreAmoMisalignedFaultM = DataMisalignedM & WriteAccessM & MisalignedFaultAllowedM; // Store and AMO both assert WriteAccess

  // A misaligned access causes an access fault rather than a misaligned fault when a misaligned load/store is
  // handled in hardware and either the access is atomic, which is not handled in hardware (except as Zama16b
  // allows below) and must not be emulated (privileged spec 3.6.3.3), or the region is non-idempotent, where the
  // spec recommends an access fault so software does not emulate the access with multiple smaller accesses that
  // could have side effects.
  // Zama16b excuses a misaligned AMO (which both reads and writes) to cacheable memory that stays within a naturally
  // aligned 16-byte granule; it does not cover LR/SC, so a misaligned LR or SC still faults
  assign MisalignedCausesAccessFaultM = DataMisalignedM & P.ZICCLSM_SUPPORTED &
                                        ((AtomicAccessM & ~(P.ZAMA16B_SUPPORTED & Cacheable & ReadAccessM & WriteAccessM & ~CrossesGranuleM)) | ~Idempotent);

  // Access faults
  // If TLB miss and translating we want to not have faults from the PMA and PMP checkers.
  assign InstrAccessFaultF    = (PMAInstrAccessFaultF    | PMPInstrAccessFaultF)    & ~TLBMiss; // exclusion-tag: mmu-instr-fault
  assign LoadAccessFaultM     = (PMALoadAccessFaultM     | PMPLoadAccessFaultM     | MisalignedCausesAccessFaultM & ReadNoAmoAccessM)     & ~TLBMiss; // exclusion-tag: mmu-load-fault
  assign StoreAmoAccessFaultM = (PMAStoreAmoAccessFaultM | PMPStoreAmoAccessFaultM | MisalignedCausesAccessFaultM & WriteAccessM) & ~TLBMiss; // exclusion-tag: mmu-store-fault

  // Specify which type of page fault is occurring
  assign InstrPageFaultF    = TLBPageFault & ExecuteAccessF;
  assign LoadPageFaultM     = TLBPageFault & ReadNoAmoAccessM;
  assign StoreAmoPageFaultM = TLBPageFault & (WriteAccessM | (|CMOpM));
endmodule
