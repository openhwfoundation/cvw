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

module datapath import cvw::*;  #(parameter cvw_t P) (
  input  logic              clk, reset,
  // Decode stage signals
  input  logic [2:0]        ImmSrcD,                 // Selects type of immediate extension
  input  logic [31:0]       InstrD,                  // Instruction in Decode stage
  input  logic [4:0]        Rs1D, Rs2D, Rs2E,             // Source registers
  // Execute stage signals
  input  logic [P.XLEN-1:0] PCE,                     // PC in Execute stage
  input  logic [P.XLEN-1:0] PCLinkE,                 // PC + 4 (of instruction in Execute stage)
  input  logic [2:0]        Funct3E,                 // Funct3 field of instruction in Execute stage
  input  logic [6:0]        Funct7E,                 // Funct7 field of instruction in Execute stage
  input  logic              StallE, FlushE,          // Stall, flush Execute stage
  input  logic [1:0]        ForwardAE, ForwardBE,    // Forward ALU operands from later stages
  input  logic              W64E,UW64E,              // W64/.uw-type instruction
  input  logic              SubArithE,               // Subtraction or arithmetic shift
  input  logic              ALUSrcAE, ALUSrcBE,      // ALU operands
  input  logic              ALUResultSrcE,           // Selects result to pass on to Memory stage
  input  logic [2:0]        ALUSelectE,              // ALU mux select signal
  input  logic              JumpE,                   // Is a jump (j) instruction
  input  logic              BranchSignedE,           // Branch comparison operands are signed (if it's a branch)
  input  logic [3:0]        BSelectE,                // One hot encoding of ZBA_ZBB_ZBC_ZBS instruction
  input  logic [3:0]        ZBBSelectE,              // ZBB mux select signal
  input  logic [2:0]        BALUControlE,            // ALU Control signals for B instructions in Execute Stage
  input  logic              BMUActiveE,              // Bit manipulation instruction being executed
  input  logic [1:0]        CZeroE,                  // {czero.nez, czero.eqz} instructions active
  output logic [1:0]        FlagsE,                  // Comparison flags ({eq, lt})
  output logic [P.XLEN-1:0] IEUAdrE,                 // Address computed by ALU
  output logic [P.XLEN-1:0] ForwardedSrcAE, ForwardedSrcBE, // ALU sources before the mux chooses between them and PCE to put in srcA/B
  // Memory stage signals
  input  logic              StallM, FlushM,          // Stall, flush Memory stage
  input  logic              FWriteIntM, FCvtIntW,    // FPU writes integer register file, FPU converts float to int
  input  logic [P.XLEN-1:0] FIntResM,                // FPU integer result
  output logic [P.XLEN-1:0] SrcAM,                   // ALU's Source A in Memory stage to privilege unit for CSR writes
  output logic [P.XLEN-1:0] WriteDataM,              // Write data in Memory stage
  // Writeback stage signals
  input  logic              StallW, FlushW,          // Stall, flush Writeback stage
  input  logic              RegWriteW, IntDivW,      // Write register file, integer divide instruction
  input  logic              SquashSCW,               // Squash a store conditional when a conflict arose
  input  logic [2:0]        ResultSrcW,              // Select source of result to write back to register file
  input  logic [P.XLEN-1:0] FCvtIntResW,             // FPU convert fp to integer result
  input  logic [P.XLEN-1:0] ReadDataW,               // Read data from LSU
  input  logic [P.XLEN-1:0] CSRReadValW,             // CSR read result
  input  logic [P.XLEN-1:0] MDUResultW,              // MDU (Multiply/divide unit) result
  input  logic [P.XLEN-1:0] FIntDivResultW,          // FPU's integer divide result
  input  logic [4:0]        RdW,                     // Destination register
  // Debug abstract register r/w signals
  input  logic              DebugMode,
  input  logic              DebugGPREnable,
  output logic [P.XLEN-1:0] DebugR1D,
  input  logic [P.XLEN-1:0] DebugRegWDATA,
  input  logic [11:0]       DebugRegAddr,
  input  logic              DebugRegWrite
);

  // Fetch stage signals
  // Decode stage signals
  logic [P.XLEN-1:0] R1D, R2D;                       // Read data from Rs1 (RD1), Rs2 (RD2)
  logic [P.XLEN-1:0] ImmExtD;                        // Extended immediate in Decode stage
  // Execute stage signals
  logic [P.XLEN-1:0] R1E, R2E;                       // Source operands read from register file
  logic [P.XLEN-1:0] ImmExtE;                        // Extended immediate in Execute stage
  logic [P.XLEN-1:0] SrcAE, SrcBE;                   // ALU operands
  logic [P.XLEN-1:0] ALUResultE, AltResultE, IEUResultE; // ALU result, Alternative result (ImmExtE or PC+4), result of execution stage
  // Memory stage signals
  logic [P.XLEN-1:0] IEUResultM;                     // Result from execution stage
  logic [P.XLEN-1:0] IFResultM;                      // Result from either IEU or single-cycle FPU op writing an integer register
  // Writeback stage signals
  logic [P.XLEN-1:0] SCResultW;                      // Store Conditional result
  logic [P.XLEN-1:0] ResultW;                        // Result to write to register file
  logic [P.XLEN-1:0] IFResultW;                      // Result from either IEU or single-cycle FPU op writing an integer register
  logic [P.XLEN-1:0] IFCvtResultW;                   // Result from IEU, signle-cycle FPU op, or 2-cycle FCVT float to int
  logic [P.XLEN-1:0] MulDivResultW;                  // Multiply always comes from MDU.  Divide could come from MDU or FPU (when using fdivsqrt for integer division)

  // Debug mux signals
  logic [4:0]        Rs1, Rd;
  logic              RegWrite;
  logic [P.XLEN-1:0] Result;

  // Debug Spec muxing of regfile inputs
  if (P.DEBUG_SUPPORTED) begin
    mux2 #(5) rfreadaddrmux (Rs1D, DebugRegAddr[4:0], DebugGPREnable, Rs1);
    mux2 #(5) rfwriteaddrmux (RdW, DebugRegAddr[4:0], DebugGPREnable, Rd);
    mux2 #(P.XLEN) rfwdatamux (ResultW, DebugRegWDATA, DebugGPREnable, Result);
    assign RegWrite = DebugMode ? DebugRegWrite & DebugGPREnable : RegWriteW;
    // Return regfile read to Debug Module
    assign DebugR1D = R1D;
  end else begin
    assign Rs1 = Rs1D;
    assign Rd = RdW;
    assign Result = ResultW;
    assign RegWrite = RegWriteW;
    assign DebugR1D = '0;
  end

  // Decode stage
  regfile #(P.XLEN, P.E_SUPPORTED) regf(clk, reset, RegWrite, Rs1, Rs2D, Rd, Result, R1D, R2D);
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
  alu   #(P)       alu(SrcAE, SrcBE, W64E, UW64E, SubArithE, ALUSelectE, BSelectE, ZBBSelectE, Funct3E, Funct7E, Rs2E, BALUControlE, BMUActiveE, CZeroE, ALUResultE, IEUAdrE);
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
