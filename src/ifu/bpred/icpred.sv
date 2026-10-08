///////////////////////////////////////////
// icpred.sv
//
// Written: Rose Thomposn rose@rosethompson.net
// Created: February 26, 2023
// Modified: February 26, 2023
//
// Purpose: Partial decode of instructions into control flow instructions (cfi)P
//          Call, Return, Jump, and Branch
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

module icpred import cvw::*;  #(parameter cvw_t P,
                                parameter INSTR_CLASS_PRED = 1)(
  input  logic             clk, reset,
  input  logic             StallD, StallE, StallM, StallW,
  input  logic             FlushD, FlushE, FlushM,
  input  logic [31:0]      PostSpillInstrRawF, InstrD,        // Instruction
  input  logic             BranchD, BranchE,
  input  logic             JumpD, JumpE,
  output logic             BranchM, BranchW,
  output logic             JumpM, JumpW,
  output logic             CallD, CallE, CallM, CallW,
  output logic             ReturnD, ReturnE, ReturnM, ReturnW,
  input  logic             BTBCallF, BTBReturnF, BTBJumpF, BTBBranchF,
  output logic             BPCallF, BPReturnF, BPJumpF, BPBranchF,
  output logic             IClassWrongM, BPReturnWrongD
);

  logic                    IClassWrongD;
  logic                    BPBranchD, BPJumpD, BPReturnD, BPCallD;
  logic                    IClassWrongE;

  if (!INSTR_CLASS_PRED) begin : DirectClassDecode
    // This section is mainly for testing, verification, and PPA comparison.
    // An alternative to using the BTB to store the instruction class is to partially decode
    // the instructions in the Fetch stage into, Call, Return, Jump, and Branch instructions.
    // This logic is not described in the text book as of 23 February 2023.
    logic     cjal, cj, cjr, cjalr, CJumpF, CBranchF;
    logic     NCJumpF, NCBranchF;

    if(P.ZCA_SUPPORTED) begin
      logic [4:0] CompressedOpcF;
      assign CompressedOpcF = {PostSpillInstrRawF[1:0], PostSpillInstrRawF[15:13]};
      assign cjal = CompressedOpcF == 5'h09 & P.XLEN == 32;
      assign cj = CompressedOpcF == 5'h0d;
      assign cjr = CompressedOpcF == 5'h14 & ~PostSpillInstrRawF[12] & PostSpillInstrRawF[6:2] == 5'b0 & PostSpillInstrRawF[11:7] != 5'b0;
      assign cjalr = CompressedOpcF == 5'h14 & PostSpillInstrRawF[12] & PostSpillInstrRawF[6:2] == 5'b0 & PostSpillInstrRawF[11:7] != 5'b0;
      assign CJumpF = cjal | cj | cjr | cjalr;
      assign CBranchF = CompressedOpcF[4:1] == 4'h7;
    end else begin
      assign {cjal, cj, cjr, cjalr, CJumpF, CBranchF} = '0;
    end

    assign NCJumpF = PostSpillInstrRawF[6:0] == 7'h67 | PostSpillInstrRawF[6:0] == 7'h6F;
    assign NCBranchF = PostSpillInstrRawF[6:0] == 7'h63;

    assign BPBranchF = NCBranchF | (P.ZCA_SUPPORTED & CBranchF);
    assign BPJumpF = NCJumpF | (P.ZCA_SUPPORTED & (CJumpF));
    assign BPReturnF = (NCJumpF & (PostSpillInstrRawF[19:15] & 5'h1B) == 5'h01 & PostSpillInstrRawF[11:7] == 5'b0) | // return must return to ra or r5
        (P.ZCA_SUPPORTED & cjr & ((PostSpillInstrRawF[11:7] & 5'h1B) == 5'h01));

    assign BPCallF = (NCJumpF & (PostSpillInstrRawF[11:07] & 5'h1B) == 5'h01) | // call(r) must link to ra or x5
        (P.ZCA_SUPPORTED & (cjal | (cjalr & (PostSpillInstrRawF[11:7] & 5'h1b) == 5'h01)));

  end else begin
    // This section connects the BTB's instruction class prediction.
    assign {BPCallF, BPReturnF, BPJumpF, BPBranchF} = {BTBCallF, BTBReturnF, BTBJumpF, BTBBranchF};
  end

  assign ReturnD = JumpD & (InstrD[19:15] & 5'h1B) == 5'h01; // returnurn must returnurn to ra or x5
  assign CallD = JumpD & (InstrD[11:7] & 5'h1B) == 5'h01; // call(r) must link to ra or x5

  flopenrc #(2) InstrClassRegE(clk, reset,  FlushE, ~StallE, {CallD, ReturnD}, {CallE, ReturnE});
  flopenrc #(4) InstrClassRegM(clk, reset,  FlushM, ~StallM, {CallE, ReturnE, JumpE, BranchE}, {CallM, ReturnM, JumpM, BranchM});
  flopenrc #(4) InstrClassRegW(clk, reset,  FlushM, ~StallW, {CallM, ReturnM, JumpM, BranchM}, {CallW, ReturnW, JumpW, BranchW});

  // branch predictor
  flopenrc #(1) BPClassWrongRegM(clk, reset, FlushM, ~StallM, IClassWrongE, IClassWrongM);
  flopenrc #(1) WrongInstrClassRegE(clk, reset, FlushE, ~StallE, IClassWrongD, IClassWrongE);

  // pipeline the predicted class
  flopenrc #(4) PredInstrClassRegD(clk, reset, FlushD, ~StallD, {BPCallF, BPReturnF, BPJumpF, BPBranchF}, {BPCallD, BPReturnD, BPJumpD, BPBranchD});

  // branch class prediction wrong.
  assign IClassWrongD = |({BPCallD, BPReturnD, BPJumpD, BPBranchD} ^ {CallD, ReturnD, JumpD, BranchD});
  assign BPReturnWrongD = BPReturnD ^ ReturnD;

endmodule
