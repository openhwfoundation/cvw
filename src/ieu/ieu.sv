///////////////////////////////////////////
// ieu.sv
//
// Written: David_Harris@hmc.edu 9 January 2021
// Modified:
//
// Purpose: Integer Execution Unit: datapath and controller
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

module ieu import cvw::*;  #(parameter cvw_t P) (
  input  logic              clk, reset,
  // Decode stage signals
  input  logic [31:0]       InstrD,                           // Instruction
  input  logic [31:0]       Instr2D,                          // Second instruction (superscalar slot 1), decoded but not issued
  input  logic              Issue2D,                          // Slot 1 is paired with slot 0 this cycle
  input  logic              Issue2M, Issue2W,                 // ... and still committing in Memory / Writeback
  input  logic              LateA2D, LateB2D,                 // Slot 1's rs1 / rs2 field matches slot 0's rd
  input  logic              LateOK2D,                         // Slot 1 is an operation the late ALU implements
  input  logic              Fuse2D,                           // The pair is fused into one indexed load (issue.sv)
  input  logic              FuseBr2D,                         // The pair is fused into one ALU op + branch (issue.sv)
  input  logic              FuseBrAdd2D,                      // ... and slot 0 is an add (else a logic op)
  output logic              FuseM,                            // ... which is now in Memory
  input  logic              Replay2M,                         // ... and faulted: slot 0 commits as the add alone
  input  logic              PredTakenE,                       // Fetch went to slot 0's branch target (predicted taken)
  output logic              LateBrM,                          // Slot 0 is a branch whose direction is checked in Memory
  output logic              LateBrTakenM,                     // ... its real direction
  output logic              LateBrWrongM,                     // ... and fetch went the other way: redirect from Memory
  output logic              Mem2M,                            // The bundle's memory operation is slot 1's
  output logic              Illegal2M,                        // Slot 1 is an illegal instruction; replay it alone
  input  logic [1:0]        STATUS_FS,                        // is FPU enabled?
  input  logic [3:0]        ENVCFG_CBE,                       // Cache block operation enables
  input  logic              IllegalIEUFPUInstrD,              // Illegal instruction
  output logic              IllegalBaseInstrD,                // Illegal base integer instruction, or illegal RV32E access to upper 16 registers
  // Execute stage signals
  input  logic [P.XLEN-1:0] PCE,                              // PC
  input  logic [P.XLEN-1:0] PCLinkE,                          // PC + 4
  output logic              PCSrcE,                           // Select next PC (between PC+4 and IEUAdrE)
  input  logic              FWriteIntE, FCvtIntE,             // FPU writes to integer register file, FPU converts float to int
  output logic [P.XLEN-1:0] IEUAdrE,                          // Branch / jump target, from slot 0
  output logic [P.XLEN-1:0] LSUAdrE,                          // Memory address, from whichever slot holds one
  output logic              IntDivE, W64E,                    // Integer divide, RV64 W-type instruction
  output logic [2:0]        Funct3E,                          // Funct3 instruction field
  output logic [P.XLEN-1:0] ForwardedSrcAE, ForwardedSrcBE,   // ALU src inputs before the mux choosing between them and PCE to put in srcA/B
  output logic [4:0]        RdE,                              // Destination register
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
  output logic [P.XLEN-1:0] SrcAM,                            // ALU SrcA to Privileged unit and FPU
  output logic [4:0]        RdM,                              // Destination register
  input  logic [P.XLEN-1:0] FIntResM,                         // Integer result from FPU (fmv, fclass, fcmp)
  output logic              InvalidateICacheM, FlushDCacheM,  // Invalidate I$, flush D$
  output logic              InstrValidD, InstrValidE, InstrValidM, // Instruction is valid
  output logic              BranchD, BranchE,
  output logic              JumpD, JumpE,
  output logic              Branch2D, Branch2E,               // Slot 1 is a conditional branch (Branch2D before the issue decision)
  output logic              Jump2D, Jump2E,                   // ... or a jal
  output logic              PCSrc2E,                          // ... that resolved taken (always, for a jal)
  output logic [P.XLEN-1:0] IEUAdr2E,                         // ... to this target
  input  logic [P.XLEN-1:0] PCLink2E,                         // Slot 1's link address, written by a slot 1 jal
  // Writeback stage signals
  input  logic [P.XLEN-1:0] FIntDivResultW,                   // Integer divide result from FPU (fdivsqrt)
  input  logic [P.XLEN-1:0] CSRReadValW,                      // CSR read value,
  input  logic [P.XLEN-1:0] MDUResultW,                       // multiply/divide unit result
  input  logic [P.XLEN-1:0] FCvtIntResW,                      // FPU's float to int conversion result
  input  logic              FCvtIntW,                         // FPU converts float to int
  output logic [4:0]        RdW,                              // Destination register
  input  logic [P.XLEN-1:0] ReadDataW,                        // LSU's read data
  // Hazard unit signals
  input  logic              StallD, StallE, StallM, StallW,   // Stall signals from hazard unit
  input  logic              FlushD, FlushE, FlushM, FlushW,   // Flush signals
  output logic              StructuralStallD,                 // IEU detects structural hazard in Decode stage
  output logic              LoadStallD,                       // Structural stalls for load, sent to performance counters
  output logic              StoreStallD,                      // load after store hazard
  output logic              CSRReadM, CSRWriteM, PrivilegedM, // CSR read, CSR write, is privileged instruction
  output logic              CSRWriteFenceM                    // CSR write or fence instruction needs to flush subsequent instructions
);

  logic [2:0] ImmSrcD;                                        // Select type of immediate extension
  logic [1:0] FlagsE;                                         // Comparison flags ({eq, lt})
  logic       ALUSrcAE, ALUSrcBE;                             // ALU source operands
  logic [2:0] ResultSrcW;                                     // Selects result in Writeback stage
  logic       ALUResultSrcE;                                  // Selects ALU result to pass on to Memory stage
  logic [2:0] ALUSelectE;                                     // ALU select mux signal
  logic       FWriteIntM;                                     // FPU writing to integer register file
  logic       IntDivW;                                        // Integer divide instruction
  logic [3:0] BSelectE;                                       // BMU result select (binary encoded; see bitmanipalu)
  logic [3:0] ZBBSelectE;                                     // ZBB Result Select Signal in Execute Stage
  logic [2:0] BALUControlE;                                   // ALU Control signals for B instructions in Execute Stage
  logic       SubArithE;                                      // Subtraction or arithmetic shift
  logic       UW64E;                                          // .uw-type instruction

  logic [6:0] Funct7E;

  // Forwarding signals
  logic [4:0] Rs1D, Rs2D;
  logic [4:0] Rs2E;                                           // Source registers

  // Slot 1 (superscalar) Decode-stage outputs: the same signals the controller produces in D for slot 0.
  // Slot 1 is decoded alongside slot 0 but does not issue yet, so these are observed by the testbench only.
  logic [4:0] Rs1_2D, Rs2_2D;                                 // Slot 1 source registers
  logic [2:0] ImmSrc2D;                                       // Slot 1 immediate format
  logic       IllegalBaseInstr2D;                             // Slot 1 is an illegal base instruction
  logic       IllegalBaseInstr2MRaw;                          // ... carried to Memory, before the commit gate
  logic       InstrValid2D;                                   // Slot 1 controller valid bit (not yet qualified by the IFU's Instr2ValidD)
  logic       StructuralStall0D;                              // Slot 0's own structural hazards
  logic [1:0] MemRW0D, MemRW0M;                               // Slot 0 memory read/write in Decode / Memory
  logic       StructuralStall2D;                              // Slot 1 depends on a result not ready to forward
  logic       LoadStall2D;                                    // A slot 1 load's data is not ready to forward yet
  logic       MDUStall2D;                                     // A slot 1 multiply's product is not ready to forward yet
  logic       BundleStoreStallD;                              // The bundle's load would collide with a store on the memory's one port
  logic       RegWriteM;                                      // Slot 0 writes a register in Memory
  logic       RegWrite2MRaw, RegWrite2WRaw;                   // What slot 1's controller decoded
  logic       RegWrite2M, RegWrite2W;                         // ... once it is known slot 1 still commits
  logic [4:0] Rd2M, Rd2W;                                     // Slot 1 destination register in Memory / Writeback

  // Slot 1 Execute-stage signals.  Slot 1 computes a result but does not commit it yet.
  logic [4:0] Rs1_2E, Rs2_2E;                                 // Slot 1 source registers in Execute
  logic [4:0] Rd2E;                                           // Slot 1 destination register in Execute
  logic [2:0] Forward2AE, Forward2BE;                         // Lane 2 forwarding selects (from controller c2)
  logic       ALUSrcA2E, ALUSrcB2E, ALUResultSrc2E;           // Slot 1 ALU operand and result selects
  logic [2:0] ALUSelect2E;                                    // Slot 1 ALU operation
  logic [2:0] Funct3_2E;                                      // Slot 1 funct3
  logic [6:0] Funct7_2E;                                      // Slot 1 funct7
  logic       W64_2E, UW64_2E, SubArith2E;                    // Slot 1 W-type, .uw-type, subtract/arithmetic-shift
  logic [3:0] BSelect2E, ZBBSelect2E;                         // Slot 1 bit-manipulation selects
  logic [2:0] BALUControl2E;                                  // Slot 1 bit-manipulation ALU control
  logic       BMUActive2E;                                    // Slot 1 bit-manipulation instruction active
  logic [1:0] CZero2E;                                        // Slot 1 czero.* active
  logic [1:0] Flags2E;                                        // Slot 1 comparison flags ({eq, lt})
  logic       BranchSigned2E;                                 // Slot 1 branch compares signed

  // Slot 1 late ALU.  A slot 1 that reads slot 0's result executes one stage later, in Memory, where
  // slot 0's result is already registered in IEUResultM.  See issue.sv for which pairs qualify.
  logic       LateA2RawE, LateB2RawE;                         // issue.sv's field matches, in Execute
  logic [1:0] LateWA2D, LateWB2D;                             // Slot 1 operand produced too late by the bundle ahead
  logic [1:0] LateWA2RawE, LateWB2RawE;                       // ... in Execute
  logic [1:0] LateSelA2E, LateSelB2E;                         // Where the late ALU takes each operand from
  logic       Late2E;                                         // Slot 1 executes on the late ALU
  logic       SlowResult0E, Slow2E;                           // Slot 0 / slot 1 in Execute has a result not ready in Memory
  logic       CaptureE;                                       // Execute held while Memory advances

  // Late branch: a slot 0 conditional branch whose operand the bundle ahead produces too late to compare
  // in Execute.  Its direction is checked by the late ALU in Memory instead of stalling it in Decode.
  logic [1:0] LateWA0D, LateWB0D;                             // Slot 0 operand produced too late (as LateWA2D, for slot 0)
  logic       LateBrD, LateBrE;                               // Slot 0 is a late branch
  logic       AssumedTakenM;                                  // The direction it was given in Execute
  logic [2:0] LateFlagsM;                                     // {eq, lt, ltu} from the late ALU
  logic       StructuralStall0GD;                             // Slot 0's own stalls, less those a late branch avoids
  logic       LateStall2D;                                    // A late slot 1's result is not ready to forward yet

  // Late slot 0: a slot 0 ALU operation whose operand the bundle ahead produces too late, run on the
  // late ALU in Memory instead of stalling it in Decode, as a late branch is.
  logic       LateOK0D;                                       // Slot 0 is an operation the late ALU implements
  logic       Late0D, Late0RawE;                              // Slot 0 is to run late / was sent late
  logic       Late0E;                                         // ... and some operand really is substituted
  logic       Slow0E;                                         // Slot 0 in Execute has a result not ready in Memory
  logic       LateStall0D;                                    // A late slot 0's result is not ready to forward yet

  // Slot 1 Memory/Writeback-stage signals.  The core has one load/store unit, so at most one slot of
  // a bundle may hold a memory operation; Mem2E/Mem2M say it is slot 1's and steer the LSU's inputs
  // to lane 2.  c2 pipelines its own control to M and W with the real StallM/FlushM, exactly as c does.
  logic [1:0] MemRW2D, MemRW2E, MemRW2M, MemRW2MRaw;          // Slot 1 memory read/write, before and after the commit gate
  logic       Mem2E;                                          // The bundle's memory operation is in slot 1, in Execute
  logic [2:0] Funct3_2M;                                      // Slot 1 access size and signedness
  logic [2:0] ResultSrc2W;                                    // Slot 1 writeback source select

  // Slot 1 multiply/divide.  The core has one multiply/divide unit, so at most one slot of a bundle may
  // hold an MDU operation; Mdu2E/Mdu2M say it is slot 1's and steer the MDU's inputs to lane 2.
  logic       MDUActive0E, MDUActive2E;                       // Slot 0 / slot 1 holds a multiply or divide
  logic       IntDiv2E;                                       // Slot 1 holds a divide
  logic       Mdu2E, Mdu2M;                                   // The bundle's MDU operation is slot 1's

  // Indexed-load fusion: slot 0 executes the add and the load after it as one load (issue.sv).
  logic       FuseD, FuseE;                                   // The bundle is a fused indexed load
  logic [2:0] FuseFunct3E, FuseFunct3M;                       // ... with the load's width and signedness
  logic [2:0] Mem0Funct3M;                                    // Slot 0's memory funct3: its own, or the fused load's
  logic       UnfuseW;                                        // The fused load faulted: slot 0 writes the add's sum
  logic [2:0] ResultSrc0W;                                    // Slot 0's writeback select from the controller
  logic       FuseBrA2E, FuseBrB2E;                           // Fused ALU + branch: slot 1's rs1 / rs2 is slot 0's result
  logic       FuseBrAdd2E;                                    // Fused ALU + branch whose slot 0 is an add (else a logic op)

  logic [2:0] ForwardAE, ForwardBE;                           // Select signals for forwarding multiplexers
  logic       RegWriteW;                                      // Register will be written in Writeback stage
  logic       BranchSignedE;                                  // Branch does signed comparison on operands
  logic       BMUActiveE;                                     // Bit manipulation instruction being executed
  logic [1:0] CZeroE;                                         // {czero.nez, czero.eqz} instructions active

  controller #(P) c(
    .clk, .reset, .StallD, .FlushD, .InstrD, .STATUS_FS, .ENVCFG_CBE, .ImmSrcD,
    .IllegalIEUFPUInstrD, .IllegalBaseInstrD,
    .StructuralStallD(StructuralStall0D), .LoadStallD, .StoreStallD, .Rs1D, .Rs2D, .Rs2E, .MemRWD(MemRW0D),
    .Rs1_2D, .Rs2_2D, .StructuralStall2D,                     // lane 2's hazard, computed here against the real RdE
    .FuseLoadD(FuseD),                                        // slot 0's add also does slot 1's load
    .SlowResultE(SlowResult0E), .LateBrE, .PredTakenE,
    .StallE, .FlushE, .FlagsE, .FWriteIntE,
    .PCSrcE, .ALUSrcAE, .ALUSrcBE, .ALUResultSrcE, .ALUSelectE,
    .Funct3E, .Funct7E, .IntDivE, .W64E, .UW64E, .SubArithE, .BranchD, .BranchE, .JumpD, .JumpE,
    .BranchSignedE, .BSelectE, .ZBBSelectE, .BALUControlE, .BMUActiveE, .CZeroE, .MDUActiveE(MDUActive0E),
    .FCvtIntE, .ForwardAE, .ForwardBE, .CMOpM, .IFUPrefetchE, .LSUPrefetchM,
    // MemRWM and Funct3M are the only two LSU inputs that can differ by lane, so they are taken to
    // local names here and muxed against slot 1's below.  The rest reach the LSU and the privileged
    // unit straight from slot 0, and which lane they came from never has to be asked: issue.sv's
    // whitelist admits only LUI/AUIPC/OP-IMM/OP (and the RV64 W forms) to slot 1, so a bundle whose
    // slot 1 is an atomic, a CSR access, a privileged instruction, cbo.* or fence.i cannot pair at
    // all, leaving slot 1's copy of those signals structurally zero.  MemRWE is simply a dead port.
    .StallM, .FlushM, .MemRWE, .MemRWM(MemRW0M), .CSRReadM, .CSRWriteM, .PrivilegedM, .AtomicM, .Funct3M,
    // Slot 0's illegal instruction already reaches the privileged unit through IllegalBaseInstrD, which
    // privpiperegs.sv pipelines, so the Memory-stage copy is only needed for slot 1's replay.
    .FlushDCacheM, .InstrValidM, .InstrValidE, .InstrValidD, .FWriteIntM, .IllegalBaseInstrM(),
    .RegWriteM, .RegWriteOtherM(RegWrite2M),                  // lane 1 forwards from lane 2
    .StallW, .FlushW, .RegWriteW, .IntDivW, .ResultSrcW(ResultSrc0W), .CSRWriteFenceM, .InvalidateICacheM,
    .RegWriteOtherW(RegWrite2W),
    .RdW, .RdE, .RdM, .RdOtherM(Rd2M), .RdOtherW(Rd2W));

  // Slot 1 controller (superscalar).  A second copy of the controller decodes Instr2D in the Decode stage.
  // Only its Decode-stage outputs are used; slot 1 does not issue, so its Execute/Memory/Writeback
  // outputs are left unconnected and its Execute-stage feedback inputs are tied off.
  controller #(P, 0) c2(
    .clk, .reset, .StallD, .FlushD, .InstrD(Instr2D), .STATUS_FS, .ENVCFG_CBE, .ImmSrcD(ImmSrc2D),
    .IllegalIEUFPUInstrD(1'b0), .IllegalBaseInstrD(IllegalBaseInstr2D),
    // The load-use hazard cannot be computed here: it depends on the Execute-stage control of the
    // real pipeline (MemReadE, CSRReadE, MDUE), which only c has.  c computes it for both lanes.
    .StructuralStallD(), .LoadStallD(), .StoreStallD(),
    .Rs1_2D(5'b0), .Rs2_2D(5'b0), .StructuralStall2D(), .SlowResultE(), .LateBrE(1'b0), .PredTakenE(1'b0), .FuseLoadD(1'b0),
    .Rs1D(Rs1_2D), .Rs2D(Rs2_2D), .Rs2E(Rs2_2E), .MemRWD(MemRW2D),
    // An unpaired slot 1 is flushed on its way into Execute rather than being allowed down the
    // pipeline and suppressed at each consumer.  Its control signals, RegWrite2M/W and Rd2M/W then
    // come out as zero on their own, so nothing downstream needs to know about pairing.
    // Branch2E, Jump2E and PCSrc2E therefore describe a slot 1 that issued.  Slot 0 is never a branch
    // or a jump beside a slot 1 branch or jal, so a slot 1 control transfer is never killed by slot 0.
    // A fused slot 1 is flushed the same way: slot 0 does its load, so slot 1 is a bubble from Execute on.
    // It still retires -- Issue2E/M/W stay set, so minstret and the tracer count it.
    .StallE, .FlushE(FlushE | ~Issue2D | FuseD), .FlagsE(Flags2E), .FWriteIntE(1'b0),
    .PCSrcE(PCSrc2E), .ALUSrcAE(ALUSrcA2E), .ALUSrcBE(ALUSrcB2E), .ALUResultSrcE(ALUResultSrc2E), .ALUSelectE(ALUSelect2E),
    .Funct3E(Funct3_2E), .Funct7E(Funct7_2E), .IntDivE(IntDiv2E), .W64E(W64_2E), .UW64E(UW64_2E), .SubArithE(SubArith2E),
    .BranchD(Branch2D), .BranchE(Branch2E), .JumpD(Jump2D), .JumpE(Jump2E),
    .BranchSignedE(BranchSigned2E), .BSelectE(BSelect2E), .ZBBSelectE(ZBBSelect2E), .BALUControlE(BALUControl2E),
    .BMUActiveE(BMUActive2E), .CZeroE(CZero2E), .MDUActiveE(MDUActive2E),
    .FCvtIntE(1'b0), .ForwardAE(Forward2AE), .ForwardBE(Forward2BE), .CMOpM(), .IFUPrefetchE(), .LSUPrefetchM(),
    // Only the two signals the LSU reads per-lane are connected.  AtomicM, CSRReadM, CSRWriteM and
    // PrivilegedM stay open because the issue rules keep atomics, CSR accesses and privileged
    // instructions in slot 0.  CMOpM and FlushDCacheM stay open because cbo.* and fence.i are
    // MISC_MEM, which slot 1's whitelist never admits, so they are constant zero here.  And
    // LSUPrefetchM, like MemRWE, is a dead input on the LSU: declared, never read.
    // A slot 1 killed in Execute by a taken branch in slot 0 is flushed on its way into Memory, for the
    // same reason.  Gating RegWrite2M/W below is not enough on its own: c2's forwarding logic reads its
    // own RegWriteM/W, so a dead slot 1 would still forward its result to the next bundle's slot 1.
    // A correctly predicted taken branch puts its target in Execute the very next cycle, so this
    // happens whenever slot 1 of the target bundle reads the fall-through's destination.
    .StallM, .FlushM(FlushM | PCSrcE), .MemRWE(MemRW2E), .MemRWM(MemRW2MRaw), .CSRReadM(), .CSRWriteM(), .PrivilegedM(), .AtomicM(), .Funct3M(Funct3_2M),
    .FlushDCacheM(), .InstrValidM(), .InstrValidE(), .InstrValidD(InstrValid2D), .FWriteIntM(),
    .IllegalBaseInstrM(IllegalBaseInstr2MRaw),
    .RegWriteM(RegWrite2MRaw), .RegWriteOtherM(RegWriteM),    // lane 2 forwards from lane 1
    .StallW, .FlushW, .RegWriteW(RegWrite2WRaw), .IntDivW(), .ResultSrcW(ResultSrc2W), .CSRWriteFenceM(), .InvalidateICacheM(),
    .RegWriteOtherW(RegWriteW),
    .RdW(Rd2W), .RdE(Rd2E), .RdM(Rd2M), .RdOtherM(RdM), .RdOtherW(RdW));

  // Slot 1 can be abandoned in Execute, after its controller's Execute register has already loaded --
  // when slot 0 turns out to be a taken branch and slot 1 was the fall-through.  c2's FlushM above
  // clears that case, and Issue2W adds the Memory-stage replay, so qualify the register-write signals
  // with Issue2M/Issue2W here: these feed both the second write port and lane 1's forwarding network,
  // so an abandoned slot 1 neither writes nor is bypassed.
  assign RegWrite2M = RegWrite2MRaw & Issue2M;
  assign RegWrite2W = RegWrite2WRaw & Issue2W;

  // A slot 1 store reaches memory in the Memory stage, so it needs the same commit gate: without it
  // an abandoned slot 1 would still write memory, which no later redirect can undo.  Gating here
  // rather than in Execute is also the cheaper placement -- both inputs are register outputs, where
  // Kill2E (and so PCSrcE, out of the branch comparator) arrives late in Execute.
  assign MemRW2M = MemRW2MRaw & {2{Issue2M}};

  // Slot 1 holds an encoding that is not a legal instruction in this configuration.  Fetch cannot tell
  // that apart from a legal one -- sh1add and an illegal encoding are the same bits, separated only by
  // P.ZBA_SUPPORTED -- so the issue rules let slot 1 take any encoding its ALU could execute and leave
  // the verdict to c2's own decoder, which already reaches it.  Slot 1 never executes it: the commit
  // gate stops the register write, and the replay discards it and refetches it as slot 0, the only
  // lane the privileged unit can describe.
  assign Illegal2M = IllegalBaseInstr2MRaw & Issue2M;

  // Which lane owns the single load/store unit.  The issue rules permit at most one memory operation
  // per bundle, so "slot 1 has one" is the same statement as "slot 0 does not", and one select does
  // for both.  Mem2E steers the Execute-stage inputs -- the address and the store data, in
  // datapath.sv -- and Mem2M the control the LSU reads in Memory.  Neither needs a register of its
  // own, because c2 already pipelines its control from Execute to Memory alongside c.
  // ~PCSrcE is the same condition as ifu.sv's Kill2E: a taken branch in slot 0 leaves slot 1 as the
  // fall-through, which must not act.  MemRW2M already stops the access, so this is not needed for
  // correctness -- it keeps the LSU from latching a dead slot 1's address into IEUAdrM, which the
  // branch predictor reads when it updates a target.  It is free because, with the address reaching
  // the LSU on its own net, nothing downstream of this select in Execute is more than a register.
  assign Mem2E = |MemRW2E & ~PCSrcE;
  assign Mem2M = |MemRW2M;

  // MemRWM reaches nothing but the load/store unit, so it is muxed in place.  Funct3M is not that
  // private: the MDU selects its result from it (mul vs mulh vs div vs rem) and the FPU's integer
  // divide reads it too.  Muxing it would hand an MDU operation in slot 0 the funct3 of a load in
  // slot 1 and silently return the wrong product, so the memory funct3 goes out on its own net
  // instead, exactly as LSUAdrE does for the address.
  mux2 #(2) memrwmmux(MemRW0M, MemRW2M, Mem2M, MemRWM);
  mux2 #(3) mem0funct3mmux(Funct3M, FuseFunct3M, FuseM, Mem0Funct3M);
  mux2 #(3) memfunct3mmux(Mem0Funct3M, Funct3_2M, Mem2M, MemFunct3M);

  // Indexed-load fusion (issue.sv).  Slot 0's controller turns the add into the load (FuseLoadD), and
  // slot 1's controller is flushed into Execute above.  What is left for here:
  //   - the load's width and signedness.  Slot 0's Funct3 belongs to the add and also drives its ALU
  //     (sh2add is funct3 100), so the load's funct3 rides beside it to Memory, for the LSU only.
  //       sh2add a5,a5,s1 ; lw a5,0(a5)    ALU uses 100 (shift by 2), LSU uses 010 (word, signed)
  //   - a fault.  The trap would name the add's PC, so as in the paper the pair is replayed unfused: the
  //     existing slot 1 replay (Replay2M) suppresses the trap, slot 0 commits as the add alone and writes
  //     its sum (still in IFResultW, since the ALU result is carried to Writeback for every instruction),
  //     and fetch restarts at the load, which runs alone and traps with its own PC.
  assign FuseD = Issue2D & Fuse2D;
  flopenrc #(4) FuseEReg(clk, reset, FlushE, ~StallE, {FuseD, Instr2D[14:12]}, {FuseE, FuseFunct3E});
  flopenrc #(4) FuseMReg(clk, reset, FlushM, ~StallM, {FuseE, FuseFunct3E}, {FuseM, FuseFunct3M});
  flopenrc #(1) UnfuseWReg(clk, reset, FlushW, ~StallW, FuseM & Replay2M, UnfuseW);
  mux2 #(3) resultsrcwmux(ResultSrc0W, 3'b000, UnfuseW, ResultSrcW);   // 000: the ALU result, the add's sum

  // Which lane owns the single multiply/divide unit, by the same reasoning as the load/store unit
  // above: the issue rules permit at most one MDU operation per bundle.  Unlike Mem2E this select
  // needs no ~PCSrcE.  The multiplier has no enable and no side effect -- it multiplies whatever it is
  // given every cycle, and only the selected, committed result is ever written -- so a slot 1 multiply
  // killed by a taken branch in slot 0 computes a product that RegWrite2M/W, gated by Issue2M/W, never
  // write.  The divider does act when it starts, but issue.sv never pairs a slot 1 divide with a slot
  // 0 branch, so a slot 1 divide that reaches Execute always commits.  MDUActive2E comes straight out
  // of c2's Execute register, so the select adds no logic ahead of the operand muxes in datapath.sv.
  //
  // The MDU's funct3, W64 and divide start go out on their own nets, as MemFunct3M does: slot 0's
  // Funct3E/M, W64E and IntDivE also feed the FPU's integer divide and conversions, which must keep
  // seeing slot 0.
  // Which of slot 1's operands the late ALU replaces with slot 0's result.  issue.sv matched raw
  // register fields, which for an immediate or a PC operand are not registers at all, so the bits are
  // cleared here for an operand the ALU does not take from the register file, and for lui, whose
  // result is its immediate.  What remains is exactly the set of real dependencies, because issue.sv
  // never pairs a dependent slot 1 it could not mark.  The register flushes like c2's Execute stage,
  // so an unpaired slot 1 is never late.
  // The Decode-stage compare against the decompressed fields is belt and braces: instrfields may name a
  // register that a compressed HINT's decompressed form replaces with x0, and the late ALU must never
  // substitute slot 0's result for an operand that reads some other register.
  logic LateA2DQ, LateB2DQ;
  assign LateA2DQ = LateA2D & (Rs1_2D == InstrD[11:7]);
  assign LateB2DQ = LateB2D & (Rs2_2D == InstrD[11:7]);
  // A fused slot 1's rs1 is slot 0's rd too, but it is a bubble, so it is never late.
  flopenrc #(2) Late2EReg(clk, reset, FlushE | ~Issue2D | FuseD, ~StallE, {LateA2DQ, LateB2DQ}, {LateA2RawE, LateB2RawE});

  // Fused ALU + branch (issue.sv): which of the branch's operands is slot 0's result, so slot 1's comparator
  // takes it from slot 0's ALU (datapath.sv).  It never also goes late: a branch's ALU operands are the PC
  // and the offset, so LateSelA2E/LateSelB2E below are 00.  And slot 0 is then never late itself (Late0D
  // and LateBrD refuse when LateA2DQ/LateB2DQ is set), so its result is ready in Execute.
  //   addi t0, t0, -1 ; bnez t0, L      FuseBrA2E = 1: compare slot 0's t0 with x0
  flopenrc #(3) FuseBrEReg(clk, reset, FlushE | ~Issue2D, ~StallE,
                           {FuseBr2D & LateA2DQ, FuseBr2D & LateB2DQ, FuseBr2D & FuseBrAdd2D & (LateA2DQ | LateB2DQ)},
                           {FuseBrA2E, FuseBrB2E, FuseBrAdd2E});

  // The late ALU also takes an operand that the bundle now in Execute produces too late to forward --
  // a load, a multiply or divide, a CSR read or an FPU-to-integer move in slot 0, or a load, multiply
  // or late operation in slot 1.  Instead of stalling the bundle in Decode, slot 1 goes late: when it
  // reaches Memory its producer is in Writeback, and the value is in ResultW or ResultW2.  Slot 1 of
  // the producing bundle is younger, so it is checked first; when it writes the register but is fast,
  // ordinary forwarding from Memory is correct and nothing is needed.  Only for a slot 1 the late ALU
  // can execute (LateOK2D); otherwise the stalls below still apply.
  //
  // This depends on the producer being exactly one stage ahead when slot 1 reaches Memory, which the
  // pipeline guarantees except when Execute is held while Memory advances (CaptureE): then the producer
  // retires first, but datapath.sv's operand capture has meanwhile picked its value up in Execute, so
  // these bits are cleared and slot 1 takes its operands as captured.
  //
  // A late slot 0 (below) is a slow producer too: its result first appears in ResultW.
  assign Slow0E   = SlowResult0E | Late0E;
  assign Slow2E   = MemRW2E[1] | MDUActive2E | Late2E;
  assign LateWA2D = ((Rd2E != 5'b0) & (Rs1_2D == Rd2E)) ? {2{Slow2E}} :
                    ((RdE  != 5'b0) & (Rs1_2D == RdE) & Slow0E) ? 2'b10 : 2'b00;
  assign LateWB2D = ((Rd2E != 5'b0) & (Rs2_2D == Rd2E)) ? {2{Slow2E}} :
                    ((RdE  != 5'b0) & (Rs2_2D == RdE) & Slow0E) ? 2'b10 : 2'b00;
  assign CaptureE = StallE & ~StallM;

  // Late branch.  Slot 0 is a conditional branch with an operand produced too late, exactly as LateWA2D
  // describes for slot 1, so rather than stall it in Decode it passes through Execute and the late ALU
  // compares its operands in Memory, taking the late one from ResultW or ResultW2.  Until then it goes
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
  assign LateWA0D = ((Rd2E != 5'b0) & (Rs1D == Rd2E)) ? {2{Slow2E}} :
                    ((RdE  != 5'b0) & (Rs1D == RdE) & Slow0E) ? 2'b10 : 2'b00;
  assign LateWB0D = ((Rd2E != 5'b0) & (Rs2D == Rd2E)) ? {2{Slow2E}} :
                    ((RdE  != 5'b0) & (Rs2D == RdE) & Slow0E) ? 2'b10 : 2'b00;
  assign LateBrD  = (P.ZICSR_SUPPORTED | P.ZIFENCEI_SUPPORTED) & P.ZCA_SUPPORTED &
                    BranchD & (|LateWA0D | |LateWB0D) &
                    ~(Issue2D & (|MemRW2D | LateA2DQ | LateB2DQ | |LateWA2D | |LateWB2D));
  flopenrc #(1) LateBrEReg(clk, reset, FlushE, ~StallE, LateBrD, LateBrE);

  // Late slot 0.  Example:
  //   bundle A:  lw   a5, 0(a0)
  //   bundle B:  addi a4, a5, 3     <- slot 0 needs a5, which the previous bundle is still loading
  // Normally B stalls one cycle in Decode.  Instead B moves on: its Execute ALU result is wrong and
  // unused, and the late ALU computes a5 + 3 in Memory, when A is in Writeback and a5 is in ResultW.
  // Slot 0 goes late when all of these hold:
  //   LateOK0D                   the late ALU implements it (add, sub, logic, shift, slt)
  //   |LateWA0D | |LateWB0D      an operand is a slow result of the previous bundle (it would stall)
  //   ~(Issue2D & ...)           slot 1 does not need the late ALU; only one instruction may use it
  // Otherwise the usual stall applies.  The late result goes only to the Writeback register
  // (datapath.sv), so a consumer in the next bundle goes late too (Slow0E) or stalls a cycle
  // (LateStall0D).  Unlike a late branch it redirects nothing, so a slot 1 load or store may sit beside it.
  // LateOK0D is checked here in Decode on InstrD, the instruction slot 0 really holds.  Fetch's raw bits
  // are not it for an instruction that spills across a fetch boundary.  InstrD is already decompressed,
  // so lateok.sv's 32-bit table covers compressed instructions too (c.addi is addi, c.beqz is beq).
  lateok #(P) lateok0(.Instr(InstrD), .MemRW(2'b00), .IsBranch(1'b0), .Recognized(1'b1), .LateOK(LateOK0D));
  // A fused slot 0 is never late either -- its Execute sum is the load's address -- and needs no term of
  // its own: the fused load reads slot 0's rd, so LateA2DQ is set and the last line already refuses it.
  assign Late0D = LateOK0D & (|LateWA0D | |LateWB0D) &
                  ~(Issue2D & (LateA2DQ | LateB2DQ | |LateWA2D | |LateWB2D));
  flopenrc #(1) Late0EReg(clk, reset, FlushE, ~StallE, Late0D, Late0RawE);

  // The late ALU's Writeback operand selects: slot 0's for a late branch or late slot 0, else slot 1's.
  flopenrc #(4) LateW2EReg(clk, reset, FlushE | (~Issue2D & ~LateBrD & ~Late0D) | CaptureE, ~StallE | CaptureE,
                           (LateBrD | Late0D) ? {LateWA0D, LateWB0D} : ({LateWA2D, LateWB2D} & {4{LateOK2D}}),
                           {LateWA2RawE, LateWB2RawE});

  // Each operand's source for the late ALU: 00 as captured in Execute, 01 slot 0's result in Memory,
  // 10 ResultW, 11 ResultW2.  Slot 0 of the same bundle is the youngest producer, so it wins.  Nothing
  // applies to an operand that is not a register (the ALU takes the PC or an immediate there) or to lui.
  // A late branch's two operands are always registers.
  //
  // LateSelA2E/LateSelB2E pick each late ALU operand in Memory:
  //   00 keep the value carried from Execute     10 replace with ResultW  (previous bundle's slot 0)
  //   01 replace with this bundle's slot 0       11 replace with ResultW2 (previous bundle's slot 1)
  // At most one instruction per bundle uses the late ALU, and it decides which line applies:
  //   1. late branch (LateBrE):   slot 0's code from Decode, as is
  //   2. late slot 0 (Late0RawE): slot 0's code, but 00 if the operand is not a register
  //   3. otherwise:               slot 1's code (Julia's slot 1 late path, unchanged)
  // LateWA2RawE/LateWB2RawE hold slot 0's code in cases 1 and 2 and slot 1's in case 3 (LateW2EReg).
  // "Not a register": ALUSrcAE means operand A is the PC (auipc), ALUSrcBE means operand B is the
  // immediate (addi), ALUResultSrcE means the result is not the ALU's (lui).  Decode compares raw bit
  // fields, so e.g. addi a4, a1, 15 has 15 where rs2 would be and looks like it reads x15 (a5).
  assign LateSelA2E = LateBrE   ? LateWA2RawE :
                      Late0RawE ? ((ALUSrcAE | ALUResultSrcE) ? 2'b00 : LateWA2RawE) :
                      (ALUSrcA2E | ALUResultSrc2E) ? 2'b00 : LateA2RawE ? 2'b01 : LateWA2RawE;
  assign LateSelB2E = LateBrE   ? LateWB2RawE :
                      Late0RawE ? ((ALUSrcBE | ALUResultSrcE) ? 2'b00 : LateWB2RawE) :
                      (ALUSrcB2E | ALUResultSrc2E) ? 2'b00 : LateB2RawE ? 2'b01 : LateWB2RawE;

  // Late0RawE says Decode sent slot 0 to the late ALU; Late0E says an operand is really replaced.
  // They differ on a false match (the immediate above) or when CaptureE cleared the codes because
  // Execute already captured the value.  Then nothing is late and slot 0's Execute result is used.
  // Slot 1 cannot be late in a bundle whose slot 0 was sent to the late ALU.
  assign Late0E     = Late0RawE & (|LateSelA2E | |LateSelB2E);              // slot 0 is late
  assign Late2E     = ~LateBrE & ~Late0RawE & (|LateSelA2E | |LateSelB2E);  // slot 1 is late

  // In Memory: the branch's real direction from the late ALU's flags, by funct3 as the comparator does.
  flopenrc #(2) LateBrMReg(clk, reset, FlushM, ~StallM, {LateBrE, PCSrcE}, {LateBrM, AssumedTakenM});
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

  assign Mdu2E = MDUActive2E;
  flopenrc #(1) Mdu2MReg(clk, reset, FlushM, ~StallM, Mdu2E, Mdu2M);
  assign MDUActiveE = MDUActive0E | MDUActive2E;
  mux2 #(3) mdufunct3emux(Funct3E, Funct3_2E, Mdu2E, MDUFunct3E);
  mux2 #(3) mdufunct3mmux(Funct3M, Funct3_2M, Mdu2M, MDUFunct3M);
  mux2 #(1) mduw64emux(W64E, W64_2E, Mdu2E, MDUW64E);
  mux2 #(1) mduintdivemux(IntDivE, IntDiv2E, Mdu2E, MDUIntDivE);

  // Memory hazards for the bundle.  The controller states both of these against slot 0's Execute stage,
  // which covers every case where slot 0 holds the memory operation.  Once slot 1 may hold it instead,
  // the same two hazards have to be stated again with slot 1 as the producer.
  //
  // Load-use: a load's data is not ready in Memory, so a dependent instruction one bundle behind has
  // to wait.  Lane 2's Memory-stage forwarding source, IEUResult2M, is slot 1's ALU result, which for
  // a load is its address -- forwarding it would quietly supply the wrong value.  One stall cycle
  // pushes the consumer to forward from Writeback instead, where ResultW2 is the real load data.  All
  // four Decode-stage sources are checked, because either slot may be the consumer.
  //
  // In all three of these, a slot 1 consumer the late ALU can execute does not stall: it goes late and
  // takes the value from ResultW2 (see LateWA2D above).  A slot 0 consumer that goes late does not
  // stall either -- a late branch (LateBrD) or a late slot 0 (Late0D).  Example:
  //   bundle A:  addi t0, t0, 1   | lw a5, 0(a0)
  //   bundle B:  add  a4, a4, a5  | ...            <- slot 0 goes late and takes a5 from ResultW2
  assign LoadStall2D = MemRW2E[1] & (Rd2E != 5'b0) &
                       (~(LateBrD | Late0D) & ((Rs1D == Rd2E) | (Rs2D == Rd2E)) |
                        (Issue2D & ~LateOK2D & ((Rs1_2D == Rd2E) | (Rs2_2D == Rd2E))));

  // Multiply/divide-use, for the same reason: the result is not complete until the end of Memory, so
  // it first appears in ResultW2, and IEUResult2M holds slot 1's meaningless ALU output.  This is the
  // slot 1 counterpart of the controller's MDUStallD, which charges slot 0's MDU operations the same
  // cycle.  A divide's iterations happen while DivBusyE holds the whole pipeline, so from the
  // consumer's point of view a divide is no later than a multiply once it leaves Execute.
  assign MDUStall2D = MDUActive2E & (Rd2E != 5'b0) &
                      (~(LateBrD | Late0D) & ((Rs1D == Rd2E) | (Rs2D == Rd2E)) |
                       (Issue2D & ~LateOK2D & ((Rs1_2D == Rd2E) | (Rs2_2D == Rd2E))));

  // Late-ALU-use, for the same reason again: a late slot 1 computes its result in Memory, so it first
  // appears in ResultW2, and IEUResult2M holds what slot 1's Execute ALU made of a stale operand.
  // Forwarding the late ALU's output to Execute instead would chain it into the next bundle's ALU,
  // which is the critical path the late ALU exists to avoid.
  assign LateStall2D = Late2E & (Rd2E != 5'b0) &
                       (~(LateBrD | Late0D) & ((Rs1D == Rd2E) | (Rs2D == Rd2E)) |
                        (Issue2D & ~LateOK2D & ((Rs1_2D == Rd2E) | (Rs2_2D == Rd2E))));

  // Late-slot-0-use: the same as LateStall2D, with the previous bundle's slot 0 as the late producer.
  //   bundle A:  add a4, a4, a5   | ...   <- slot 0 is late (Late0E): a4 is computed in Memory
  //   bundle B:  lw  a6, 0(a4)    | ...   <- needs a4 in Execute for its address
  // A's correct a4 first appears in ResultW; IFResultM holds the wrong value from A's Execute ALU.  A
  // consumer that can go late takes a4 from ResultW and does not stall (Slow0E above).  One that
  // cannot -- a load or store address, a jalr, a multiply -- waits here one cycle, then forwards it from
  // Writeback.
  assign LateStall0D = Late0E & (RdE != 5'b0) &
                       (~(LateBrD | Late0D) & ((Rs1D == RdE) | (Rs2D == RdE)) |
                        (Issue2D & ~LateOK2D & ((Rs1_2D == RdE) | (Rs2_2D == RdE))));

  // Store-then-load: a structural conflict over the data memory's single SRAM port, not a data
  // dependency, so it ignores registers entirely.  A read is issued in Execute and a write happens in
  // Memory, so a load one stage behind a store would want the port in the very cycle the store writes
  // it.  The controller states this for slot 0 against slot 0, which is one of four combinations now
  // that the load and the store may sit in different slots.  A bundle holds at most one memory
  // operation, so each side is just an OR over the slots, and the controller's own term becomes
  // redundant rather than wrong.
  assign BundleStoreStallD = (MemRW0D[1] | (Issue2D & MemRW2D[1]))   // the bundle in Decode has a load
                           & (MemRWE[0]  | MemRW2E[0]);              // the bundle in Execute has a store

  // Stall the bundle when slot 1 depends on a result that cannot be forwarded yet, exactly as slot 0
  // already does.  Gated by Issue2D so a slot 1 hazard costs nothing on cycles where the two slots
  // were never going to issue together.  The two hazards above need no such gate: they concern the
  // bundle already in Execute, which has issued whatever it issued.  A slot 1 the late ALU can execute
  // takes the slow result from ResultW instead.
  // StructuralStall0D is slot 0's own stall from the controller (load-use and the like).  A slot 0 that
  // goes late -- a late branch or a late slot 0 -- does not need it, since avoiding it is the point; it
  // keeps only the store-then-load stall, which concerns the memory port, not its operands.
  assign StructuralStall0GD = (LateBrD | Late0D) ? StoreStallD : StructuralStall0D;
  assign StructuralStallD = StructuralStall0GD | (Issue2D & ~LateOK2D & StructuralStall2D) | LoadStall2D | MDUStall2D | LateStall2D | LateStall0D | BundleStoreStallD;

  datapath #(P) dp(
    .clk, .reset, .ImmSrcD, .InstrD, .Rs1D, .Rs2D, .Rs2E, .StallE, .FlushE, .ForwardAE, .ForwardBE, .W64E, .UW64E, .SubArithE,
    .ImmSrc2D, .Instr2D, .Rs1_2D, .Rs2_2D, .Rs2_2E, .Forward2AE, .Forward2BE,                       // slot 1
    .ALUSrcA2E, .ALUSrcB2E, .ALUResultSrc2E, .ALUSelect2E, .Funct3_2E, .Funct7_2E,                  // slot 1
    .W64_2E, .UW64_2E, .SubArith2E, .BSelect2E, .ZBBSelect2E, .BALUControl2E, .BMUActive2E, .CZero2E, // slot 1
    .BranchSigned2E, .Flags2E, .IEUAdr2E, .Jump2E, .PCLink2E, .FuseBrA2E, .FuseBrB2E, .FuseBrAdd2E, // slot 1 branch / jal
    .RegWrite2W, .Rd2W,                                                                             // slot 1 write port
    .Mem2E, .ResultSrc2W,                                                                           // slot 1 memory steering
    .Mdu2E, .MDUSrcAE, .MDUSrcBE,                                                                   // slot 1 multiply steering
    .LateSelA2E, .LateSelB2E, .LateBrE, .Late0RawE, .LateFlagsM,                                                // late ALU
    .Funct3E, .Funct7E, .ALUSrcAE, .ALUSrcBE, .ALUResultSrcE, .ALUSelectE, .JumpE, .BranchSignedE,
    .PCE, .PCLinkE, .FlagsE, .IEUAdrE, .LSUAdrE, .ForwardedSrcAE, .ForwardedSrcBE, .BSelectE, .ZBBSelectE, .BALUControlE, .BMUActiveE, .CZeroE,
    .StallM, .FlushM, .FWriteIntM, .FIntResM, .SrcAM, .WriteDataM, .FCvtIntW,
    .StallW, .FlushW, .RegWriteW, .IntDivW, .SquashSCW, .ResultSrcW, .ReadDataW, .FCvtIntResW,
    .CSRReadValW, .MDUResultW, .FIntDivResultW, .RdW);
endmodule
