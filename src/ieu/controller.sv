///////////////////////////////////////////
// controller.sv
//
// Written: David_Harris@hmc.edu, Sarah.Harris@unlv.edu, kekim@hmc.edu
// Created: 9 January 2021
// Modified: 3 March 2023
//
// Purpose: Top level controller module
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

module controller import cvw::*;  #(parameter cvw_t P) (
  input  logic        clk, reset,
  // Decode stage control signals
  input  logic        StallD, FlushD,          // Stall, flush Decode stage
  input  logic [31:0] InstrD,                  // Instruction in Decode stage
  input  logic [1:0]  STATUS_FS,               // is FPU enabled?
  input  logic [3:0]  ENVCFG_CBE,              // Cache block operation enables
  output logic [2:0]  ImmSrcD,                 // Type of immediate extension
  input  logic        IllegalIEUFPUInstrD,     // Illegal IEU and FPU instruction
  output logic        IllegalBaseInstrD,       // Illegal I-type instruction, or illegal RV32 access to upper 16 registers
  output logic        JumpD,                   // Jump instruction
  output logic        BranchD,                 // Branch instruction
  output logic        StructuralStallD,        // Structural stalls detected by controller
  output logic        LoadStallD,              // Structural stalls for load, sent to performance counters
  output logic        StoreStallD,             // load after store hazard
  output logic [4:0]  Rs1D, Rs2D, Rs2E,        // Register sources to read in Decode or Execute stage
  // Execute stage control signals
  input  logic        StallE, FlushE,          // Stall, flush Execute stage
  input  logic [1:0]  FlagsE,                  // Comparison flags ({eq, lt})
  input  logic        FWriteIntE,              // Write integer register, coming from FPU controller
  input  logic        FCvtIntE,                              // FPU convert float to int
  output logic        PCSrcE,                  // Select signal to choose next PC (for datapath and Hazard unit)
  output logic        ALUSrcAE, ALUSrcBE,      // ALU operands
  output logic        ALUResultSrcE,           // Selects result to pass on to Memory stage
  output logic [2:0]  ALUSelectE,              // ALU mux select signal
  output logic [2:0]  Funct3E,                 // Instruction's funct3 field
  output logic [6:0]  Funct7E,                 // Instruction's funct7 field
  output logic        IntDivE,                 // Integer divide
  output logic        W64E, UW64E,             // RV64 W/.uw-type operation
  output logic        SubArithE,               // Subtraction or arithmetic shift
  output logic        JumpE,                   // jump instruction
  output logic        BranchE,                 // Branch instruction
  output logic        BranchSignedE,           // Branch comparison operands are signed (if it's a branch)
  output logic [3:0]  BSelectE,                // One-Hot encoding of if it's ZBA_ZBB_ZBC_ZBS instruction
  output logic [3:0]  ZBBSelectE,              // ZBB mux select signal in Execute stage
  output logic [2:0]  BALUControlE,            // ALU Control signals for B instructions in Execute Stage
  output logic        BMUActiveE,              // Bit manipulation instruction being executed
  output logic [1:0]  CZeroE,                  // {czero.nez, czero.eqz} instructions active
  output logic        MDUActiveE,              // Mul/Div instruction being executed
  output logic [3:0]  CMOpM,                   // 1: cbo.inval; 2: cbo.flush; 4: cbo.clean; 8: cbo.zero
  output logic        IFUPrefetchE,            // instruction prefetch
  output logic        LSUPrefetchM,            // data prefetch
  output logic [1:0]  ForwardAE, ForwardBE,    // Select signals for forwarding multiplexers
  // Memory stage control signals
  input  logic        StallM, FlushM,          // Stall, flush Memory stage
  output logic [1:0]  MemRWE,                  // Mem read/write: MemRWM[1] = 1 for read, MemRWM[0] = 1 for write
  output logic [1:0]  MemRWM,                  // Mem read/write: MemRWM[1] = 1 for read, MemRWM[0] = 1 for write
  output logic        CSRReadM, CSRWriteM, PrivilegedM, // CSR read, write, or privileged instruction
  output logic [1:0]  AtomicM,                 // Atomic (AMO) instruction
  output logic [2:0]  Funct3M,                 // Instruction's funct3 field
  output logic        InvalidateICacheM, FlushDCacheM, // Invalidate I$, flush D$
  output logic        InstrValidD, InstrValidE, InstrValidM, // Instruction is valid
  output logic        FWriteIntM,              // FPU controller writes integer register file
  // Writeback stage control signals
  input  logic        StallW, FlushW,          // Stall, flush Writeback stage
  output logic        RegWriteW, IntDivW,      // Instruction writes a register, is an integer divide
  output logic [2:0]  ResultSrcW,              // Select source of result to write back to register file
  // Stall during CSRs
  output logic        CSRWriteFenceM,          // CSR write or fence instruction; needs to flush the following instructions
  output logic [4:0]  RdE, RdM,                // Pipelined destination registers
  // Forwarding controls
  output logic [4:0]  RdW                      // Register destinations in Execute, Memory, or Writeback stage
);

  logic [4:0] Rs1E;                      // pipelined register sources
  logic [6:0] OpD;                             // Opcode in Decode stage
  logic [2:0] Funct3D;                         // Funct3 field in Decode stage
  logic [6:0] Funct7D;                         // Funct7 field in Decode stage
  logic [4:0] RdD;                             // Rs1/2 source register / dest reg in Decode stage

  `define CTRLW 24

  // pipelined control signals
  logic        RegWriteD, RegWriteE;           // RegWrite (register will be written)
  logic [2:0]  ResultSrcD, ResultSrcE, ResultSrcM; // Select which result to write back to register file
  logic [2:0]  PreImmSrcD;                     // Immediate source format (before amending for prefetches)
  logic [1:0]  MemRWD;                         // Store (write to memory)
  logic        ALUOpD;                         // 0 for address generation, 1 for all other operations (must use Funct3)
  logic        BaseW64D;                       // W64 for Base instructions specifically
  logic        BaseRegWriteD;                  // Indicates if Base instruction register write instruction
  logic        BaseSubArithD;                  // Indicates if Base instruction subtracts, sra, slt, sltu
  logic        BaseALUSrcBD;                   // Base instruction ALU B source select signal
  logic        ALUSrcAD, ALUSrcBD;             // ALU inputs
  logic        ALUResultSrcD, W64D, MDUD;      // ALU result, is RV64 W-type, is multiply/divide instruction
  logic        CSRZeroSrcD;                    // Ignore setting and clearing zeros to CSR
  logic        CSRReadD;                       // CSR read instruction
  logic [1:0]  AtomicD;                        // Atomic (AMO) instruction
  logic        FenceXD;                        // Fence instruction
  logic        CMOD;                           // Cache management instruction
  logic        InvalidateICacheD, FlushDCacheD;// Invalidate I$, flush D$
  logic        MemReadE, CSRReadE;             // Instruction reads memory, reads a CSR (needed for Hazard unit)
  logic        MDUE;                           // MDU (multiply/divide) operation
  logic        SCE;                            // Store Conditional instruction
  logic        CSRWriteD, CSRWriteE;           // CSR write
  logic        PrivilegedD, PrivilegedE;       // Privileged instruction
  logic        InvalidateICacheE, FlushDCacheE;// Invalidate I$, flush D$
  logic [`CTRLW-1:0] ControlsD;                // Main Instruction Decoder control signals
  logic        SubArithD;                      // TRUE for R-type subtracts and sra, slt, sltu or B-type ext clr, andn, orn, xnor
  logic        subD, sraD, sltD, sltuD;        // Indicates if is one of these instructions
  logic        BranchTakenE;                   // Branch is taken
  logic        eqE, ltE;                       // Comparator outputs
  logic        unused;
  logic        BranchFlagE;                    // Branch flag to use (chosen between eq or lt)
  logic        IEURegWriteE;                   // Register write
  logic        IllegalERegAdrD;                // RV32E attempts to write upper 16 registers
  logic [1:0]  AtomicE;                        // Atomic instruction
  logic        FenceD, FenceE;                 // Fence instruction
  logic        SFenceVmaD;                     // sfence.vma instruction
  logic        IntDivM;                        // Integer divide instruction
  logic        RegWriteM;                      // Instruction writes a register (needed for Hazard unit)
  logic [1:0]  CZeroD;
  logic        IFunctD, RFunctD, MFunctD;      // Detect I, R, and M-type RV32IM/Rv64IM instructions
  logic        LFunctD, SFunctD, BFunctD;      // Detect load, store, branch instructions
  logic        FLSFunctD;                      // Detect floating-point loads and stores
  logic        JRFunctD;                       // detect jalr instruction
  logic        FenceFunctD;                    // Detect fence instruction
  logic        CMOFunctD;                      // Detect CMO instruction
  logic        AFunctD, AMOFunctD;             // Detect atomic instructions
  logic        RWFunctD, MWFunctD;             // detect RW/MW instructions
  logic        PFunctD, CSRFunctD;             // detect privileged / CSR instruction
  logic        FenceM;                         // Fence.I or sfence.VMA instruction in memory stage
  logic [2:0]  PreALUSelectD;                  // ALU Output selection mux control (before possible Zicond logic)
  logic [2:0]  ALUSelectD;                     // ALU Output selection mux control
  logic        IWValidFunct3D;                 // Detects if Funct3 is valid for IW instructions
  logic [3:0]  CMOpD, CMOpE;                   // which CMO instruction 1: cbo.inval; 2: cbo.flush; 4: cbo.clean; 8: cbo.zero
  logic        IFUPrefetchD;                   // instruction prefetch
  logic        LSUPrefetchD, LSUPrefetchE;     // data prefetch
  logic        MatchDE;                        // Match between a source register in Decode stage and destination register in Execute stage
  logic        FCvtIntStallD, MDUStallD, CSRRdStallD; // Stall due to conversion, load, multiply/divide, CSR read
  logic        FunctCZeroD;                    // Funct7 and Funct3 indicate czero.* (not including Op check)
  logic        BUW64D;                         // Indicates if it is a .uw type B instruction in Decode Stage

  // Extract fields
  assign OpD     = InstrD[6:0];
  assign Funct3D = InstrD[14:12];
  assign Funct7D = InstrD[31:25];
  assign Rs1D    = InstrD[19:15];
  assign Rs2D    = InstrD[24:20];
  assign RdD     = InstrD[11:7];

  // Funct 7 checking
  // Be rigorous about detecting illegal instructions if CSRs or bit manipulation or conditional ops are supported
  // otherwise be cheap

  if (P.ZICSR_SUPPORTED | P.ZBA_SUPPORTED  | P.ZBB_SUPPORTED  | P.ZBC_SUPPORTED  | P.ZBS_SUPPORTED |
      P.ZBKB_SUPPORTED  | P.ZBKC_SUPPORTED | P.ZBKX_SUPPORTED | P.ZKNE_SUPPORTED |
      P.ZKND_SUPPORTED  | P.ZKNH_SUPPORTED | P.ZICOND_SUPPORTED) begin : legalcheck // Exact integer decoding
    logic Funct7ZeroD, Funct7b5D, IShiftD, INoShiftD;
    logic Funct7ShiftZeroD, Funct7Shiftb5D;

    assign Funct7ZeroD      = (Funct7D == 7'b0000000); // most R-type instructions
    assign Funct7b5D        = (Funct7D == 7'b0100000); // srai, sub
    assign FunctCZeroD      = (Funct3D == 3'b101 | Funct3D == 3'b111) & (Funct7D == 7'b0000111) & P.ZICOND_SUPPORTED; // czero.eqz or czero.nez
    assign Funct7ShiftZeroD = (P.XLEN==64 & ~OpD[3]) ? (Funct7D[6:1] == 6'b000000) : Funct7ZeroD; // 64-bit logical shifts allowed on XLEN=64, non-W
    assign Funct7Shiftb5D   = (P.XLEN==64 & ~OpD[3]) ? (Funct7D[6:1] == 6'b010000) : Funct7b5D;   // 64-bit arithmetic shifts allowed on XLEN=64, non-W
    assign IShiftD          = (Funct3D == 3'b001 & Funct7ShiftZeroD) | (Funct3D == 3'b101 & (Funct7ShiftZeroD | Funct7Shiftb5D)); // slli, srli, srai, or w forms
    assign INoShiftD        = ((Funct3D != 3'b001) & (Funct3D != 3'b101));
    assign IFunctD          = IShiftD | INoShiftD;
    assign RFunctD          = ((Funct3D == 3'b000 | Funct3D == 3'b101) & Funct7b5D) | FunctCZeroD | Funct7ZeroD;
    assign MFunctD          = (Funct7D == 7'b0000001) & (P.M_SUPPORTED | (P.ZMMUL_SUPPORTED & ~Funct3D[2])); // muldiv
    assign LFunctD          = Funct3D == 3'b000 | Funct3D == 3'b001 | Funct3D == 3'b010 | Funct3D == 3'b100 | Funct3D == 3'b101 |
                              ((P.XLEN == 64) & (Funct3D == 3'b011 | Funct3D == 3'b110));
    assign FLSFunctD        = (STATUS_FS != 2'b00) & ((Funct3D == 3'b010 & P.F_SUPPORTED) | (Funct3D == 3'b011 & P.D_SUPPORTED) |
                              (Funct3D == 3'b100 & P.Q_SUPPORTED) | (Funct3D == 3'b001 & P.ZFH_SUPPORTED));
    assign FenceFunctD      = (Funct3D == 3'b000) | (P.ZIFENCEI_SUPPORTED & Funct3D == 3'b001);
    assign CMOFunctD        = (Funct3D == 3'b010 & RdD == 5'b0) &
                              ((P.ZICBOZ_SUPPORTED & InstrD[31:20] == 12'd4 & ENVCFG_CBE[3]) |
                               (P.ZICBOM_SUPPORTED & ((InstrD[31:20] == 12'd0 & (ENVCFG_CBE[1:0] != 2'b00))) |
                                                      (InstrD[31:20] == 12'd1 | InstrD[31:20] == 12'd2) & ENVCFG_CBE[2]));
    assign AFunctD          = (Funct3D == 3'b010) | (P.XLEN == 64 & Funct3D == 3'b011);
    assign AMOFunctD        = (InstrD[31:27] == 5'b00001) |
                              (InstrD[31:27] == 5'b00000) |
                              (InstrD[31:27] == 5'b00100) |
                              (InstrD[31:27] == 5'b01100) |
                              (InstrD[31:27] == 5'b01000) |
                              (InstrD[31:27] == 5'b10000) |
                              (InstrD[31:27] == 5'b10100) |
                              (InstrD[31:27] == 5'b11000) |
                              (InstrD[31:27] == 5'b11100);
    assign RWFunctD         = ((Funct3D == 3'b000 | Funct3D == 3'b001 | Funct3D == 3'b101) & Funct7ZeroD |
                              (Funct3D == 3'b000 | Funct3D == 3'b101) & Funct7b5D) & (P.XLEN == 64);
    assign MWFunctD         = MFunctD & (P.XLEN == 64) & ~(Funct3D == 3'b001 | Funct3D == 3'b010 | Funct3D == 3'b011);
    assign SFunctD          = Funct3D == 3'b000 | Funct3D == 3'b001 | Funct3D == 3'b010 |
                              ((P.XLEN == 64) & (Funct3D == 3'b011));
    assign BFunctD          = Funct3D[2:1] != 2'b01; // legal branches
    assign JRFunctD         = Funct3D == 3'b000;
    assign PFunctD          = Funct3D == 3'b000 & RdD == 5'b0;
    assign CSRFunctD        = Funct3D[1:0] != 2'b00;
    assign IWValidFunct3D   = Funct3D == 3'b000 | Funct3D == 3'b001 | Funct3D == 3'b101;
  end else begin : legalcheck2
    assign IFunctD = 1'b1; // Don't bother to separate out shift decoding
    assign RFunctD = ~Funct7D[0]; // Not a multiply
    assign MFunctD = Funct7D[0] & (P.M_SUPPORTED | (P.ZMMUL_SUPPORTED & ~Funct3D[2])); // muldiv
    assign LFunctD = 1'b1; // don't bother to check Funct3 for loads
    assign FLSFunctD = 1'b1; // don't bother to check Func3 for floating-point loads/stores
    assign FenceFunctD = 1'b1; // don't bother to check fields for fences
    assign CMOFunctD = 1'b1; // don't bother to check fields for CMO instructions
    assign AFunctD = 1'b1; // don't bother to check fields for atomics
    assign AMOFunctD = 1'b1; // don't bother to check Funct7 for AMO operations
    assign RWFunctD = 1'b1; // don't bother to check fields for RW instructions
    assign MWFunctD = 1'b1; // don't bother to check fields for MW instructions
    assign SFunctD = 1'b1; // don't bother to check Funct3 for stores
    assign BFunctD = 1'b1; // don't bother to check Funct3 for branches
    assign JRFunctD = 1'b1; // don't bother to check Funct3 for jalrs
    assign PFunctD = 1'b1; // don't bother to check fields for privileged instructions
    assign CSRFunctD = 1'b1; // don't bother to check Funct3 for CSR operations
    assign IWValidFunct3D = 1'b1;
  end

  // Main Instruction Decoder
  /* verilator lint_off CASEINCOMPLETE */
  always_comb begin
    ControlsD = `CTRLW'b0_000_00_00_000_0_0_0_0_0_0_0_0_0_00_0_1; // default: Illegal instruction
    case(OpD)
    // RegWrite_ImmSrc_ALUSrc(A_B)_MemRW_ResultSrc_Branch_ALUOp_Jump_ALUResultSrc_BaseW64_CSRRead_Privileged_Fence_MDU_Atomic_CMO_Illegal
      7'b0000011: if (LFunctD)
                      ControlsD = `CTRLW'b1_000_01_10_001_0_0_0_0_0_0_0_0_0_00_0_0; // loads
      7'b0000111: if (FLSFunctD)
                      ControlsD = `CTRLW'b0_000_01_10_001_0_0_0_0_0_0_0_0_0_00_0_1; // flw - only legal if FP supported
      7'b0001111: if (FenceFunctD) begin
                    if (P.ZIFENCEI_SUPPORTED)
                      ControlsD = `CTRLW'b0_000_00_00_000_0_0_0_0_0_0_0_1_0_00_0_0; // fence
                    else
                      ControlsD = `CTRLW'b0_000_00_00_000_0_0_0_0_0_0_0_0_0_00_0_0; // fence treated as nop
                  end else if (CMOFunctD) begin
                      ControlsD = `CTRLW'b0_101_01_00_000_0_0_0_0_0_0_0_0_0_00_1_0; // CMO Instruction
                  end
      7'b0010011: if (IFunctD)
                      ControlsD = `CTRLW'b1_000_01_00_000_0_1_0_0_0_0_0_0_0_00_0_0; // I-type ALU
      7'b0010111:     ControlsD = `CTRLW'b1_100_11_00_000_0_0_0_0_0_0_0_0_0_00_0_0; // auipc
      7'b0011011: if (IFunctD & IWValidFunct3D & P.XLEN == 64)
                      ControlsD = `CTRLW'b1_000_01_00_000_0_1_0_0_1_0_0_0_0_00_0_0; // IW-type ALU for RV64i
      7'b0100011: if (SFunctD)
                      ControlsD = `CTRLW'b0_001_01_01_000_0_0_0_0_0_0_0_0_0_00_0_0; // stores
      7'b0100111: if (FLSFunctD)
                      ControlsD = `CTRLW'b0_001_01_01_000_0_0_0_0_0_0_0_0_0_00_0_1; // fsw - only legal if FP supported
      7'b0101111: if (AFunctD) begin
                    if (P.ZALRSC_SUPPORTED & InstrD[31:27] == 5'b00010 & Rs2D == 5'b0)
                      ControlsD = `CTRLW'b1_000_00_10_001_0_0_0_0_0_0_0_0_0_01_0_0; // lr
                    else if (P.ZALRSC_SUPPORTED & InstrD[31:27] == 5'b00011)
                      ControlsD = `CTRLW'b1_101_01_01_100_0_0_0_0_0_0_0_0_0_01_0_0; // sc
                    else if (P.ZAAMO_SUPPORTED & AMOFunctD)
                      ControlsD = `CTRLW'b1_101_01_11_001_0_0_0_0_0_0_0_0_0_10_0_0; // amo
                 end
      7'b0110011: if (RFunctD)
                      ControlsD = `CTRLW'b1_000_00_00_000_0_1_0_0_0_0_0_0_0_00_0_0; // R-type
                  else if (MFunctD)
                      ControlsD = `CTRLW'b1_000_00_00_011_0_0_0_0_0_0_0_0_1_00_0_0; // Multiply/Divide
      7'b0110111:     ControlsD = `CTRLW'b1_100_01_00_000_0_0_0_1_0_0_0_0_0_00_0_0; // lui
      7'b0111011: if (RWFunctD)
                      ControlsD = `CTRLW'b1_000_00_00_000_0_1_0_0_1_0_0_0_0_00_0_0; // R-type W instructions for RV64i
                  else if (MWFunctD)
                      ControlsD = `CTRLW'b1_000_00_00_011_0_0_0_0_1_0_0_0_1_00_0_0; // W-type Multiply/Divide
      7'b1100011: if (BFunctD)
                      ControlsD = `CTRLW'b0_010_11_00_000_1_0_0_0_0_0_0_0_0_00_0_0; // branches
      7'b1100111: if (JRFunctD)
                      ControlsD = `CTRLW'b1_000_01_00_000_0_0_1_1_0_0_0_0_0_00_0_0; // jalr
      7'b1101111:     ControlsD = `CTRLW'b1_011_11_00_000_0_0_1_1_0_0_0_0_0_00_0_0; // jal
      7'b1110011: if (P.ZICSR_SUPPORTED) begin
                   if (PFunctD)
                      ControlsD = `CTRLW'b0_000_00_00_000_0_0_0_0_0_0_1_0_0_00_0_0; // privileged; decoded further in privdec modules
                   else if (CSRFunctD)
                      ControlsD = `CTRLW'b1_000_00_00_010_0_0_0_0_0_1_0_0_0_00_0_0; // csrs
                  end
    endcase
  end
  /* verilator lint_on CASEINCOMPLETE */

  // Unswizzle control bits
  // Squash control signals if coming from an illegal compressed instruction
  // On RV32E, can't write to upper 16 registers.  Checking reads to upper 16 is more costly so disregard them.
  assign IllegalERegAdrD = P.E_SUPPORTED & P.ZICSR_SUPPORTED & ControlsD[`CTRLW-1] & InstrD[11];
  assign {BaseRegWriteD, PreImmSrcD, ALUSrcAD, BaseALUSrcBD, MemRWD,
          ResultSrcD, BranchD, ALUOpD, JumpD, ALUResultSrcD, BaseW64D, CSRReadD,
          PrivilegedD, FenceXD, MDUD, AtomicD, CMOD, unused} = IllegalIEUFPUInstrD ? `CTRLW'b0 : ControlsD;

  assign CSRZeroSrcD = InstrD[14] ? (InstrD[19:15] == 0) : (Rs1D == 0); // Is a CSR instruction using zero as the source?
  assign CSRWriteD = CSRReadD & !(CSRZeroSrcD & InstrD[13]);            // Don't write if setting or clearing zeros
  assign SFenceVmaD = PrivilegedD & (InstrD[31:25] ==  7'b0001001);
  assign FenceD = SFenceVmaD | FenceXD; // possible sfence.vma or fence.i

  // ALU Decoding is lazy, only using func7[5] to distinguish add/sub and srl/sra
  assign sltuD = (Funct3D == 3'b011);
  assign subD = (Funct3D == 3'b000 & Funct7D[5] & OpD[5]);  // OpD[5] needed to distinguish sub from addi
  assign sraD = (Funct3D == 3'b101 & Funct7D[5]);
  assign BaseSubArithD = ALUOpD & (subD | sraD | sltD | sltuD);

  // bit manipulation Configuration Block
  if (P.ZBS_SUPPORTED  | P.ZBA_SUPPORTED  | P.ZBB_SUPPORTED  | P.ZBC_SUPPORTED |
      P.ZBKB_SUPPORTED | P.ZBKC_SUPPORTED | P.ZBKX_SUPPORTED | P.ZKNE_SUPPORTED |
      P.ZKND_SUPPORTED | P.ZKNH_SUPPORTED) begin : bitmanipi
    logic IllegalBitmanipInstrD;          // Unrecognized B instruction
    logic BRegWriteD;                     // Indicates if it is a R type BMU instruction in decode stage
    logic BW64D;                          // Indicates if it is a W type BMU instruction in decode stage
    logic BSubArithD;                     // TRUE for BMU ext, clr, andn, orn, xnor
    logic BALUSrcBD;                      // BMU alu src select signal

    bmuctrl #(P) bmuctrl(.clk, .reset, .InstrD, .ALUOpD,
      .BRegWriteD, .BALUSrcBD, .BW64D, .BUW64D, .BSubArithD, .IllegalBitmanipInstrD, .StallE, .FlushE,
      .ALUSelectD(PreALUSelectD), .BSelectE, .ZBBSelectE, .BALUControlE, .BMUActiveE);
    if (P.ZBA_SUPPORTED) begin
      // ALU Decoding is more comprehensive when ZBA is supported. slt and slti conflicts with sh1add, sh1add.uw
      assign sltD = (Funct3D == 3'b010 & (~(Funct7D[4]) | ~OpD[5])) ;
    end else assign sltD = (Funct3D == 3'b010);

    // Combine base and bit manipulation signals
    // coverage off: IllegalERegAdr can't occur in rv64gc; only applicable to E mode
    assign IllegalBaseInstrD = (ControlsD[0] & IllegalBitmanipInstrD) | IllegalERegAdrD ;
    // coverage on
    assign RegWriteD = BaseRegWriteD | BRegWriteD;
    assign W64D = BaseW64D | BW64D;
    assign ALUSrcBD = BaseALUSrcBD | BALUSrcBD;
    assign SubArithD = BaseSubArithD | BSubArithD; // TRUE If BMU or R-type instruction involves inverted operand

  end else begin : bitmanipi
    assign PreALUSelectD = ALUOpD ? Funct3D : 3'b000; // add for address generation when not doing ALU operation
    assign sltD = (Funct3D == 3'b010);
    assign IllegalBaseInstrD = ControlsD[0] | IllegalERegAdrD ;
    assign RegWriteD = BaseRegWriteD;
    assign W64D = BaseW64D;
    assign ALUSrcBD = BaseALUSrcBD;
    assign SubArithD = BaseSubArithD; // TRUE If B-type or R-type instruction involves inverted operand
    assign BUW64D = 1'b0; // no .uw instructions

    // tie off unused bit manipulation signals
    assign BSelectE = 4'b0000;
    assign ZBBSelectE = 4'b0000;
    assign BALUControlE = 3'b0;
    assign BMUActiveE = 1'b0;
  end

  if (P.ZICOND_SUPPORTED) begin : Zicond
    logic  SomeCZeroD; // instruction is czero.*
    assign SomeCZeroD = FunctCZeroD & (OpD == 7'b0110011);
    assign CZeroD = {SomeCZeroD & (Funct3D == 3'b111), SomeCZeroD & (Funct3D == 3'b101)}; // {czero.nez, czero.eqz}
    assign ALUSelectD = SomeCZeroD ? 3'b111 : PreALUSelectD; // perform AND operation for czero.* instructions
  end else begin
    assign CZeroD = 2'b00; // Zicond not supported
    assign ALUSelectD = PreALUSelectD;
  end

  // Fences
  // Ordinary fence is presently a nop
  // fence.i flushes the D$ and invalidates the I$ if Zifencei is supported and I$ is implemented
  if (P.ZIFENCEI_SUPPORTED & (P.ICACHE_SUPPORTED | P.DCACHE_SUPPORTED)) begin : fencei
    logic FenceID;
    assign FenceID = FenceXD & (Funct3D == 3'b001); // is it a FENCE.I instruction?
    assign InvalidateICacheD = FenceID;
    assign FlushDCacheD = FenceID;
  end else begin : fencei
    assign InvalidateICacheD = 1'b0;
    assign FlushDCacheD = 1'b0;
  end

  // Cache Management instructions
  always_comb begin
    CMOpD = 4'b0000; // default: not a cbo instruction
    if ((P.ZICBOZ_SUPPORTED) & CMOD) begin
      CMOpD[3] = (InstrD[31:20] == 12'd4); // cbo.zero
    end
    if ((P.ZICBOM_SUPPORTED) & CMOD) begin
      CMOpD[2] = (InstrD[31:20] == 12'd2); // cbo.clean
      CMOpD[1] = (InstrD[31:20] == 12'd1) | ((InstrD[31:20] == 12'd0) & (ENVCFG_CBE[1:0] == 2'b01)); // cbo.flush
      CMOpD[0] = (InstrD[31:20] == 12'd0) & (ENVCFG_CBE[1:0] == 2'b11); // cbo.inval
    end
  end

  // Prefetch Hints
  always_comb begin
    // default: not a prefetch hint
    IFUPrefetchD = 1'b0;
    LSUPrefetchD = 1'b0;
    ImmSrcD = PreImmSrcD;
    if (P.ZICBOP_SUPPORTED & (InstrD[14:0] == 15'b110_00000_0010011)) begin // ori with destination x0 is hint for Prefetch
      /* verilator lint_off CASEINCOMPLETE */
      case (Rs2D) // which type of prefectch?  Note: prefetch.r and .w are handled the same in Wally
        5'b00000: IFUPrefetchD = 1'b1; // prefetch.i
        5'b00001: LSUPrefetchD = 1'b1; // prefetch.r
        5'b00011: LSUPrefetchD = 1'b1; // prefetch.w
        // default: not a prefetch hint
      endcase
      /* verilator lint_on CASEINCOMPLETE */
      if (IFUPrefetchD | LSUPrefetchD) ImmSrcD = 3'b001; // use S-type immediate format for prefetches
    end
  end

  // Decode stage pipeline control register
  flopenrc #(1)  controlregD(clk, reset, FlushD, ~StallD, 1'b1, InstrValidD);

  // Execute stage pipeline control register and logic
  flopenrc #(45) controlregE(clk, reset, FlushE, ~StallE,
                           {ALUSelectD, RegWriteD, ResultSrcD, MemRWD, JumpD, BranchD, ALUSrcAD, ALUSrcBD, ALUResultSrcD, CSRReadD, CSRWriteD, PrivilegedD, Funct3D, Funct7D, W64D, BUW64D, SubArithD, MDUD, AtomicD, InvalidateICacheD, FlushDCacheD, FenceD, CMOpD, IFUPrefetchD, LSUPrefetchD, CZeroD, InstrValidD},
                           {ALUSelectE, IEURegWriteE, ResultSrcE, MemRWE, JumpE, BranchE, ALUSrcAE, ALUSrcBE, ALUResultSrcE, CSRReadE, CSRWriteE, PrivilegedE, Funct3E, Funct7E, W64E, UW64E, SubArithE, MDUE, AtomicE, InvalidateICacheE, FlushDCacheE, FenceE, CMOpE, IFUPrefetchE, LSUPrefetchE, CZeroE, InstrValidE});
  flopenrc #(5)  Rs1EReg(clk, reset, FlushE, ~StallE, Rs1D, Rs1E);
  flopenrc #(5)  Rs2EReg(clk, reset, FlushE, ~StallE, Rs2D, Rs2E);
  flopenrc #(5)  RdEReg(clk, reset, FlushE, ~StallE, RdD, RdE);

  // Branch Logic
  //  The comparator handles both signed and unsigned branches using BranchSignedE
  //  Hence, only eq and lt flags are needed
  assign BranchSignedE = (~(Funct3E[2:1] == 2'b11) & BranchE);
  assign {eqE, ltE} = FlagsE;
  mux2 #(1) branchflagmux(eqE, ltE, Funct3E[2], BranchFlagE);
  assign BranchTakenE = BranchFlagE ^ Funct3E[0];
  assign PCSrcE = JumpE | BranchE & BranchTakenE;

  // Other execute stage controller signals
  assign MemReadE = MemRWE[1];
  assign SCE = (ResultSrcE == 3'b100);
  assign MDUActiveE = (ResultSrcE == 3'b011);
  assign RegWriteE = IEURegWriteE | FWriteIntE; // IRF register writes could come from IEU or FPU controllers
  assign IntDivE = MDUE & Funct3E[2]; // Integer division operation

  // Memory stage pipeline control register
  flopenrc #(25) controlregM(clk, reset, FlushM, ~StallM,
                         {RegWriteE, ResultSrcE, MemRWE, CSRReadE, CSRWriteE, PrivilegedE, Funct3E, FWriteIntE, AtomicE, InvalidateICacheE, FlushDCacheE, FenceE, InstrValidE, IntDivE, CMOpE, LSUPrefetchE},
                         {RegWriteM, ResultSrcM, MemRWM, CSRReadM, CSRWriteM, PrivilegedM, Funct3M, FWriteIntM, AtomicM, InvalidateICacheM, FlushDCacheM, FenceM, InstrValidM, IntDivM, CMOpM, LSUPrefetchM});
  flopenrc #(5)  RdMReg(clk, reset, FlushM, ~StallM, RdE, RdM);

  // Writeback stage pipeline control register
  flopenrc #(5) controlregW(clk, reset, FlushW, ~StallW,
                         {RegWriteM, ResultSrcM, IntDivM},
                         {RegWriteW, ResultSrcW, IntDivW});
  flopenrc #(5) RdWReg(clk, reset, FlushW, ~StallW, RdM, RdW);

  // Flush F, D, and E stages on a CSR write or Fence.I or SFence.VMA
  assign CSRWriteFenceM = CSRWriteM | FenceM;

  // Forwarding logic
  always_comb begin
    ForwardAE = 2'b00;
    ForwardBE = 2'b00;
    if (Rs1E != 5'b0)
      if      ((Rs1E == RdM) & RegWriteM) ForwardAE = 2'b10;
      else if ((Rs1E == RdW) & RegWriteW) ForwardAE = 2'b01;

    if (Rs2E != 5'b0)
      if      ((Rs2E == RdM) & RegWriteM) ForwardBE = 2'b10;
      else if ((Rs2E == RdW) & RegWriteW) ForwardBE = 2'b01;
  end

  // Stall on dependent operations that finish in Mem Stage and can't bypass in time
  // Structural hazard causes stall if any of these events occur
  assign MatchDE = ((Rs1D == RdE) | (Rs2D == RdE)) & (RdE != 5'b0); // Decode-stage instruction source depends on result from execute stage instruction
  assign LoadStallD = (MemReadE|SCE) & MatchDE;
  assign StoreStallD = MemRWD[1] & MemRWE[0];   // Store or AMO followed by load or AMO
  assign CSRRdStallD = CSRReadE & MatchDE;
  assign MDUStallD = MDUE & MatchDE; // Int mult/div is at least two cycle latency, even when coming from the FDIV
  assign FCvtIntStallD = FCvtIntE & MatchDE; // FPU to Integer transfers have single-cycle latency except fcvt
  assign StructuralStallD = LoadStallD | StoreStallD | CSRRdStallD | MDUStallD | FCvtIntStallD;
endmodule
