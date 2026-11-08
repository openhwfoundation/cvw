///////////////////////////////////////////
// bpred.sv
//
// Written: Rose Thomposn rose@rosethompson.net
// Created: 12 February 2021
// Modified: 19 January 2023
//
// Purpose: Branch direction prediction and jump/branch target prediction.
//          Prediction made during the fetch stage and corrected in the execution stage.
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

`include "BranchPredictorType.vh"


module bpred import cvw::*;  #(parameter cvw_t P) (
  input  logic              clk, reset,
  input  logic              StallF, StallD, StallE, StallM, StallW,
  input  logic              FlushD, FlushE, FlushM, FlushW,
  // Fetch stage
  // the prediction
  input  logic [31:0]       InstrD,                    // Decompressed decode stage instruction. Used to decode instruction class
  input  logic [P.XLEN-1:0] PCNextF,                   // Next Fetch Address
  input  logic [P.XLEN-1:0] PCNextSeqF,                // Sequential next PC: after slot 0, or after both slots when they issue together
  output logic [P.XLEN-1:0] PC1NextF,                  // Branch Predictor predicted or corrected fetch address on misprediction
  output logic              BPPCSrcF,                  // Predicted taken, so the next PC is the predicted target rather than sequential
  output logic [P.XLEN-1:0] NextValidPCE,              // Address of next valid instruction after the instruction in the Memory stage

  // Update Predictor
  input  logic [P.XLEN-1:0] PCF,                       // Fetch stage instruction address
  input  logic [P.XLEN-1:0] PCD,                       // Decode stage instruction address. Also the address the branch predictor took
  input  logic [P.XLEN-1:0] PCE,                       // Execution stage instruction address
  input  logic [P.XLEN-1:0] PCM,                       // Memory stage instruction address

  input  logic [31:0]       PostSpillInstrRawF,        // Instruction

  // Branch and jump outcome
  input  logic              InstrValidD, InstrValidE,
  input  logic              Commit1E,                  // Slot 1 will commit alongside slot 0, so the bundle is two instructions long
  input  logic [P.XLEN-1:0] PCLink1E,                  // ... and this is the address just past slot 1, where the bundle then ends
  input  logic              BranchD, BranchE,
  input  logic              JumpD, JumpE,
  input  logic              PCSrcE,                    // Execution stage branch is taken
  input  logic [P.XLEN-1:0] IEUAdrE,                   // The branch/jump target address
  input  logic [P.XLEN-1:0] IEUAdrM,                   // The branch/jump target address
  input  logic [P.XLEN-1:0] PCLinkE,                   // The address following the branch instruction. (AKA Fall through address)
  input  logic              LateBrM,                   // The branch in Memory was resolved there (ieu.sv late branch) ...
  input  logic              LateBrTakenM,              // ... and this is its real direction; PCSrcE was only the assumed one
  output logic [3:0]        IClassM,                   // The valid instruction class. 1-hot encoded as {call, return, jump, branch}

  // Report branch prediction status
  output logic              BPWrongE,                  // Prediction is wrong
  output logic              BPWrongM,                  // Prediction is wrong
  output logic              BPDirWrongM,               // Prediction direction is wrong
  output logic              BTAWrongM,                 // Prediction target wrong
  output logic              RASPredPCWrongM,           // RAS prediction is wrong
  output logic              IClassWrongM               // Class prediction is wrong
);

  logic [1:0]              BPDirF;

  logic                    BPDirWrongE;
  logic [P.XLEN-1:0]       BPBTAF, RASPCF;

  logic [P.XLEN-1:0]       BPPCF;
  logic [P.XLEN-1:0]       PC0NextF;
  logic [P.XLEN-1:0]       PCCorrectE;
  logic [P.XLEN-1:0]       PCFallThroughE;  // Address after everything that issued in Execute

  logic                    RASTargetWrongE;

  logic                    BTBCallF, BTBReturnF, BTBJumpF, BTBBranchF;
  logic                    BPBranchF, BPJumpF, BPReturnF, BPCallF;
  logic                    BPBranchD, BPJumpD, BPReturnD, BPCallD;
  logic                    ReturnD, CallD;
  logic                    ReturnE, CallE;
  logic                    BranchM, JumpM, ReturnM, CallM;
  logic                    BranchW, JumpW, ReturnW, CallW;
  logic                    BPReturnWrongD;
  logic                    BPBTAWrongM;
  logic                    PCSrcM;

  // Part 1 branch direction prediction
  if (P.BPRED_TYPE == `BP_TWOBIT) begin : Predictor
    twoBitPredictor #(P, P.XLEN, P.BPRED_SIZE) DirPredictor(.clk, .reset, .StallF, .StallD, .StallE, .StallM, .StallW,
      .FlushD, .FlushE, .FlushM, .FlushW,
      .PCNextF, .PCM, .BPDirF, .BPDirWrongE,
      .BranchE, .BranchM, .PCSrcE);

  end else if (P.BPRED_TYPE == `BP_GSHARE) begin : Predictor
    gshare #(P, P.XLEN, P.BPRED_SIZE) DirPredictor(.clk, .reset, .StallF, .StallD, .StallE, .StallM, .StallW, .FlushD, .FlushE, .FlushM, .FlushW,
      .PCNextF, .PCF, .PCD, .PCE, .PCM, .BPDirF, .BPDirWrongE,
      .BPBranchF, .BranchD, .BranchE, .BranchM, .BranchW,
      .PCSrcE, .LateBrM, .LateBrTakenM);

  end else if (P.BPRED_TYPE == `BP_GLOBAL) begin : Predictor
    gshare #(P, P.XLEN, P.BPRED_SIZE, 0) DirPredictor(.clk, .reset, .StallF, .StallD, .StallE, .StallM, .StallW, .FlushD, .FlushE, .FlushM, .FlushW,
      .PCNextF, .PCF, .PCD, .PCE, .PCM, .BPDirF, .BPDirWrongE,
      .BPBranchF, .BranchD, .BranchE, .BranchM, .BranchW,
      .PCSrcE, .LateBrM, .LateBrTakenM);

  end else if (P.BPRED_TYPE == `BP_GSHARE_BASIC) begin : Predictor
    gsharebasic #(P, P.XLEN, P.BPRED_SIZE) DirPredictor(.clk, .reset, .StallF, .StallD, .StallE, .StallM, .StallW, .FlushD, .FlushE, .FlushM, .FlushW,
      .PCNextF, .PCM, .BPDirF, .BPDirWrongE,
      .BranchE, .BranchM, .PCSrcE);

  end else if (P.BPRED_TYPE == `BP_GLOBAL_BASIC) begin : Predictor
    gsharebasic #(P, P.XLEN, P.BPRED_SIZE, 0) DirPredictor(.clk, .reset, .StallF, .StallD, .StallE, .StallM, .StallW, .FlushD, .FlushE, .FlushM, .FlushW,
      .PCNextF, .PCM, .BPDirF, .BPDirWrongE,
      .BranchE, .BranchM, .PCSrcE);

  end else if (P.BPRED_TYPE == `BP_LOCAL_BASIC) begin : Predictor
    localbpbasic #(P, P.XLEN, P.BPRED_NUM_LHR, P.BPRED_SIZE) DirPredictor(.clk, .reset,
      .StallF, .StallD, .StallE, .StallM, .StallW, .FlushD, .FlushE, .FlushM, .FlushW,
      .PCNextF, .PCM, .BPDirF, .BPDirWrongE,
      .BranchE, .BranchM, .PCSrcE);
  end else if (P.BPRED_TYPE == `BP_LOCAL_AHEAD) begin : Predictor
    localaheadbp #(P, P.XLEN, P.BPRED_NUM_LHR, P.BPRED_SIZE) DirPredictor(.clk, .reset,
      .StallF, .StallD, .StallE, .StallM, .StallW, .FlushD, .FlushE, .FlushM, .FlushW,
      .PCNextF, .PCM, .BPDirD(BPDirF), .BPDirWrongE,
      .BranchE, .BranchM, .PCSrcE);
  end else if (P.BPRED_TYPE == `BP_LOCAL_REPAIR) begin : Predictor
    localrepairbp #(P, P.XLEN, P.BPRED_NUM_LHR, P.BPRED_SIZE) DirPredictor(.clk, .reset,
      .StallF, .StallD, .StallE, .StallM, .StallW, .FlushD, .FlushE, .FlushM, .FlushW,
      .PCNextF, .PCE, .PCM, .BPDirD(BPDirF), .BPDirWrongE,
      .BranchD, .BranchE, .BranchM, .PCSrcE);
  end

  flopenrc #(1) PCSrcMReg(clk, reset, FlushM, ~StallM, PCSrcE, PCSrcM);

  // Part 2 Branch target address prediction
  // BTB contains target address for all CFI

  btb #(P, P.BTB_SIZE)
    TargetPredictor(.clk, .reset, .StallF, .StallD, .StallE, .StallM, .StallW, .FlushD, .FlushE, .FlushM, .FlushW,
      .PCNextF, .PCF, .PCD, .PCE, .PCM,
      .BPBTAF,
      .BTBIClassF({BTBCallF, BTBReturnF, BTBJumpF, BTBBranchF}),
      .BPBTAWrongM,
      .IClassWrongM,
      .IEUAdrE, .IEUAdrM,
      .IClassD({CallD, ReturnD, JumpD, BranchD}),
      .IClassE({CallE, ReturnE, JumpE, BranchE}),
      .IClassM({CallM, ReturnM, JumpM, BranchM}),
      .IClassW({CallW, ReturnW, JumpW, BranchW}));

  icpred #(P, P.INSTR_CLASS_PRED) icpred(.clk, .reset, .StallD, .StallE, .StallM, .StallW, .FlushD, .FlushE, .FlushM,
    .PostSpillInstrRawF, .InstrD, .BranchD, .BranchE, .JumpD, .JumpE, .BranchM, .BranchW, .JumpM, .JumpW,
    .CallD, .CallE, .CallM, .CallW, .ReturnD, .ReturnE, .ReturnM, .ReturnW, .BTBCallF, .BTBReturnF, .BTBJumpF,
    .BTBBranchF, .BPCallF, .BPReturnF, .BPJumpF, .BPBranchF, .IClassWrongM, .BPReturnWrongD, .BPReturnD);

  // Part 3 RAS
  // A call pushes the address after itself.  That is the bundle's fall-through, whichever slot holds the
  // call: a slot 0 call never pairs, so the bundle ends at PCLinkE, and a slot 1 call ends it at PCLink1E.
  //   0x100 jal ra,f                       pushes 0x104
  //   0x100 addi a0,a0,1 ; 0x104 jal ra,f   pushes 0x108
  RASPredictor #(P) RASPredictor(.clk, .reset, .StallD, .StallE, .StallM, .FlushD, .FlushE, .FlushM,
    .BPReturnF, .ReturnD, .ReturnE, .CallE,
    .BPReturnWrongD, .BPReturnD, .RASPCF, .PCLinkE(PCFallThroughE));

  // Check the prediction
  // if it is a CFI then check if the next instruction address (PCD) matches the branch's target or fallthrough address.
  // if the class prediction is wrong a regular instruction may have been predicted as a taken branch
  // this will result in PCD not being equal to the fall through address PCLinkE (PCE+4).
  // The next instruction is always valid as no other flush would occur at the same time as the branch and not
  // also flush the branch.  This will change in a superscalar cpu.
  // branch is wrong only if the PC does not match and both the Decode and Fetch stages have valid instructions.
  assign BPWrongE = (PCCorrectE != PCD) & InstrValidE & InstrValidD;
  flopenrc #(1) BPWrongMReg(clk, reset, FlushM, ~StallM, BPWrongE, BPWrongM);

  // Output the predicted PC or corrected PC on misprediction.
  assign BPPCSrcF = (BPBranchF & BPDirF[1]) | BPJumpF;
  mux2 #(P.XLEN) pcmuxbp(BPBTAF, RASPCF, BPReturnF, BPPCF);
  // Selects the BP or PC+2/4.
  mux2 #(P.XLEN) pcmux0(PCNextSeqF, BPPCF, BPPCSrcF, PC0NextF);
  // If the prediction is wrong select the correct address.
  mux2 #(P.XLEN) pcmux1(PC0NextF, PCCorrectE, BPWrongE, PC1NextF);
  // Correct branch/jump target.  When not taken, execution continues after everything that issued in
  // Execute, which is one instruction past PCLinkE when slot 1 issued alongside slot 0.  Without
  // this, BPWrongE fires on every dual-issue cycle and redirects to slot 1, which has already
  // committed, so it would execute twice.
  // PCLinkE itself must not change: it is also the address a slot 0 jal writes to rd.
  // The bundle is two instructions long only if slot 1 actually commits.  When slot 1 is killed --
  // because slot 0 turned out to be a taken branch -- the fall-through is slot 1's own address, so
  // this comparison against PCD makes BPWrongE fire and redirect there, re-executing it as slot 0.
  assign PCFallThroughE = Commit1E ? PCLink1E : PCLinkE;
  mux2 #(P.XLEN) pccorrectemux(PCFallThroughE, IEUAdrE, PCSrcE, PCCorrectE);

  // If the fence/csrw was predicted as a taken branch then we select PCF, rather than PCE.
  // Effectively this is PCM+4 or the non-existent PCLinkM
  if (P.INSTR_CLASS_PRED) mux2 #(P.XLEN) pcmuxBPWrongInvalidateFlush(PCE, PCF, BPWrongM, NextValidPCE);
  else assign NextValidPCE = PCE;

  if (P.ZIHPM_SUPPORTED) begin
    logic [P.XLEN-1:0]       RASPCD, RASPCE;
    logic                    RASPredPCWrongE;
    // performance counters
    // 1. class         (class wrong / minstret) (IClassWrongM / csr)                    // Correct now
    // 2. target btb    (btb target wrong / class[0,1,3])  (btb target wrong / (br + j + jal)
    // 3. target ras    (ras target wrong / class[2])
    // 4. direction     (br dir wrong / class[0])

    // Unfortunately we can't use PCD to infer the correctness of the BTB or RAS because the class prediction
    // could be wrong or the fall through address selected for branch predict not taken.
    // By pipelining the BTB's PC and RAS address through the pipeline we can measure the accuracy of
    // both without the above inaccuracies.
    assign RASPredPCWrongE = (RASPCE != IEUAdrE) & ReturnE & PCSrcE;

    flopenrc #(P.XLEN) RASTargetDReg(clk, reset, FlushD, ~StallD, RASPCF, RASPCD);
    flopenrc #(P.XLEN) RASTargetEReg(clk, reset, FlushE, ~StallE, RASPCD, RASPCE);
    flopenrc #(2) BPPredWrongRegM(clk, reset, FlushM, ~StallM,
      {BPDirWrongE, RASPredPCWrongE},
      {BPDirWrongM, RASPredPCWrongM});

    assign BTAWrongM = BPBTAWrongM & PCSrcM;

  end else begin
    assign {BTAWrongM, RASPredPCWrongM, BPDirWrongM} = 0;
  end

  assign IClassM = {CallM, ReturnM, JumpM, BranchM};

endmodule
