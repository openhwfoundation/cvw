///////////////////////////////////////////
// wallypipelinedcore.sv
//
// Written: David_Harris@hmc.edu 9 January 2021
// Modified:
//
// Purpose: Pipelined RISC-V Processor
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
////////////////////////////////////////////////////////////////////////////////////////////////

module wallypipelinedcore import cvw::*; #(parameter cvw_t P) (
  input  logic                  clk, reset,
  // Privileged
  input  logic                  MTimerInt, MExtInt, SExtInt, MSwInt,
  input  logic [63:0]           MTIME_CLINT,
  // Bus Interface
  input  logic [P.AHBW-1:0]     HRDATA,
  input  logic                  HREADY, HRESP,
  output logic                  HCLK, HRESETn,
  output logic [P.PA_BITS-1:0]  HADDR,
  output logic [P.AHBW-1:0]     HWDATA,
  output logic [P.XLEN/8-1:0]   HWSTRB,
  output logic                  HWRITE,
  output logic [2:0]            HSIZE,
  output logic [2:0]            HBURST,
  output logic [3:0]            HPROT,
  output logic [1:0]            HTRANS,
  output logic                  HMASTLOCK,
  input  logic                  ExternalStall
);

  logic                          StallF, StallD, StallE, StallM, StallW;
  logic                          FlushD, FlushE, FlushM, FlushW;
  logic                          TrapM, RetM;

  // signals that must connect through DP
  logic                          IntDivE, W64E;
  logic                          CSRReadM, CSRWriteM, PrivilegedM;
  logic [1:0]                    AtomicM;
  logic [P.XLEN-1:0]             ForwardedSrcAE, ForwardedSrcBE;
  logic [P.XLEN-1:0]             SrcAM;
  logic [2:0]                    Funct3E;
  logic [31:0]                   InstrD;
  logic [31:0]                   Instr2D;                                  // superscalar slot 1 instruction in Decode
  logic                          Issue2D, Issue2E, Issue2M, Issue2W;       // superscalar slot 1 issues alongside slot 0
  logic                          LateA2D, LateB2D;                         // slot 1 operand is slot 0's result (late ALU)
  logic                          LateOK2D;                                 // slot 1 could run on the late ALU
  logic                          Fuse2D, FuseM;                            // the pair is fused into one indexed load (Decode / Memory)
  logic                          FuseBr2D;                                 // the pair is fused into one ALU op + branch
  logic                          PredTakenE;                               // fetch went to slot 0's predicted target
  logic                          LateBrM, LateBrTakenM, LateBrWrongM;      // slot 0 branch resolved in Memory
  logic                          Replay2RawM;                              // slot 1 must re-run alone, unless it was on the wrong path
  logic [31:0]                   InstrM, InstrOrigM;
  logic [P.XLEN-1:0]             PCSpillF, PCE, PCLinkE;
  logic [P.XLEN-1:0]             PCM, PCSpillM;
  logic [P.XLEN-1:0]             CSRReadValW, MDUResultW;
  logic [P.XLEN-1:0]             EPCM, TrapVectorM;
  logic [1:0]                    MemRWE;
  logic [1:0]                    MemRWM;
  logic                          InstrValidD, InstrValidE, InstrValidM;
  logic                          InstrMisalignedFaultM;
  logic                          IllegalBaseInstrD, IllegalFPUInstrD, IllegalIEUFPUInstrD;
  logic                          Mem2M;                           // The bundle's memory operation is slot 1's
  logic                          Illegal2M;                       // ... or slot 1 is an illegal instruction
  logic                          IllegalComp2M;                   // ... or an illegal compressed one, flagged by its decompressor
  logic                          Replay2M;                        // ... either way slot 1 must re-run alone
  logic                          MemFault2M;                      // Slot 1's memory operation faulted (the memory half of Replay2M)
  logic                          InstrPageFaultF, LoadPageFaultM, StoreAmoPageFaultM;
  logic                          LoadMisalignedFaultM, LoadAccessFaultM;
  logic                          StoreAmoMisalignedFaultM, StoreAmoAccessFaultM;
  logic                          InvalidateICacheM, FlushDCacheM;
  logic                          PCSrcE;
  logic                          CSRWriteFenceM;
  logic                          DivBusyE;
  logic                          StructuralStallD;
  logic                          LoadStallD;
  logic                          StoreStallD;
  logic                          SquashSCW;
  logic                          MDUActiveE;                      // Mul/Div instruction being executed, in either slot
  logic [P.XLEN-1:0]             MDUSrcAE, MDUSrcBE;              // MDU operands, from the slot holding the bundle's MDU operation
  logic [2:0]                    MDUFunct3E, MDUFunct3M;          // MDU operation, from that slot
  logic                          MDUW64E;                         // MDU W-type, from that slot
  logic                          MDUIntDivE;                      // MDU integer divide, from that slot
  logic                          ENVCFG_ADUE;                     // HPTW A/D Update enable
  logic                          ENVCFG_PBMTE;                    // Page-based memory type enable
  logic [3:0]                    ENVCFG_CBE;                      // Cache Block operation enables
  logic [3:0]                    CMOpM;                           // 1: cbo.inval; 2: cbo.clean; 4: cbo.flush; 8: cbo.zero
  logic                          IFUPrefetchE, LSUPrefetchM;      // instruction / data prefetch hints

  // floating point unit signals
  logic [2:0]                    FRM_REGW;
  logic [4:0]                    RdE, RdM, RdW;
  logic                          FPUStallD;
  logic                          FWriteIntE;
  logic [P.FLEN-1:0]             FWriteDataM;
  logic [P.XLEN-1:0]             FIntResM;
  logic [P.XLEN-1:0]             FCvtIntResW;
  logic                          FCvtIntW;
  logic                          FDivBusyE;
  logic                          FRegWriteM;
  logic                          FpLoadStoreM;
  logic [4:0]                    SetFflagsM;
  logic [P.XLEN-1:0]             FIntDivResultW;

  // memory management unit signals
  logic                          ITLBWriteF;
  logic                          ITLBMissOrUpdateAF;
  logic [P.XLEN-1:0]             SATP_REGW;
  logic                          STATUS_MXR, STATUS_SUM, STATUS_MPRV;
  logic [1:0]                    STATUS_MPP, STATUS_FS;
  logic [1:0]                    PrivilegeModeW;
  logic [P.XLEN-1:0]             PTE;
  logic [2:0]                    PageType;
  logic                          sfencevmaM, sfencevmaAllM;
  logic                          SelHPTW;

  // PMA checker signals
  /* verilator lint_off UNDRIVEN */ // these signals are undriven in configurations without a privileged unit
  var logic [P.PA_BITS-3:0]      PMPADDR_ARRAY_REGW[P.PMP_ENTRIES-1:0];
  var logic [7:0]                PMPCFG_ARRAY_REGW[P.PMP_ENTRIES-1:0];
  /* verilator lint_on UNDRIVEN */

  // IMem stalls
  logic                          IFUStallF;
  logic                          LSUStallM;

  // cpu lsu interface
  logic [2:0]                    Funct3M;                         // slot 0's funct3, to the FPU
  logic [2:0]                    MemFunct3M;                      // the bundle's memory funct3, to the LSU
  logic [P.XLEN-1:0]             IEUAdrE;                         // slot 0's branch / jump target, to the IFU
  logic [P.XLEN-1:0]             LSUAdrE;                         // the bundle's memory address, to the LSU
  logic [P.XLEN-1:0]             WriteDataM;
  logic [P.XLEN-1:0]             IEUAdrM;
  logic [P.XLEN-1:0]             IEUAdrxTvalM;
  logic [P.LLEN-1:0]             ReadDataW;
  logic                          CommittedM;

  // AHB ifu interface
  logic [P.PA_BITS-1:0]          IFUHADDR;
  logic [2:0]                    IFUHBURST;
  logic [1:0]                    IFUHTRANS;
  logic [2:0]                    IFUHSIZE;
  logic                          IFUHWRITE;
  logic                          IFUHREADY;

  // AHB LSU interface
  logic [P.PA_BITS-1:0]          LSUHADDR;
  logic [P.XLEN-1:0]             LSUHWDATA;
  logic [P.XLEN/8-1:0]           LSUHWSTRB;
  logic                          LSUHWRITE;
  logic                          LSUHREADY;

  logic                          BPWrongE, BPWrongM;
  logic                          BPDirWrongM;
  logic                          BTAWrongM;
  logic                          RASPredPCWrongM;
  logic                          IClassWrongM;
  logic [3:0]                    IClassM;
  logic                          InstrAccessFaultF, HPTWInstrAccessFaultF, HPTWInstrPageFaultF;
  logic                          HPTWInstrAccessFaultHeldF, HPTWInstrPageFaultHeldF;
  logic [2:0]                    LSUHSIZE;
  logic [2:0]                    LSUHBURST;
  logic [1:0]                    LSUHTRANS;

  logic                          DCacheMiss;
  logic                          DCacheAccess;
  logic                          ICacheMiss;
  logic                          ICacheAccess;
  logic                          BigEndianM;
  logic                          FCvtIntE;
  logic                          CommittedF;
  logic                          BranchD, BranchE, JumpD, JumpE;
  logic                          Branch2D, Branch2E, Jump2D, Jump2E, PCSrc2E; // slot 1 conditional branch or jal, and its outcome
  logic [P.XLEN-1:0]             IEUAdr2E, PCLink2E;              // slot 1 branch/jal target, and its link address
  logic                          DCacheStallM, ICacheStallF;
  logic                          WaitM;                           // wfi is waiting for an interrupt

  // instruction fetch unit: PC, branch prediction, instruction cache
  ifu #(P) ifu(.clk, .reset,
    .StallF, .StallD, .StallE, .StallM, .StallW, .FlushD, .FlushE, .FlushM, .FlushW,
    .InstrValidE, .InstrValidD,
    .BranchD, .BranchE, .JumpD, .JumpE, .Branch2D, .Branch2E, .Jump2D, .Jump2E, .PCSrc2E, .IEUAdr2E, .PCLink2E, .ICacheStallF,
    // Fetch
    .HRDATA, .PCSpillF, .IFUHADDR,
    .IFUStallF, .IFUHBURST, .IFUHTRANS, .IFUHSIZE, .IFUHREADY, .IFUHWRITE,
    .ICacheAccess, .ICacheMiss,
    // Execute
    .PCLinkE, .PCSrcE, .IEUAdrE, .IEUAdrM, .PCE, .BPWrongE, .BPWrongM,
    // Mem
    .CommittedF, .EPCM, .TrapVectorM, .RetM, .TrapM, .InvalidateICacheM, .CSRWriteFenceM,
    .InstrD, .Instr2D, .Issue2D, .Issue2E, .Issue2M, .Issue2W, .LateA2D, .LateB2D, .LateOK2D, .Fuse2D, .FuseBr2D, .Replay2M, .PredTakenE, .LateBrM, .LateBrTakenM, .LateBrWrongM, .IllegalComp2M, .InstrM, .InstrOrigM, .PCM, .PCSpillM, .IClassM, .BPDirWrongM,
    .BTAWrongM, .RASPredPCWrongM, .IClassWrongM,
    // Faults out
    .IllegalBaseInstrD, .IllegalFPUInstrD, .InstrPageFaultF, .IllegalIEUFPUInstrD, .InstrMisalignedFaultM,
    // mmu management
    .PrivilegeModeW, .PTE, .PageType, .SATP_REGW, .STATUS_MXR, .STATUS_SUM, .STATUS_MPRV,
    .STATUS_MPP, .ENVCFG_PBMTE, .ENVCFG_ADUE, .ITLBWriteF, .sfencevmaM, .sfencevmaAllM, .ITLBMissOrUpdateAF,
    .HPTWInstrAccessFaultF, .HPTWInstrPageFaultF, .HPTWInstrAccessFaultHeldF, .HPTWInstrPageFaultHeldF,
    // pmp/pma (inside mmu) signals.
    .PMPCFG_ARRAY_REGW, .PMPADDR_ARRAY_REGW, .InstrAccessFaultF);

  // integer execution unit: integer register file, datapath and controller
  ieu #(P) ieu(.clk, .reset,
    // Decode Stage interface
    .InstrD, .Instr2D, .Issue2D, .Issue2M, .Issue2W, .LateA2D, .LateB2D, .LateOK2D, .Fuse2D, .FuseBr2D, .FuseM, .Replay2M, .PredTakenE, .LateBrM, .LateBrTakenM, .LateBrWrongM, .Mem2M, .Illegal2M, .STATUS_FS, .ENVCFG_CBE, .IllegalIEUFPUInstrD, .IllegalBaseInstrD,
    // Execute Stage interface
    .PCE, .PCLinkE, .FWriteIntE, .FCvtIntE, .IEUAdrE, .LSUAdrE, .IntDivE, .W64E,
    .Funct3E, .ForwardedSrcAE, .ForwardedSrcBE, .MDUActiveE, .CMOpM, .IFUPrefetchE, .LSUPrefetchM,
    .MDUSrcAE, .MDUSrcBE, .MDUFunct3E, .MDUFunct3M, .MDUW64E, .MDUIntDivE,
    // Memory stage interface
    .SquashSCW,  // from LSU
    .MemRWE,     // read/write control goes to LSU
    .MemRWM,     // read/write control goes to LSU
    .AtomicM,    // atomic control goes to LSU
    .WriteDataM, // Write data to LSU
    .Funct3M, .MemFunct3M,    // funct3 to MDU/FPU; size and signedness to LSU
    .SrcAM,      // to privilege and fpu
    .RdE, .RdM, .FIntResM, .FlushDCacheM,
    .BranchD, .BranchE, .JumpD, .JumpE, .Branch2D, .Branch2E, .Jump2D, .Jump2E, .PCSrc2E, .IEUAdr2E, .PCLink2E,
    // Writeback stage
    .CSRReadValW, .MDUResultW, .FIntDivResultW, .RdW, .ReadDataW(ReadDataW[P.XLEN-1:0]),
    .InstrValidM, .InstrValidE, .InstrValidD, .FCvtIntResW, .FCvtIntW,
    // hazards
    .StallD, .StallE, .StallM, .StallW, .FlushD, .FlushE, .FlushM, .FlushW,
    .StructuralStallD, .LoadStallD, .StoreStallD, .PCSrcE,
    .CSRReadM, .CSRWriteM, .PrivilegedM, .CSRWriteFenceM, .InvalidateICacheM);

  lsu #(P) lsu(
    .clk, .reset, .StallM, .FlushM, .StallW, .FlushW, .MemFault2M,
    // CPU interface
    .MemRWE, .MemRWM, .Funct3M(MemFunct3M), .Funct7M(InstrM[31:25]), .AtomicM,
    .CommittedM, .DCacheMiss, .DCacheAccess, .SquashSCW,
    .FpLoadStoreM, .FWriteDataM, .IEUAdrE(LSUAdrE), .IEUAdrM, .WriteDataM,
    .ReadDataW, .FlushDCacheM, .CMOpM, .LSUPrefetchM,
    // connected to ahb (all stay the same)
    .LSUHADDR, .HRDATA, .LSUHWDATA, .LSUHWSTRB, .LSUHSIZE,
    .LSUHBURST, .LSUHTRANS, .LSUHWRITE, .LSUHREADY,
    // connect to csr or privilege and stay the same.
    .PrivilegeModeW, .BigEndianM, // connects to csr
    .PMPCFG_ARRAY_REGW,           // connects to csr
    .PMPADDR_ARRAY_REGW,          // connects to csr
    // hptw keep i/o
    .SATP_REGW,                   // from csr
    .STATUS_MXR,                  // from csr
    .STATUS_SUM,                  // from csr
    .STATUS_MPRV,                 // from csr
    .STATUS_MPP,                  // from csr
    .ENVCFG_PBMTE,                // from csr
    .ENVCFG_ADUE,                 // from csr
    .sfencevmaM, .sfencevmaAllM,  // connects to privilege
    .DCacheStallM,                // connects to privilege
    .IEUAdrxTvalM,                // connects to privilege
    .LoadPageFaultM,              // connects to privilege
    .StoreAmoPageFaultM,          // connects to privilege
    .LoadMisalignedFaultM,        // connects to privilege
    .LoadAccessFaultM,            // connects to privilege
    .HPTWInstrAccessFaultF,       // connects to privilege
    .HPTWInstrPageFaultF,         // connects to privilege
    .StoreAmoMisalignedFaultM,    // connects to privilege
    .StoreAmoAccessFaultM,        // connects to privilege
    .PCSpillF, .ITLBMissOrUpdateAF, .PTE, .PageType, .ITLBWriteF, .SelHPTW,
    .LSUStallM);

  if (P.BUS_SUPPORTED) begin : ebu
    ebu #(P) ebu(
      .clk, .reset,
      // IFU interface
      .IFUHADDR, .IFUHBURST, .IFUHTRANS, .IFUHREADY, .IFUHSIZE,
      // LSU interface
      .LSUHADDR, .LSUHWDATA, .LSUHWSTRB, .LSUHSIZE, .LSUHBURST,
      .LSUHTRANS, .LSUHWRITE, .LSUHREADY,
      // BUS interface
      .HREADY, .HRESP, .HCLK, .HRESETn,
      .HADDR, .HWDATA, .HWSTRB, .HWRITE, .HSIZE, .HBURST,
      .HPROT, .HTRANS, .HMASTLOCK);
  end else begin
    assign {IFUHREADY, LSUHREADY, HCLK, HRESETn, HADDR, HWDATA,
            HWSTRB, HWRITE, HSIZE, HBURST, HPROT, HTRANS, HMASTLOCK} = '0;
  end

  // Superscalar replay.  The privileged unit holds one PC, cause and tval for the Memory stage, so it
  // cannot describe a trap taken by slot 1 while slot 0 occupies that stage.  Rather than give it a
  // second set, a faulting slot 1 is abandoned and re-fetched on its own: the trap below is suppressed,
  // slot 0 (which is architecturally earlier and completed) commits, and the IFU redirects to slot 1's
  // own PC.  Slot 1 then runs as an ordinary unpaired instruction, faults again, and traps through the
  // existing single-issue path, so mepc, mcause and mtval are right with no change to privileged.sv.
  // Guarded by ZICSR_SUPPORTED because without a privileged unit no trap is ever taken, and replaying
  // a fault nothing will service would re-fetch the same instruction forever.
  // Slot 1 has exactly two ways to need a trap -- a faulting memory operation, and an illegal
  // instruction -- and both are the same problem: a trap the Memory stage cannot describe.  So both
  // take the one replay path.
  // Only a load can bring the memory half of this about, because issue.sv keeps stores in slot 0.  A
  // replayed store would need its write cancelled, and a replay cannot do that: the only thing that
  // cancels a write here is FlushW, which a replay withholds so that slot 0 can still commit.  See the
  // LOAD arm of issue.sv for what admitting stores would require.  A replayed load needs nothing of
  // the sort -- it writes no memory, and Issue2W already stops its register write.
  // MemFault2M is the memory half on its own.  The LSU squashes its own faulting access, but the D$ and
  // bus still assert a stall for it every cycle it sits in Memory.  A trap is immune because the hazard
  // unit ignores the LSU stall under FlushWCause; a replay deliberately does not flush Writeback, so the
  // hazard unit must ignore the stall under MemFault2M instead or the replay never leaves Memory.
  // A fused indexed load (ieu.sv) faults the same way: its trap would name the add's PC, so the pair is
  // replayed unfused -- slot 0 commits as the add, and the load is refetched to run and trap alone.
  assign MemFault2M = P.ZICSR_SUPPORTED & (Mem2M | FuseM) &
                      (LoadMisalignedFaultM | LoadAccessFaultM | LoadPageFaultM |
                       StoreAmoMisalignedFaultM | StoreAmoAccessFaultM | StoreAmoPageFaultM);
  // A slot 1 beside a late branch that turns out taken was on the wrong path: it is abandoned, not replayed.
  assign Replay2RawM = MemFault2M | (P.ZICSR_SUPPORTED & (Illegal2M | IllegalComp2M));
  assign Replay2M    = Replay2RawM & ~LateBrWrongM;

  // global stall and flush control
  hazard hzu(
    .BPWrongE, .CSRWriteFenceM, .Replay2M, .MemFault2M, .LateBrWrongM, .RetM, .TrapM,
    .StructuralStallD,
    .LSUStallM, .IFUStallF,
    .FPUStallD, .ExternalStall,
    .DivBusyE, .FDivBusyE,
    .WaitM,
    // Stall & flush outputs
    .StallF, .StallD, .StallE, .StallM, .StallW,
    .FlushD, .FlushE, .FlushM, .FlushW);

  // privileged unit
  if (P.ZICSR_SUPPORTED) begin : priv
    privileged #(P) priv(
      .clk, .reset,
      .FlushD, .FlushE, .FlushM, .FlushW, .StallD, .StallE, .StallM, .StallW,
      .CSRReadM, .CSRWriteM, .SrcAM, .PCM, .PCSpillM,
      .InstrM, .InstrOrigM, .CSRReadValW, .EPCM, .TrapVectorM,
      .RetM, .TrapM, .sfencevmaM, .sfencevmaAllM, .InvalidateICacheM, .DCacheStallM, .ICacheStallF,
      .InstrValidM, .CommittedM, .CommittedF,
      .FRegWriteM, .LoadStallD, .StoreStallD,
      .BPDirWrongM, .BTAWrongM, .BPWrongM,
      .RASPredPCWrongM, .IClassWrongM, .DivBusyE, .FDivBusyE,
      // Issue2M reaches the privileged unit only to increment minstret for slot 1.  A replayed slot 1
      // has not retired -- it is about to run again on its own -- so it must not be counted here.
      .IClassM, .Issue2M(Issue2M & ~Replay2M & ~LateBrWrongM), .DCacheMiss, .DCacheAccess, .ICacheMiss, .ICacheAccess, .PrivilegedM,
      // The six data faults are masked on replay: slot 1 raised them, but this stage describes slot 0,
      // so the trap is deferred until slot 1 re-runs on its own and can be described correctly.
      .InstrPageFaultF, .LoadPageFaultM(LoadPageFaultM & ~Replay2M), .StoreAmoPageFaultM(StoreAmoPageFaultM & ~Replay2M),
      .InstrMisalignedFaultM, .IllegalIEUFPUInstrD,
      .LoadMisalignedFaultM(LoadMisalignedFaultM & ~Replay2M), .StoreAmoMisalignedFaultM(StoreAmoMisalignedFaultM & ~Replay2M),
      .MTimerInt, .MExtInt, .SExtInt, .MSwInt,
      .MTIME_CLINT, .IEUAdrxTvalM, .SetFflagsM,
      .InstrAccessFaultF, .HPTWInstrAccessFaultF(HPTWInstrAccessFaultHeldF), .HPTWInstrPageFaultF(HPTWInstrPageFaultHeldF), .LoadAccessFaultM(LoadAccessFaultM & ~Replay2M), .StoreAmoAccessFaultM(StoreAmoAccessFaultM & ~Replay2M), .SelHPTW,
      .PrivilegeModeW, .SATP_REGW,
      .STATUS_MXR, .STATUS_SUM, .STATUS_MPRV, .STATUS_MPP, .STATUS_FS,
      .PMPCFG_ARRAY_REGW, .PMPADDR_ARRAY_REGW,
      .FRM_REGW, .ENVCFG_CBE, .ENVCFG_PBMTE, .ENVCFG_ADUE, .WaitM, .BigEndianM);
  end else begin
    assign {CSRReadValW, PrivilegeModeW,
            SATP_REGW, STATUS_MXR, STATUS_SUM, STATUS_MPRV, STATUS_MPP, STATUS_FS, FRM_REGW,
            // PMPCFG_ARRAY_REGW, PMPADDR_ARRAY_REGW,
            ENVCFG_CBE, ENVCFG_PBMTE, ENVCFG_ADUE,
            EPCM, TrapVectorM, RetM, TrapM,
            sfencevmaM, sfencevmaAllM, BigEndianM, WaitM} = '0;
  end

  // multiply/divide unit
  if (P.ZMMUL_SUPPORTED) begin : mdu
    // The operands, funct3, W64 and divide start come from whichever slot holds the bundle's MDU
    // operation (see ieu.sv).
    mdu #(P) mdu(.clk, .reset, .StallM, .StallW, .FlushE, .FlushM, .FlushW,
      .ForwardedSrcAE(MDUSrcAE), .ForwardedSrcBE(MDUSrcBE),
      .Funct3E(MDUFunct3E), .Funct3M(MDUFunct3M), .IntDivE(MDUIntDivE), .W64E(MDUW64E), .MDUActiveE,
      .MDUResultW, .DivBusyE);
  end else begin // no M instructions supported
    assign MDUResultW = '0;
    assign DivBusyE   = 1'b0;
  end

  // floating point unit
  if (P.F_SUPPORTED) begin : fpu
    fpu #(P) fpu(
      .clk, .reset,
      .FRM_REGW,                           // Rounding mode from CSR
      .InstrD,                             // instruction from IFU
      .Instr2D,                            // superscalar slot 1 instruction (decoded, not issued)
      .ReadDataW(ReadDataW[P.FLEN-1:0]),   // Read data from memory
      .ForwardedSrcAE,                     // Integer input being processed (from IEU)
      .StallE, .StallM, .StallW,           // stall signals from HZU
      .FlushE, .FlushM, .FlushW,           // flush signals from HZU
      .RdE, .RdM, .RdW,                    // which FP register to write to (from IEU)
      .STATUS_FS,                          // is floating-point enabled?
      .FRegWriteM,                         // FP register write enable
      .FpLoadStoreM,
      .ForwardedSrcBE,                     // Integer input for intdiv
      .Funct3E, .Funct3M, .IntDivE, .W64E, // Integer flags and functions
      .FPUStallD,                          // Stall the decode stage
      .FWriteIntE, .FCvtIntE,              // integer register write enable, conversion operation
      .FWriteDataM,                        // Data to be written to memory
      .FIntResM,                           // data to be written to integer register
      .FCvtIntResW,                        // fp -> int conversion result to be stored in int register
      .FCvtIntW,                           // fpu result selection
      .FDivBusyE,                          // Is the divide/sqrt unit busy (stall execute stage)
      .IllegalFPUInstrD,                   // Is the instruction an illegal fpu instruction
      .SetFflagsM,                         // FPU flags (to privileged unit)
      .FIntDivResultW);
  end else begin                           // no F_SUPPORTED or D_SUPPORTED; tie outputs low
    assign {FPUStallD, FWriteIntE, FCvtIntE, FIntResM, FCvtIntW, FRegWriteM,
            IllegalFPUInstrD, SetFflagsM, FpLoadStoreM,
            FWriteDataM, FCvtIntResW, FIntDivResultW, FDivBusyE} = '0;
  end

endmodule
