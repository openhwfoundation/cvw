///////////////////////////////////////////
// datapath.sv
//
// Written: David_Harris@hmc.edu, Sarah.Harris@unlv.edu
// Created: 9 January 2021
// Modified:
//
// Purpose: Wally Integer Datapath
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

module datapath import cvw::*; #(parameter cvw_t P) (
  input  logic              clk, reset,              // Clock and reset
  // Decode stage signals
  input  logic [2:0]        ImmSrcD,                 // Type of immediate extension
  input  logic [31:0]       InstrD,                  // Instruction in Decode stage
  input  logic [4:0]        Rs1D, Rs2D, Rs2E,        // Source registers rs1 and rs2 in Decode stage, rs2 in Execute stage
  // Execute stage signals
  input  logic [P.XLEN-1:0] PCE,                     // PC in Execute stage
  input  logic [P.XLEN-1:0] PCLinkE,                 // PC + 2 or 4 of instruction in Execute stage (link address)
  input  logic [2:0]        Funct3E,                 // funct3 field of instruction in Execute stage
  input  logic [6:0]        Funct7E,                 // funct7 field of instruction in Execute stage
  input  logic              StallE, FlushE,          // Stall and flush Execute stage
  input  logic [1:0]        ForwardAE, ForwardBE,    // Forwarding select for ALU operands A and B
  input  logic              W64E, UW64E,             // RV64 W-type and .uw-type instruction in Execute stage
  input  logic              SubArithE,               // Subtraction or arithmetic shift
  input  logic              ALUSrcAE, ALUSrcBE,      // ALU source select for operands A and B
  input  logic              ALUResultSrcE,           // Selects result to pass on to Memory stage
  input  logic [2:0]        ALUSelectE,              // ALU operation select in Execute stage
  input  logic              JumpE,                   // Jump instruction in Execute stage
  input  logic              BranchSignedE,           // Branch comparison operands are signed (if it's a branch)
  input  logic [3:0]        BSelectE,                // BMU result select (binary encoded; see bitmanipalu)
  input  logic [3:0]        ZBBSelectE,              // Zbb result select
  input  logic [2:0]        BALUControlE,            // ALU Control signals for B instructions in Execute Stage
  input  logic              BMUActiveE,              // Bit manipulation instruction being executed
  input  logic [1:0]        CZeroE,                  // {czero.nez, czero.eqz} instructions active
  output logic [1:0]        FlagsE,                  // Comparison flags ({eq, lt})
  output logic [P.XLEN-1:0] IEUAdrE,                 // Memory address or branch/jump target in Execute stage
  output logic [P.XLEN-1:0] ForwardedSrcAE, ForwardedSrcBE, // Source operands A and B after forwarding, before ALU source select
  // Memory stage signals
  input  logic              StallM, FlushM,          // Stall and flush Memory stage
  input  logic              FWriteIntM, FCvtIntW,    // FPU writes integer register file in Memory stage, converts float to integer in Writeback stage
  input  logic [P.XLEN-1:0] FIntResM,                // FPU result to integer register file (fmv, fclass, fcmp)
  output logic [P.XLEN-1:0] SrcAM,                   // ALU source A in Memory stage, for CSR writes
  output logic [P.XLEN-1:0] WriteDataM,              // Write data from IEU
  // Writeback stage signals
  input  logic              StallW, FlushW,          // Stall and flush Writeback stage
  input  logic              RegWriteW, IntDivW,      // Write register file, integer divide instruction in Writeback stage
  input  logic              SquashSCW,               // Store conditional failed; do not write the register file
  input  logic [2:0]        ResultSrcW,              // Select source of result to write back to register file
  input  logic [P.XLEN-1:0] FCvtIntResW,             // Float-to-integer conversion result
  input  logic [P.XLEN-1:0] ReadDataW,               // Read data from memory in Writeback stage
  input  logic [P.XLEN-1:0] CSRReadValW,             // CSR read value
  input  logic [P.XLEN-1:0] MDUResultW,              // Multiply/divide result
  input  logic [P.XLEN-1:0] FIntDivResultW,          // Integer divide result from FPU divider in Writeback stage
  input  logic [4:0]        RdW                      // Destination register in Writeback stage
);

  // Decode stage signals
  logic [P.XLEN-1:0] R1D, R2D;                       // Read data from Rs1 (RD1), Rs2 (RD2)
  logic [P.XLEN-1:0] ImmExtD;                        // Extended immediate in Decode stage
  // Execute stage signals
  logic [P.XLEN-1:0] R1E, R2E;                       // Source operands read from register file
  logic [P.XLEN-1:0] ImmExtE;                        // Extended immediate in Execute stage
  logic [P.XLEN-1:0] SrcAE, SrcBE;                   // ALU operands
  logic [P.XLEN-1:0] ALUResultE, AltResultE, IEUResultE; // ALU result, Alternative result (ImmExtE or PC+4), result of execution stage
  logic [P.XLEN-1:0] IEUAdrRawE;                     // ALU sum before clearing bit 0 of a jump target
  // Memory stage signals
  logic [P.XLEN-1:0] IEUResultM;                     // Result from execution stage
  logic [P.XLEN-1:0] IFResultM;                      // Result from either IEU or single-cycle FPU op writing an integer register
  // Writeback stage signals
  logic [P.XLEN-1:0] SCResultW;                      // Store Conditional result
  logic [P.XLEN-1:0] ResultW;                        // Result to write to register file
  logic [P.XLEN-1:0] IFResultW;                      // Result from either IEU or single-cycle FPU op writing an integer register
  logic [P.XLEN-1:0] IFCvtResultW;                   // Result from IEU, single-cycle FPU op, or 2-cycle FCVT float to int
  logic [P.XLEN-1:0] MulDivResultW;                  // Multiply always comes from MDU.  Divide could come from MDU or FPU (when using fdivsqrt for integer division)

  // Decode stage
  regfile #(P.XLEN, P.E_SUPPORTED) regf(clk, reset, RegWriteW, Rs1D, Rs2D, RdW, ResultW, R1D, R2D);
  extend #(P)        ext(.InstrD(InstrD[31:7]), .ImmSrcD, .ImmExtD);

  // Execute stage pipeline register and logic
  flopenrc #(P.XLEN) RD1EReg(clk, reset, FlushE, ~StallE, R1D, R1E);
  flopenrc #(P.XLEN) RD2EReg(clk, reset, FlushE, ~StallE, R2D, R2E);
  flopenrc #(P.XLEN) ImmExtEReg(clk, reset, FlushE, ~StallE, ImmExtD, ImmExtE);

  mux3  #(P.XLEN)  faemux(R1E, ResultW, IFResultM, ForwardAE, ForwardedSrcAE);
  mux3  #(P.XLEN)  fbemux(R2E, ResultW, IFResultM, ForwardBE, ForwardedSrcBE);
  comparator #(P.XLEN) comp(ForwardedSrcAE, ForwardedSrcBE, BranchSignedE, FlagsE);
  mux2  #(P.XLEN)  srcamux(ForwardedSrcAE, PCE, ALUSrcAE, SrcAE);
  mux2  #(P.XLEN)  srcbmux(ForwardedSrcBE, ImmExtE, ALUSrcBE, SrcBE);
  alu   #(P)       alu(SrcAE, SrcBE, W64E, UW64E, SubArithE, ALUSelectE, BSelectE, ZBBSelectE, Funct3E, Funct7E, Rs2E, BALUControlE, BMUActiveE, CZeroE, ALUResultE, IEUAdrRawE);
  // jalr sets the least significant bit of the target address to zero.  jal and branch targets are
  // always even, so masking on JumpE alone is sufficient and leaves load/store addresses untouched.
  assign IEUAdrE = {IEUAdrRawE[P.XLEN-1:1], IEUAdrRawE[0] & ~JumpE};
  mux2  #(P.XLEN)  altresultmux(ImmExtE, PCLinkE, JumpE, AltResultE);
  mux2  #(P.XLEN)  ieuresultmux(ALUResultE, AltResultE, ALUResultSrcE, IEUResultE);

  // Memory stage pipeline register
  flopenrc #(P.XLEN) SrcAMReg(clk, reset, FlushM, ~StallM, SrcAE, SrcAM);
  flopenrc #(P.XLEN) IEUResultMReg(clk, reset, FlushM, ~StallM, IEUResultE, IEUResultM);
  flopenrc #(P.XLEN) WriteDataMReg(clk, reset, FlushM, ~StallM, ForwardedSrcBE, WriteDataM);

  // Writeback stage pipeline register and logic
  flopenrc #(P.XLEN) IFResultWReg(clk, reset, FlushW, ~StallW, IFResultM, IFResultW);

  // floating point inputs: FIntResM comes from fclass, fcmp, fmv; FCvtIntResW comes from fcvt
  if (P.F_SUPPORTED) begin : fpmux
    mux2  #(P.XLEN)  resultmuxM(IEUResultM, FIntResM, FWriteIntM, IFResultM);
    mux2  #(P.XLEN)  cvtresultmuxW(IFResultW, FCvtIntResW, FCvtIntW, IFCvtResultW);
    if (P.IDIV_ON_FPU & P.F_SUPPORTED) begin
      mux2  #(P.XLEN)  divresultmuxW(MDUResultW, FIntDivResultW, IntDivW, MulDivResultW);
    end else begin
      assign MulDivResultW = MDUResultW;
    end
  end else begin : fpmux
    assign IFResultM = IEUResultM;
    assign IFCvtResultW = IFResultW;
    assign MulDivResultW = MDUResultW;
  end
  mux5  #(P.XLEN) resultmuxW(IFCvtResultW, ReadDataW, CSRReadValW, MulDivResultW, SCResultW, ResultSrcW, ResultW);

  // handle Store Conditional result if atomic extension supported
  if (P.ZALRSC_SUPPORTED) assign SCResultW = {{(P.XLEN-1){1'b0}}, SquashSCW};
  else                    assign SCResultW = '0;
endmodule
