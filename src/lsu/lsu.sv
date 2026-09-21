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
/////////////////////////////////////////////////////////////////////////////////////////////////////////

module lsu import cvw::*;  #(parameter cvw_t P) (
  input  logic                    clk, reset,
  input  logic                    StallM, FlushM, StallW, FlushW,
  output logic                    LSUStallM,                            // LSU stalls pipeline during a multicycle operation
  // connected to cpu (controls)
  input  logic [1:0]              MemRWE,                               // Read/Write control
  input  logic [1:0]              MemRWM,                               // Read/Write control
  input  logic [2:0]              Funct3M,                              // Size of memory operation
  input  logic [6:0]              Funct7M,                              // Atomic memory operation function
  input  logic [1:0]              AtomicM,                              // Atomic memory operation
  input  logic                    FlushDCacheM,                         // Flush D cache to next level of memory
  input  logic [3:0]              CMOpM,                                // 1: cbo.inval; 2: cbo.flush; 4: cbo.clean; 8: cbo.zero
  input  logic                    LSUPrefetchM,                         // Prefetch; presently unused
  output logic                    CommittedM,                           // Delay interrupts while memory operation in flight
  output logic                    SquashSCW,                            // Store conditional failed disable write to GPR
  output logic                    DCacheMiss,                           // D cache miss for performance counters
  output logic                    DCacheAccess,                         // D cache memory access for performance counters
  // address and write data
  input  logic [P.XLEN-1:0]       IEUAdrE,                              // Execution stage memory address
  output logic [P.XLEN-1:0]       IEUAdrM,                              // Memory stage memory address
  input  logic [P.XLEN-1:0]       WriteDataM,                           // Write data from IEU
  output logic [P.LLEN-1:0]       ReadDataW,                            // Read data to IEU or FPU
  // cpu privilege
  input  logic [1:0]              PrivilegeModeW,                       // Current privilege mode
  input  logic                    BigEndianM,                           // Swap byte order to big endian
  input  logic                    sfencevmaM,                           // Virtual memory address fence, invalidate TLB entries
  output logic                    DCacheStallM,                         // D$ busy with multicycle operation
  output logic [P.XLEN-1:0]       IEUAdrxTvalM,                         // IEUAdrM, but could be spilled onto the next cacheline or virtual page.
  // fpu
  input  logic [P.FLEN-1:0]       FWriteDataM,                          // Write data from FPU
  input  logic                    FpLoadStoreM,                         // Selects FPU as store for write data
  // faults
  output logic                    LoadPageFaultM, StoreAmoPageFaultM,   // Page fault exceptions
  output logic                    LoadMisalignedFaultM,                 // Load address misaligned fault
  output logic                    LoadAccessFaultM,                     // Load access fault (PMA)
  output logic                    HPTWInstrAccessFaultF,                // HPTW generated access fault during instruction fetch
  output logic                    HPTWInstrPageFaultF,                  // HPTW generated access fault during instruction fetch
  // cpu hazard unit (trap)
  output logic                    StoreAmoMisalignedFaultM,             // Store or AMO address misaligned fault
  output logic                    StoreAmoAccessFaultM,                 // Store or AMO access fault
  // connect to ahb
  output logic [P.PA_BITS-1:0]    LSUHADDR,                             // Bus address from LSU to EBU
  input  logic [P.XLEN-1:0]       HRDATA,                               // Bus read data from LSU to EBU
  output logic [P.XLEN-1:0]       LSUHWDATA,                            // Bus write data from LSU to EBU
  input  logic                    LSUHREADY,                            // Bus ready from LSU to EBU
  output logic                    LSUHWRITE,                            // Bus write operation from LSU to EBU
  output logic [2:0]              LSUHSIZE,                             // Bus operation size from LSU to EBU
  output logic [2:0]              LSUHBURST,                            // Bus burst from LSU to EBU
  output logic [1:0]              LSUHTRANS,                            // Bus transaction type from LSU to EBU
  output logic [P.XLEN/8-1:0]     LSUHWSTRB,                            // Bus byte write enables from LSU to EBU
  // page table walker
  input  logic [P.XLEN-1:0]       SATP_REGW,                            // SATP (supervisor address translation and protection) CSR
  input  logic                    STATUS_MXR, STATUS_SUM, STATUS_MPRV,  // STATUS CSR bits: make executable readable, supervisor user memory, machine privilege
  input  logic [1:0]              STATUS_MPP,                           // Machine previous privilege mode
  input  logic                    ENVCFG_PBMTE,                         // Page-based memory types enabled
  input  logic                    ENVCFG_ADUE,                          // HPTW A/D Update enable
  input  logic [P.XLEN-1:0]       PCSpillF,                             // Fetch PC
  input  logic                    ITLBMissOrUpdateAF,                   // ITLB miss causes HPTW (hardware pagetable walker) walk or update access bit
  output logic [P.XLEN-1:0]       PTE,                                  // Page table entry write to ITLB
  output logic [2:0]              PageType,                             // Type of page table entry to write to ITLB
  output logic                    ITLBWriteF,                           // Write PTE to ITLB
  output logic                    SelHPTW,                              // During a HPTW walk the effective privilege mode becomes S_MODE
  input var logic [7:0]           PMPCFG_ARRAY_REGW[P.PMP_ENTRIES-1:0], // PMP configuration from privileged unit
  input var logic [P.PA_BITS-3:0] PMPADDR_ARRAY_REGW[P.PMP_ENTRIES-1:0] // PMP address from privileged unit
);
  localparam logic MISALIGN_SUPPORT = P.ZICCLSM_SUPPORTED & P.DCACHE_SUPPORTED;
  localparam MLEN = MISALIGN_SUPPORT ? 2*P.LLEN : P.LLEN; // widen buffer for misaligned accessess

  logic [P.XLEN+1:0]     IEUAdrExtM;                             // Memory stage address zero-extended to PA_BITS or XLEN whichever is longer
  logic [P.XLEN+1:0]     IEUAdrExtE;                             // Execution stage address zero-extended to PA_BITS or XLEN whichever is longer
  logic [P.PA_BITS-1:0]  PAdrM;                                  // Physical memory address
  logic [P.XLEN+1:0]     IHAdrM;                                 // Either IEU or HPTW memory address

  logic [1:0]            PreLSURWM;                              // IEU or HPTW Read/Write signal
  logic [1:0]            LSURWM;                                 // IEU or HPTW Read/Write signal gated by LR/SC
  logic [2:0]            LSUFunct3M;                             // IEU or HPTW memory operation size
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
  logic [P.LLEN-1:0]     LittleEndianWriteDataM;                 // Ending-swapped write data
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
  logic                  LSUFlushW;                              // HPTW or hazard unit flushes operation
  logic                  SelDTIM;                                // Select DTIM rather than bus or D$
  logic [P.XLEN-1:0]     WriteDataZM;
  logic                  LSULoadPageFaultM, LSUStoreAmoPageFaultM;
  logic                  DTLBMissOrUpdateDAM;

  /////////////////////////////////////////////////////////////////////////////////////////////
  // Pipeline for IEUAdr E to M
  // Zero-extend address to 34 bits for XLEN=32
  /////////////////////////////////////////////////////////////////////////////////////////////

  flopenrc #(P.XLEN) AddressMReg(clk, reset, FlushM, ~StallM, IEUAdrE, IEUAdrM);
  if(MISALIGN_SUPPORT) begin : ziccslm_align
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

    if(P.ZICBOZ_SUPPORTED) begin : cboz
      assign WriteDataZM = LSUCMOpM[3] ? 0 : WriteDataM;
   end else begin : cboz
      assign WriteDataZM = WriteDataM;
    end

  /////////////////////////////////////////////////////////////////////////////////////////////
  // HPTW (only needed if VM supported)
  // MMU include PMP and is needed if any privileged supported
  /////////////////////////////////////////////////////////////////////////////////////////////

  if(P.VIRTMEM_SUPPORTED) begin : hptw
    hptw #(P) hptw(.clk, .reset, .MemRWM, .AtomicM, .ITLBMissOrUpdateAF, .ITLBWriteF,
      .DTLBMissOrUpdateDAM, .DTLBWriteM,
      .FlushW, .DCacheBusStallM, .SATP_REGW, .PCSpillF,
      .STATUS_MXR, .STATUS_SUM, .STATUS_MPRV, .STATUS_MPP, .ENVCFG_ADUE, .PrivilegeModeW,
      .ReadDataM(ReadDataM[P.XLEN-1:0]), // ReadDataM is LLEN, but HPTW only needs XLEN
      .WriteDataM(WriteDataZM), .Funct3M, .LSUFunct3M, .Funct7M, .LSUFunct7M,
      .IEUAdrExtM, .PTE, .IHWriteDataM, .PageType, .PreLSURWM, .LSUAtomicM,
      .IHAdrM, .CMOpM, .LSUCMOpM, .HPTWStall, .SelHPTW,
      .HPTWFlushW, .LSULoadAccessFaultM, .LSUStoreAmoAccessFaultM,
      .LoadAccessFaultM, .StoreAmoAccessFaultM, .HPTWInstrAccessFaultF,
      .LoadPageFaultM, .StoreAmoPageFaultM, .LSULoadPageFaultM, .LSUStoreAmoPageFaultM, .HPTWInstrPageFaultF
);
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
    assign {HPTWInstrAccessFaultF, HPTWInstrPageFaultF} = '0;
   end

  // CommittedM indicates the cache, bus, or HPTW are busy with a multiple cycle operation.
  // CommittedM is 1 after the first cycle and until the last cycle.  Partially completed memory
  // operations delay interrupts until the next instruction by suppressing pending interrupts in
  // the trap module.
  assign CommittedM = SelHPTW | DCacheCommittedM | BusCommittedM;
  assign GatedStallW = StallW & ~SelHPTW;
  assign DCacheBusStallM = DCacheStallM | LSUBusStallM;
  assign CacheBusHPWTStall = DCacheBusStallM | HPTWStall;
  assign LSUStallM = CacheBusHPWTStall | SpillStallM;

  /////////////////////////////////////////////////////////////////////////////////////////////
  // MMU and misalignment fault logic required if privileged unit exists
  /////////////////////////////////////////////////////////////////////////////////////////////
  if(P.ZICSR_SUPPORTED == 1) begin : dmmu
    logic DisableTranslation;                             // During HPTW walk or D$ flush disable virtual memory address translation
    logic WriteAccessM;
    logic DataUpdateDAM;                                  // DTLB hit needs to update dirty or access bits

    assign DisableTranslation = SelHPTW | FlushDCacheM;
    assign WriteAccessM = PreLSURWM[0];
    mmu #(.P(P), .TLB_ENTRIES(P.DTLB_ENTRIES), .IMMU(0))
    dmmu(.clk, .reset, .SATP_REGW, .STATUS_MXR, .STATUS_SUM, .STATUS_MPRV, .STATUS_MPP, .ENVCFG_PBMTE, .ENVCFG_ADUE,
      .PrivilegeModeW, .DisableTranslation, .VAdr(IHAdrM), .Size(LSUFunct3M[1:0]),
      .PTE, .PageTypeWriteVal(PageType), .TLBWrite(DTLBWriteM), .TLBFlush(sfencevmaM),
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
  // Discard memory request on pipeline flush
  assign LSUFlushW = HPTWFlushW | FlushW;

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
    if(P.DCACHE_SUPPORTED) begin : dcache
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
      logic                    FlushDCache;                                      // Suppress d cache flush if there is an ITLB miss.
      logic                    BusCMOZero;
      logic [3:0]              CacheCMOpM;
      logic                    BusAtomic;

      if(P.ZICBOZ_SUPPORTED) begin
        assign BusCMOZero = LSUCMOpM[3] & ~CacheableM;
        assign CacheCMOpM = (CacheableM & ~SelHPTW) ? CMOpM : '0;
        assign BusAtomic = AtomicM[1] & ~CacheableM;
      end else begin
        assign BusCMOZero = 1'b0;
        assign CacheCMOpM = '0;
        assign BusAtomic = 1'b0;
      end
      assign BusRW = (~CacheableM & ~SelDTIM )? LSURWM : '0;
      assign CacheableOrFlushCacheM = CacheableM | FlushDCacheM;
      assign CacheRWM = (CacheableM & ~SelDTIM) ? LSURWM : '0;
      assign FlushDCache = FlushDCacheM & ~SelHPTW;                          // exclusion-tag: lsu FlushDCacheSelHPTW

      cache #(.P(P), .PA_BITS(P.PA_BITS), .LINELEN(P.DCACHE_LINELENINBITS), .NUMSETS(P.DCACHE_WAYSIZEINBYTES*8/LINELEN),
              .NUMWAYS(P.DCACHE_NUMWAYS), .LOGBWPL(LLENLOGBWPL), .WORDLEN(CACHEWORDLEN), .MUXINTERVAL(P.LLEN), .READ_ONLY_CACHE(0)) dcache(
        .clk, .reset, .Stall(GatedStallW & ~SelSpillE), .SelBusBeat, .FlushStage(LSUFlushW),
        .CacheRW(CacheRWM),
        .FlushCache(FlushDCache), .NextSet(IEUAdrExtE[11:0]), .PAdr(PAdrM),
        .ByteMask(ByteMaskSpillM), .BeatCount(BeatCount[AHBWLOGBWPL-1:AHBWLOGBWPL-LLENLOGBWPL]),
        .WriteData(LSUWriteDataSpillM), .SelHPTW,
        .CacheStall(DCacheStallM), .CacheMiss(DCacheMiss), .CacheAccess(DCacheAccess),
        .CacheCommitted(DCacheCommittedM),
        .CacheBusAdr(DCacheBusAdr), .ReadDataWord(DCacheReadDataWordM),
        .FetchBuffer, .CacheBusRW(CacheBusRW),
        .CacheBusAck(DCacheBusAck), .InvalidateCache(1'b0), .InvalidateFlushStage(LSUFlushW), .CMOpM(CacheCMOpM));

      ahbcacheinterface #(.P(P), .BEATSPERLINE(BEATSPERLINE), .AHBWLOGBWPL(AHBWLOGBWPL), .LINELEN(LINELEN),  .LLENPOVERAHBW(LLENPOVERAHBW), .READ_ONLY_CACHE(0)) ahbcacheinterface(
        .HCLK(clk), .HRESETn(~reset), .Flush(LSUFlushW),
        .HRDATA, .HWDATA(LSUHWDATA), .HWSTRB(LSUHWSTRB),
        .HSIZE(LSUHSIZE), .HBURST(LSUHBURST), .HTRANS(LSUHTRANS), .HWRITE(LSUHWRITE), .HREADY(LSUHREADY),
        .BeatCount, .SelBusBeat, .CacheReadDataWordM(DCacheReadDataWordM[P.LLEN-1:0]), .WriteDataM(LSUWriteDataM),
        .Funct3(LSUFunct3M), .HADDR(LSUHADDR), .CacheBusAdr(DCacheBusAdr), .CacheBusRW, .BusAtomic, .BusCMOZero, .CacheableOrFlushCacheM,
        .CacheBusAck(DCacheBusAck), .FetchBuffer, .PAdr(PAdrM),
        .Cacheable(CacheableOrFlushCacheM), .BusRW, .Stall(GatedStallW),
        .BusStall(LSUBusStallM), .BusCommitted(BusCommittedM));

      mux3 #(P.LLEN) UnCachedDataMux(.d0(DCacheReadDataWordSpillM), .d1({LLENPOVERAHBW{FetchBuffer[P.XLEN-1:0]}}),
                                    .d2({{P.LLEN-P.XLEN{1'b0}}, DTIMReadDataWordM[P.XLEN-1:0]}),
                                    .s({SelDTIM, ~(CacheableOrFlushCacheM)}), .y(ReadDataWordMuxM));
    end else begin : passthrough // No Cache, use simple ahbinterface instead of ahbcacheinterface
      logic [1:0] BusRW;                    // Non-DTIM memory access, ignore cacheableM
      logic [P.XLEN-1:0] FetchBuffer;
      assign BusRW = ~SelDTIM ? LSURWM : 0;

      assign LSUHADDR = PAdrM;
      assign LSUHSIZE = LSUFunct3M;

      ahbinterface #(P.XLEN, 1'b1) ahbinterface(.HCLK(clk), .HRESETn(~reset), .Flush(LSUFlushW), .HREADY(LSUHREADY),
        .HRDATA(HRDATA), .HTRANS(LSUHTRANS), .HWRITE(LSUHWRITE), .HWDATA(LSUHWDATA),
        .HWSTRB(LSUHWSTRB), .BusRW, .BusAtomic(AtomicM[1]), .ByteMask(ByteMaskM[P.XLEN/8-1:0]), .WriteData(LSUWriteDataM[P.XLEN-1:0]),
        .Stall(GatedStallW), .BusStall(LSUBusStallM), .BusCommitted(BusCommittedM), .FetchBuffer(FetchBuffer));

    // Mux between the 2 sources of read data, 0: Bus, 1: DTIM
      if(P.DTIM_SUPPORTED) mux2 #(P.XLEN) ReadDataMux2(FetchBuffer, DTIMReadDataWordM[P.XLEN-1:0], SelDTIM, ReadDataWordMuxM[P.XLEN-1:0]);
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

  flopen #(P.LLEN) ReadDataMWReg(clk, ~StallW, ReadDataM, ReadDataW);

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
