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

module ieu import cvw::*; #(parameter cvw_t P) (
  input  logic              clk, reset,                      // Clock and reset
  // Decode stage signals
  input  logic [31:0]       InstrD,                          // Instruction in Decode stage
  input  logic [1:0]        STATUS_FS,                       // mstatus.FS: FPU state (00 off)
  input  logic [3:0]        ENVCFG_CBE,                      // Cache block operation enables
  input  logic              IllegalIEUFPUInstrD,             // Illegal integer or FP instruction in Decode stage
  output logic              IllegalBaseInstrD,               // Illegal base integer instruction, or illegal RV32E access to upper 16 registers
  // Execute stage signals
  input  logic [P.XLEN-1:0] PCE,                             // PC in Execute stage
  input  logic [P.XLEN-1:0] PCLinkE,                         // PC + 2 or 4 of instruction in Execute stage (link address)
  output logic              PCSrcE,                          // Select next PC: 1 branch/jump target IEUAdrE, 0 PC + 2/4
  input  logic              FWriteIntE, FCvtIntE,            // FPU writes integer register file, FPU converts float to integer in Execute stage
  output logic [P.XLEN-1:0] IEUAdrE,                         // Memory address or branch/jump target in Execute stage
  output logic              IntDivE, W64E,                   // Integer divide or remainder, RV64 W-type instruction
  output logic [2:0]        Funct3E,                         // funct3 field of instruction in Execute stage
  output logic [P.XLEN-1:0] ForwardedSrcAE, ForwardedSrcBE,  // Source operands A and B after forwarding, before ALU source select
  output logic [4:0]        RdE,                             // Destination register in Execute stage
  output logic              MDUActiveE,                      // Mul/Div instruction being executed
  output logic [3:0]        CMOpM,                           // Cache management operation: 1 cbo.inval, 2 cbo.clean, 4 cbo.flush, 8 cbo.zero
  output logic              IFUPrefetchE,                    // instruction prefetch
  output logic              LSUPrefetchM,                    // Data prefetch (presently unused)
  // Memory stage signals
  input  logic              SquashSCW,                       // Store conditional failed; do not write the register file
  output logic [1:0]        MemRWE,                          // Memory read/write control in Execute stage: [1] read, [0] write
  output logic [1:0]        MemRWM,                          // Memory read/write control in Memory stage: [1] read, [0] write
  output logic [1:0]        AtomicM,                         // Atomic memory operation: 10 AMO, 01 LR/SC
  output logic [P.XLEN-1:0] WriteDataM,                      // Write data from IEU
  output logic [2:0]        Funct3M,                         // funct3 field of instruction in Memory stage
  output logic [P.XLEN-1:0] SrcAM,                           // ALU source A in Memory stage, for CSR writes
  output logic [4:0]        RdM,                             // Destination register in Memory stage
  input  logic [P.XLEN-1:0] FIntResM,                        // FPU result to integer register file (fmv, fclass, fcmp)
  output logic              InvalidateICacheM, FlushDCacheM, // Invalidate I$ (fence.i), flush D$
  output logic              InstrValidD, InstrValidE, InstrValidM, // Instruction in Decode, Execute, Memory stages is valid
  output logic              BranchD, BranchE,                // Branch instruction in Decode, Execute stages
  output logic              JumpD, JumpE,                    // Jump instruction in Decode, Execute stages
  // Writeback stage signals
  input  logic [P.XLEN-1:0] FIntDivResultW,                  // Integer divide result from FPU divider in Writeback stage
  input  logic [P.XLEN-1:0] CSRReadValW,                     // CSR read value
  input  logic [P.XLEN-1:0] MDUResultW,                      // Multiply/divide result
  input  logic [P.XLEN-1:0] FCvtIntResW,                     // Float-to-integer conversion result
  input  logic              FCvtIntW,                        // FPU converts float to integer in Writeback stage
  output logic [4:0]        RdW,                             // Destination register in Writeback stage
  input  logic [P.XLEN-1:0] ReadDataW,                       // Read data from memory in Writeback stage
  // Hazard unit signals
  input  logic              StallD, StallE, StallM, StallW,  // Stall Decode, Execute, Memory, Writeback stages
  input  logic              FlushD, FlushE, FlushM, FlushW,  // Flush Decode, Execute, Memory, Writeback stages
  output logic              StructuralStallD,                // Structural hazard stall in Decode stage
  output logic              LoadStallD,                      // Load-use stall, for performance counters
  output logic              StoreStallD,                     // Store-load hazard stall, for performance counters
  output logic              CSRReadM, CSRWriteM, PrivilegedM, // CSR read, CSR write, and privileged instructions
  output logic              CSRWriteFenceM                   // CSR write or fence instruction; flush the following instructions
);

  logic [2:0] ImmSrcD;                                       // Select type of immediate extension
  logic [1:0] FlagsE;                                        // Comparison flags ({eq, lt})
  logic       ALUSrcAE, ALUSrcBE;                            // ALU source operands
  logic [2:0] ResultSrcW;                                    // Selects result in Writeback stage
  logic       ALUResultSrcE;                                 // Selects ALU result to pass on to Memory stage
  logic [2:0] ALUSelectE;                                    // ALU select mux signal
  logic       FWriteIntM;                                    // FPU writing to integer register file
  logic       IntDivW;                                       // Integer divide instruction
  logic [3:0] BSelectE;                                      // BMU result select (binary encoded; see bitmanipalu)
  logic [3:0] ZBBSelectE;                                    // ZBB Result Select Signal in Execute Stage
  logic [2:0] BALUControlE;                                  // ALU Control signals for B instructions in Execute Stage
  logic       SubArithE;                                     // Subtraction or arithmetic shift
  logic       UW64E;                                         // .uw-type instruction

  logic [6:0] Funct7E;

  // Forwarding signals
  logic [4:0] Rs1D, Rs2D;
  logic [4:0] Rs2E;                                          // Source registers
  logic [1:0] ForwardAE, ForwardBE;                          // Select signals for forwarding multiplexers
  logic       RegWriteW;                                     // Register will be written in Writeback stage
  logic       BranchSignedE;                                 // Branch does signed comparison on operands
  logic       BMUActiveE;                                    // Bit manipulation instruction being executed
  logic [1:0] CZeroE;                                        // {czero.nez, czero.eqz} instructions active

  controller #(P) c(
    .clk, .reset, .StallD, .FlushD, .InstrD, .STATUS_FS, .ENVCFG_CBE, .ImmSrcD,
    .IllegalIEUFPUInstrD, .IllegalBaseInstrD,
    .StructuralStallD, .LoadStallD, .StoreStallD, .Rs1D, .Rs2D, .Rs2E,
    .StallE, .FlushE, .FlagsE, .FWriteIntE,
    .PCSrcE, .ALUSrcAE, .ALUSrcBE, .ALUResultSrcE, .ALUSelectE,
    .Funct3E, .Funct7E, .IntDivE, .W64E, .UW64E, .SubArithE, .BranchD, .BranchE, .JumpD, .JumpE,
    .BranchSignedE, .BSelectE, .ZBBSelectE, .BALUControlE, .BMUActiveE, .CZeroE, .MDUActiveE,
    .FCvtIntE, .ForwardAE, .ForwardBE, .CMOpM, .IFUPrefetchE, .LSUPrefetchM,
    .StallM, .FlushM, .MemRWE, .MemRWM, .CSRReadM, .CSRWriteM, .PrivilegedM, .AtomicM, .Funct3M,
    .FlushDCacheM, .InstrValidM, .InstrValidE, .InstrValidD, .FWriteIntM,
    .StallW, .FlushW, .RegWriteW, .IntDivW, .ResultSrcW, .CSRWriteFenceM, .InvalidateICacheM,
    .RdW, .RdE, .RdM);

  datapath #(P) dp(
    .clk, .reset, .ImmSrcD, .InstrD, .Rs1D, .Rs2D, .Rs2E, .StallE, .FlushE, .ForwardAE, .ForwardBE, .W64E, .UW64E, .SubArithE,
    .Funct3E, .Funct7E, .ALUSrcAE, .ALUSrcBE, .ALUResultSrcE, .ALUSelectE, .JumpE, .BranchSignedE,
    .PCE, .PCLinkE, .FlagsE, .IEUAdrE, .ForwardedSrcAE, .ForwardedSrcBE, .BSelectE, .ZBBSelectE, .BALUControlE, .BMUActiveE, .CZeroE,
    .StallM, .FlushM, .FWriteIntM, .FIntResM, .SrcAM, .WriteDataM, .FCvtIntW,
    .StallW, .FlushW, .RegWriteW, .IntDivW, .SquashSCW, .ResultSrcW, .ReadDataW, .FCvtIntResW,
    .CSRReadValW, .MDUResultW, .FIntDivResultW, .RdW);
endmodule
