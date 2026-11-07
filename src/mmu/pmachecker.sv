///////////////////////////////////////////
// pmachecker.sv
//
// Written:  Thomas Fleming tfleming@hmc.edu, Jessica Torrey jtorrey@hmc.edu 20 April 2021
// Modified: David Harris, Rose Thompson, Muhammad Zain
//
// Purpose: Physical memory attribute checker.
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

module pmachecker import cvw::*; #(parameter cvw_t P) (
  input  logic [P.PA_BITS-1:0] PhysicalAddress,
  input  logic                 PAOutOfRange,   // Untranslated address has nonzero bits above PA_BITS
  input  logic [2:0]           Size,           // access size: 000 = 8 bits, 001 = 16 bits, 010 = 32 bits, 011 = 64 bits, 100 = 128 bits
  input  logic [3:0]           CMOpM,
  input  logic                 AtomicAccessM,  // Atomic access
  input  logic                 ExecuteAccessF, // Execute access
  input  logic                 WriteAccessM,   // Write access
  input  logic                 ReadAccessM,    // Read access
  input  logic [1:0]           PBMemoryType,   // PBMT field of PTE during TLB hit, or 00 otherwise
  output logic                 Cacheable, Idempotent, SelTIM,
  output logic                 PMAInstrAccessFaultF,
  output logic                 PMALoadAccessFaultM,
  output logic                 PMAStoreAmoAccessFaultM
);

  localparam logic [2:0]       AHBWSIZE = 3'($clog2(P.AHBW/8)); // bus width as an access size

  logic                        PMAAccessFault, PMADataAccessFault;
  logic                        AccessRW, AccessRWXC, AccessRX;
  logic [12:0]                 SelRegions;
  logic                        AtomicAllowed;
  logic                        CacheableRegion, IdempotentRegion;
  logic                        SelExtIO, SelExtMem;

  // Determine what type of access is being made
  assign AccessRW  = ReadAccessM | WriteAccessM; // exclusion-tag: pma-access-rw
  assign AccessRWXC = ReadAccessM | WriteAccessM | ExecuteAccessF | (|CMOpM);
  assign AccessRX  = ReadAccessM | ExecuteAccessF; // exclusion-tag: pma-access-rx

  // Determine which region of physical memory (if any) is being accessed
  // SelRegions: 0 none, 1 DTIM, 2 IROM, 3 EXT_MEM, 4 BOOTROM, 5 UNCORE_RAM, 6 CLINT, 7 GPIO, 8 UART, 9 PLIC, 10 SDC, 11 SPI, 12 PWM
  adrdecs #(P) adrdecs(PhysicalAddress, AccessRW, AccessRX, AccessRWXC, Size[1:0], SelRegions);

  // Optional I/O window inside EXT_MEM (e.g. control registers of an external
  // peripheral): still decoded and routed as EXT_MEM, but not cacheable, not
  // idempotent, not atomic and not executable.
  adrdec #(P.PA_BITS) extiodec(PhysicalAddress, P.EXT_IO_BASE[P.PA_BITS-1:0], P.EXT_IO_RANGE[P.PA_BITS-1:0], P.EXT_IO_SUPPORTED, AccessRWXC, Size[1:0], 4'b1111, SelExtIO);
  assign SelExtMem = SelRegions[3] & ~SelExtIO; // exclusion-tag: sel-ext-mem

  // Only non-core RAM/ROM memory regions are cacheable. PBMT can override cacheable; NC and IO are uncachable
  assign CacheableRegion = SelExtMem | SelRegions[4] | SelRegions[5];  // exclusion-tag: unused-cacheable
  assign Cacheable = (PBMemoryType == 2'b00) ? CacheableRegion : 1'b0;

  // Non-idempotent means access could have side effect and must not be done speculatively or redundantly
  // I/O is nonidempotent.  PBMT can override PMA; NC is idempotent and IO is non-idempotent
  assign IdempotentRegion = SelRegions[1] | SelRegions[2] | SelExtMem | SelRegions[4] | SelRegions[5];
  assign Idempotent = (PBMemoryType == 2'b00) ? IdempotentRegion : (PBMemoryType == 2'b01);

  // Atomic operations are only allowed on RAM
  assign AtomicAllowed = SelRegions[1] | SelExtMem | SelRegions[5]; // exclusion-tag: unused-atomic
  // Check if tightly integrated memories are selected
  assign SelTIM = SelRegions[1] | SelRegions[2]; // exclusion-tag: unused-tim

  // Detect access faults.  An address outside the physical address space selects no region.
  // A fetch from the I/O window faults, so the IFU never reads it, not even on a wrong path.
  assign PMAAccessFault          = (SelRegions[0] | PAOutOfRange) & AccessRWXC | AtomicAccessM & ~AtomicAllowed | ExecuteAccessF & SelExtIO; // exclusion-tag: pma-access-fault
  assign PMAInstrAccessFaultF    = ExecuteAccessF & PMAAccessFault; // exclusion-tag: pma-instr-fault
  // An uncached access is a single bus transfer, so an access wider than the bus (fld/fsd on RV32, flq/fsq) may
  // access only cacheable memory: not an I/O region, a TIM, or a Svpbmt NC or IO page
  if (P.LLEN > P.AHBW) assign PMADataAccessFault = PMAAccessFault | (Size > AHBWSIZE) & ~Cacheable;
  else                 assign PMADataAccessFault = PMAAccessFault;
  assign PMALoadAccessFaultM     = ReadAccessM & ~WriteAccessM & PMADataAccessFault; // exclusion-tag: pma-load-fault
  assign PMAStoreAmoAccessFaultM = (WriteAccessM | (|CMOpM))   & PMADataAccessFault; // exclusion-tag: pma-store-fault
endmodule
