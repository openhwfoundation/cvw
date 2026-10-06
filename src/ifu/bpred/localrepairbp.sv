///////////////////////////////////////////
// localrepairbp
//
// Written: Rose Thompson
// Email: rose@rosethompson.net
// Created: 15 April 2023
//
// Purpose: Local history branch predictor with speculation and repair using CBH.
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

module localrepairbp import cvw::*; #(parameter cvw_t P,
                                      parameter XLEN,
                       parameter m = 6, // 2^m = number of local history branches
                       parameter k = 10) ( // number of past branches stored
  input logic             clk,
  input logic             reset,
  input logic             StallF, StallD, StallE, StallM, StallW,
  input logic             FlushD, FlushE, FlushM, FlushW,
  output logic [1:0]      BPDirD,
  output logic            BPDirWrongE,
  // update
  input logic [XLEN-1:0] PCNextF, PCE, PCM,
  input logic             BranchD, BranchE, BranchM, PCSrcE
);

  //logic [1:0]             BPDirD, BPDirE;
  logic [1:0]             BPDirE;
  logic [1:0]             BPDirM;
  logic [1:0]             NewBPDirE, NewBPDirM, NewBPDirW;

  logic [k-1:0]           LHRF, LHRD, LHRE, LHRM, LHRW, LHRNextF;
  logic [k-1:0]           LHRNextW;
  logic                   PCSrcM;
  logic [2**m-1:0][k-1:0] LHRArray;
  logic [m-1:0]           IndexLHRNextF, IndexLHRM;
  logic [XLEN-1:0]       PCW;

  logic [k-1:0]           LHRCommittedF, LHRSpeculativeF;
  logic [m-1:0]           IndexLHRD;
  logic [k-1:0]           LHRNextE;
  logic                   SpeculativeFlushedF;


  ram2p1r1wbe #(.USE_SRAM(P.USE_SRAM), .DEPTH(2**k), .WIDTH(2)) PHT(.clk(clk),
    .ce1(~StallD), .ce2(~StallW & ~FlushW),
    .ra1(LHRF),
    .rd1(BPDirD),
    .wa2(LHRW),
    .wd2(NewBPDirW),
    .we2(BranchM),
    .bwe2(1'b1));

  //flopenrc #(2) PredictionRegD(clk, reset,  FlushD, ~StallD, BPDirF, BPDirD);
  flopenrc #(2) PredictionRegE(clk, reset,  FlushE, ~StallE, BPDirD, BPDirE);
  flopenrc #(2) PredictionRegM(clk, reset,  FlushM, ~StallM, BPDirE, BPDirM);

  satCounter2 BPDirUpdateE(.BrDir(PCSrcE), .OldState(BPDirM), .NewState(NewBPDirM));
  //flopenrc #(2) NewPredictionRegM(clk, reset,  FlushM, ~StallM, NewBPDirE, NewBPDirM);
  flopenrc #(2) NewPredictionRegW(clk, reset,  FlushW, ~StallW, NewBPDirM, NewBPDirW);

  assign BPDirWrongE = PCSrcE != BPDirM[1] & BranchE;

  // This is the main difference between global and local history basic implementations. In global,
  // the ghr wraps back into itself directly without
  // being pipelined.  I.E. GHR is not read in F and then pipelined to M where it is updated.  Instead
  // GHR is both read and update in M.  GHR is still pipelined so that the PHT is updated with the correct
  // GHR.  Local history in contrast must pipeline the specific history register read during F and then update
  // that same one in M.  This implementation does not forward if a branch matches in the D, E, or M stages.
  assign LHRNextW = BranchM ? {PCSrcM, LHRW[k-1:1]} : LHRW;

  // this is local history
  assign IndexLHRM = {PCW[m+1] ^ PCW[1], PCW[m:2]};
  assign IndexLHRNextF = {PCNextF[m+1] ^ PCNextF[1], PCNextF[m:2]};

  ram2p1r1wbe #(.USE_SRAM(P.USE_SRAM), .DEPTH(2**m), .WIDTH(k)) BHT(.clk(clk),
    .ce1(~StallF), .ce2(~StallW & ~FlushW),
    .ra1(IndexLHRNextF),
    .rd1(LHRCommittedF),
    .wa2(IndexLHRM),
    .wd2(LHRNextW),
    .we2(BranchM),
    .bwe2('1));

  assign IndexLHRD = {PCE[m+1] ^ PCE[1], PCE[m:2]};
  assign LHRNextE = BranchD ? {BPDirD[1], LHRE[k-1:1]} : LHRE;
  // RT: TODO active research: replace with a small CAM, quantify benefit
  ram2p1r1wbe #(.USE_SRAM(P.USE_SRAM), .DEPTH(2**m), .WIDTH(k)) SHB(.clk(clk),
    .ce1(~StallF), .ce2(~StallE & ~FlushE),
    .ra1(IndexLHRNextF),
    .rd1(LHRSpeculativeF),
    .wa2(IndexLHRD),
    .wd2(LHRNextE),
    .we2(BranchD),
    .bwe2('1));
  // RT: TODO active research: replace with small CAM, quantify benefit
  logic [2**m-1:0]        FlushedBits;
  always_ff @(posedge clk) begin // Valid bit array,
    SpeculativeFlushedF <= FlushedBits[IndexLHRNextF];
    if (reset | FlushD) FlushedBits        <= '1;
    if(BranchD & ~StallE & ~FlushE) begin
      FlushedBits[IndexLHRD] <= 1'b0;
    end
  end

  //assign SpeculativeFlushedF = '1;
  mux2 #(k) LHRMux(LHRSpeculativeF, LHRCommittedF, SpeculativeFlushedF, LHRF);

  flopenrc #(1) PCSrcMReg(clk, reset, FlushM, ~StallM, PCSrcE, PCSrcM);

  //flopenrc #(k) LHRFReg(clk, reset, FlushD, ~StallF, LHRNextF, LHRF);
  //assign LHRF = LHRNextF;
  flopenrc #(k) LHRDReg(clk, reset, FlushD, ~StallD, LHRF, LHRD);
  flopenrc #(k) LHREReg(clk, reset, FlushE, ~StallE, LHRD, LHRE);
  flopenrc #(k) LHRMReg(clk, reset, FlushM, ~StallM, LHRE, LHRM);
  flopenrc #(k) LHRWReg(clk, reset, FlushW, ~StallW, LHRM, LHRW);

  flopenr #(XLEN) PCWReg(clk, reset, ~StallW, PCM, PCW);

endmodule
