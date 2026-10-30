///////////////////////////////////////////
// icpred.sv
//
// Written:  Rose Thompson rose@rosethompson.net 26 February 2023
// Modified: David Harris
//
// Purpose: Instruction class predecoder.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2023-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module icpred import cvw::*; #(parameter cvw_t P,
                               parameter INSTR_CLASS_PRED = 1) (
  input  logic             clk, reset,
  input  logic             StallD, StallE, StallM, StallW,             // Stall Decode, Execute, Memory, Writeback stages
  input  logic             FlushD, FlushE, FlushM,                     // Flush Decode, Execute, Memory stages
  input  logic [31:0]      PostSpillInstrRawF, InstrD,                 // Fetched instruction, instruction in Decode stage
  input  logic             BranchD, BranchE,                           // Branch instruction in Decode, Execute stages
  input  logic             JumpD, JumpE,                               // Jump instruction in Decode, Execute stages
  output logic             BranchM, BranchW,                           // Branch instruction in Memory, Writeback stages
  output logic             JumpM, JumpW,                               // Jump instruction in Memory, Writeback stages
  output logic             CallD, CallE, CallM, CallW,                 // Call instruction in Decode, Execute, Memory, Writeback stages
  output logic             ReturnD, ReturnE, ReturnM, ReturnW,         // Return instruction in Decode, Execute, Memory, Writeback stages
  input  logic             BTBCallF, BTBReturnF, BTBJumpF, BTBBranchF, // Instruction class predicted by BTB
  output logic             BPCallF, BPReturnF, BPJumpF, BPBranchF,     // Predicted instruction class in Fetch stage
  output logic             IClassWrongM, BPReturnWrongD,               // Instruction class prediction was wrong, return prediction was wrong in Decode stage
  output logic             BPReturnD                                   // Instruction in Decode stage was predicted to be a return
);

  logic                    IClassWrongD;
  logic                    BPBranchD, BPJumpD, BPCallD;
  logic                    IClassWrongE;

  if (!INSTR_CLASS_PRED) begin : DirectClassDecode
    // This section is mainly for testing, verification, and PPA comparison.
    // An alternative to using the BTB to store the instruction class is to partially decode
    // the instructions in the Fetch stage into, Call, Return, Jump, and Branch instructions.
    // This logic is not described in the textbook as of 23 February 2023.
    localparam logic [6:0] OP_JALR   = 7'h67;
    localparam logic [6:0] OP_JAL    = 7'h6F;
    localparam logic [6:0] OP_BRANCH = 7'h63;
    // Compressed opcodes {op, funct3}
    localparam logic [4:0] C_JAL     = 5'h09; // c.jal (RV32 only)
    localparam logic [4:0] C_J       = 5'h0d; // c.j
    localparam logic [4:0] C_JR      = 5'h14; // c.jr/c.jalr when rs2 = 0 and rs1 != 0
    localparam logic [3:0] C_BRANCH  = 4'h7;  // c.beqz/c.bnez: {op, funct3[2:1]}
    logic     cjal, cj, cjr, cjalr, CJumpF, CBranchF;
    logic     NCJumpF, NCBranchF;

    if (P.ZCA_SUPPORTED) begin
      logic [4:0] CompressedOpcF;
      assign CompressedOpcF = {PostSpillInstrRawF[1:0], PostSpillInstrRawF[15:13]};
      assign cjal = CompressedOpcF == C_JAL & P.XLEN == 32;
      assign cj = CompressedOpcF == C_J;
      assign cjr = CompressedOpcF == C_JR & ~PostSpillInstrRawF[12] & PostSpillInstrRawF[6:2] == 5'b0 & PostSpillInstrRawF[11:7] != 5'b0;
      assign cjalr = CompressedOpcF == C_JR & PostSpillInstrRawF[12] & PostSpillInstrRawF[6:2] == 5'b0 & PostSpillInstrRawF[11:7] != 5'b0;
      assign CJumpF = cjal | cj | cjr | cjalr;
      assign CBranchF = CompressedOpcF[4:1] == C_BRANCH;
    end else begin
      assign {cjal, cj, cjr, cjalr, CJumpF, CBranchF} = '0;
    end

    assign NCJumpF = PostSpillInstrRawF[6:0] == OP_JALR | PostSpillInstrRawF[6:0] == OP_JAL;
    assign NCBranchF = PostSpillInstrRawF[6:0] == OP_BRANCH;

    assign BPBranchF = NCBranchF | (P.ZCA_SUPPORTED & CBranchF);
    assign BPJumpF = NCJumpF | (P.ZCA_SUPPORTED & (CJumpF));
    assign BPReturnF = (PostSpillInstrRawF[6:0] == OP_JALR & (PostSpillInstrRawF[19:15] & 5'h1B) == 5'h01 & PostSpillInstrRawF[11:7] == 5'b0) | // return is a jalr to ra or x5
        (P.ZCA_SUPPORTED & cjr & ((PostSpillInstrRawF[11:7] & 5'h1B) == 5'h01));

    assign BPCallF = (NCJumpF & (PostSpillInstrRawF[11:07] & 5'h1B) == 5'h01) | // call(r) must link to ra or x5
        (P.ZCA_SUPPORTED & (cjal | (cjalr & (PostSpillInstrRawF[11:7] & 5'h1b) == 5'h01)));

  end else begin
    // This section connects the BTB's instruction class prediction.
    assign {BPCallF, BPReturnF, BPJumpF, BPBranchF} = {BTBCallF, BTBReturnF, BTBJumpF, BTBBranchF};
  end

  assign ReturnD = JumpD & ~InstrD[3] & (InstrD[19:15] & 5'h1B) == 5'h01; // return is a jalr (not jal, whose [19:15] are offset bits) to ra or x5
  assign CallD = JumpD & (InstrD[11:7] & 5'h1B) == 5'h01; // call(r) must link to ra or x5

  flopenrc #(2) InstrClassRegE(clk, reset, FlushE, ~StallE, {CallD, ReturnD}, {CallE, ReturnE});
  flopenrc #(4) InstrClassRegM(clk, reset, FlushM, ~StallM, {CallE, ReturnE, JumpE, BranchE}, {CallM, ReturnM, JumpM, BranchM});
  flopenrc #(4) InstrClassRegW(clk, reset, FlushM, ~StallW, {CallM, ReturnM, JumpM, BranchM}, {CallW, ReturnW, JumpW, BranchW});

  // branch predictor
  flopenrc #(1) BPClassWrongRegM(clk, reset, FlushM, ~StallM, IClassWrongE, IClassWrongM);
  flopenrc #(1) WrongInstrClassRegE(clk, reset, FlushE, ~StallE, IClassWrongD, IClassWrongE);

  // pipeline the predicted class
  flopenrc #(4) PredInstrClassRegD(clk, reset, FlushD, ~StallD, {BPCallF, BPReturnF, BPJumpF, BPBranchF}, {BPCallD, BPReturnD, BPJumpD, BPBranchD});

  // branch class prediction wrong.
  assign IClassWrongD = |({BPCallD, BPReturnD, BPJumpD, BPBranchD} ^ {CallD, ReturnD, JumpD, BranchD});
  assign BPReturnWrongD = BPReturnD ^ ReturnD;

endmodule
