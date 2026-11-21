///////////////////////////////////////////
// ieu.sv
//
// Written:  David Harris David_Harris@hmc.edu 9 January 2021
// Modified: Rose Thompson, Katherine Parry, Kevin Kim, James Stine, Ben Bracker
//
// Purpose: Integer execution unit.
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

module ieu import cvw::*; #(parameter cvw_t P) (
  input  logic              clk, reset,
  // Decode stage signals
  input  logic [31:0]       Slot0InstrD,                           // Instruction
  input  logic [31:0]       Slot1InstrD,                          // Second instruction (superscalar slot 1), decoded but not issued
  input  logic              Slot1IssueD,                          // Slot 1 is paired with slot 0 this cycle
  input  logic              Slot1IssueM, Slot1IssueW,                 // ... and still committing in Memory / Writeback
  input  logic              Slot1LateAD, Slot1LateBD,                 // Slot 1's rs1 / rs2 field matches slot 0's rd
  input  logic              Slot1LateOKD,                         // Slot 1 is an operation the late ALU implements
  input  logic              Slot1FuseD,                           // The pair is fused into one indexed load (issue.sv)
  input  logic              Slot1FuseBrD,                         // The pair is fused into one ALU op + branch (issue.sv)
  input  logic              Slot1FuseBrAddD,                      // ... and slot 0 is an add (else a logic op)
  output logic              FuseM,                            // ... which is now in Memory
  input  logic              Slot1ReplayM,                         // ... and faulted: slot 0 commits as the add alone
  input  logic              PredTakenE,                       // Fetch went to slot 0's branch target (predicted taken)
  output logic              LateBrM,                          // Slot 0 is a branch whose direction is checked in Memory
  output logic              LateBrTakenM,                     // ... its real direction
  output logic              LateBrWrongM,                     // ... and fetch went the other way: redirect from Memory
  output logic              Slot1MemM,                            // The bundle's memory operation is slot 1's
  output logic              Slot1IllegalM,                        // Slot 1 is an illegal instruction; replay it alone
  input  logic [1:0]        STATUS_FS,                        // is FPU enabled?
  input  logic [3:0]        ENVCFG_CBE,                       // Cache block operation enables
  input  logic              IllegalIEUFPUInstrD,              // Illegal instruction
  output logic              Slot0IllegalBaseInstrD,                // Illegal base integer instruction, or illegal RV32E access to upper 16 registers
  // Execute stage signals
  input  logic [P.XLEN-1:0] PCE,                              // PC
  input  logic [P.XLEN-1:0] Slot0PCLinkE,                          // PC + 4
  output logic              Slot0PCSrcE,                           // Select next PC (between PC+4 and Slot0IEUAdrE)
  input  logic              FWriteIntE, FCvtIntE,             // FPU writes to integer register file, FPU converts float to int
  output logic [P.XLEN-1:0] Slot0IEUAdrE,                          // Branch / jump target, from slot 0
  output logic [P.XLEN-1:0] LSUAdrE,                          // Memory address, from whichever slot holds one
  output logic              Slot0IntDivE, W64E,                    // Integer divide, RV64 W-type instruction
  output logic [2:0]        Funct3E,                          // Funct3 instruction field
  output logic [P.XLEN-1:0] Slot0ForwardedSrcAE, Slot0ForwardedSrcBE,   // ALU src inputs before the mux choosing between them and PCE to put in srcA/B
  output logic [4:0]        Slot0RdE,                              // Destination register
  output logic              MDUActiveE,                       // Mul/Div instruction being executed, in either slot
  output logic [P.XLEN-1:0] MDUSrcAE, MDUSrcBE,               // MDU operands, from whichever slot holds the bundle's multiply
  output logic [2:0]        MDUFunct3E, MDUFunct3M,           // MDU operation, from that slot
  output logic              MDUW64E,                          // MDU W-type, from that slot
  output logic              MDUIntDivE,                       // MDU integer divide, from that slot
  output logic [3:0]        CMOpM,                            // 1: cbo.inval; 2: cbo.clean; 4: cbo.flush; 8: cbo.zero
  output logic              IFUPrefetchE,                     // instruction prefetch
  output logic              LSUPrefetchM,                     // data prefetch
  // Memory stage signals
  input  logic              SquashSCW,                        // Squash store conditional, from LSU
  output logic [1:0]        MemRWE,                           // Read/write control goes to LSU
  output logic [1:0]        MemRWM,                           // Read/write control goes to LSU
  output logic [1:0]        AtomicM,                          // Atomic control goes to LSU
  output logic [P.XLEN-1:0] WriteDataM,                       // Write data to LSU
  output logic [2:0]        Funct3M,                          // Funct3 of slot 0, to the FPU
  output logic [2:0]        MemFunct3M,                       // Funct3 (size and signedness) to LSU, from either slot
  output logic [P.XLEN-1:0] Slot0SrcAM,                            // ALU SrcA to Privileged unit and FPU
  output logic [4:0]        Slot0RdM,                              // Destination register
  input  logic [P.XLEN-1:0] FIntResM,                         // Integer result from FPU (fmv, fclass, fcmp)
  output logic              InvalidateICacheM, FlushDCacheM,  // Invalidate I$, flush D$
  output logic              Slot0InstrValidD, InstrValidE, InstrValidM, // Instruction is valid
  output logic              Slot0BranchD, Slot0BranchE,
  output logic              Slot0JumpD, Slot0JumpE,
  output logic              Slot1BranchD, Slot1BranchE,               // Slot 1 is a conditional branch (Slot1BranchD before the issue decision)
  output logic              Slot1JumpD, Slot1JumpE,                   // ... or a jal
  output logic              Slot1PCSrcE,                          // ... that resolved taken (always, for a jal)
  output logic [P.XLEN-1:0] Slot1IEUAdrE,                         // ... to this target
  input  logic [P.XLEN-1:0] Slot1PCLinkE,                         // Slot 1's link address, written by a slot 1 jal
  // Writeback stage signals
  input  logic [P.XLEN-1:0] FIntDivResultW,                   // Integer divide result from FPU (fdivsqrt)
  input  logic [P.XLEN-1:0] CSRReadValW,                      // CSR read value,
  input  logic [P.XLEN-1:0] MDUResultW,                       // multiply/divide unit result
  input  logic [P.XLEN-1:0] FCvtIntResW,                      // FPU's float to int conversion result
  input  logic              FCvtIntW,                         // FPU converts float to int
  output logic [4:0]        Slot0RdW,                              // Destination register
  input  logic [P.XLEN-1:0] ReadDataW,                        // LSU's read data
  // Hazard unit signals
  input  logic              StallD, StallE, StallM, StallW,   // Stall signals from hazard unit
  input  logic              FlushD, FlushE, FlushM, FlushW,   // Flush signals
  output logic              StructuralStallD,                 // IEU detects structural hazard in Decode stage
  output logic              Slot0LoadStallD,                       // Structural stalls for load, sent to performance counters
  output logic              StoreStallD,                      // load after store hazard
  output logic              CSRReadM, CSRWriteM, PrivilegedM, // CSR read, CSR write, is privileged instruction
  output logic              CSRWriteFenceM                    // CSR write or fence instruction needs to flush subsequent instructions
);

  logic [2:0] Slot0ImmSrcD;                                        // Select type of immediate extension
  logic [1:0] Slot0FlagsE;                                         // Comparison flags ({eq, lt})
  logic       Slot0ALUSrcAE, Slot0ALUSrcBE;                             // ALU source operands
  logic [2:0] ResultSrcW;                                     // Selects result in Writeback stage
  logic       Slot0ALUResultSrcE;                                  // Selects ALU result to pass on to Memory stage
  logic [2:0] Slot0ALUSelectE;                                     // ALU select mux signal
  logic       FWriteIntM;                                     // FPU writing to integer register file
  logic       IntDivW;                                        // Integer divide instruction
  logic [3:0] Slot0BSelectE;                                       // BMU result select (binary encoded; see bitmanipalu)
  logic [3:0] Slot0ZBBSelectE;                                     // ZBB Result Select Signal in Execute Stage
  logic [2:0] Slot0BALUControlE;                                   // ALU Control signals for B instructions in Execute Stage
  logic       Slot0SubArithE;                                      // Subtraction or arithmetic shift
  logic       UW64E;                                          // .uw-type instruction

  logic [6:0] Funct7E;

  // Forwarding signals
  logic [4:0] Slot0Rs1D, Slot0Rs2D;
  logic [4:0] Slot0Rs2E;                                           // Source registers

  // Slot 1 (superscalar) Decode-stage outputs: the same signals the controller produces in D for slot 0.
  // Slot 1 is decoded alongside slot 0 but does not issue yet, so these are observed by the testbench only.
  logic [4:0] Slot1Rs1D, Slot1Rs2D;                                 // Slot 1 source registers
  logic [2:0] Slot1ImmSrcD;                                       // Slot 1 immediate format
  logic       Slot1IllegalBaseInstrD;                             // Slot 1 is an illegal base instruction
  logic       Slot1IllegalBaseInstrRawM;                          // ... carried to Memory, before the commit gate
  logic       Slot1InstrValidD;                                   // Slot 1 controller valid bit (not yet qualified by the IFU's Instr1ValidD)
  logic       Slot0StructuralStallD;                              // Slot 0's own structural hazards
  logic [1:0] Slot0MemRWD, Slot0MemRWM;                               // Slot 0 memory read/write in Decode / Memory
  logic       Slot1StructuralStallD;                              // Slot 1 depends on a result not ready to forward
  logic       Slot1LoadStallD;                                    // A slot 1 load's data is not ready to forward yet
  logic       Slot1MDUStallD;                                     // A slot 1 multiply's product is not ready to forward yet
  logic       BundleStoreStallD;                              // The bundle's load would collide with a store on the memory's one port
  logic       Slot0RegWriteM;                                      // Slot 0 writes a register in Memory
  logic       Slot1RegWriteRawM, Slot1RegWriteRawW;                   // What slot 1's controller decoded
  logic       Slot1RegWriteM, Slot1RegWriteW;                         // ... once it is known slot 1 still commits
  logic [4:0] Slot1RdM, Slot1RdW;                                     // Slot 1 destination register in Memory / Writeback

  // Slot 1 Execute-stage signals.  Slot 1 computes a result but does not commit it yet.
  logic [4:0] Slot1Rs1E, Slot1Rs2E;                                 // Slot 1 source registers in Execute
  logic [4:0] Slot1RdE;                                           // Slot 1 destination register in Execute
  logic       Slot1RegWriteE;                                     // Slot 1 writes an integer register in Execute
  logic [2:0] Slot1ForwardAE, Slot1ForwardBE;                         // Slot 1 forwarding selects (from controller c1)
  logic       Slot1ALUSrcAE, Slot1ALUSrcBE, Slot1ALUResultSrcE;           // Slot 1 ALU operand and result selects
  logic [2:0] Slot1ALUSelectE;                                    // Slot 1 ALU operation
  logic [2:0] Slot1Funct3E;                                      // Slot 1 funct3
  logic [6:0] Slot1Funct7E;                                      // Slot 1 funct7
  logic       W64_1E, UW64_1E, Slot1SubArithE;                    // Slot 1 W-type, .uw-type, subtract/arithmetic-shift
  logic [3:0] Slot1BSelectE, Slot1ZBBSelectE;                         // Slot 1 bit-manipulation selects
  logic [2:0] Slot1BALUControlE;                                  // Slot 1 bit-manipulation ALU control
  logic       Slot1BMUActiveE;                                    // Slot 1 bit-manipulation instruction active
  logic [1:0] Slot1CZeroE;                                        // Slot 1 czero.* active
  logic [1:0] Slot1FlagsE;                                        // Slot 1 comparison flags ({eq, lt})
  logic       Slot1BranchSignedE;                                 // Slot 1 branch compares signed

  // Slot 1 late ALU.  A slot 1 that reads slot 0's result executes one stage later, in Memory, where
  // slot 0's result is already registered in Slot0IEUResultM.  See issue.sv for which pairs qualify.
  logic       Slot1LateARawE, Slot1LateBRawE;                         // issue.sv's field matches, in Execute
  logic [1:0] Slot1LateWAD, Slot1LateWBD;                             // Slot 1 operand produced too late by the bundle ahead
  logic [1:0] LateWA1RawE, LateWB1RawE;                       // ... in Execute
  logic [1:0] Slot1LateSelAE, Slot1LateSelBE;                         // Where the late ALU takes each operand from
  logic       Slot1LateE;                                         // Slot 1 executes on the late ALU
  logic       Slot0SlowResultE, Slot1SlowE;                           // Slot 0 / slot 1 in Execute has a result not ready in Memory
  logic       CaptureE;                                       // Execute held while Memory advances

  // Late branch: a slot 0 conditional branch whose operand the bundle ahead produces too late to compare
  // in Execute.  Its direction is checked by the late ALU in Memory instead of stalling it in Decode.
  logic [1:0] Slot0LateWAD, Slot0LateWBD;                             // Slot 0 operand produced too late (as Slot1LateWAD, for slot 0)
  logic       LateBrD, LateBrE;                               // Slot 0 is a late branch
  logic       AssumedTakenM;                                  // The direction it was given in Execute
  logic [2:0] LateFlagsM;                                     // {eq, lt, ltu} from the late ALU
  logic       StructuralStall0GD;                             // Slot 0's own stalls, less those a late branch avoids
  logic       Slot1LateStallD;                                    // A late slot 1's result is not ready to forward yet

  // Late slot 0: a slot 0 ALU operation whose operand the bundle ahead produces too late, run on the
  // late ALU in Memory instead of stalling it in Decode, as a late branch is.
  logic       Slot0LateOKD;                                       // Slot 0 is an operation the late ALU implements
  logic       Slot0LateD, Slot0LateRawE;                              // Slot 0 is to run late / was sent late
  logic       Slot0LateE;                                         // ... and some operand really is substituted
  logic       Slot0SlowE;                                         // Slot 0 in Execute has a result not ready in Memory
  logic       Slot0LateStallD;                                    // A late slot 0's result is not ready to forward yet

  // Slot 1 Memory/Writeback-stage signals.  The core has one load/store unit, so at most one slot of
  // a bundle may hold a memory operation; Slot1MemE/Slot1MemM say it is slot 1's and steer the LSU's inputs
  // to slot 1.  c1 pipelines its own control to M and W with the real StallM/FlushM, exactly as c does.
  logic [1:0] Slot1MemRWD, Slot1MemRWE, Slot1MemRWM, Slot1MemRWRawM;          // Slot 1 memory read/write, before and after the commit gate
  logic       Slot1MemE;                                          // The bundle's memory operation is in slot 1, in Execute
  logic [2:0] Slot1Funct3M;                                      // Slot 1 access size and signedness
  logic [2:0] Slot1ResultSrcW;                                    // Slot 1 writeback source select

  // Slot 1 multiply/divide.  The core has one multiply/divide unit, so at most one slot of a bundle may
  // hold an MDU operation; Slot1MduE/Slot1MduM say it is slot 1's and steer the MDU's inputs to slot 1.
  logic       Slot0MDUActiveE, Slot1MDUActiveE;                       // Slot 0 / slot 1 holds a multiply or divide
  logic       Slot1IntDivE;                                       // Slot 1 holds a divide
  logic       Slot1MduE, Slot1MduM;                                   // The bundle's MDU operation is slot 1's

  // Indexed-load fusion: slot 0 executes the add and the load after it as one load (issue.sv).
  logic       FuseD, FuseE;                                   // The bundle is a fused indexed load
  logic [2:0] FuseFunct3E, FuseFunct3M;                       // ... with the load's width and signedness
  logic [2:0] Mem0Funct3M;                                    // Slot 0's memory funct3: its own, or the fused load's
  logic       UnfuseW;                                        // The fused load faulted: slot 0 writes the add's sum
  logic [2:0] Slot0ResultSrcRawW;                                    // Slot 0's writeback select from the controller
  logic       Slot1FuseBrAE, Slot1FuseBrBE;                           // Fused ALU + branch: slot 1's rs1 / rs2 is slot 0's result
  logic       Slot1FuseBrAddE;                                    // Fused ALU + branch whose slot 0 is an add (else a logic op)

  logic [2:0] Slot0ForwardAE, Slot0ForwardBE;                           // Select signals for forwarding multiplexers
  logic       Slot0RegWriteW;                                      // Register will be written in Writeback stage
  logic       Slot0BranchSignedE;                                  // Branch does signed comparison on operands
  logic       Slot0BMUActiveE;                                     // Bit manipulation instruction being executed
  logic [1:0] Slot0CZeroE;                                         // {czero.nez, czero.eqz} instructions active

  controller #(P) c(
    .clk, .reset, .StallD, .FlushD, .Slot0InstrD, .STATUS_FS, .ENVCFG_CBE, .Slot0ImmSrcD,
    .IllegalIEUFPUInstrD, .Slot0IllegalBaseInstrD,
    .StructuralStallD(Slot0StructuralStallD), .Slot0LoadStallD, .StoreStallD, .Slot0Rs1D, .Slot0Rs2D, .Slot0Rs2E, .Slot0MemRWD(Slot0MemRWD),
    .Slot1Rs1D, .Slot1Rs2D, .Slot1StructuralStallD,                     // slot 1's hazard, computed here against the real Slot0RdE
    .FuseLoadD(FuseD),                                        // slot 0's add also does slot 1's load
    .SlowResultE(Slot0SlowResultE), .LateBrE, .PredTakenE,
    .StallE, .FlushE, .Slot0FlagsE, .FWriteIntE,
    .Slot0PCSrcE, .Slot0ALUSrcAE, .Slot0ALUSrcBE, .Slot0ALUResultSrcE, .Slot0ALUSelectE,
    .Funct3E, .Funct7E, .Slot0IntDivE, .W64E, .UW64E, .Slot0SubArithE, .Slot0BranchD, .Slot0BranchE, .Slot0JumpD, .Slot0JumpE,
    .Slot0BranchSignedE, .Slot0BSelectE, .Slot0ZBBSelectE, .Slot0BALUControlE, .Slot0BMUActiveE, .Slot0CZeroE, .MDUActiveE(Slot0MDUActiveE),
    .FCvtIntE, .Slot0ForwardAE, .Slot0ForwardBE, .CMOpM, .IFUPrefetchE, .LSUPrefetchM,
    // MemRWM and Funct3M are the only two LSU inputs that can differ by slot, so they are taken to
    // local names here and muxed against slot 1's below.  The rest reach the LSU and the privileged
    // unit straight from slot 0, and which slot they came from never has to be asked: issue.sv's
    // whitelist admits only LUI/AUIPC/OP-IMM/OP (and the RV64 W forms) to slot 1, so a bundle whose
    // slot 1 is an atomic, a CSR access, a privileged instruction, cbo.* or fence.i cannot pair at
    // all, leaving slot 1's copy of those signals structurally zero.  MemRWE is simply a dead port.
    .StallM, .FlushM, .MemRWE, .MemRWM(Slot0MemRWM), .CSRReadM, .CSRWriteM, .PrivilegedM, .AtomicM, .Funct3M,
    // Slot 0's illegal instruction already reaches the privileged unit through Slot0IllegalBaseInstrD, which
    // privpiperegs.sv pipelines, so the Memory-stage copy is only needed for slot 1's replay.
    .FlushDCacheM, .InstrValidM, .InstrValidE, .Slot0InstrValidD, .FWriteIntM, .IllegalBaseInstrM(),
    .Slot0RegWriteM, .RegWriteOtherM(Slot1RegWriteM),                  // slot 0 forwards from slot 1
    .StallW, .FlushW, .Slot0RegWriteW, .IntDivW, .ResultSrcW(Slot0ResultSrcRawW), .CSRWriteFenceM, .InvalidateICacheM,
    .RegWriteOtherW(Slot1RegWriteW),
    .Slot0RdW, .Slot0RdE, .Slot0RdM, .RdOtherM(Slot1RdM), .RdOtherW(Slot1RdW), .Slot0RegWriteE());

  // Slot 1 controller (superscalar).  A second copy of the controller decodes Slot1InstrD in the Decode stage.
  // Only its Decode-stage outputs are used; slot 1 does not issue, so its Execute/Memory/Writeback
  // outputs are left unconnected and its Execute-stage feedback inputs are tied off.
  if (P.SUPERSCALAR_SUPPORTED) begin : slot1ctrl
    controller #(P, 0) c1(
      .clk, .reset, .StallD, .FlushD, .Slot0InstrD(Slot1InstrD), .STATUS_FS, .ENVCFG_CBE, .Slot0ImmSrcD(Slot1ImmSrcD),
      .IllegalIEUFPUInstrD(1'b0), .Slot0IllegalBaseInstrD(Slot1IllegalBaseInstrD),
      // The load-use hazard cannot be computed here: it depends on the Execute-stage control of the
      // real pipeline (MemReadE, CSRReadE, MDUE), which only c has.  c computes it for both slots.
      .StructuralStallD(), .Slot0LoadStallD(), .StoreStallD(),
      .Slot1Rs1D(5'b0), .Slot1Rs2D(5'b0), .Slot1StructuralStallD(), .SlowResultE(), .LateBrE(1'b0), .PredTakenE(1'b0), .FuseLoadD(1'b0),
      .Slot0Rs1D(Slot1Rs1D), .Slot0Rs2D(Slot1Rs2D), .Slot0Rs2E(Slot1Rs2E), .Slot0MemRWD(Slot1MemRWD),
      // An unpaired slot 1 is flushed on its way into Execute rather than being allowed down the
      // pipeline and suppressed at each consumer.  Its control signals, Slot1RegWriteM/W and Slot1RdM/W then
      // come out as zero on their own, so nothing downstream needs to know about pairing.
      // Slot1BranchE, Slot1JumpE and Slot1PCSrcE therefore describe a slot 1 that issued.  Slot 0 is never a branch
      // or a jump beside a slot 1 branch or jal, so a slot 1 control transfer is never killed by slot 0.
      // A fused slot 1 is flushed the same way: slot 0 does its load, so slot 1 is a bubble from Execute on.
      // It still retires -- Slot1IssueE/M/W stay set, so minstret and the tracer count it.
      .StallE, .FlushE(FlushE | ~Slot1IssueD | FuseD), .Slot0FlagsE(Slot1FlagsE), .FWriteIntE(1'b0),
      .Slot0PCSrcE(Slot1PCSrcE), .Slot0ALUSrcAE(Slot1ALUSrcAE), .Slot0ALUSrcBE(Slot1ALUSrcBE), .Slot0ALUResultSrcE(Slot1ALUResultSrcE), .Slot0ALUSelectE(Slot1ALUSelectE),
      .Funct3E(Slot1Funct3E), .Funct7E(Slot1Funct7E), .Slot0IntDivE(Slot1IntDivE), .W64E(W64_1E), .UW64E(UW64_1E), .Slot0SubArithE(Slot1SubArithE),
      .Slot0BranchD(Slot1BranchD), .Slot0BranchE(Slot1BranchE), .Slot0JumpD(Slot1JumpD), .Slot0JumpE(Slot1JumpE),
      .Slot0BranchSignedE(Slot1BranchSignedE), .Slot0BSelectE(Slot1BSelectE), .Slot0ZBBSelectE(Slot1ZBBSelectE), .Slot0BALUControlE(Slot1BALUControlE),
      .Slot0BMUActiveE(Slot1BMUActiveE), .Slot0CZeroE(Slot1CZeroE), .MDUActiveE(Slot1MDUActiveE),
      .FCvtIntE(1'b0), .Slot0ForwardAE(Slot1ForwardAE), .Slot0ForwardBE(Slot1ForwardBE), .CMOpM(), .IFUPrefetchE(), .LSUPrefetchM(),
      // Only the two signals the LSU reads per-slot are connected.  AtomicM, CSRReadM, CSRWriteM and
      // PrivilegedM stay open because the issue rules keep atomics, CSR accesses and privileged
      // instructions in slot 0.  CMOpM and FlushDCacheM stay open because cbo.* and fence.i are
      // MISC_MEM, which slot 1's whitelist never admits, so they are constant zero here.  And
      // LSUPrefetchM, like MemRWE, is a dead input on the LSU: declared, never read.
      // A slot 1 killed in Execute by a taken branch in slot 0 is flushed on its way into Memory, for the
      // same reason.  Gating Slot1RegWriteM/W below is not enough on its own: c1's forwarding logic reads its
      // own Slot0RegWriteM/W, so a dead slot 1 would still forward its result to the next bundle's slot 1.
      // A correctly predicted taken branch puts its target in Execute the very next cycle, so this
      // happens whenever slot 1 of the target bundle reads the fall-through's destination.
      .StallM, .FlushM(FlushM | Slot0PCSrcE), .MemRWE(Slot1MemRWE), .MemRWM(Slot1MemRWRawM), .CSRReadM(), .CSRWriteM(), .PrivilegedM(), .AtomicM(), .Funct3M(Slot1Funct3M),
      .FlushDCacheM(), .InstrValidM(), .InstrValidE(), .Slot0InstrValidD(Slot1InstrValidD), .FWriteIntM(),
      .IllegalBaseInstrM(Slot1IllegalBaseInstrRawM),
      .Slot0RegWriteM(Slot1RegWriteRawM), .RegWriteOtherM(Slot0RegWriteM),    // slot 1 forwards from slot 0
      .StallW, .FlushW, .Slot0RegWriteW(Slot1RegWriteRawW), .IntDivW(), .ResultSrcW(Slot1ResultSrcW), .CSRWriteFenceM(), .InvalidateICacheM(),
      .RegWriteOtherW(Slot0RegWriteW),
      .Slot0RdW(Slot1RdW), .Slot0RdE(Slot1RdE), .Slot0RdM(Slot1RdM), .RdOtherM(Slot0RdM), .RdOtherW(Slot0RdW), .Slot0RegWriteE(Slot1RegWriteE));
  end else begin : noslot1ctrl
    // Single issue: there is no slot 1 to decode, so all of its control is constant.
    assign {Slot1ImmSrcD, Slot1IllegalBaseInstrD, Slot1Rs1D, Slot1Rs2D, Slot1Rs2E, Slot1MemRWD, Slot1PCSrcE, Slot1ALUSrcAE, Slot1ALUSrcBE,
            Slot1ALUResultSrcE, Slot1ALUSelectE, Slot1Funct3E, Slot1Funct7E, Slot1IntDivE, W64_1E, UW64_1E, Slot1SubArithE,
            Slot1BranchD, Slot1BranchE, Slot1JumpD, Slot1JumpE, Slot1BranchSignedE, Slot1BSelectE, Slot1ZBBSelectE, Slot1BALUControlE,
            Slot1BMUActiveE, Slot1CZeroE, Slot1MDUActiveE, Slot1ForwardAE, Slot1ForwardBE, Slot1MemRWE, Slot1MemRWRawM, Slot1Funct3M,
            Slot1InstrValidD, Slot1IllegalBaseInstrRawM, Slot1RegWriteRawM, Slot1RegWriteRawW, Slot1ResultSrcW, Slot1RdW, Slot1RdE, Slot1RegWriteE, Slot1RdM} = '0;
  end

  // Slot 1 can be abandoned in Execute, after its controller's Execute register has already loaded --
  // when slot 0 turns out to be a taken branch and slot 1 was the fall-through.  c1's FlushM above
  // clears that case, and Slot1IssueW adds the Memory-stage replay, so qualify the register-write signals
  // with Slot1IssueM/Slot1IssueW here: these feed both the second write port and slot 0's forwarding network,
  // so an abandoned slot 1 neither writes nor is bypassed.
  assign Slot1RegWriteM = Slot1RegWriteRawM & Slot1IssueM;
  assign Slot1RegWriteW = Slot1RegWriteRawW & Slot1IssueW;

  // A slot 1 store reaches memory in the Memory stage, so it needs the same commit gate: without it
  // an abandoned slot 1 would still write memory, which no later redirect can undo.  Gating here
  // rather than in Execute is also the cheaper placement -- both inputs are register outputs, where
  // Slot1KillE (and so Slot0PCSrcE, out of the branch comparator) arrives late in Execute.
  assign Slot1MemRWM = Slot1MemRWRawM & {2{Slot1IssueM}};

  // Slot 1 holds an encoding that is not a legal instruction in this configuration.  Fetch cannot tell
  // that apart from a legal one -- sh1add and an illegal encoding are the same bits, separated only by
  // P.ZBA_SUPPORTED -- so the issue rules let slot 1 take any encoding its ALU could execute and leave
  // the verdict to c1's own decoder, which already reaches it.  Slot 1 never executes it: the commit
  // gate stops the register write, and the replay discards it and refetches it as slot 0, the only
  // slot the privileged unit can describe.
  assign Slot1IllegalM = Slot1IllegalBaseInstrRawM & Slot1IssueM;

  // Which slot owns the single load/store unit.  The issue rules permit at most one memory operation
  // per bundle, so "slot 1 has one" is the same statement as "slot 0 does not", and one select does
  // for both.  Slot1MemE steers the Execute-stage inputs -- the address and the store data, in
  // datapath.sv -- and Slot1MemM the control the LSU reads in Memory.  Neither needs a register of its
  // own, because c1 already pipelines its control from Execute to Memory alongside c.
  // ~Slot0PCSrcE is the same condition as ifu.sv's Slot1KillE: a taken branch in slot 0 leaves slot 1 as the
  // fall-through, which must not act.  Slot1MemRWM already stops the access, so this is not needed for
  // correctness -- it keeps the LSU from latching a dead slot 1's address into IEUAdrM, which the
  // branch predictor reads when it updates a target.  It is free because, with the address reaching
  // the LSU on its own net, nothing downstream of this select in Execute is more than a register.
  assign Slot1MemE = |Slot1MemRWE & ~Slot0PCSrcE;
  assign Slot1MemM = |Slot1MemRWM;

  // MemRWM reaches nothing but the load/store unit, so it is muxed in place.  Funct3M is not that
  // private: the MDU selects its result from it (mul vs mulh vs div vs rem) and the FPU's integer
  // divide reads it too.  Muxing it would hand an MDU operation in slot 0 the funct3 of a load in
  // slot 1 and silently return the wrong product, so the memory funct3 goes out on its own net
  // instead, exactly as LSUAdrE does for the address.
  if (P.SUPERSCALAR_SUPPORTED) begin : memslot
    mux2 #(2) memrwmmux(Slot0MemRWM, Slot1MemRWM, Slot1MemM, MemRWM);
    mux2 #(3) memfunct3mmux(Mem0Funct3M, Slot1Funct3M, Slot1MemM, MemFunct3M);
  end else begin : memslot0
    assign MemRWM     = Slot0MemRWM;
    assign MemFunct3M = Mem0Funct3M;
  end

  // Indexed-load fusion (issue.sv).  Slot 0's controller turns the add into the load (FuseLoadD), and
  // slot 1's controller is flushed into Execute above.  What is left for here:
  //   - the load's width and signedness.  Slot 0's Funct3 belongs to the add and also drives its ALU
  //     (sh2add is funct3 100), so the load's funct3 rides beside it to Memory, for the LSU only.
  //       sh2add a5,a5,s1 ; lw a5,0(a5)    ALU uses 100 (shift by 2), LSU uses 010 (word, signed)
  //   - a fault.  The trap would name the add's PC, so as in the paper the pair is replayed unfused: the
  //     existing slot 1 replay (Slot1ReplayM) suppresses the trap, slot 0 commits as the add alone and writes
  //     its sum (still in IFResultW, since the ALU result is carried to Writeback for every instruction),
  //     and fetch restarts at the load, which runs alone and traps with its own PC.
  assign FuseD = Slot1IssueD & Slot1FuseD;
  if (P.FUSION_SUPPORTED) begin : fuseload
    flopenrc #(4) FuseEReg(clk, reset, FlushE, ~StallE, {FuseD, Slot1InstrD[14:12]}, {FuseE, FuseFunct3E});
    flopenrc #(4) FuseMReg(clk, reset, FlushM, ~StallM, {FuseE, FuseFunct3E}, {FuseM, FuseFunct3M});
    flopenrc #(1) UnfuseWReg(clk, reset, FlushW, ~StallW, FuseM & Slot1ReplayM, UnfuseW);
    mux2 #(3) resultsrcwmux(Slot0ResultSrcRawW, 3'b000, UnfuseW, ResultSrcW);   // 000: the ALU result, the add's sum
    mux2 #(3) mem0funct3mmux(Funct3M, FuseFunct3M, FuseM, Mem0Funct3M);   // the fused load's width (above)
  end else begin : nofuseload
    assign {FuseE, FuseFunct3E, FuseM, FuseFunct3M, UnfuseW} = '0;
    assign ResultSrcW  = Slot0ResultSrcRawW;
    assign Mem0Funct3M = Funct3M;
  end

  // Which slot owns the single multiply/divide unit, by the same reasoning as the load/store unit
  // above: the issue rules permit at most one MDU operation per bundle.  Unlike Slot1MemE this select
  // needs no ~Slot0PCSrcE.  The multiplier has no enable and no side effect -- it multiplies whatever it is
  // given every cycle, and only the selected, committed result is ever written -- so a slot 1 multiply
  // killed by a taken branch in slot 0 computes a product that Slot1RegWriteM/W, gated by Slot1IssueM/W, never
  // write.  The divider does act when it starts, but issue.sv never pairs a slot 1 divide with a slot
  // 0 branch, so a slot 1 divide that reaches Execute always commits.  Slot1MDUActiveE comes straight out
  // of c1's Execute register, so the select adds no logic ahead of the operand muxes in datapath.sv.
  //
  // The MDU's funct3, W64 and divide start go out on their own nets, as MemFunct3M does: slot 0's
  // Funct3E/M, W64E and Slot0IntDivE also feed the FPU's integer divide and conversions, which must keep
  // seeing slot 0.
  // Which of slot 1's operands the late ALU replaces with slot 0's result.  issue.sv matched raw
  // register fields, which for an immediate or a PC operand are not registers at all, so the bits are
  // cleared here for an operand the ALU does not take from the register file, and for lui, whose
  // result is its immediate.  What remains is exactly the set of real dependencies, because issue.sv
  // never pairs a dependent slot 1 it could not mark.  The register flushes like c1's Execute stage,
  // so an unpaired slot 1 is never late.
  // The Decode-stage compare against the decompressed fields is belt and braces: instrfields may name a
  // register that a compressed HINT's decompressed form replaces with x0, and the late ALU must never
  // substitute slot 0's result for an operand that reads some other register.
  logic Slot1LateADQ, Slot1LateBDQ;
  assign Slot1LateADQ = Slot1LateAD & (Slot1Rs1D == Slot0InstrD[11:7]);
  assign Slot1LateBDQ = Slot1LateBD & (Slot1Rs2D == Slot0InstrD[11:7]);
  // A fused slot 1's rs1 is slot 0's rd too, but it is a bubble, so it is never late.
  flopenrc #(2) Slot1LateEReg(clk, reset, FlushE | ~Slot1IssueD | FuseD, ~StallE, {Slot1LateADQ, Slot1LateBDQ}, {Slot1LateARawE, Slot1LateBRawE});

  // Fused ALU + branch (issue.sv): which of the branch's operands is slot 0's result, so slot 1's comparator
  // takes it from slot 0's ALU (datapath.sv).  It never also goes late: a branch's ALU operands are the PC
  // and the offset, so Slot1LateSelAE/Slot1LateSelBE below are 00.  And slot 0 is then never late itself (Slot0LateD
  // and LateBrD refuse when Slot1LateADQ/Slot1LateBDQ is set), so its result is ready in Execute.
  //   addi t0, t0, -1 ; bnez t0, L      Slot1FuseBrAE = 1: compare slot 0's t0 with x0
  if (P.FUSION_SUPPORTED) begin : fusebr
    flopenrc #(3) FuseBrEReg(clk, reset, FlushE | ~Slot1IssueD, ~StallE,
                             {Slot1FuseBrD & Slot1LateADQ, Slot1FuseBrD & Slot1LateBDQ, Slot1FuseBrD & Slot1FuseBrAddD & (Slot1LateADQ | Slot1LateBDQ)},
                             {Slot1FuseBrAE, Slot1FuseBrBE, Slot1FuseBrAddE});
  end else begin : nofusebr
    assign {Slot1FuseBrAE, Slot1FuseBrBE, Slot1FuseBrAddE} = '0;
  end

  // The late ALU also takes an operand that the bundle now in Execute produces too late to forward --
  // a load, a multiply or divide, a CSR read or an FPU-to-integer move in slot 0, or a load, multiply
  // or late operation in slot 1.  Instead of stalling the bundle in Decode, slot 1 goes late: when it
  // reaches Memory its producer is in Writeback, and the value is in Slot0ResultW or Slot1ResultW.  Slot 1 of
  // the producing bundle is younger, so it is checked first; when it writes the register but is fast,
  // ordinary forwarding from Memory is correct and nothing is needed.  Only for a slot 1 the late ALU
  // can execute (Slot1LateOKD); otherwise the stalls below still apply.
  //
  // This depends on the producer being exactly one stage ahead when slot 1 reaches Memory, which the
  // pipeline guarantees except when Execute is held while Memory advances (CaptureE): then the producer
  // retires first, but datapath.sv's operand capture has meanwhile picked its value up in Execute, so
  // these bits are cleared and slot 1 takes its operands as captured.
  //
  // A late slot 0 (below) is a slow producer too: its result first appears in Slot0ResultW.
  assign Slot0SlowE   = Slot0SlowResultE | Slot0LateE;
  assign Slot1SlowE   = Slot1MemRWE[1] | Slot1MDUActiveE | Slot1LateE;
  assign Slot1LateWAD = ((Slot1RdE != 5'b0) & Slot1RegWriteE & ~Slot0PCSrcE & (Slot1Rs1D == Slot1RdE)) ? {2{Slot1SlowE}} :
                    ((Slot0RdE  != 5'b0) & (Slot1Rs1D == Slot0RdE) & Slot0SlowE) ? 2'b10 : 2'b00;
  assign Slot1LateWBD = ((Slot1RdE != 5'b0) & Slot1RegWriteE & ~Slot0PCSrcE & (Slot1Rs2D == Slot1RdE)) ? {2{Slot1SlowE}} :
                    ((Slot0RdE  != 5'b0) & (Slot1Rs2D == Slot0RdE) & Slot0SlowE) ? 2'b10 : 2'b00;
  assign CaptureE = StallE & ~StallM;

  // Late branch.  Slot 0 is a conditional branch with an operand produced too late, exactly as Slot1LateWAD
  // describes for slot 1, so rather than stall it in Decode it passes through Execute and the late ALU
  // compares its operands in Memory, taking the late one from Slot0ResultW or Slot1ResultW.  Until then it goes
  // the way fetch went (PredTakenE): Execute neither redirects on its direction nor trains the predictor
  // with it, but still checks and corrects its target.  If Memory finds the other direction, ifu.sv
  // redirects from there and hazard.sv flushes what was fetched behind it, as for a replay.  That costs
  // one cycle more than an Execute-stage misprediction, against the stall cycle it saves every time.
  //
  // The late ALU serves one instruction per bundle, so a slot 1 that needs it, or that holds the
  // memory operation (whose access would happen beside a branch not yet known to fall through, and
  // which might need a replay of its own), keeps the bundle on the ordinary stalling path.  The
  // redirect uses the Memory-stage path that CSR writes and fences use, and the target misalignment
  // check stays in Execute, so a late branch also needs those and compressed instructions.
  assign Slot0LateWAD = ((Slot1RdE != 5'b0) & Slot1RegWriteE & ~Slot0PCSrcE & (Slot0Rs1D == Slot1RdE)) ? {2{Slot1SlowE}} :
                    ((Slot0RdE  != 5'b0) & (Slot0Rs1D == Slot0RdE) & Slot0SlowE) ? 2'b10 : 2'b00;
  assign Slot0LateWBD = ((Slot1RdE != 5'b0) & Slot1RegWriteE & ~Slot0PCSrcE & (Slot0Rs2D == Slot1RdE)) ? {2{Slot1SlowE}} :
                    ((Slot0RdE  != 5'b0) & (Slot0Rs2D == Slot0RdE) & Slot0SlowE) ? 2'b10 : 2'b00;
  assign LateBrD  = P.LATE_ALU_SUPPORTED & (P.ZICSR_SUPPORTED | P.ZIFENCEI_SUPPORTED) & P.ZCA_SUPPORTED &
                    Slot0BranchD & (|Slot0LateWAD | |Slot0LateWBD) &
                    ~(Slot1IssueD & (|Slot1MemRWD | Slot1LateADQ | Slot1LateBDQ | |Slot1LateWAD | |Slot1LateWBD));
  flopenrc #(1) LateBrEReg(clk, reset, FlushE, ~StallE, LateBrD, LateBrE);

  // Late slot 0.  Example:
  //   bundle A:  lw   a5, 0(a0)
  //   bundle B:  addi a4, a5, 3     <- slot 0 needs a5, which the previous bundle is still loading
  // Normally B stalls one cycle in Decode.  Instead B moves on: its Execute ALU result is wrong and
  // unused, and the late ALU computes a5 + 3 in Memory, when A is in Writeback and a5 is in Slot0ResultW.
  // Slot 0 goes late when all of these hold:
  //   Slot0LateOKD                   the late ALU implements it (add, sub, logic, shift, slt)
  //   |Slot0LateWAD | |Slot0LateWBD      an operand is a slow result of the previous bundle (it would stall)
  //   ~(Slot1IssueD & ...)           slot 1 does not need the late ALU; only one instruction may use it
  // Otherwise the usual stall applies.  The late result goes only to the Writeback register
  // (datapath.sv), so a consumer in the next bundle goes late too (Slot0SlowE) or stalls a cycle
  // (Slot0LateStallD).  Unlike a late branch it redirects nothing, so a slot 1 load or store may sit beside it.
  // Slot0LateOKD is checked here in Decode on Slot0InstrD, the instruction slot 0 really holds.  Fetch's raw bits
  // are not it for an instruction that spills across a fetch boundary.  Slot0InstrD is already decompressed,
  // so lateok.sv's 32-bit table covers compressed instructions too (c.addi is addi, c.beqz is beq).
  if (P.LATE_ALU_SUPPORTED) begin : late0ok
    lateok #(P) lateok0(.Instr(Slot0InstrD), .MemRW(2'b00), .IsBranch(1'b0), .Recognized(1'b1), .LateOK(Slot0LateOKD));
  end else begin : nolate0ok
    assign Slot0LateOKD = 1'b0;
  end
  // A fused slot 0 is never late either -- its Execute sum is the load's address -- and needs no term of
  // its own: the fused load reads slot 0's rd, so Slot1LateADQ is set and the last line already refuses it.
  assign Slot0LateD = P.LATE_ALU_SUPPORTED & Slot0LateOKD & (|Slot0LateWAD | |Slot0LateWBD) &
                  ~(Slot1IssueD & (Slot1LateADQ | Slot1LateBDQ | |Slot1LateWAD | |Slot1LateWBD));
  flopenrc #(1) Slot0LateEReg(clk, reset, FlushE, ~StallE, Slot0LateD, Slot0LateRawE);

  // The late ALU's Writeback operand selects: slot 0's for a late branch or late slot 0, else slot 1's.
  flopenrc #(4) Slot1LateWEReg(clk, reset, FlushE | (~Slot1IssueD & ~LateBrD & ~Slot0LateD) | CaptureE, ~StallE | CaptureE,
                           (LateBrD | Slot0LateD) ? {Slot0LateWAD, Slot0LateWBD} : ({Slot1LateWAD, Slot1LateWBD} & {4{Slot1LateOKD}}),
                           {LateWA1RawE, LateWB1RawE});

  // Each operand's source for the late ALU: 00 as captured in Execute, 01 slot 0's result in Memory,
  // 10 Slot0ResultW, 11 Slot1ResultW.  Slot 0 of the same bundle is the youngest producer, so it wins.  Nothing
  // applies to an operand that is not a register (the ALU takes the PC or an immediate there) or to lui.
  // A late branch's two operands are always registers.
  //
  // Slot1LateSelAE/Slot1LateSelBE pick each late ALU operand in Memory:
  //   00 keep the value carried from Execute     10 replace with Slot0ResultW  (previous bundle's slot 0)
  //   01 replace with this bundle's slot 0       11 replace with Slot1ResultW (previous bundle's slot 1)
  // At most one instruction per bundle uses the late ALU, and it decides which line applies:
  //   1. late branch (LateBrE):   slot 0's code from Decode, as is
  //   2. late slot 0 (Slot0LateRawE): slot 0's code, but 00 if the operand is not a register
  //   3. otherwise:               slot 1's code (Julia's slot 1 late path, unchanged)
  // LateWA1RawE/LateWB1RawE hold slot 0's code in cases 1 and 2 and slot 1's in case 3 (Slot1LateWEReg).
  // "Not a register": Slot0ALUSrcAE means operand A is the PC (auipc), Slot0ALUSrcBE means operand B is the
  // immediate (addi), Slot0ALUResultSrcE means the result is not the ALU's (lui).  Decode compares raw bit
  // fields, so e.g. addi a4, a1, 15 has 15 where rs2 would be and looks like it reads x15 (a5).
  // With LATE_ALU_SUPPORTED = 0 both selects are 00: nothing is late, and the late ALU is unused.
  assign Slot1LateSelAE = ~P.LATE_ALU_SUPPORTED ? 2'b00 :
                      LateBrE   ? LateWA1RawE :
                      Slot0LateRawE ? ((Slot0ALUSrcAE | Slot0ALUResultSrcE) ? 2'b00 : LateWA1RawE) :
                      (Slot1ALUSrcAE | Slot1ALUResultSrcE) ? 2'b00 : Slot1LateARawE ? 2'b01 : LateWA1RawE;
  assign Slot1LateSelBE = ~P.LATE_ALU_SUPPORTED ? 2'b00 :
                      LateBrE   ? LateWB1RawE :
                      Slot0LateRawE ? ((Slot0ALUSrcBE | Slot0ALUResultSrcE) ? 2'b00 : LateWB1RawE) :
                      (Slot1ALUSrcBE | Slot1ALUResultSrcE) ? 2'b00 : Slot1LateBRawE ? 2'b01 : LateWB1RawE;

  // Slot0LateRawE says Decode sent slot 0 to the late ALU; Slot0LateE says an operand is really replaced.
  // They differ on a false match (the immediate above) or when CaptureE cleared the codes because
  // Execute already captured the value.  Then nothing is late and slot 0's Execute result is used.
  // Slot 1 cannot be late in a bundle whose slot 0 was sent to the late ALU.
  assign Slot0LateE     = Slot0LateRawE & (|Slot1LateSelAE | |Slot1LateSelBE);              // slot 0 is late
  assign Slot1LateE     = ~LateBrE & ~Slot0LateRawE & (|Slot1LateSelAE | |Slot1LateSelBE);  // slot 1 is late

  // In Memory: the branch's real direction from the late ALU's flags, by funct3 as the comparator does.
  flopenrc #(2) LateBrMReg(clk, reset, FlushM, ~StallM, {LateBrE, Slot0PCSrcE}, {LateBrM, AssumedTakenM});
  always_comb
    case (Funct3M)
      3'b000:  LateBrTakenM =  LateFlagsM[2];   // beq
      3'b001:  LateBrTakenM = ~LateFlagsM[2];   // bne
      3'b100:  LateBrTakenM =  LateFlagsM[1];   // blt
      3'b101:  LateBrTakenM = ~LateFlagsM[1];   // bge
      3'b110:  LateBrTakenM =  LateFlagsM[0];   // bltu
      3'b111:  LateBrTakenM = ~LateFlagsM[0];   // bgeu
      default: LateBrTakenM = 1'b0;
    endcase
  assign LateBrWrongM = LateBrM & (LateBrTakenM != AssumedTakenM);

  assign Slot1MduE = Slot1MDUActiveE;
  assign MDUActiveE = Slot0MDUActiveE | Slot1MDUActiveE;
  if (P.SUPERSCALAR_SUPPORTED) begin : mduslot
    flopenrc #(1) Slot1MduMReg(clk, reset, FlushM, ~StallM, Slot1MduE, Slot1MduM);
    mux2 #(3) mdufunct3emux(Funct3E, Slot1Funct3E, Slot1MduE, MDUFunct3E);
    mux2 #(3) mdufunct3mmux(Funct3M, Slot1Funct3M, Slot1MduM, MDUFunct3M);
    mux2 #(1) mduw64emux(W64E, W64_1E, Slot1MduE, MDUW64E);
    mux2 #(1) mduintdivemux(Slot0IntDivE, Slot1IntDivE, Slot1MduE, MDUIntDivE);
  end else begin : mduslot0
    assign Slot1MduM      = 1'b0;
    assign MDUFunct3E = Funct3E;
    assign MDUFunct3M = Funct3M;
    assign MDUW64E    = W64E;
    assign MDUIntDivE = Slot0IntDivE;
  end

  // Memory hazards for the bundle.  The controller states both of these against slot 0's Execute stage,
  // which covers every case where slot 0 holds the memory operation.  Once slot 1 may hold it instead,
  // the same two hazards have to be stated again with slot 1 as the producer.
  //
  // Load-use: a load's data is not ready in Memory, so a dependent instruction one bundle behind has
  // to wait.  Slot 1's Memory-stage forwarding source, Slot1IEUResultM, is slot 1's ALU result, which for
  // a load is its address -- forwarding it would quietly supply the wrong value.  One stall cycle
  // pushes the consumer to forward from Writeback instead, where Slot1ResultW is the real load data.  All
  // four Decode-stage sources are checked, because either slot may be the consumer.
  //
  // In all three of these, a slot 1 consumer the late ALU can execute does not stall: it goes late and
  // takes the value from Slot1ResultW (see Slot1LateWAD above).  A slot 0 consumer that goes late does not
  // stall either -- a late branch (LateBrD) or a late slot 0 (Slot0LateD).  Example:
  //   bundle A:  addi t0, t0, 1   | lw a5, 0(a0)
  //   bundle B:  add  a4, a4, a5  | ...            <- slot 0 goes late and takes a5 from Slot1ResultW
  assign Slot1LoadStallD = Slot1MemRWE[1] & (Slot1RdE != 5'b0) &
                       (~(LateBrD | Slot0LateD) & ((Slot0Rs1D == Slot1RdE) | (Slot0Rs2D == Slot1RdE)) |
                        (Slot1IssueD & ~Slot1LateOKD & ((Slot1Rs1D == Slot1RdE) | (Slot1Rs2D == Slot1RdE))));

  // Multiply/divide-use, for the same reason: the result is not complete until the end of Memory, so
  // it first appears in Slot1ResultW, and Slot1IEUResultM holds slot 1's meaningless ALU output.  This is the
  // slot 1 counterpart of the controller's Slot0MDUStallD, which charges slot 0's MDU operations the same
  // cycle.  A divide's iterations happen while DivBusyE holds the whole pipeline, so from the
  // consumer's point of view a divide is no later than a multiply once it leaves Execute.
  assign Slot1MDUStallD = Slot1MDUActiveE & (Slot1RdE != 5'b0) &
                      (~(LateBrD | Slot0LateD) & ((Slot0Rs1D == Slot1RdE) | (Slot0Rs2D == Slot1RdE)) |
                       (Slot1IssueD & ~Slot1LateOKD & ((Slot1Rs1D == Slot1RdE) | (Slot1Rs2D == Slot1RdE))));

  // Late-ALU-use, for the same reason again: a late slot 1 computes its result in Memory, so it first
  // appears in Slot1ResultW, and Slot1IEUResultM holds what slot 1's Execute ALU made of a stale operand.
  // Forwarding the late ALU's output to Execute instead would chain it into the next bundle's ALU,
  // which is the critical path the late ALU exists to avoid.
  assign Slot1LateStallD = Slot1LateE & (Slot1RdE != 5'b0) &
                       (~(LateBrD | Slot0LateD) & ((Slot0Rs1D == Slot1RdE) | (Slot0Rs2D == Slot1RdE)) |
                        (Slot1IssueD & ~Slot1LateOKD & ((Slot1Rs1D == Slot1RdE) | (Slot1Rs2D == Slot1RdE))));

  // Late-slot-0-use: the same as Slot1LateStallD, with the previous bundle's slot 0 as the late producer.
  //   bundle A:  add a4, a4, a5   | ...   <- slot 0 is late (Slot0LateE): a4 is computed in Memory
  //   bundle B:  lw  a6, 0(a4)    | ...   <- needs a4 in Execute for its address
  // A's correct a4 first appears in Slot0ResultW; IFResultM holds the wrong value from A's Execute ALU.  A
  // consumer that can go late takes a4 from Slot0ResultW and does not stall (Slot0SlowE above).  One that
  // cannot -- a load or store address, a jalr, a multiply -- waits here one cycle, then forwards it from
  // Writeback.
  assign Slot0LateStallD = Slot0LateE & (Slot0RdE != 5'b0) &
                       (~(LateBrD | Slot0LateD) & ((Slot0Rs1D == Slot0RdE) | (Slot0Rs2D == Slot0RdE)) |
                        (Slot1IssueD & ~Slot1LateOKD & ((Slot1Rs1D == Slot0RdE) | (Slot1Rs2D == Slot0RdE))));

  // Store-then-load: a structural conflict over the data memory's single SRAM port, not a data
  // dependency, so it ignores registers entirely.  A read is issued in Execute and a write happens in
  // Memory, so a load one stage behind a store would want the port in the very cycle the store writes
  // it.  The controller states this for slot 0 against slot 0, which is one of four combinations now
  // that the load and the store may sit in different slots.  A bundle holds at most one memory
  // operation, so each side is just an OR over the slots, and the controller's own term becomes
  // redundant rather than wrong.
  assign BundleStoreStallD = (Slot0MemRWD[1] | (Slot1IssueD & Slot1MemRWD[1]))   // the bundle in Decode has a load
                           & (MemRWE[0]  | Slot1MemRWE[0]);              // the bundle in Execute has a store

  // Stall the bundle when slot 1 depends on a result that cannot be forwarded yet, exactly as slot 0
  // already does.  Gated by Slot1IssueD so a slot 1 hazard costs nothing on cycles where the two slots
  // were never going to issue together.  The two hazards above need no such gate: they concern the
  // bundle already in Execute, which has issued whatever it issued.  A slot 1 the late ALU can execute
  // takes the slow result from Slot0ResultW instead.
  // Slot0StructuralStallD is slot 0's own stall from the controller (load-use and the like).  A slot 0 that
  // goes late -- a late branch or a late slot 0 -- does not need it, since avoiding it is the point; it
  // keeps only the store-then-load stall, which concerns the memory port, not its operands.
  assign StructuralStall0GD = (LateBrD | Slot0LateD) ? StoreStallD : Slot0StructuralStallD;
  assign StructuralStallD = StructuralStall0GD | (Slot1IssueD & ~Slot1LateOKD & Slot1StructuralStallD) | Slot1LoadStallD | Slot1MDUStallD | Slot1LateStallD | Slot0LateStallD | BundleStoreStallD;

  datapath #(P) dp(
    .clk, .reset, .Slot0ImmSrcD, .Slot0InstrD, .Slot0Rs1D, .Slot0Rs2D, .Slot0Rs2E, .StallE, .FlushE, .Slot0ForwardAE, .Slot0ForwardBE, .W64E, .UW64E, .Slot0SubArithE,
    .Slot1ImmSrcD, .Slot1InstrD, .Slot1Rs1D, .Slot1Rs2D, .Slot1Rs2E, .Slot1ForwardAE, .Slot1ForwardBE,                       // slot 1
    .Slot1ALUSrcAE, .Slot1ALUSrcBE, .Slot1ALUResultSrcE, .Slot1ALUSelectE, .Slot1Funct3E, .Slot1Funct7E,                  // slot 1
    .W64_1E, .UW64_1E, .Slot1SubArithE, .Slot1BSelectE, .Slot1ZBBSelectE, .Slot1BALUControlE, .Slot1BMUActiveE, .Slot1CZeroE, // slot 1
    .Slot1BranchSignedE, .Slot1FlagsE, .Slot1IEUAdrE, .Slot1JumpE, .Slot1PCLinkE, .Slot1FuseBrAE, .Slot1FuseBrBE, .Slot1FuseBrAddE, // slot 1 branch / jal
    .Slot1RegWriteW, .Slot1RdW,                                                                             // slot 1 write port
    .Slot1MemE, .Slot1ResultSrcW,                                                                           // slot 1 memory steering
    .Slot1MduE, .MDUSrcAE, .MDUSrcBE,                                                                   // slot 1 multiply steering
    .Slot1LateSelAE, .Slot1LateSelBE, .LateBrE, .Slot0LateRawE, .LateFlagsM,                                                // late ALU
    .Funct3E, .Funct7E, .Slot0ALUSrcAE, .Slot0ALUSrcBE, .Slot0ALUResultSrcE, .Slot0ALUSelectE, .Slot0JumpE, .Slot0BranchSignedE,
    .PCE, .Slot0PCLinkE, .Slot0FlagsE, .Slot0IEUAdrE, .LSUAdrE, .Slot0ForwardedSrcAE, .Slot0ForwardedSrcBE, .Slot0BSelectE, .Slot0ZBBSelectE, .Slot0BALUControlE, .Slot0BMUActiveE, .Slot0CZeroE,
    .StallM, .FlushM, .FWriteIntM, .FIntResM, .Slot0SrcAM, .WriteDataM, .FCvtIntW,
    .StallW, .FlushW, .Slot0RegWriteW, .IntDivW, .SquashSCW, .ResultSrcW, .ReadDataW, .FCvtIntResW,
    .CSRReadValW, .MDUResultW, .FIntDivResultW, .Slot0RdW);
endmodule
