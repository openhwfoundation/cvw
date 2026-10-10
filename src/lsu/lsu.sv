/////////////////////////////////////////////////////////////////////////////////////////////////////////
// lsu.sv
//
// Written: David_Harris@hmc.edu, rose@rosethompson.net
// Created: 9 January 2021
// Modified: 11 January 2023
//
// Purpose: Load/Store Unit
//          HPTW, DMMU, data cache, interface to external bus
//          Atomic, Endian swap, and subword read/write logic
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
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
/////////////////////////////////////////////////////////////////////////////////////////////////////////

module lsu import cvw::*;  #(parameter cvw_t P) (
  input  logic                    clk, reset,                           // Clock and reset
  input  logic                    StallM, FlushM, StallW, FlushW,       // Stall and flush Memory and Writeback stages
  output logic                    LSUStallM,                            // LSU stalls pipeline during a multicycle operation
  // connected to cpu (controls)
  input  logic [1:0]              MemRWE,                               // Memory read/write control in Execute stage: [1] read, [0] write
  input  logic [1:0]              MemRWM,                               // Memory read/write control in Memory stage: [1] read, [0] write
  input  logic [2:0]              Funct3M,                              // funct3 field of instruction in Memory stage
  input  logic [6:0]              Funct7M,                              // funct7 field of instruction in Memory stage
  input  logic [1:0]              AtomicM,                              // Atomic memory operation: 10 AMO, 01 LR/SC
  input  logic                    FlushDCacheM,                         // Flush D cache to next level of memory
  input  logic [3:0]              CMOpM,                                // Cache management operation: 1 cbo.inval, 2 cbo.clean, 4 cbo.flush, 8 cbo.zero
  input  logic                    LSUPrefetchM,                         // Data prefetch (presently unused)
  output logic                    CommittedM,                           // Delay interrupts while memory operation in flight
  output logic                    SquashSCW,                            // Store conditional failed; do not write the register file
  output logic                    DCacheMiss,                           // D$ miss, for performance counters
  output logic                    DCacheAccess,                         // D$ access, for performance counters
  // address and write data
  input  logic [P.XLEN-1:0]       IEUAdrE,                              // Memory address or branch/jump target in Execute stage
  output logic [P.XLEN-1:0]       IEUAdrM,                              // Memory address or branch/jump target in Memory stage
  input  logic [P.XLEN-1:0]       WriteDataM,                           // Write data from IEU
  output logic [P.LLEN-1:0]       ReadDataW,                            // Read data from memory in Writeback stage
  // cpu privilege
  input  logic [1:0]              PrivilegeModeW,                       // Current privilege mode
  input  logic                    BigEndianM,                           // Memory access is big-endian
  input  logic                    sfencevmaM,                           // sfence.vma: invalidate TLB entries
  input  logic                    sfencevmaAllM,                        // sfence.vma with rs2=x0: flush all TLB entries including global
  output logic                    DCacheStallM,                         // D$ busy with multicycle operation
  output logic [P.XLEN-1:0]       IEUAdrxTvalM,                         // IEUAdrM, or the address of the spilled half for xtval
  // fpu
  input  logic [P.FLEN-1:0]       FWriteDataM,                          // FP data to store
  input  logic                    FpLoadStoreM,                         // FP load or store
  // faults
  output logic                    LoadPageFaultM, StoreAmoPageFaultM,   // Load and store/AMO page faults
  output logic                    LoadMisalignedFaultM,                 // Load address misaligned fault
  output logic                    LoadAccessFaultM,                     // Load access fault
  output logic                    HPTWInstrAccessFaultF,                // HPTW access fault during instruction page table walk, in Fetch stage
  output logic                    HPTWInstrPageFaultF,                  // HPTW page fault during instruction page table walk, in Fetch stage
  // cpu hazard unit (trap)
  output logic                    StoreAmoMisalignedFaultM,             // Store or AMO address misaligned fault
  output logic                    StoreAmoAccessFaultM,                 // Store or AMO access fault
  // connect to ahb
  output logic [P.PA_BITS-1:0]    LSUHADDR,                             // LSU AHB address
  input  logic [P.XLEN-1:0]       HRDATA,                               // AHB read data
  output logic [P.XLEN-1:0]       LSUHWDATA,                            // LSU AHB write data
  input  logic                    LSUHREADY,                            // AHB ready to LSU; never gated because the LSU has priority
  output logic                    LSUHWRITE,                            // LSU AHB write (1) or read (0)
  output logic [2:0]              LSUHSIZE,                             // LSU AHB transfer size
  output logic [2:0]              LSUHBURST,                            // LSU AHB burst type
  output logic [1:0]              LSUHTRANS,                            // LSU AHB transfer type
  output logic [P.XLEN/8-1:0]     LSUHWSTRB,                            // LSU AHB byte write enables
  // page table walker
  input  logic [P.XLEN-1:0]       SATP_REGW,                            // satp CSR
  input  logic                    STATUS_MXR, STATUS_SUM, STATUS_MPRV,  // mstatus.MXR, SUM, MPRV: control address translation permissions
  input  logic [1:0]              STATUS_MPP,                           // mstatus.MPP: machine previous privilege mode
  input  logic                    ENVCFG_PBMTE,                         // Page-based memory types enabled
  input  logic                    ENVCFG_ADUE,                          // HPTW A/D Update enable
  input  logic [P.XLEN-1:0]       PCSpillF,                             // PCF, or PCF + 2 for the second half of a spilled fetch
  input  logic                    ITLBMissOrUpdateAF,                   // ITLB miss or access bit update requires an HPTW walk
  output logic [P.XLEN-1:0]       PTE,                                  // Page table entry
  output logic [2:0]              PageType,                             // Page type to TLBs
  output logic                    ITLBWriteF,                           // Write ITLB
  output logic                    SelHPTW,                              // HPTW is accessing memory through the LSU
  input var logic [7:0]           PMPCFG_ARRAY_REGW[P.PMP_ENTRIES-1:0], // PMP configuration CSRs
  input var logic [P.PA_BITS-3:0] PMPADDR_ARRAY_REGW[P.PMP_ENTRIES-1:0] // PMP address CSRs
);
  localparam logic MISALIGN_SUPPORT = P.ZICCLSM_SUPPORTED & P.DCACHE_SUPPORTED;
  localparam MLEN = MISALIGN_SUPPORT ? 2*P.LLEN : P.LLEN; // widen buffer for misaligned accesses

  logic [P.XLEN+1:0]     IEUAdrExtM;                             // Memory stage address zero-extended to PA_BITS or XLEN whichever is longer
  logic [P.XLEN+1:0]     IEUAdrExtE;                             // Execution stage address zero-extended to PA_BITS or XLEN whichever is longer
  logic [P.PA_BITS-1:0]  PAdrM;                                  // Physical memory address
  logic [P.XLEN+1:0]     IHAdrM;                                 // Either IEU or HPTW memory address

  logic [1:0]            PreLSURWM;                              // IEU or HPTW Read/Write signal
  logic [1:0]            LSURWM;                                 // IEU or HPTW Read/Write signal gated by LR/SC
  logic [2:0]            LSUFunct3M;                             // IEU or HPTW memory operation size
  logic [2:0]            LSUSizeM;                               // Memory operation size as an AHB HSIZE
  logic [6:0]            LSUFunct7M;                             // AMO function gated by HPTW
  logic [1:0]            LSUAtomicM;                             // AMO signal gated by HPTW
  logic [3:0]            LSUCMOpM;                               // CMOpM gated by HPTW

  logic                  GatedStallW;                            // Hazard unit StallW gated when SelHPTW = 1

  logic                  LSUBusStallM;                           // Bus interface busy with multicycle operation masked by HPTWFlushW
  logic                  HPTWStall;                              // HPTW busy with multicycle operation
  logic                  DCacheBusStallM;                        // Cache or bus stall
  logic                  CacheBusHPWTStall;                      // Cache, bus, or hptw is requesting a stall
  logic                  SelSpillE;                              // Align logic detected a spill and needs to stall

  logic                  CacheableM;                             // PMA indicates memory address is cacheable
  logic                  BusCommittedM;                          // Bus memory operation in flight, delay interrupts
  logic                  DCacheCommittedM;                       // D$ memory operation started, delay interrupts

  logic [P.LLEN-1:0]     DTIMReadDataWordM;                      // DTIM read data
  logic [MLEN-1:0]       DCacheReadDataWordM;                    // D$ read data
  logic [MLEN-1:0]       LSUWriteDataSpillM;                     // Final write data
  logic [MLEN/8-1:0]     ByteMaskSpillM;                         // Selects which bytes within a word to write
  logic [P.LLEN-1:0]     DCacheReadDataWordSpillM;               // D$ read data
  logic [P.LLEN-1:0]     ReadDataWordMuxM;                       // DTIM or D$ read data
  logic [P.LLEN-1:0]     LittleEndianReadDataWordM;              // Endian-swapped read data
  logic [P.LLEN-1:0]     ReadDataM;                              // Final read data

  logic [P.XLEN-1:0]     IHWriteDataM;                           // IEU or HPTW write data
  logic [P.XLEN-1:0]     IMAWriteDataM;                          // IEU, HPTW, or AMO write data
  logic [P.LLEN-1:0]     IMAFWriteDataM;                         // IEU, HPTW, AMO, or FPU write data
  logic [P.LLEN-1:0]     LittleEndianWriteDataM;                 // Endian-swapped write data
  logic [P.LLEN-1:0]     LSUWriteDataM;                          // Final write data
  logic [(P.LLEN-1)/8:0] ByteMaskM;                              // Selects which bytes within a word to write
  logic [(P.LLEN-1)/8:0] ByteMaskExtendedM;                      // Selects which bytes within a word to write
  logic [1:0]            MemRWSpillM;
  logic                  SpillStallM;

  logic                  DTLBMissM;                              // DTLB miss causes HPTW walk
  logic                  DTLBWriteM;                             // Writes PTE and PageType to DTLB
  logic                  LSULoadAccessFaultM;                    // Load access fault
  logic                  LSUStoreAmoAccessFaultM;                // Store access fault
  logic                  HPTWFlushW;                             // HPTW needs to flush operation
  logic                  MemAccessInFlightM;                     // M-stage access started on the D$/bus (or performed and holding) and not yet captured
  logic                  MemAccessDoneM;                         // M-stage access performed and its result captured; do not re-issue
  logic                  HoldAccessM;                            // Suppress the M-stage access presented to the D$/bus (already performed)
  logic [P.LLEN-1:0]     ReadDataHoldM;                          // Captured read data of a performed access awaiting retirement
  logic [P.LLEN-1:0]     ReadDataSelM;                           // Read data to the W stage (live or held)
  logic                  LSUFlushW;                              // HPTW or hazard unit flushes operation
  logic                  SelfFaultM;                             // M-stage access has its own fault; squash it
  logic                  SelDTIM;                                // Select DTIM rather than bus or D$
  logic [P.XLEN-1:0]     WriteDataZM;                            // IEU write data, forced to zero for cbo.zero
  logic                  LSULoadPageFaultM, LSUStoreAmoPageFaultM;
  logic                  DTLBMissOrUpdateDAM;

  /////////////////////////////////////////////////////////////////////////////////////////////
  // Pipeline for IEUAdr E to M
  // Zero-extend address to 34 bits for XLEN=32
  /////////////////////////////////////////////////////////////////////////////////////////////

  flopenrc #(P.XLEN) AddressMReg(clk, reset, FlushM, ~StallM, IEUAdrE, IEUAdrM);
  if (MISALIGN_SUPPORT) begin : ziccslm_align
    logic [P.XLEN-1:0] IEUAdrSpillE;
    logic [P.XLEN-1:0] IEUAdrSpillM;
    align #(P) align(.clk, .reset, .StallM, .FlushM, .IEUAdrE, .IEUAdrM, .Funct3M, .FpLoadStoreM,
                     .MemRWM,
                     .DCacheReadDataWordM, .CacheBusHPWTStall, .SelHPTW,
                     .ByteMaskM, .ByteMaskExtendedM, .LSUWriteDataM, .ByteMaskSpillM, .LSUWriteDataSpillM,
                     .IEUAdrSpillE, .IEUAdrSpillM, .IEUAdrxTvalM, .SelSpillE, .DCacheReadDataWordSpillM, .SpillStallM);
    assign IEUAdrExtM = {2'b00, IEUAdrSpillM};
    assign IEUAdrExtE = {2'b00, IEUAdrSpillE};
  end else begin : no_ziccslm_align
    assign IEUAdrExtM = {2'b00, IEUAdrM};
    assign IEUAdrExtE = {2'b00, IEUAdrE};
    assign SelSpillE = 1'b0;
    assign DCacheReadDataWordSpillM = DCacheReadDataWordM;
    assign ByteMaskSpillM = ByteMaskM;
    assign LSUWriteDataSpillM = LSUWriteDataM;
    assign MemRWSpillM = MemRWM;
    assign {SpillStallM} = 1'b0;
    assign IEUAdrxTvalM = IEUAdrM;
  end

  if (P.ZICBOZ_SUPPORTED) begin : cboz
    assign WriteDataZM = LSUCMOpM[3] ? 0 : WriteDataM;
  end else begin : cboz
    assign WriteDataZM = WriteDataM;
  end

  /////////////////////////////////////////////////////////////////////////////////////////////
  // HPTW (only needed if VM supported)
  // MMU includes PMP and is needed if any privileged supported
  /////////////////////////////////////////////////////////////////////////////////////////////

  if (P.VIRTMEM_SUPPORTED) begin : hptw
    hptw #(P) hptw(.clk, .reset, .MemRWM, .AtomicM, .ITLBMissOrUpdateAF, .ITLBWriteF,
      .DTLBMissOrUpdateDAM, .DTLBWriteM,
      .FlushW, .DCacheBusStallM, .MemAccessInFlightM, .MemAccessDoneM, .SATP_REGW, .PCSpillF,
      .STATUS_MXR, .STATUS_SUM, .STATUS_MPRV, .STATUS_MPP, .ENVCFG_ADUE, .PrivilegeModeW,
      .ReadDataM(ReadDataM[P.XLEN-1:0]), // ReadDataM is LLEN, but HPTW only needs XLEN
      .WriteDataM(WriteDataZM), .Funct3M, .LSUFunct3M, .Funct7M, .LSUFunct7M,
      .IEUAdrExtM, .PTE, .IHWriteDataM, .PageType, .PreLSURWM, .LSUAtomicM,
      .IHAdrM, .CMOpM, .LSUCMOpM, .HPTWStall, .SelHPTW,
      .HPTWFlushW, .LSULoadAccessFaultM, .LSUStoreAmoAccessFaultM,
      .LoadAccessFaultM, .StoreAmoAccessFaultM, .HPTWInstrAccessFaultF,
      .LoadPageFaultM, .StoreAmoPageFaultM, .LSULoadPageFaultM, .LSUStoreAmoPageFaultM, .HPTWInstrPageFaultF
);

    // Memory-access state for walker arbitration (issues #1538, #1766).
    // An M-stage access the D$/bus has started (fetch, writeback, or bus data phase) or has performed and is
    // holding (D$ ADDRESS_SETUP, bus MEM3) must not be pre-empted by a page table walk: it can be neither
    // aborted nor replayed.  Once performed while the pipeline is stalled, capture its result and hold it
    // until the pipeline advances; the walker may then use the D$/bus, and the access is not re-issued.
    logic MemAccessPerformedM;
    assign MemAccessPerformedM = (DCacheCommittedM | BusCommittedM) & ~DCacheBusStallM & ~SpillStallM & ~SelHPTW;
    assign MemAccessInFlightM  = (DCacheCommittedM | BusCommittedM) & ~MemAccessDoneM;
    always_ff @(posedge clk)
      if (reset | FlushW | ~StallW) MemAccessDoneM <= 1'b0;
      else if (MemAccessPerformedM) MemAccessDoneM <= 1'b1;
    flopenr #(P.LLEN) ReadDataHoldReg(clk, reset, MemAccessPerformedM & ~MemAccessDoneM, ReadDataM, ReadDataHoldM);
  end else begin // No HPTW, so signals are not multiplexed
    assign PreLSURWM = MemRWM;
    assign IHAdrM = IEUAdrExtM;
    assign LSUFunct3M = Funct3M;
    assign LSUFunct7M = Funct7M;
    assign LSUAtomicM = AtomicM;
    assign LSUCMOpM = CMOpM;
    assign IHWriteDataM = WriteDataZM;
    assign LoadAccessFaultM = LSULoadAccessFaultM;
    assign StoreAmoAccessFaultM = LSUStoreAmoAccessFaultM;
    assign LoadPageFaultM = LSULoadPageFaultM;
    assign StoreAmoPageFaultM = LSUStoreAmoPageFaultM;
    assign {HPTWStall, SelHPTW, PTE, PageType, DTLBWriteM, ITLBWriteF, HPTWFlushW} = '0;
    assign {MemAccessInFlightM, MemAccessDoneM} = '0;
    assign ReadDataHoldM = '0;
    assign {HPTWInstrAccessFaultF, HPTWInstrPageFaultF} = '0;
  end

  // CommittedM indicates the cache, bus, or HPTW are busy with a multiple cycle operation.
  // CommittedM is 1 after the first cycle and until the last cycle.  Partially completed memory
  // operations delay interrupts until the next instruction by suppressing pending interrupts in
  // the trap module.
  assign CommittedM = SelHPTW | DCacheCommittedM | BusCommittedM | MemAccessDoneM;
  assign HoldAccessM = MemAccessDoneM & ~SelHPTW; // performed access awaiting retirement: don't re-issue it (walker accesses pass)
  assign GatedStallW = StallW & ~SelHPTW;
  assign DCacheBusStallM = DCacheStallM | LSUBusStallM;
  assign CacheBusHPWTStall = DCacheBusStallM | HPTWStall;
  assign LSUStallM = CacheBusHPWTStall | SpillStallM;

  // AHB defines HSIZE 100/101/110 as 128/256/512-bit transfers, but funct3 uses those codes for the
  // unsigned integer loads lbu/lhu/lwu, which are byte/halfword/word accesses.  Clear the unsigned bit
  // for integer accesses; FP accesses use funct3 as the true width (including 100 for a 128-bit flq).
  assign LSUSizeM = FpLoadStoreM ? LSUFunct3M : {1'b0, LSUFunct3M[1:0]};

  /////////////////////////////////////////////////////////////////////////////////////////////
  // MMU and misalignment fault logic required if privileged unit exists
  /////////////////////////////////////////////////////////////////////////////////////////////
  if (P.ZICSR_SUPPORTED == 1) begin : dmmu
    logic DisableTranslation;                             // During HPTW walk or D$ flush disable virtual memory address translation
    logic WriteAccessM;
    logic DataUpdateDAM;                                  // DTLB hit needs to update dirty or access bits

    assign DisableTranslation = SelHPTW | FlushDCacheM;
    assign WriteAccessM = PreLSURWM[0];
    mmu #(.P(P), .TLB_ENTRIES(P.DTLB_ENTRIES), .IMMU(0))
    dmmu(.clk, .reset, .SATP_REGW, .STATUS_MXR, .STATUS_SUM, .STATUS_MPRV, .STATUS_MPP, .ENVCFG_PBMTE, .ENVCFG_ADUE,
      .PrivilegeModeW, .DisableTranslation, .VAdr(IHAdrM), .Size(LSUFunct3M[1:0]),
      .PTE, .PageTypeWriteVal(PageType), .TLBWrite(DTLBWriteM), .TLBFlush(sfencevmaM), .TLBFlushAll(sfencevmaAllM),
      .PhysicalAddress(PAdrM), .TLBMiss(DTLBMissM), .Cacheable(CacheableM), .Idempotent(), .SelTIM(SelDTIM),
      .InstrAccessFaultF(), .LoadAccessFaultM(LSULoadAccessFaultM),
      .StoreAmoAccessFaultM(LSUStoreAmoAccessFaultM), .InstrPageFaultF(), .LoadPageFaultM(LSULoadPageFaultM),
      .StoreAmoPageFaultM(LSUStoreAmoPageFaultM),
      .LoadMisalignedFaultM, .StoreAmoMisalignedFaultM,
      .UpdateDA(DataUpdateDAM), .CMOpM(LSUCMOpM),
      .AtomicAccessM(|LSUAtomicM), .ExecuteAccessF(1'b0),
      .WriteAccessM, .ReadAccessM(PreLSURWM[1]),
      .PMPCFG_ARRAY_REGW, .PMPADDR_ARRAY_REGW);

    assign DTLBMissOrUpdateDAM = DTLBMissM | (P.SVADU_SUPPORTED & DataUpdateDAM);
  end else begin  // No MMU, so no PMA/page faults and no address translation
    assign DTLBMissOrUpdateDAM = '0;
    assign {DTLBMissM, LSULoadAccessFaultM, LSUStoreAmoAccessFaultM, LoadMisalignedFaultM, StoreAmoMisalignedFaultM} = '0;
    assign {LSULoadPageFaultM, LSUStoreAmoPageFaultM} = '0;
    assign PAdrM = IHAdrM[P.PA_BITS-1:0];
    assign CacheableM = 1'b1;
    assign SelDTIM = P.DTIM_SUPPORTED & ~P.BUS_SUPPORTED; // if no PMA then select dtim if there is a DTIM.  If there is
    // a bus then this is always 0. Cannot have both without PMA.
  end

  /////////////////////////////////////////////////////////////////////////////////////////////
  // Memory System (options)
  // 1. DTIM
  // 2. DTIM and bus
  // 3. Bus
  // 4. Cache and bus
  /////////////////////////////////////////////////////////////////////////////////////////////

  // Pause IEU memory request if TLB miss.  After TLB fill, replay request.
  // Discard memory request on pipeline flush or when the access itself faults: TrapM waits for a committed
  // IFU fetch (~CommittedF, #412), so FlushW alone would let the faulting access proceed.  The walker's accesses are exempt.
  assign SelfFaultM = ~SelHPTW & (LSULoadPageFaultM | LSUStoreAmoPageFaultM | LSULoadAccessFaultM |
                                 LSUStoreAmoAccessFaultM | LoadMisalignedFaultM | StoreAmoMisalignedFaultM);
  assign LSUFlushW = HPTWFlushW | FlushW | SelfFaultM;

  if (P.DTIM_SUPPORTED) begin : dtim
    logic [P.PA_BITS-1:0] DTIMAdr;
    logic [1:0]           DTIMMemRWM;

    // The DTIM uses untranslated addresses, so it is not compatible with virtual memory.
    mux2 #(P.PA_BITS) DTIMAdrMux(IEUAdrExtE[P.PA_BITS-1:0], IEUAdrExtM[P.PA_BITS-1:0], MemRWM[0], DTIMAdr);
    assign DTIMMemRWM = SelDTIM ? LSURWM : 0;
    dtim #(P) dtim(.clk, .reset, .ce(~GatedStallW),
              .MemRWM(DTIMMemRWM),
              .DTIMAdr, .FlushW(LSUFlushW), .WriteDataM(LSUWriteDataM),
              .ReadDataWordM(DTIMReadDataWordM[P.LLEN-1:0]), .ByteMaskM(ByteMaskM));
  end else
    assign DTIMReadDataWordM = '0;
  if (P.BUS_SUPPORTED) begin : bus
    if (P.DCACHE_SUPPORTED) begin : dcache
      localparam   LLENWORDSPERLINE = P.DCACHE_LINELENINBITS/P.LLEN;             // Number of LLEN words in cacheline
      localparam   LLENLOGBWPL = $clog2(LLENWORDSPERLINE);                       // Log2 of ^
      localparam   BEATSPERLINE = P.DCACHE_LINELENINBITS/P.AHBW;                 // Number of AHBW words (beats) in cacheline
      localparam   AHBWLOGBWPL = $clog2(BEATSPERLINE);                           // Log2 of ^
      localparam   LINELEN = P.DCACHE_LINELENINBITS;                             // Number of bits in cacheline
      localparam   LLENPOVERAHBW = P.LLEN / P.AHBW;                              // Number of AHB beats in a LLEN word. AHBW cannot be larger than LLEN. (implementation limitation)
      localparam   CACHEWORDLEN = P.ZICCLSM_SUPPORTED ? 2*P.LLEN : P.LLEN;       // Width of the cache's input and output data buses.  Misaligned doubles width for fast access

      logic [LINELEN-1:0]      FetchBuffer;                                      // Temporary buffer to hold partially fetched cacheline
      logic [P.PA_BITS-1:0]    DCacheBusAdr;                                     // Cacheline address to fetch or writeback.
      logic [AHBWLOGBWPL-1:0]  BeatCount;                                        // Position within a cacheline.  ahbcacheinterface to cache
      logic                    DCacheBusAck;                                     // ahbcacheinterface completed fetch or writeback
      logic                    SelBusBeat;                                       // ahbcacheinterface selects position in cacheline with BeatCount
      logic [1:0]              CacheBusRW;                                       // Cache sends request to ahbcacheinterface
      logic [1:0]              BusRW;                                            // Uncached bus memory access
      logic                    CacheableOrFlushCacheM;                           // Memory address is cacheable or operation is a cache flush
      logic [1:0]              CacheRWM;                                         // Cache read (10), write (01), AMO (11)
      logic                    FlushDCache;                                      // Suppress D$ flush during an HPTW walk
      logic                    BusCMOZero;
      logic [3:0]              CacheCMOpM;
      logic                    BusAtomic;

      // Each datapath is gated on the extension that needs it: cbo.zero to uncached memory on Zicboz,
      // the cache CMO port on either CBO extension, and uncached AMOs on Zaamo
      if (P.ZICBOZ_SUPPORTED) assign BusCMOZero = LSUCMOpM[3] & ~CacheableM & ~HoldAccessM;
      else                    assign BusCMOZero = 1'b0;
      if (P.ZICBOM_SUPPORTED | P.ZICBOZ_SUPPORTED) assign CacheCMOpM = (CacheableM & ~SelHPTW & ~HoldAccessM) ? CMOpM : '0;
      else                                         assign CacheCMOpM = '0;
      if (P.ZAAMO_SUPPORTED) assign BusAtomic = AtomicM[1] & ~CacheableM;
      else                   assign BusAtomic = 1'b0;
      assign BusRW = (~CacheableM & ~SelDTIM & ~HoldAccessM) ? LSURWM : '0;
      assign CacheableOrFlushCacheM = CacheableM | FlushDCacheM;
      assign CacheRWM = (CacheableM & ~SelDTIM & ~HoldAccessM) ? LSURWM : '0;
      assign FlushDCache = FlushDCacheM & ~SelHPTW;                          // exclusion-tag: lsu FlushDCacheSelHPTW

      localparam                     LINEBYTELEN = P.DCACHE_LINELENINBITS/8;              // Line length in bytes
      localparam                     OFFSETLEN = $clog2(LINEBYTELEN);                     // Number of bits in offset field
      localparam                     SETLEN = $clog2(P.DCACHE_WAYSIZEINBYTES*8/LINELEN);  // Number of set bits

      cache #(.P(P), .PA_BITS(P.PA_BITS), .LINELEN(P.DCACHE_LINELENINBITS), .NUMSETS(P.DCACHE_WAYSIZEINBYTES*8/LINELEN),
              .OFFSETLEN(OFFSETLEN), .SETLEN(SETLEN),
              .NUMWAYS(P.DCACHE_NUMWAYS), .LOGBWPL(LLENLOGBWPL), .WORDLEN(CACHEWORDLEN), .MUXINTERVAL(P.LLEN), .READ_ONLY_CACHE(0)) dcache(
        .clk, .reset, .Stall(GatedStallW & ~SelSpillE), .SelBusBeat, .FlushStage(LSUFlushW),
        .CacheRW(CacheRWM),
        .FlushCache(FlushDCache), .NextSet(IEUAdrExtE[OFFSETLEN+SETLEN-1:0]), .PAdr(PAdrM),
        .ByteMask(ByteMaskSpillM), .BeatCount(BeatCount[AHBWLOGBWPL-1:AHBWLOGBWPL-LLENLOGBWPL]),
        .WriteData(LSUWriteDataSpillM), .SelHPTW,
        .CacheStall(DCacheStallM), .CacheMiss(DCacheMiss), .CacheAccess(DCacheAccess),
        .CacheCommitted(DCacheCommittedM),
        .CacheBusAdr(DCacheBusAdr), .ReadDataWord(DCacheReadDataWordM),
        .FetchBuffer, .CacheBusRW(CacheBusRW),
        .CacheBusAck(DCacheBusAck), .InvalidateCache(1'b0), .InvalidateFlushStage(LSUFlushW), .CMOpM(CacheCMOpM));

      ahbcacheinterface #(.P(P), .BEATSPERLINE(BEATSPERLINE), .AHBWLOGBWPL(AHBWLOGBWPL), .LINELEN(LINELEN), .LLENPOVERAHBW(LLENPOVERAHBW), .READ_ONLY_CACHE(0)) ahbcacheinterface(
        .HCLK(clk), .HRESETn(~reset), .Flush(LSUFlushW),
        .HRDATA, .HWDATA(LSUHWDATA), .HWSTRB(LSUHWSTRB),
        .HSIZE(LSUHSIZE), .HBURST(LSUHBURST), .HTRANS(LSUHTRANS), .HWRITE(LSUHWRITE), .HREADY(LSUHREADY),
        .BeatCount, .SelBusBeat, .CacheReadDataWordM(DCacheReadDataWordM[P.LLEN-1:0]), .WriteDataM(LSUWriteDataM),
        .Size(LSUSizeM), .HADDR(LSUHADDR), .CacheBusAdr(DCacheBusAdr), .CacheBusRW, .BusAtomic, .BusCMOZero, .CacheableOrFlushCacheM,
        .CacheBusAck(DCacheBusAck), .FetchBuffer, .PAdr(PAdrM),
        .Cacheable(CacheableOrFlushCacheM), .BusRW, .Stall(GatedStallW),
        .BusStall(LSUBusStallM), .BusCommitted(BusCommittedM));

      mux3 #(P.LLEN) UnCachedDataMux(.d0(DCacheReadDataWordSpillM), .d1({LLENPOVERAHBW{FetchBuffer[P.XLEN-1:0]}}),
                                    .d2({{P.LLEN-P.XLEN{1'b0}}, DTIMReadDataWordM[P.XLEN-1:0]}),
                                    .s({SelDTIM, ~(CacheableOrFlushCacheM)}), .y(ReadDataWordMuxM));
    end else begin : passthrough // No Cache, use simple ahbinterface instead of ahbcacheinterface
      logic [1:0] BusRW;                    // Non-DTIM memory access, ignore cacheableM
      logic [P.XLEN-1:0] FetchBuffer;
      assign BusRW = (~SelDTIM & ~HoldAccessM) ? LSURWM : 0;

      assign LSUHADDR = PAdrM;
      assign LSUHSIZE = LSUSizeM;

      ahbinterface #(P.XLEN, 1'b1) ahbinterface(.HCLK(clk), .HRESETn(~reset), .Flush(LSUFlushW), .HREADY(LSUHREADY),
        .HRDATA(HRDATA), .HTRANS(LSUHTRANS), .HWRITE(LSUHWRITE), .HWDATA(LSUHWDATA),
        .HWSTRB(LSUHWSTRB), .BusRW, .BusAtomic(AtomicM[1]), .ByteMask(ByteMaskM[P.XLEN/8-1:0]), .WriteData(LSUWriteDataM[P.XLEN-1:0]),
        .Stall(GatedStallW), .BusStall(LSUBusStallM), .BusCommitted(BusCommittedM), .FetchBuffer(FetchBuffer));

      // Mux between the 2 sources of read data, 0: Bus, 1: DTIM
      if (P.DTIM_SUPPORTED) mux2 #(P.XLEN) ReadDataMux2(FetchBuffer, DTIMReadDataWordM[P.XLEN-1:0], SelDTIM, ReadDataWordMuxM[P.XLEN-1:0]);
      else assign ReadDataWordMuxM[P.XLEN-1:0] = FetchBuffer[P.XLEN-1:0];
      assign LSUHBURST = 3'b0;
      assign {DCacheStallM, DCacheCommittedM, DCacheMiss, DCacheAccess, DCacheReadDataWordM} = '0;
    end
  end else begin : nobus // block: bus, only DTIM
    assign {LSUHWDATA, LSUHADDR, LSUHWRITE, LSUHSIZE, LSUHBURST, LSUHTRANS, LSUHWSTRB} = '0;
    assign DCacheReadDataWordM = '0;
    assign ReadDataWordMuxM = DTIMReadDataWordM;
    assign {LSUBusStallM, BusCommittedM} = '0;
    assign {DCacheMiss, DCacheAccess} = '0;
    assign {DCacheStallM, DCacheCommittedM} = '0;
  end

  /////////////////////////////////////////////////////////////////////////////////////////////
  // Atomic operations
  /////////////////////////////////////////////////////////////////////////////////////////////

  if (P.ZAAMO_SUPPORTED | P.ZALRSC_SUPPORTED) begin : atomic
    atomic #(P) atomic(.clk, .reset, .StallW, .ReadDataM(ReadDataM[P.XLEN-1:0]), .IHWriteDataM, .PAdrM,
      .LSUFunct7M, .LSUFunct3M, .LSUAtomicM, .PreLSURWM, .LSUFlushW,
      .IMAWriteDataM, .SquashSCW, .LSURWM);
  end else begin : lrsc
    assign SquashSCW = 1'b0;
    assign LSURWM = PreLSURWM;
    assign IMAWriteDataM = IHWriteDataM;
  end

  if (P.F_SUPPORTED)
    if (P.FLEN >= P.XLEN)
      mux2 #(P.LLEN) datamux({{{P.LLEN-P.XLEN}{1'b0}}, IMAWriteDataM}, FWriteDataM, FpLoadStoreM, IMAFWriteDataM);
    else
      mux2 #(P.LLEN) datamux(IMAWriteDataM, {{{P.XLEN-P.FLEN}{1'b0}}, FWriteDataM}, FpLoadStoreM, IMAFWriteDataM);

  else assign IMAFWriteDataM = IMAWriteDataM;

  /////////////////////////////////////////////////////////////////////////////////////////////
  // Subword Accesses
  /////////////////////////////////////////////////////////////////////////////////////////////

  subwordread #(P) subwordread(.ReadDataWordMuxM(LittleEndianReadDataWordM), .PAdrM(PAdrM[3:0]), .BigEndianM,
    .FpLoadStoreM, .Funct3M(LSUFunct3M), .ReadDataM);
  subwordwrite #(P.LLEN) subwordwrite(.LSUFunct3M, .IMAFWriteDataM, .LittleEndianWriteDataM);

  // Compute byte masks
  swbytemask #(P.LLEN, P.ZICCLSM_SUPPORTED) swbytemask(.Size(LSUFunct3M), .Adr(PAdrM[$clog2(P.LLEN/8)-1:0]), .ByteMask(ByteMaskM), .ByteMaskExtended(ByteMaskExtendedM));

  /////////////////////////////////////////////////////////////////////////////////////////////
  // MW Pipeline Register
  /////////////////////////////////////////////////////////////////////////////////////////////

  // A performed access whose result was captured while the pipeline was stalled retires from the hold register
  mux2 #(P.LLEN) readdataselmux(ReadDataM, ReadDataHoldM, MemAccessDoneM, ReadDataSelM);
  flopen #(P.LLEN) ReadDataMWReg(clk, ~StallW, ReadDataSelM, ReadDataW);

  /////////////////////////////////////////////////////////////////////////////////////////////
  // Big Endian Byte Swapper
  //  hart works little-endian internally
  //  swap the bytes when read from big-endian memory
  /////////////////////////////////////////////////////////////////////////////////////////////

  if (P.BIGENDIAN_SUPPORTED) begin : endian
    endianswap #(P.LLEN) storeswap(.BigEndianM, .a(LittleEndianWriteDataM), .y(LSUWriteDataM));
    endianswap #(P.LLEN) loadswap(.BigEndianM, .a(ReadDataWordMuxM), .y(LittleEndianReadDataWordM));
  end else begin
    assign LSUWriteDataM = LittleEndianWriteDataM;
    assign LittleEndianReadDataWordM = ReadDataWordMuxM;
  end
endmodule
