///////////////////////////////////////////
// ifu.sv
//
// Written: David_Harris@hmc.edu 9 January 2021
// Modified:
//
// Purpose: Instruction Fetch Unit
//           PC, branch prediction, instruction cache
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

module ifu import cvw::*;  #(parameter cvw_t P) (
  input  logic                 clk, reset,
  input  logic                 StallF, StallD, StallE, StallM, StallW,
  input  logic                 FlushD, FlushE, FlushM, FlushW,
  output logic                 IFUStallF,                                // IFU stalsl pipeline during a multicycle operation
  // Command from CPU
  input  logic                 InvalidateICacheM,                        // Clears all instruction cache valid bits
  input  logic                 CSRWriteFenceM,                           // CSR write or fence instruction, PCNextF = the next valid PC (typically PCE)
  input  logic                 InstrValidD, InstrValidE,
  input  logic                 BranchD, BranchE,
  input  logic                 JumpD, JumpE,
  // Bus interface
  output logic [P.PA_BITS-1:0] IFUHADDR,                                 // Bus address from IFU to EBU
  input  logic [P.XLEN-1:0]    HRDATA,                                   // Bus read data from IFU to EBU
  input  logic                 IFUHREADY,                                // Bus ready from IFU to EBU
  output logic                 IFUHWRITE,                                // Bus write operation from IFU to EBU
  output logic [2:0]           IFUHSIZE,                                 // Bus operation size from IFU to EBU
  output logic [2:0]           IFUHBURST,                                // Bus burst from IFU to EBU
  output logic [1:0]           IFUHTRANS,                                // Bus transaction type from IFU to EBU

  output logic [P.XLEN-1:0]    PCSpillF,                                 // PCF with possible + 2 to handle spill to HPTW
  // Execute
  output logic [P.XLEN-1:0]    PCLinkE,                                  // The address following the branch instruction. (AKA Fall through address)
  input  logic                 PCSrcE,                                   // Execution stage branch is taken
  input  logic [P.XLEN-1:0]    IEUAdrE,                                  // The branch/jump target address
  input  logic [P.XLEN-1:0]    IEUAdrM,                                  // The branch/jump target address
  output logic [P.XLEN-1:0]    PCE,                                      // Execution stage instruction address
  output logic                 BPWrongE,                                 // Prediction is wrong
  output logic                 BPWrongM,                                 // Prediction is wrong
  // Mem
  output logic                 CommittedF,                               // I$ or bus memory operation started, delay interrupts
  input  logic [P.XLEN-1:0]    EPCM,                                     // Exception Program counter from privileged unit
  input  logic [P.XLEN-1:0]    TrapVectorM,                              // Trap vector, from privileged unit
  input  logic                 RetM, TrapM,                              // return instruction, or trap
  output logic [31:0]          InstrD,                                   // The decoded instruction in Decode stage
  output logic [P.XLEN-1:0]    PCD,                                      // Decode stage instruction address
  output logic [31:0]          InstrM,                                   // The decoded instruction in Memory stage
  output logic [31:0]          InstrOrigM,                               // Original compressed or uncompressed instruction in Memory stage for Illegal Instruction MTVAL
  output logic [P.XLEN-1:0]    PCM,                                      // Memory stage instruction address
  output logic [P.XLEN-1:0]    PCSpillM,                                 // Memory stage instruction address
  // branch predictor
  output logic [3:0]           IClassM,                              // The valid instruction class. 1-hot encoded as jalr, ret, jr (not ret), j, br
  output logic                 BPDirWrongM,                          // Prediction direction is wrong
  output logic                 BTAWrongM,                                // Prediction target wrong
  output logic                 RASPredPCWrongM,                          // RAS prediction is wrong
  output logic                 IClassWrongM,                             // Class prediction is wrong
  output logic                 ICacheStallF,                             // I$ busy with multicycle operation
  // Faults
  input  logic                 IllegalBaseInstrD,                        // Illegal non-compressed instruction
  input  logic                 IllegalFPUInstrD,                         // Illegal FP instruction
  input  logic                 IllegalVPUInstrD,                         // Illegal vector instruction
  output logic                 InstrPageFaultF,                          // Instruction page fault
  output logic                 IllegalIEUFPUVPUInstrD,                      // Illegal instruction including compressed & FP
  output logic                 InstrMisalignedFaultM,                    // Branch target not aligned to 4 bytes if no compressed allowed (2 bytes if allowed)
  // mmu management
  input  logic [1:0]           PrivilegeModeW,                           // Privilege mode in Writeback stage
  input  logic [P.XLEN-1:0]    PTE,                                      // Hardware page table walker (HPTW) writes Page table entry (PTE) to ITLB
  input  logic [2:0]           PageType,                                 // Hardware page table walker (HPTW) writes PageType to ITLB
  input  logic                 ITLBWriteF,                               // Writes PTE and PageType to ITLB
  input  logic [P.XLEN-1:0]    SATP_REGW,                                // Location of the root page table and page table configuration
  input  logic                 STATUS_MXR,                               // Status CSR: make executable page readable
  input  logic                 STATUS_SUM,                               // Status CSR: Supervisor access to user memory
  input  logic                 STATUS_MPRV,                              // Status CSR: modify machine privilege
  input  logic [1:0]           STATUS_MPP,                               // Status CSR: previous machine privilege level
  input  logic                 ENVCFG_PBMTE,                             // Page-based memory types enabled
  input  logic                 ENVCFG_ADUE,                              // HPTW A/D Update enable
  input  logic                 sfencevmaM,                               // Virtual memory address fence, invalidate TLB entries
  output logic                 ITLBMissOrUpdateAF,                       // ITLB miss causes HPTW (hardware pagetable walker) walk or update access bit
  input  var logic [7:0]       PMPCFG_ARRAY_REGW[P.PMP_ENTRIES-1:0],     // PMP configuration from privileged unit
  input  var logic [P.PA_BITS-3:0] PMPADDR_ARRAY_REGW[P.PMP_ENTRIES-1:0],// PMP address from privileged unit
  output logic                 InstrAccessFaultF,                        // Instruction access fault
  output logic                 ICacheAccess,                             // Report I$ read to performance counters
  output logic                 ICacheMiss                                // Report I$ miss to performance counters
);

  localparam [31:0]            nop = 32'h00000013;                       // instruction for NOP
  localparam            LINELEN = P.ICACHE_SUPPORTED ? P.ICACHE_LINELENINBITS : P.XLEN;

  logic [P.XLEN-1:0]           PCNextF;                                  // Next PCF, selected from Branch predictor, Privilege, or PC+2/4
  logic [P.XLEN-1:0]           PC1NextF;                                 // Branch predictor next PCF
  logic [P.XLEN-1:0]           PC2NextF;                                 // Selected PC between branch prediction and next valid PC if CSRWriteFence
  logic [P.XLEN-1:0]           UnalignedPCNextF;                         // The next PCF, but not aligned to 2 bytes.
  logic                        InstrMisalignedFaultE;                    // Branch/jump target not aligned to 4 bytes if no compressed allowed (2 bytes if allowed)
  logic [P.XLEN-1:0]           PCPlus2or4F;                              // PCF + 2 (CompressedF) or PCF + 4 (Non-compressed)
  logic [P.XLEN-1:0]           PCSpillNextF;                             // Next PCF after possible + 2 to handle spill
  logic [P.XLEN-1:2]           PCPlus4F;                                 // PCPlus4F is always PCF + 4.  Fancy way to compute PCPlus2or4F
  logic [P.XLEN-1:0]           NextValidPCE;                             // The PC of the next valid instruction in the pipeline after  csr write or fence
  logic [P.XLEN-1:0]           PCF;                                      // Fetch stage instruction address
  logic [P.PA_BITS-1:0]        PCPF;                                     // Physical address after address translation
  logic [P.XLEN+1:0]           PCFExt;

  logic [31:0]                 IROMInstrF;                               // Instruction from the IROM
  logic [31:0]                 ICacheInstrF;                             // Instruction from the I$
  logic [31:0]                 InstrRawF;                                // Instruction from the IROM, I$, or bus
  logic                        CompressedF, CompressedE;                 // The fetched instruction is compressed
  logic [31:0]                 PostSpillInstrRawF;                       // Fetch instruction after merge two halves of spill
  logic [31:0]                 InstrRawD;                                // Non-decompressed instruction in the Decode stage
  logic                        IllegalIEUInstrD;                         // IEU Instruction (regular or compressed) is not good

  logic [1:0]                  IFURWF;                                   // IFU alreays read IFURWF = 10
  logic [31:0]                 InstrE;                                   // Instruction in the Execution stage
  logic [31:0]                 NextInstrD, NextInstrE;                   // Instruction into the next stage after possible stage flush

  logic                        CacheableF;                               // PMA indicates instruction address is cacheable
  logic                        SelSpillNextF;                            // In a spill, stall pipeline and gate local stallF
  logic                        BusStall;                                 // Bus interface busy with multicycle operation
  logic                        IFUCacheBusStallF;                        // EIther I$ or bus busy with multicycle operation
  logic                        GatedStallD;                              // StallD gated by selected next spill
  // branch predictor signal
  logic                        BusCommittedF;                            // Bus memory operation in flight, delay interrupts
  logic                        CacheCommittedF;                          // I$ memory operation started, delay interrupts
  logic                        SelIROM;                                  // PMA indicates instruction address is in the IROM
  logic [15:0]                 InstrRawE, InstrRawM;
  logic [LINELEN-1:0]          FetchBuffer;
  logic [31:0]                 ShiftUncachedInstr;
  logic                        ITLBMissF;
  logic                        InstrUpdateAF;                            // ITLB hit needs to update dirty or access bits

  assign PCFExt = {2'b00, PCSpillF};

  /////////////////////////////////////////////////////////////////////////////////////////////
  // Spill Support
  /////////////////////////////////////////////////////////////////////////////////////////////

  if(P.ZCA_SUPPORTED) begin : Spill
    logic [P.XLEN-1:0] PCSpillD, PCSpillE;
    logic [P.XLEN-1:0] PCIncrM;
    logic              SelSpillF, SelSpillD, SelSpillE, SelSpillM;
    spill #(P) spill(.clk, .reset, .StallF, .FlushD, .PCF, .PCPlus4F, .PCNextF, .InstrRawF,  .CacheableF,
      .IFUCacheBusStallF, .ITLBMissOrUpdateAF, .PCSpillNextF, .PCSpillF, .SelSpillNextF, .SelSpillF, .PostSpillInstrRawF, .CompressedF);
    flopenr #(1) SpillDReg(clk, reset, ~StallD, SelSpillF, SelSpillD);
    flopenr #(1) SpillEReg(clk, reset, ~StallE, SelSpillD, SelSpillE);
    flopenr #(1) SpillMReg(clk, reset, ~StallM, SelSpillE, SelSpillM);
    assign PCIncrM = PCM + 'd2;
    mux2 #(P.XLEN) pcspillmmux(PCM, PCIncrM, SelSpillM, PCSpillM);

  end else begin : NoSpill
    assign PCSpillNextF = PCNextF;
    assign PCSpillF = PCF;
    assign PostSpillInstrRawF = InstrRawF;
    assign {SelSpillNextF, CompressedF} = '0;
    assign PCSpillM = PCM;
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Memory management
  ////////////////////////////////////////////////////////////////////////////////////////////////

  if(P.ZICSR_SUPPORTED == 1) begin : immu
    ///////////////////////////////////////////
    // sfence.vma causes TLB flushes
    ///////////////////////////////////////////
    // sets ITLBFlush to pulse for one cycle of the sfence.vma instruction
    // In this instr we want to flush the tlb and then do a pagetable walk to update the itlb and continue the program.
    // But we're still in the stalled sfence instruction, so if itlbflushf == sfencevmaM, tlbflush would never drop and
    // the tlbwrite would never take place after the pagetable walk. by adding in ~StallMQ, we are able to drop itlbflush
    // after a cycle AND pulse it for another cycle on any further back-to-back sfences.
    logic StallMQ, TLBFlush;
    flopr #(1) StallMReg(.clk, .reset, .d(StallM), .q(StallMQ));
    assign TLBFlush = sfencevmaM & ~StallMQ;

    mmu #(.P(P), .TLB_ENTRIES(P.ITLB_ENTRIES), .IMMU(1))
    immu(.clk, .reset, .SATP_REGW, .STATUS_MXR, .STATUS_SUM, .STATUS_MPRV, .STATUS_MPP, .ENVCFG_PBMTE, .ENVCFG_ADUE,
         .PrivilegeModeW, .DisableTranslation(1'b0),
         .VAdr(PCFExt),
         .Size(2'b10),
         .PTE(PTE),
         .PageTypeWriteVal(PageType),
         .TLBWrite(ITLBWriteF),
         .TLBFlush,
         .PhysicalAddress(PCPF),
         .TLBMiss(ITLBMissF),
         .Cacheable(CacheableF), .Idempotent(), .SelTIM(SelIROM),
         .InstrAccessFaultF, .LoadAccessFaultM(), .StoreAmoAccessFaultM(),
         .InstrPageFaultF, .LoadPageFaultM(), .StoreAmoPageFaultM(),
         .LoadMisalignedFaultM(), .StoreAmoMisalignedFaultM(),
         .UpdateDA(InstrUpdateAF), .CMOpM(4'b0),
         .AtomicAccessM(1'b0),.ExecuteAccessF(1'b1), .WriteAccessM(1'b0), .ReadAccessM(1'b0),
         .PMPCFG_ARRAY_REGW, .PMPADDR_ARRAY_REGW);

     assign ITLBMissOrUpdateAF = ITLBMissF | (P.SVADU_SUPPORTED & InstrUpdateAF);
  end else begin
    assign {ITLBMissF, InstrAccessFaultF, InstrPageFaultF, InstrUpdateAF} = '0;
    assign PCPF = PCFExt[P.PA_BITS-1:0];
    assign CacheableF = 1'b1;
    assign SelIROM = '0;
    assign ITLBMissOrUpdateAF = '0;
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Memory
  ////////////////////////////////////////////////////////////////////////////////////////////////

  // CommittedM tells the CPU's privileged unit the current instruction
  // in the memory stage is a memory operation and that memory operation is either completed
  // or is partially executed. Partially completed memory operations need to prevent an interrupts.
  // There is not a clean way to restore back to a partial executed instruction.  CommiteedM will
  // delay the interrupt until the LSU is in a clean state.
  assign CommittedF = CacheCommittedF | BusCommittedF;

  // The IROM uses untranslated addresses, so it is not compatible with virtual memory.
  if (P.IROM_SUPPORTED) begin : irom
    logic IROMce;
    assign IROMce = ~GatedStallD | reset;
    assign IFURWF = 2'b10;
    irom #(P) irom(.clk, .ce(IROMce), .Adr(PCSpillNextF[P.XLEN-1:0]), .IROMInstrF);
  end else begin
    assign IFURWF = 2'b10;
    assign IROMInstrF = '0;
  end
  if (P.BUS_SUPPORTED) begin : bus
    localparam   BEATSPERLINE = P.ICACHE_SUPPORTED ? P.ICACHE_LINELENINBITS/P.AHBW : 1;
    localparam   AHBWLOGBWPL = P.ICACHE_SUPPORTED ? $clog2(BEATSPERLINE) : 1;

    if(P.ICACHE_SUPPORTED) begin : icache
      localparam            LLENPOVERAHBW = P.LLEN / P.AHBW; // Number of AHB beats in a LLEN word. AHBW cannot be larger than LLEN. (implementation limitation)
      logic [P.PA_BITS-1:0] ICacheBusAdr;
      logic                 ICacheBusAck;
      logic [1:0]           CacheBusRW, BusRW, CacheRWF;

      assign BusRW = ~ITLBMissF & ~CacheableF & ~SelIROM ? IFURWF : '0;
      assign CacheRWF = ~ITLBMissF & CacheableF & ~SelIROM ? IFURWF : '0;
      cache #(.P(P), .PA_BITS(P.PA_BITS), .LINELEN(P.ICACHE_LINELENINBITS),
              .NUMSETS(P.ICACHE_WAYSIZEINBYTES*8/P.ICACHE_LINELENINBITS),
              .NUMWAYS(P.ICACHE_NUMWAYS), .LOGBWPL(AHBWLOGBWPL), .WORDLEN(32), .MUXINTERVAL(16), .READ_ONLY_CACHE(1))
      icache(.clk, .reset, .FlushStage(FlushD), .Stall(GatedStallD),
             .FetchBuffer, .CacheBusAck(ICacheBusAck),
             .CacheBusAdr(ICacheBusAdr), .CacheStall(ICacheStallF),
             .CacheBusRW,
             .ReadDataWord(ICacheInstrF),
             .SelHPTW('0),
             .CacheMiss(ICacheMiss), .CacheAccess(ICacheAccess),
             .ByteMask('0), .BeatCount('0), .SelBusBeat('0),
             .WriteData('0),
             .CacheRW(CacheRWF),
             .FlushCache('0),
             .NextSet(PCSpillNextF[11:0]),
             .PAdr(PCPF),
             .CacheCommitted(CacheCommittedF), .InvalidateCache(InvalidateICacheM), .InvalidateFlushStage(FlushW), .CMOpM('0));

      ahbcacheinterface #(P, BEATSPERLINE, AHBWLOGBWPL, LINELEN, LLENPOVERAHBW, 1)
      ahbcacheinterface(.HCLK(clk), .HRESETn(~reset),
            .HRDATA,
            .Flush(FlushD), .CacheBusRW, .BusCMOZero(1'b0), .HSIZE(IFUHSIZE), .HBURST(IFUHBURST), .HTRANS(IFUHTRANS), .HWSTRB(),
            .Funct3(3'b010), .HADDR(IFUHADDR), .HREADY(IFUHREADY), .HWRITE(IFUHWRITE), .CacheBusAdr(ICacheBusAdr),
            .BeatCount(), .Cacheable(CacheableF), .SelBusBeat(), .WriteDataM('0), .BusAtomic('0),
            .CacheBusAck(ICacheBusAck), .HWDATA(), .CacheableOrFlushCacheM(1'b0), .CacheReadDataWordM('0),
            .FetchBuffer, .PAdr(PCPF),
            .BusRW, .Stall(GatedStallD),
            .BusStall, .BusCommitted(BusCommittedF));

      mux3 #(32) UnCachedDataMux(.d0(ICacheInstrF), .d1(ShiftUncachedInstr), .d2(IROMInstrF),
                                 .s({SelIROM, ~CacheableF}), .y(InstrRawF[31:0]));
    end else begin : passthrough
      assign IFUHADDR = PCPF;
      logic [1:0] BusRW;
      assign BusRW = ~ITLBMissF & ~SelIROM ? IFURWF : 0;
      assign IFUHSIZE = 3'b010;

      ahbinterface #(P.XLEN, 1'b0) ahbinterface(.HCLK(clk), .Flush(FlushD), .HRESETn(~reset), .HREADY(IFUHREADY),
        .HRDATA(HRDATA), .HTRANS(IFUHTRANS), .HWRITE(IFUHWRITE), .HWDATA(),
        .HWSTRB(), .BusRW, .BusAtomic('0), .ByteMask(), .WriteData('0),
        .Stall(GatedStallD), .BusStall, .BusCommitted(BusCommittedF), .FetchBuffer(FetchBuffer));

      assign CacheCommittedF = '0;
      if(P.IROM_SUPPORTED) mux2 #(32) UnCachedDataMux2(ShiftUncachedInstr, IROMInstrF, SelIROM, InstrRawF);
      else assign InstrRawF = ShiftUncachedInstr;
      assign IFUHBURST = 3'b0;
      assign {ICacheMiss, ICacheAccess, ICacheStallF} = '0;
    end

    // mux between the alignments of uncached reads.
    if(P.XLEN == 64) mux4 #(32) UncachedShiftInstrMux(FetchBuffer[32-1:0], FetchBuffer[48-1:16],
                                                      FetchBuffer[64-1:32], {16'b0, FetchBuffer[64-1:48]},
                                                      PCSpillF[2:1], ShiftUncachedInstr);
    else mux2 #(32) UncachedShiftInstrMux(FetchBuffer[32-1:0], {16'b0, FetchBuffer[32-1:16]}, PCSpillF[1], ShiftUncachedInstr);
  end else begin : nobus // block: bus
    assign {IFUHADDR, IFUHWRITE, IFUHSIZE, IFUHBURST, IFUHTRANS,
            BusStall, CacheCommittedF, BusCommittedF, FetchBuffer} = '0;
    assign {ICacheStallF, ICacheMiss, ICacheAccess} = '0;
    assign InstrRawF = IROMInstrF;
  end

  assign IFUCacheBusStallF = ICacheStallF | BusStall;
  assign IFUStallF = IFUCacheBusStallF | SelSpillNextF;
  assign GatedStallD = StallD & ~SelSpillNextF;

  flopenl #(32) AlignedInstrRawDFlop(clk, reset | FlushD, ~StallD, PostSpillInstrRawF, nop, InstrRawD);

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // PCNextF logic
  ////////////////////////////////////////////////////////////////////////////////////////////////

  if(P.ZICSR_SUPPORTED | P.ZIFENCEI_SUPPORTED)
    mux2 #(P.XLEN) pcmux2(.d0(PC1NextF), .d1(NextValidPCE), .s(CSRWriteFenceM),.y(PC2NextF));
  else assign PC2NextF = PC1NextF;

  mux3 #(P.XLEN) pcmux3(PC2NextF, EPCM, TrapVectorM, {TrapM, RetM}, UnalignedPCNextF);
  mux2 #(P.XLEN) pcresetmux({UnalignedPCNextF[P.XLEN-1:1], 1'b0}, P.RESET_VECTOR[P.XLEN-1:0], reset, PCNextF);
  flopen #(P.XLEN) pcreg(clk, ~StallF | reset, PCNextF, PCF);

  // pcadder
  // add 2 or 4 to the PC, based on whether the instruction is 16 bits or 32
  assign PCPlus4F = PCF[P.XLEN-1:2] + 1; // add 4 to PC

  if (P.ZCA_SUPPORTED) begin : pcadd
    // choose PC+2 or PC+4 based on CompressedF, which arrives later.
    // Speeds up critical path as compared to selecting adder input based on CompressedF
    always_comb
      if (CompressedF) // add 2
        if (PCF[1]) PCPlus2or4F = {PCPlus4F, 2'b00};
        else        PCPlus2or4F = {PCF[P.XLEN-1:2], 2'b10};
      else          PCPlus2or4F = {PCPlus4F, PCF[1:0]}; // add 4
  end else begin : pcadd
    assign PCPlus2or4F = {PCPlus4F, PCF[1:0]}; // always add 4 if compressed instructions are not supported
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Branch and Jump Predictor
  ////////////////////////////////////////////////////////////////////////////////////////////////
  if (P.BPRED_SUPPORTED) begin : bpred
    bpred #(P) bpred(.clk, .reset,
                .StallF, .StallD, .StallE, .StallM, .StallW,
                .FlushD, .FlushE, .FlushM, .FlushW, .InstrValidD, .InstrValidE,
                .BranchD, .BranchE, .JumpD, .JumpE,
                .InstrD, .PCNextF, .PCPlus2or4F, .PC1NextF, .PCE, .PCM, .PCSrcE, .IEUAdrE, .IEUAdrM, .PCF, .NextValidPCE,
                .PCD, .PCLinkE, .IClassM, .BPWrongE, .PostSpillInstrRawF, .BPWrongM,
                .BPDirWrongM, .BTAWrongM, .RASPredPCWrongM, .IClassWrongM);

  end else begin : bpred
    mux2 #(P.XLEN) pcmux1(.d0(PCPlus2or4F), .d1(IEUAdrE), .s(PCSrcE), .y(PC1NextF));
    logic BranchM, JumpM, BranchW, JumpW;
    logic CallD, CallE, CallM, CallW;
    logic ReturnD, ReturnE, ReturnM, ReturnW;
    assign BPWrongE = PCSrcE;
    icpred #(P, 0) icpred(.clk, .reset, .StallD, .StallE, .StallM, .StallW, .FlushD, .FlushE, .FlushM,
      .PostSpillInstrRawF, .InstrD, .BranchD, .BranchE, .JumpD, .JumpE, .BranchM, .BranchW, .JumpM, .JumpW,
      .CallD, .CallE, .CallM, .CallW, .ReturnD, .ReturnE, .ReturnM, .ReturnW,
      .BTBCallF(1'b0), .BTBReturnF(1'b0), .BTBJumpF(1'b0),
      .BTBBranchF(1'b0), .BPCallF(), .BPReturnF(), .BPJumpF(), .BPBranchF(), .IClassWrongM,
      .BPReturnWrongD());
    flopenrc #(1) PCSrcMReg(clk, reset, FlushM, ~StallM, PCSrcE, BPWrongM);
    assign RASPredPCWrongM = 1'b0;
    assign BPDirWrongM = BPWrongM;
    assign BTAWrongM = BPWrongM;
    assign IClassM = {CallM, ReturnM, JumpM, BranchM};
    assign NextValidPCE = PCE;
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Decode stage pipeline register and compressed instruction decoding.
  ////////////////////////////////////////////////////////////////////////////////////////////////

  // Decode stage pipeline register and logic
  flopenrc #(P.XLEN) PCDReg(clk, reset, FlushD, ~StallD, PCF, PCD);

  // expand 16-bit compressed instructions to 32 bits
  if (P.ZCA_SUPPORTED) begin : decomp
    logic IllegalCompInstrD;
    decompress #(P) decomp(.InstrRawD, .InstrD, .IllegalCompInstrD);
    assign IllegalIEUInstrD = IllegalBaseInstrD | IllegalCompInstrD; // illegal if bad 32 or 16-bit instr
  end else begin : decomp
    assign InstrD = InstrRawD;
    assign IllegalIEUInstrD = IllegalBaseInstrD;
  end
  assign IllegalIEUFPUVPUInstrD = IllegalIEUInstrD & (IllegalFPUInstrD | !P.F_SUPPORTED) & (IllegalVPUInstrD | !P.V_SUPPORTED); // *** this isn't quite correct.  it should be F_SUPPORTED or any fpu suported

  // Misaligned PC logic
  // Instruction address misalignment only from br/jal(r) instructions.
  // instruction address misalignment is generated by the target of control flow instructions, not
  // the fetch itself.
  // xret and Traps both cannot produce instruction misaligned.
  // xret: mepc is an MXLEN-bit read/write register formatted as shown in Figure 3.21.
  // The low bit of mepc (mepc[0]) is always zero. On implementations that support
  // only IALIGN=32, the two low bits (mepc[1:0]) are always zero.
  // Spec 3.1.14
  // Traps: Can’t happen.  The bottom two bits of MTVEC are ignored so the trap always is to a multiple of 4.  See 3.1.7 of the privileged spec.
  assign InstrMisalignedFaultE = (IEUAdrE[1] & ~P.ZCA_SUPPORTED) & PCSrcE;
  flopenr #(1) InstrMisalignedReg(clk, reset, ~StallM, InstrMisalignedFaultE, InstrMisalignedFaultM);

  // Instruction and PC pipeline registers flush to NOP, not zero
  mux2    #(32)     FlushInstrEMux(InstrD, nop, FlushE, NextInstrD);
  flopenr #(32)     InstrEReg(clk, reset, ~StallE, NextInstrD, InstrE);
  flopenr #(P.XLEN) PCEReg(clk, reset, ~StallE, PCD, PCE);

  // InstrM is only needed with CSRs or atomic operations
  if (P.ZICSR_SUPPORTED | P.ZAAMO_SUPPORTED | P.ZALRSC_SUPPORTED) begin
    mux2    #(32)     FlushInstrMMux(InstrE, nop, FlushM, NextInstrE);
    flopenr #(32)     InstrMReg(clk, reset, ~StallM, NextInstrE, InstrM);
  end else assign InstrM = '0;
  // PCM is only needed with CSRs or branch prediction
  if (P.ZICSR_SUPPORTED | P.BPRED_SUPPORTED)
    flopenr #(P.XLEN) PCMReg(clk, reset, ~StallM, PCE, PCM);
  else assign PCM = '0;

  // If compressed instructions are supported, increment PCLink by 2 or 4 for a jal.  Otherwise, just by 4
  if (P.ZCA_SUPPORTED) begin
    logic CompressedD;  // instruction is compressed
    flopenrc #(1) CompressedDReg(clk, reset, FlushD, ~StallD, CompressedF, CompressedD);
    flopenrc #(1) CompressedEReg(clk, reset, FlushE, ~StallE, CompressedD, CompressedE);
    assign PCLinkE = PCE + (CompressedE ? 'd2 : 'd4); // 'd4 means 4 but stops Design Compiler complaining about signed to unsigned conversion
  end else begin
    assign CompressedE = 1'b0;
    assign PCLinkE = PCE + 'd4;
  end

  // pipeline original compressed instruction in case it is needed for MTVAL on an illegal instruction exception
  if (P.ZICSR_SUPPORTED & P.ZCA_SUPPORTED | 1) begin
    logic CompressedM; // instruction is compressed
    flopenrc #(16) InstrRawEReg(clk, reset, FlushE, ~StallE, InstrRawD[15:0], InstrRawE);
    flopenrc #(16) InstrRawMReg(clk, reset, FlushM, ~StallM, InstrRawE, InstrRawM);
    flopenrc #(1)  CompressedMReg(clk, reset, FlushM, ~StallM, CompressedE, CompressedM);
    mux2     #(32) InstrOrigMux(InstrM, {16'b0, InstrRawM}, CompressedM, InstrOrigM);
  end else
    assign InstrOrigM = InstrM;

endmodule
