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
////////////////////////////////////////////////////////////////////////////////////////////////

module ifu import cvw::*;  #(parameter cvw_t P) (
  input  logic                 clk, reset,
  input  logic                 StallF, StallD, StallE, StallM, StallW,
  input  logic                 FlushD, FlushE, FlushM, FlushW,
  output logic                 IFUStallF,                                // IFU stalls pipeline during a multicycle operation
  // Command from CPU
  input  logic                 InvalidateICacheM,                        // Clears all instruction cache valid bits
  input  logic                 CSRWriteFenceM,                           // CSR write or fence instruction, PCNextF = the next valid PC (typically PCE)
  input  logic                 InstrValidD, InstrValidE,
  input  logic                 BranchD, BranchE,
  input  logic                 JumpD, JumpE,
  // Bus interface
  output logic [P.PA_BITS-1:0] IFUHADDR,                                 // Bus address from IFU to EBU
  input  logic [P.XLEN-1:0]    HRDATA,                                   // Bus read data from EBU to IFU
  input  logic                 IFUHREADY,                                // Bus ready from EBU to IFU
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
  input  logic                 Branch2D, Branch2E,                       // Slot 1 is a conditional branch (Branch2D before the issue decision)
  input  logic                 Jump2D, Jump2E,                           // ... or a jal
  input  logic                 PCSrc2E,                                  // ... that resolved taken (always, for a jal)
  input  logic [P.XLEN-1:0]    IEUAdr2E,                                 // ... to this target
  output logic [P.XLEN-1:0]    PCLink2E,                                 // The address following slot 1: a slot 1 jal's link value
  output logic [P.XLEN-1:0]    PCE,                                     // Execution stage instruction address
  output logic                 BPWrongE,                                 // Prediction is wrong
  output logic                 BPWrongM,                                 // Prediction is wrong
  // Mem
  output logic                 CommittedF,                               // I$ or bus memory operation started, delay interrupts
  input  logic [P.XLEN-1:0]    EPCM,                                     // Exception Program counter from privileged unit
  input  logic [P.XLEN-1:0]    TrapVectorM,                              // Trap vector, from privileged unit
  input  logic                 RetM, TrapM,                              // return instruction, or trap
  output logic [31:0]          InstrD,                                   // The decoded instruction in Decode stage
  output logic [31:0]          Instr2D,                                  // Second decoded instruction in Decode stage (superscalar slot 1)
  output logic                 Issue2D, Issue2E,                         // Slot 1 issues alongside slot 0 in Decode / Execute
  output logic                 LateA2D, LateB2D,                         // Slot 1's rs1 / rs2 is slot 0's rd (late ALU bypass)
  output logic                 LateOK2D,                                 // Slot 1 is an operation the late ALU implements
  output logic                 Fuse2D,                                   // The pair is fused into one indexed load (issue.sv)
  output logic                 FuseBr2D,                                 // The pair is fused into one ALU op + branch (issue.sv)
  output logic                 FuseBrAdd2D,                              // ... and slot 0 is an add (else a logic op)
  output logic                 Issue2M, Issue2W,                         // ... and in Memory / Writeback, where it commits
  input  logic                 Replay2M,                                 // Slot 1's memory operation faulted; refetch it alone
  output logic                 PredTakenE,                               // Fetch went to slot 0's predicted target
  input  logic                 LateBrM, LateBrTakenM,                    // Slot 0's branch was checked in Memory, and its direction
  input  logic                 LateBrWrongM,                             // ... which is not the way fetch went
  output logic                 IllegalComp2M,                            // Slot 1 is an illegal compressed instruction; replay it
  output logic [31:0]          InstrM,                                   // The decoded instruction in Memory stage
  output logic [31:0]          InstrOrigM,                               // Original compressed or uncompressed instruction in Memory stage for Illegal Instruction XTVAL
  output logic [P.XLEN-1:0]    PCM,                                      // Memory stage instruction address
  output logic [P.XLEN-1:0]    PCSpillM,                                 // PCM, plus 2 if the instruction spilled across two fetches
  // branch predictor
  output logic [3:0]           IClassM,                                  // The valid instruction class. 1-hot encoded as {call, return, jump, branch}
  output logic                 BPDirWrongM,                              // Prediction direction is wrong
  output logic                 BTAWrongM,                                // Prediction target wrong
  output logic                 RASPredPCWrongM,                          // RAS prediction is wrong
  output logic                 IClassWrongM,                             // Class prediction is wrong
  output logic                 ICacheStallF,                             // I$ busy with multicycle operation
  // Faults
  input  logic                 IllegalBaseInstrD,                        // Illegal non-compressed instruction
  input  logic                 IllegalFPUInstrD,                         // Illegal FP instruction
  output logic                 InstrPageFaultF,                          // Instruction page fault
  output logic                 IllegalIEUFPUInstrD,                      // Illegal instruction including compressed & FP
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
  input  logic                 sfencevmaAllM,                            // sfence.vma with rs2=x0: flush all TLB entries including global
  output logic                 ITLBMissOrUpdateAF,                       // ITLB miss causes HPTW (hardware pagetable walker) walk or update access bit (masked while a walk fault is held)
  input  logic                 HPTWInstrAccessFaultF,                    // HPTW access fault while walking for the fetch (one-cycle pulse from the walker)
  input  logic                 HPTWInstrPageFaultF,                      // HPTW page fault while walking for the fetch (one-cycle pulse from the walker)
  output logic                 HPTWInstrAccessFaultHeldF,                // HPTW access fault for the current fetch, held until the fetch advances
  output logic                 HPTWInstrPageFaultHeldF,                  // HPTW page fault for the current fetch, held until the fetch advances
  input  var logic [7:0]       PMPCFG_ARRAY_REGW[P.PMP_ENTRIES-1:0],     // PMP configuration from privileged unit
  input  var logic [P.PA_BITS-3:0] PMPADDR_ARRAY_REGW[P.PMP_ENTRIES-1:0], // PMP address from privileged unit
  output logic                 InstrAccessFaultF,                        // Instruction access fault
  output logic                 ICacheAccess,                             // Report I$ read to performance counters
  output logic                 ICacheMiss                                // Report I$ miss to performance counters
);

  localparam [31:0]            nop = 32'h00000013;                       // instruction for NOP
  localparam                   LINELEN = P.ICACHE_SUPPORTED ? P.ICACHE_LINELENINBITS : P.XLEN;
  localparam                   FETCHWIDTH = 64;                          // Two 32-bit instruction slots fetched per cycle for superscalar

  logic [P.XLEN-1:0]           PCNextF;                                  // Next PCF, selected from Branch predictor, Privilege, or PC+2/4
  logic [P.XLEN-1:0]           PC1NextF;                                 // Branch predictor next PCF
  logic [P.XLEN-1:0]           PC2NextF;                                 // Selected PC between branch prediction and next valid PC if CSRWriteFence
  logic [P.XLEN-1:0]           UnalignedPCNextF;                         // The next PCF, but not aligned to 2 bytes.
  logic                        InstrMisalignedFaultE;                    // Branch/jump target not aligned to 4 bytes if no compressed allowed (2 bytes if allowed)
  logic [P.XLEN-1:0]           PCPlus2or4F;                              // PCF + 2 (CompressedF) or PCF + 4 (Non-compressed): the address of slot 1
  logic [P.XLEN-1:0]           PCNextSeqF;                               // Fall-through PC: the first instruction not executed this cycle (PCPlus2or4F, or PCF + 8 when both slots issue)
  logic [P.XLEN-1:0]           PCSpillNextF;                             // Next PCF after possible + 2 to handle spill
  logic [P.XLEN-1:2]           PCPlus4F;                                 // PCPlus4F is always PCF + 4.  Fancy way to compute PCPlus2or4F
  logic [P.XLEN-1:0]           PCD;                                      // Decode stage instruction address
  logic [P.XLEN-1:0]           NextValidPCE;                             // The PC of the next valid instruction in the pipeline after csr write or fence
  logic [P.XLEN-1:0]           RedirectPCM;                              // Memory stage redirect target: csr write / fence, or a slot 1 replay
  logic [P.XLEN-1:0]           PCF;                                      // Fetch stage instruction address
  logic [P.PA_BITS-1:0]        PCPF;                                     // Physical address after address translation
  logic [P.XLEN+1:0]           PCFExt;

  logic [31:0]                 IROMInstrF;                               // Instruction from the IROM
  logic [FETCHWIDTH-1:0]       ICacheInstrF;                             // Two instruction slots from the I$: [31:0] at PCSpillF, [63:32] the next 32 bits
  logic [FETCHWIDTH-1:0]       FetchDataF;                               // Fetch window from the IROM, I$, or bus: [31:0] instr at PCSpillF, [63:32] next 32 bits
  logic [31:0]                 InstrRawF;                                // First fetched instruction (slot 0) from the IROM, I$, or bus
  logic                        CompressedF, CompressedE, CompressedM;    // The fetched instruction is compressed
  logic                        Compressed2F, Compressed2E;               // Slot 1 is a 16-bit instruction
  logic                        IllegalCompInstr2D;                       // Slot 1's decompressor rejected its encoding
  logic [P.XLEN-1:0]           PCBundleEndF;                             // Address just past both slots of the bundle
  logic [31:0]                 PostSpillInstrRawF;                       // Fetch instruction after merge two halves of spill
  logic [31:0]                 InstrRawD;                                // Non-decompressed instruction in the Decode stage
  logic                        IllegalIEUInstrD;                         // IEU Instruction (regular or compressed) is not good

  // Second instruction slot (superscalar).  Slot 1 is the instruction following slot 0 in the fetch window.
  // It is decoded in parallel with slot 0 but not yet issued to Execute.
  logic [31:0]                 Instr2RawF;                               // Slot 1 raw instruction, aligned to start at bit 0
  logic                        Instr2ValidF;                             // Slot 1 holds a complete instruction from the I$
  logic [31:0]                 Instr2RawD;                               // Slot 1 raw instruction in the Decode stage
  logic [P.XLEN-1:0]           Instr2PCD;                                // Slot 1 instruction address in the Decode stage
  logic                        Instr2ValidD;                             // Slot 1 in Decode holds a complete instruction
  logic                        Issue2F;                                  // Both slots may issue together
  logic                        PredTakenD;                               // Fetch went to slot 0's predicted target
  logic [P.XLEN-1:0]           RedirectSeqPCM;                           // Memory stage redirect, before a late branch's target
  logic                        LateA2F, LateB2F;                         // ... and which of slot 1's operands are slot 0's result
  logic                        LateOK2F;                                 // ... and whether slot 1 could run on the late ALU
  logic                        Fuse2F;                                   // ... and whether the pair fuses into one indexed load
  logic                        FuseBr2F;                                 // ... or into one ALU op + branch
  logic                        FuseBrAdd2F;                              // ... whose slot 0 is an add
  logic                        Kill2E;                                   // Slot 1 issued but must not commit
  logic                        Commit2E;                                 // Slot 1 issued and will commit
  logic                        BPPCSrcF;                                 // Branch predictor says this fetch is a taken branch or jump
  logic                        SelSpillF;                                // Fetching the second half of an instruction that spills across a line

  logic [1:0]                  IFURWF;                                   // IFU always reads: IFURWF = 10
  logic [31:0]                 InstrE;                                   // Instruction in the Execution stage
  logic [31:0]                 NextInstrD, NextInstrE;                   // Instruction into the next stage after possible stage flush

  logic                        CacheableF;                               // PMA indicates instruction address is cacheable
  logic                        SelSpillNextF;                            // In a spill, stall pipeline and gate local stallF
  logic                        BusStall;                                 // Bus interface busy with multicycle operation
  logic                        IFUCacheBusStallF;                        // Either I$ or bus busy with multicycle operation
  logic                        GatedStallD;                              // StallD gated by selected next spill
  logic                        BusCommittedF;                            // Bus memory operation in flight, delay interrupts
  logic                        CacheCommittedF;                          // I$ memory operation started, delay interrupts
  logic                        SelIROM;                                  // PMA indicates instruction address is in the IROM
  logic [LINELEN-1:0]          FetchBuffer;
  logic [FETCHWIDTH-1:0]       ShiftUncachedInstr;                       // Uncached fetch window; slot 1 has an instruction/value only when the bus is 64 bits
  logic                        ITLBMissF;
  logic                        InstrUpdateAF;                            // ITLB hit needs to update dirty or access bits
  logic                        IFUFaultF;                                // Fetch failed the PMA or PMP check, so it must not access the cache or bus
  logic                        ITLBMissOrUpdateRawF;                     // ITLB miss or A update needed, before masking by a held walk fault
  logic                        ITLBWalkFaultF;                           // The walk for the current fetch faulted (held or this cycle)
  logic                        InstrPageFaultRawF, InstrAccessFaultRawF; // Faults on the half of the fetch currently being translated

  assign PCFExt = {2'b00, PCSpillF};

  /////////////////////////////////////////////////////////////////////////////////////////////
  // Spill Support
  /////////////////////////////////////////////////////////////////////////////////////////////

  if (P.ZCA_SUPPORTED) begin : Spill
    logic [P.XLEN-1:0] PCSpillD, PCSpillE;
    logic [P.XLEN-1:0] PCIncrM;
    logic              SelSpillD, SelSpillE, SelSpillM;
    spill #(P) spill(.clk, .reset, .StallF, .FlushD, .PCF, .PCPlus4F, .PCNextF, .InstrRawF, .CacheableF,
      .InstrPageFaultF(InstrPageFaultRawF), .InstrAccessFaultF(InstrAccessFaultRawF),
      .IFUCacheBusStallF, .ITLBMissOrUpdateRawF, .PCSpillNextF, .PCSpillF, .SelSpillNextF, .SelSpillF,
      .PostSpillInstrRawF, .CompressedF);
    // A spill is taken only when the first half fetches cleanly, so a fault during a spill belongs to the
    // second half and is reported at PCM+2.
    assign InstrPageFaultF = InstrPageFaultRawF;
    assign InstrAccessFaultF = InstrAccessFaultRawF;
    flopenr #(1) SpillDReg(clk, reset, ~StallD, SelSpillF, SelSpillD);
    flopenr #(1) SpillEReg(clk, reset, ~StallE, SelSpillD, SelSpillE);
    flopenr #(1) SpillMReg(clk, reset, ~StallM, SelSpillE, SelSpillM);
    assign PCIncrM = PCM + 'd2;
    mux2 #(P.XLEN) pcspillmmux(PCM, PCIncrM, SelSpillM, PCSpillM);

  end else begin : NoSpill
    assign PCSpillNextF = PCNextF;
    assign PCSpillF = PCF;
    assign PostSpillInstrRawF = InstrRawF;
    assign {SelSpillNextF, SelSpillF, CompressedF} = '0;
    assign PCSpillM = PCM;
    assign InstrPageFaultF = InstrPageFaultRawF;
    assign InstrAccessFaultF = InstrAccessFaultRawF;
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Memory management
  ////////////////////////////////////////////////////////////////////////////////////////////////

  if (P.ZICSR_SUPPORTED == 1) begin : immu
    ///////////////////////////////////////////
    // sfence.vma causes TLB flushes
    ///////////////////////////////////////////
    // sets ITLBFlush to pulse for one cycle of the sfence.vma instruction
    // In this instr we want to flush the tlb and then do a pagetable walk to update the itlb and continue the program.
    // But we're still in the stalled sfence instruction, so if itlbflushf == sfencevmaM, tlbflush would never drop and
    // the tlbwrite would never take place after the pagetable walk. by adding in ~StallMQ, we are able to drop itlbflush
    // after a cycle AND pulse it for another cycle on any further back-to-back sfences.
    logic StallMQ, TLBFlush, TLBFlushAll;
    flopr #(1) StallMReg(.clk, .reset, .d(StallM), .q(StallMQ));
    assign TLBFlush = sfencevmaM & ~StallMQ;
    assign TLBFlushAll = sfencevmaAllM & ~StallMQ;

    mmu #(.P(P), .TLB_ENTRIES(P.ITLB_ENTRIES), .IMMU(1))
    immu(.clk, .reset, .SATP_REGW, .STATUS_MXR, .STATUS_SUM, .STATUS_MPRV, .STATUS_MPP, .ENVCFG_PBMTE, .ENVCFG_ADUE,
         .PrivilegeModeW, .DisableTranslation(1'b0),
         .VAdr(PCFExt),
         .Size(2'b10),
         .PTE(PTE),
         .PageTypeWriteVal(PageType),
         .TLBWrite(ITLBWriteF),
         .TLBFlush, .TLBFlushAll,
         .PhysicalAddress(PCPF),
         .TLBMiss(ITLBMissF),
         .Cacheable(CacheableF), .Idempotent(), .SelTIM(SelIROM),
         .InstrAccessFaultF(InstrAccessFaultRawF), .LoadAccessFaultM(), .StoreAmoAccessFaultM(),
         .InstrPageFaultF(InstrPageFaultRawF), .LoadPageFaultM(), .StoreAmoPageFaultM(),
         .LoadMisalignedFaultM(), .StoreAmoMisalignedFaultM(),
         .UpdateDA(InstrUpdateAF), .CMOpM(4'b0),
         .AtomicAccessM(1'b0), .ExecuteAccessF(1'b1), .WriteAccessM(1'b0), .ReadAccessM(1'b0),
         .PMPCFG_ARRAY_REGW, .PMPADDR_ARRAY_REGW);

    assign ITLBMissOrUpdateRawF = ITLBMissF | (P.SVADU_SUPPORTED & InstrUpdateAF);

    // Hold a page table walk fault for the current fetch (issues #1538, #1766).
    // A walk that faults (access fault on a page table entry address, or reserved bits in a non-leaf PTE) writes
    // nothing into the ITLB, so the miss would re-request a walk every cycle.  The walker reports the fault as a
    // one-cycle pulse; remember it until the fetch advances (PCF changes), present it to the pipeline as a level,
    // suppress further walk requests, and do not fetch.
    logic [1:0] ITLBWalkFaultHeldF; // {access fault, page fault}
    always_ff @(posedge clk)
      if (reset | ~StallF) ITLBWalkFaultHeldF <= 2'b00;
      else                 ITLBWalkFaultHeldF <= ITLBWalkFaultHeldF | {HPTWInstrAccessFaultF, HPTWInstrPageFaultF};
    assign HPTWInstrAccessFaultHeldF = ITLBWalkFaultHeldF[1] | HPTWInstrAccessFaultF;
    assign HPTWInstrPageFaultHeldF   = ITLBWalkFaultHeldF[0] | HPTWInstrPageFaultF;
    assign ITLBWalkFaultF = HPTWInstrAccessFaultHeldF | HPTWInstrPageFaultHeldF;
    assign ITLBMissOrUpdateAF = ITLBMissOrUpdateRawF & ~ITLBWalkFaultF;
  end else begin
    assign {ITLBMissF, InstrAccessFaultRawF, InstrPageFaultRawF, InstrUpdateAF} = '0;
    assign PCPF = PCFExt[P.PA_BITS-1:0];
    assign CacheableF = 1'b1;
    assign SelIROM = '0;
    assign {ITLBMissOrUpdateRawF, ITLBMissOrUpdateAF, ITLBWalkFaultF} = '0;
    assign {HPTWInstrAccessFaultHeldF, HPTWInstrPageFaultHeldF} = {HPTWInstrAccessFaultF, HPTWInstrPageFaultF};
  end

  // A fetch that has already failed the PMA or PMP check traps in the Memory stage, so it must not
  // start a bus transfer or a cache line fill.  Gating the cache as well as the bus keeps a line
  // that the hart may not execute from being filled into the I$.
  assign IFUFaultF = InstrAccessFaultF | InstrPageFaultF | ITLBWalkFaultF;

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Memory
  ////////////////////////////////////////////////////////////////////////////////////////////////

  // CommittedF tells the privileged unit that an I$ or bus operation is in flight.
  // Partially completed memory operations must not be interrupted because there is no clean way
  // to restore a partially executed operation.  CommittedF delays the interrupt until the IFU is in a clean state.
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

    if (P.ICACHE_SUPPORTED) begin : icache
      localparam            LLENPOVERAHBW = P.LLEN / P.AHBW; // Number of AHB beats in a LLEN word. AHBW cannot be larger than LLEN. (implementation limitation)
      localparam            LINEBYTELEN = P.ICACHE_LINELENINBITS/8;              // Line length in bytes
      localparam            OFFSETLEN = $clog2(LINEBYTELEN);                     // Number of bits in offset field
      localparam            SETLEN = $clog2(P.ICACHE_WAYSIZEINBYTES*8/LINELEN);  // Number of set bits
      logic [P.PA_BITS-1:0] ICacheBusAdr;
      logic                 ICacheBusAck;
      logic [1:0]           CacheBusRW, BusRW, CacheRWF;

      // Wait for an ITLB walk (miss or A update) before fetching: a fill from the old PA would be tagged with the new PA
      assign BusRW = ~ITLBMissOrUpdateRawF & ~CacheableF & ~SelIROM & ~IFUFaultF ? IFURWF : '0;
      assign CacheRWF = ~ITLBMissOrUpdateRawF & CacheableF & ~SelIROM & ~IFUFaultF ? IFURWF : '0;
      cache #(.P(P), .PA_BITS(P.PA_BITS), .LINELEN(P.ICACHE_LINELENINBITS),
              .NUMSETS(P.ICACHE_WAYSIZEINBYTES*8/P.ICACHE_LINELENINBITS),
              .OFFSETLEN(OFFSETLEN), .SETLEN(SETLEN),
              .NUMWAYS(P.ICACHE_NUMWAYS), .LOGBWPL(AHBWLOGBWPL), .WORDLEN(FETCHWIDTH), .MUXINTERVAL(16), .READ_ONLY_CACHE(1))
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
             .NextSet(PCSpillNextF[OFFSETLEN+SETLEN-1:0]),
             .PAdr(PCPF),
             .CacheCommitted(CacheCommittedF), .InvalidateCache(InvalidateICacheM), .InvalidateFlushStage(FlushW), .CMOpM('0));

      ahbcacheinterface #(P, BEATSPERLINE, AHBWLOGBWPL, LINELEN, LLENPOVERAHBW, 1)
      ahbcacheinterface(.HCLK(clk), .HRESETn(~reset),
            .HRDATA,
            .Flush(FlushD), .CacheBusRW, .BusCMOZero(1'b0), .HSIZE(IFUHSIZE), .HBURST(IFUHBURST), .HTRANS(IFUHTRANS), .HWSTRB(),
            .Size(3'b010), .HADDR(IFUHADDR), .HREADY(IFUHREADY), .HWRITE(IFUHWRITE), .CacheBusAdr(ICacheBusAdr),
            .BeatCount(), .Cacheable(CacheableF), .SelBusBeat(), .WriteDataM('0), .BusAtomic('0),
            .CacheBusAck(ICacheBusAck), .HWDATA(), .CacheableOrFlushCacheM(1'b0), .CacheReadDataWordM('0),
            .FetchBuffer, .PAdr(PCPF),
            .BusRW, .Stall(GatedStallD),
            .BusStall, .BusCommitted(BusCommittedF));

      mux3 #(FETCHWIDTH) UnCachedDataMux(.d0(ICacheInstrF), .d1(ShiftUncachedInstr), .d2({32'b0, IROMInstrF}),
                                         .s({SelIROM, ~CacheableF}), .y(FetchDataF));
    end else begin : passthrough
      assign IFUHADDR = PCPF;
      logic [1:0] BusRW;
      assign BusRW = ~ITLBMissOrUpdateRawF & ~SelIROM & ~IFUFaultF ? IFURWF : 0;
      assign IFUHSIZE = 3'b010;

      ahbinterface #(P.XLEN, 1'b0) ahbinterface(.HCLK(clk), .Flush(FlushD), .HRESETn(~reset), .HREADY(IFUHREADY),
        .HRDATA(HRDATA), .HTRANS(IFUHTRANS), .HWRITE(IFUHWRITE), .HWDATA(),
        .HWSTRB(), .BusRW, .BusAtomic('0), .ByteMask(), .WriteData('0),
        .Stall(GatedStallD), .BusStall, .BusCommitted(BusCommittedF), .FetchBuffer(FetchBuffer));

      assign CacheCommittedF = '0;
      if (P.IROM_SUPPORTED) mux2 #(FETCHWIDTH) UnCachedDataMux2(ShiftUncachedInstr, {32'b0, IROMInstrF}, SelIROM, FetchDataF);
      else assign FetchDataF = ShiftUncachedInstr;
      assign IFUHBURST = 3'b0;
      assign {ICacheMiss, ICacheAccess, ICacheStallF} = '0;
    end

    // mux between the alignments of uncached reads.  An uncached fetch is a single bus beat, so the
    // window is shifted so the halfword at PCSpillF lands at bit 0 and zero-filled above the beat.
    if (P.XLEN == 64) mux4 #(FETCHWIDTH) UncachedShiftInstrMux(FetchBuffer[64-1:0], {16'b0, FetchBuffer[64-1:16]},
                                                               {32'b0, FetchBuffer[64-1:32]}, {48'b0, FetchBuffer[64-1:48]},
                                                               PCSpillF[2:1], ShiftUncachedInstr);
    else mux2 #(FETCHWIDTH) UncachedShiftInstrMux({32'b0, FetchBuffer[32-1:0]}, {48'b0, FetchBuffer[32-1:16]}, PCSpillF[1], ShiftUncachedInstr);
  end else begin : nobus // block: bus
    assign {IFUHADDR, IFUHWRITE, IFUHSIZE, IFUHBURST, IFUHTRANS,
            BusStall, CacheCommittedF, BusCommittedF, FetchBuffer} = '0;
    assign {ICacheStallF, ICacheMiss, ICacheAccess} = '0;
    assign FetchDataF = {32'b0, IROMInstrF};
  end

  // Split the fetch window into its two instruction slots.
  // Slot 0 is the instruction at PCSpillF; the I$ aligns it to bit 0 at halfword granularity.
  // Slot 1 follows it: it starts at bit 16 if slot 0 is compressed, else at bit 32.
  // Each slot is then expanded by its own decompressor in the Decode stage.
  assign InstrRawF  = FetchDataF[31:0];
  assign Compressed2F = P.ZCA_SUPPORTED & ~&Instr2RawF[1:0];
  mux2 #(32) instr2mux(FetchDataF[63:32], FetchDataF[47:16], CompressedF, Instr2RawF);

  // Slot 0 is always complete (the spill logic fetches a second line when it straddles one).
  // Slot 1 has no spill yet, so it is only valid when it comes from the I$ and lies entirely within
  // the current cache line; past the end of the line the window is zero-padded.  Uncached, IROM, and
  // spill fetches deliver a single instruction.
  if (P.ICACHE_SUPPORTED) begin : instr2valid
    localparam LINEBYTES = P.ICACHE_LINELENINBITS/8;
    localparam OFFSETLEN = $clog2(LINEBYTES);
    logic [OFFSETLEN:0] Instr2OffsetF;                                    // Byte offset of slot 1 within the line
    logic [OFFSETLEN:0] Instr2EndF;                                       // Byte offset just past the end of slot 1
    assign Instr2OffsetF = {1'b0, PCF[OFFSETLEN-1:0]} + (CompressedF ? 'd2 : 'd4);
    assign Instr2EndF    = Instr2OffsetF + (Compressed2F ? 'd2 : 'd4);
    assign Instr2ValidF  = CacheableF & ~SelIROM & ~SelSpillF & (Instr2EndF <= LINEBYTES[OFFSETLEN:0]);
  end else begin : instr2valid
    assign Instr2ValidF = 1'b0;
  end

  // Decide in Fetch whether both slots may issue together.  This has to happen here rather than in
  // Decode because the PC advance below depends on it: a bundle of two advances the PC by both
  // lengths at once.  When Issue2F is low the core behaves exactly as single-issue Wally.
  issue #(P) issue(.Instr0F(InstrRawF), .Instr1F(Instr2RawF), .Instr2ValidF, .BPPCSrcF, .Issue2F, .LateA2F, .LateB2F, .LateOK2F, .Fuse2F, .FuseBr2F, .FuseBrAdd2F);

  assign IFUCacheBusStallF = ICacheStallF | BusStall;
  // The fetch side owns the stall for an unresolved ITLB miss / A update: the pipeline holds until the walker
  // has filled the ITLB (the walker may defer the request while the LSU has a memory access in flight).  A
  // fetch whose walk faulted does not stall; it proceeds carrying the held fault.
  assign IFUStallF = IFUCacheBusStallF | SelSpillNextF | ITLBMissOrUpdateAF;
  assign GatedStallD = StallD & ~SelSpillNextF;

  flopenl #(32) AlignedInstrRawDFlop(clk, reset | FlushD, ~StallD, PostSpillInstrRawF, nop, InstrRawD);

  // Slot 1 Fetch -> Decode registers, mirroring slot 0's (instruction, PC) plus a valid bit.
  // Slot 1's PC is PCPlus2or4F: the address right after slot 0.
  flopenl  #(32)     AlignedInstr2RawDFlop(clk, reset | FlushD, ~StallD, Instr2RawF, nop, Instr2RawD);
  flopenrc #(P.XLEN) Instr2PCDReg(clk, reset, FlushD, ~StallD, PCPlus2or4F, Instr2PCD);
  flopenrc #(1)      Instr2ValidDReg(clk, reset, FlushD, ~StallD, Instr2ValidF, Instr2ValidD);
  flopenrc #(1)      Issue2DReg(clk, reset, FlushD, ~StallD, Issue2F, Issue2D);
  // Which way fetch went after slot 0: a late branch (ieu.sv) keeps that direction until Memory checks it.
  flopenrc #(1)      PredTakenDReg(clk, reset, FlushD, ~StallD, BPPCSrcF, PredTakenD);
  flopenrc #(1)      PredTakenEReg(clk, reset, FlushE, ~StallE, PredTakenD, PredTakenE);
  flopenrc #(6)      Late2DReg(clk, reset, FlushD, ~StallD, {LateA2F, LateB2F, LateOK2F, Fuse2F, FuseBr2F, FuseBrAdd2F}, {LateA2D, LateB2D, LateOK2D, Fuse2D, FuseBr2D, FuseBrAdd2D});

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // PCNextF logic
  ////////////////////////////////////////////////////////////////////////////////////////////////

  // All redirects here come from the Memory stage.  A replay sends fetch back to slot 1's own PC,
  // which is PCM advanced by slot 0's length -- 2 when slot 0 was compressed, 4 otherwise.  A late
  // branch (ieu.sv) found to go the other way goes to its target, or to that same address when it
  // turned out not taken: fetch only assumed taken when slot 0 was predicted taken, which never pairs,
  // so nothing issued beside it.  At most one select is high: CSRWriteFenceM means slot 0 is a CSR
  // write or a fence, which neither pairs nor is a branch, and core.sv suppresses Replay2M under a
  // late branch misprediction, since slot 1 was on the wrong path.
  if (P.ZICSR_SUPPORTED | P.ZIFENCEI_SUPPORTED) begin
    mux2 #(P.XLEN) pcredirectmux(NextValidPCE, PCM + (CompressedM ? 'd2 : 'd4), Replay2M | LateBrWrongM, RedirectSeqPCM);
    mux2 #(P.XLEN) latebrtargetmux(RedirectSeqPCM, IEUAdrM, LateBrWrongM & LateBrTakenM, RedirectPCM);
    mux2 #(P.XLEN) pcmux2(.d0(PC1NextF), .d1(RedirectPCM), .s(CSRWriteFenceM | Replay2M | LateBrWrongM), .y(PC2NextF));
  end else assign PC2NextF = PC1NextF;   // ieu.sv makes no late branches without this path

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

  // When both slots issue, fetch continues after the pair rather than after slot 0.  A bundle is 4, 6
  // or 8 bytes depending on each slot's length, so the end is slot 1's own address advanced by slot
  // 1's length.  PCPlus2or4F stays the address of slot 1 itself, which is what the Decode-stage slot 1
  // PC register needs.
  assign PCBundleEndF = PCPlus2or4F + (Compressed2F ? 'd2 : 'd4);
  mux2 #(P.XLEN) pcnextseqmux(PCBundleEndF, PCPlus2or4F, ~Issue2F, PCNextSeqF);

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Branch and Jump Predictor
  ////////////////////////////////////////////////////////////////////////////////////////////////

  // The bundle's control transfer.  issue.sv admits at most one branch or jal per bundle, in either
  // slot, so the predictor sees one per bundle whichever slot holds it.  It keeps slot 0's PCs: a
  // slot 1 branch or jal is predicted and trained at the bundle's address, which is where fetch looks
  // it up, so the BTB and the direction predictor need no slot field.  Kill2E stays on slot 0's
  // PCSrcE -- a taken slot 1 branch or jal does not kill itself.
  //   0x100 addi a0,a0,1 ; 0x104 j loop     JumpBE = 1, IEUAdrBE = loop, trained at PC 0x100
  //
  // InstrBD is the instruction icpred looks at to tell a call from a plain jump (jal ra vs j): slot 1's
  // when slot 1 is the jump.  Only the jump's own rd matters there, so slot 0 is never needed then.
  //
  // IEUAdrBM is the target the BTB is written with in Memory.  It has its own register rather than
  // reusing the load/store unit's IEUAdrM, because the bundle's memory operation may be in the other
  // slot and then IEUAdrM holds its address, not the target:
  //   beq a0,a1,L ; lw a2,0(a3)      IEUAdrM = a3 + 0, IEUAdrBM = L
  //   sw  a0,0(a1); jal ra,f         IEUAdrM = a1 + 0, IEUAdrBM = f
  logic              BranchBD, BranchBE, JumpBD, JumpBE, PCSrcBE;
  logic [31:0]       InstrBD;
  logic [P.XLEN-1:0] IEUAdrBE, IEUAdrBM;
  assign BranchBD = BranchD | Branch2D & Issue2D;
  assign BranchBE = BranchE | Branch2E;
  assign JumpBD   = JumpD | Jump2D & Issue2D;
  assign JumpBE   = JumpE | Jump2E;
  assign PCSrcBE  = PCSrcE | PCSrc2E;
  mux2 #(32)     instrbdmux(InstrD, Instr2D, Jump2D & Issue2D, InstrBD);
  mux2 #(P.XLEN) ieuadrbemux(IEUAdrE, IEUAdr2E, Branch2E | Jump2E, IEUAdrBE);
  flopenrc #(P.XLEN) IEUAdrBMReg(clk, reset, FlushM, ~StallM, IEUAdrBE, IEUAdrBM);

  if (P.BPRED_SUPPORTED) begin : bpred
    bpred #(P) bpred(.clk, .reset,
                .StallF, .StallD, .StallE, .StallM, .StallW,
                .FlushD, .FlushE, .FlushM, .FlushW, .InstrValidD, .InstrValidE, .Commit2E, .PCLink2E,
                .BranchD(BranchBD), .BranchE(BranchBE), .JumpD(JumpBD), .JumpE(JumpBE),
                .InstrD(InstrBD), .PCNextF, .PCNextSeqF, .PC1NextF, .BPPCSrcF, .PCE, .PCM, .PCSrcE(PCSrcBE),
                .IEUAdrE(IEUAdrBE), .IEUAdrM(IEUAdrBM), .PCF, .NextValidPCE,
                .PCD, .PCLinkE, .IClassM, .BPWrongE, .PostSpillInstrRawF, .BPWrongM,
                .BPDirWrongM, .BTAWrongM, .RASPredPCWrongM, .IClassWrongM, .LateBrM, .LateBrTakenM);

  end else begin : bpred
    mux2 #(P.XLEN) pcmux1(.d0(PCNextSeqF), .d1(IEUAdrBE), .s(PCSrcBE), .y(PC1NextF));
    // No predictor: the next PC is sequential until a branch resolves taken in Execute, which is the
    // same behaviour as predicting not-taken.  So branches may pair here too, and Kill2E catches the
    // taken case.  BPPCSrcF still needs a driver in this branch because bpred is not instantiated.
    assign BPPCSrcF = 1'b0;
    logic BranchM, JumpM, BranchW, JumpW;
    logic CallD, CallE, CallM, CallW;
    logic ReturnD, ReturnE, ReturnM, ReturnW;
    assign BPWrongE = PCSrcBE;
    icpred #(P, 0) icpred(.clk, .reset, .StallD, .StallE, .StallM, .StallW, .FlushD, .FlushE, .FlushM,
      .PostSpillInstrRawF, .InstrD(InstrBD), .BranchD(BranchBD), .BranchE(BranchBE), .JumpD(JumpBD), .JumpE(JumpBE), .BranchM, .BranchW, .JumpM, .JumpW,
      .CallD, .CallE, .CallM, .CallW, .ReturnD, .ReturnE, .ReturnM, .ReturnW,
      .BTBCallF(1'b0), .BTBReturnF(1'b0), .BTBJumpF(1'b0),
      .BTBBranchF(1'b0), .BPCallF(), .BPReturnF(), .BPJumpF(), .BPBranchF(), .IClassWrongM,
      .BPReturnWrongD(), .BPReturnD());
    flopenrc #(1) PCSrcMReg(clk, reset, FlushM, ~StallM, PCSrcBE, BPWrongM);
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
    // Slot 1 gets its own decompressor.  Slot 0's illegal flag joins IllegalIEUInstrD above, but
    // slot 1 has no such path -- the privileged unit describes only slot 0 -- so an illegal
    // compressed instruction in slot 1 is sent down the replay route instead, exactly as an illegal
    // 32-bit one is.  Carried to Memory so it reaches Replay2M, with the Execute register flushed
    // for an unpaired slot 1 (mirroring controller c2) and the result qualified by Issue2M, so a
    // slot 1 abandoned in Execute never triggers a replay.
    logic IllegalCompInstr2E, IllegalCompInstr2M;
    decompress #(P) decomp2(.InstrRawD(Instr2RawD), .InstrD(Instr2D), .IllegalCompInstrD(IllegalCompInstr2D));
    flopenrc #(1) IllegalComp2EReg(clk, reset, FlushE | ~Issue2D, ~StallE, IllegalCompInstr2D, IllegalCompInstr2E);
    flopenrc #(1) IllegalComp2MReg(clk, reset, FlushM, ~StallM, IllegalCompInstr2E, IllegalCompInstr2M);
    assign IllegalComp2M = IllegalCompInstr2M & Issue2M;
  end else begin : decomp
    assign InstrD = InstrRawD;
    assign IllegalIEUInstrD = IllegalBaseInstrD;
    assign Instr2D = Instr2RawD;
    assign IllegalComp2M = 1'b0;
    assign IllegalCompInstr2D = 1'b0;
  end
  // Illegal only if the IEU decoder rejects it and the FPU decoder also rejects it (or there is no FPU)
  assign IllegalIEUFPUInstrD = IllegalIEUInstrD & (IllegalFPUInstrD | !P.F_SUPPORTED);

  // Misaligned PC logic
  // Instruction address misalignment only from br/jal(r) instructions.
  // instruction address misalignment is generated by the target of control flow instructions, not
  // the fetch itself.
  // xret and Traps both cannot produce instruction misaligned.
  // xret: mepc is an MXLEN-bit read/write register formatted as shown in Figure 3.21.
  // The low bit of mepc (mepc[0]) is always zero. On implementations that support
  // only IALIGN=32, the two low bits (mepc[1:0]) are always zero.
  // Spec 3.1.14
  // Traps: Can't happen.  The bottom two bits of MTVEC are ignored so the trap always is to a multiple of 4.  See 3.1.7 of the privileged spec.
  assign InstrMisalignedFaultE = (IEUAdrE[1] & ~P.ZCA_SUPPORTED) & PCSrcE;
  flopenrc #(1) InstrMisalignedReg(clk, reset, FlushM, ~StallM, InstrMisalignedFaultE, InstrMisalignedFaultM);

  // Instruction and PC pipeline registers flush to NOP, not zero
  mux2    #(32)     FlushInstrEMux(InstrD, nop, FlushE, NextInstrD);
  flopenr #(32)     InstrEReg(clk, reset, ~StallE, NextInstrD, InstrE);
  flopenr #(P.XLEN) PCEReg(clk, reset, ~StallE, PCD, PCE);
  // Issue2E is a validity bit, not data: on a flush slot 1 must not issue, so it is cleared
  // (unlike PCE above, which may safely go stale because InstrValidE tracks validity separately).
  flopenrc #(1)     Issue2EReg(clk, reset, FlushE, ~StallE, Issue2D, Issue2E);
  // Slot 1 may have to be abandoned after it has already issued: slot 0 can be a conditional branch,
  // and if it resolves taken then slot 1, the fall-through, is on the wrong path.  PCSrcE is that
  // resolved outcome (JumpE | BranchE & BranchTakenE), so it is exactly the kill condition.
  // This gates the register's *input*.  FlushE would be the wrong mechanism: it stops the Decode
  // instruction from entering Execute and does nothing to an instruction already in Execute.
  assign Kill2E   = PCSrcE;
  assign Commit2E = Issue2E & ~Kill2E;
  // Carrying Issue2 to Writeback is what gates slot 1's register write.  Because these clear on
  // flush, a trap or a misprediction that flushes the bundle also stops slot 1 from committing.
  // Replay2M is the Memory-stage equivalent of Kill2E: slot 1's memory operation faulted, so it is
  // abandoned here and refetched to run alone.  It cannot use FlushW, which would also discard slot 0.
  flopenrc #(1)     Issue2MReg(clk, reset, FlushM, ~StallM, Commit2E, Issue2M);
  // A late branch found taken in Memory abandons the slot 1 beside it, the fall-through, as Kill2E
  // does for a branch resolved in Execute.
  flopenrc #(1)     Issue2WReg(clk, reset, FlushW, ~StallW, Issue2M & ~Replay2M & ~LateBrWrongM, Issue2W);

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
    logic Compressed2D; // slot 1 is compressed
    flopenrc #(1) CompressedDReg(clk, reset, FlushD, ~StallD, CompressedF, CompressedD);
    flopenrc #(1) CompressedEReg(clk, reset, FlushE, ~StallE, CompressedD, CompressedE);
    assign PCLinkE = PCE + (CompressedE ? 'd2 : 'd4); // 'd4 means 4 but stops Design Compiler complaining about signed to unsigned conversion
    // Slot 1's length, carried alongside slot 0's, gives the address just past slot 1.  Slot 1 starts
    // at PCLinkE, so:
    //   0x100 addi a0,a0,1 ; 0x104 jal ra,f      PCLink2E = 0x108   (0x106 if the jal is a c.jal)
    // It is a slot 1 jal's link value (datapath.sv) and, whenever slot 1 commits, the bundle's
    // fall-through address (bpred.sv).
    flopenrc #(1) Compressed2DReg(clk, reset, FlushD, ~StallD, Compressed2F, Compressed2D);
    flopenrc #(1) Compressed2EReg(clk, reset, FlushE, ~StallE, Compressed2D, Compressed2E);
    assign PCLink2E = PCLinkE + (Compressed2E ? 'd2 : 'd4);
  end else begin
    assign CompressedE = 1'b0;
    assign Compressed2E = 1'b0;
    assign PCLinkE = PCE + 'd4;
    assign PCLink2E = PCLinkE + 'd4;
  end

  // pipeline original compressed instruction in case it is needed for XTVAL on an illegal instruction exception
  // Only csr reads InstrOrigM, and it differs from InstrM only for compressed instructions.  The block
  // is always generated because the slot 1 replay redirect also reads CompressedM, declared above.
  if (P.ZICSR_SUPPORTED & P.ZCA_SUPPORTED | 1) begin
    logic [15:0] InstrRawE, InstrRawM;
    flopenrc #(16) InstrRawEReg(clk, reset, FlushE, ~StallE, InstrRawD[15:0], InstrRawE);
    flopenrc #(16) InstrRawMReg(clk, reset, FlushM, ~StallM, InstrRawE, InstrRawM);
    flopenrc #(1)  CompressedMReg(clk, reset, FlushM, ~StallM, CompressedE, CompressedM);
    mux2     #(32) InstrOrigMux(InstrM, {16'b0, InstrRawM}, CompressedM, InstrOrigM);
  end else
    assign InstrOrigM = InstrM;

endmodule
