///////////////////////////////////////////
// twoBitPredictor.sv
//
// Written: Rose Thomposn
// Email: rose@rosethompson.net
// Created: February 14, 2021
// Modified:
//
// Purpose: 2 bit saturating counter predictor with parameterized table depth.
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

module twoBitPredictor import cvw::*; #(parameter cvw_t P, parameter XLEN,
                         parameter k = 10) (
  input  logic             clk,
  input  logic             reset,
  input  logic             StallF, StallD, StallE, StallM, StallW,
  input  logic             FlushD, FlushE, FlushM, FlushW,
  input  logic [XLEN-1:0]  PCNextF, PCM,
  output logic [1:0]       BPDirF,
  output logic             BPDirWrongE,
  input  logic             BranchE, BranchM,
  input  logic             PCSrcE
);

  logic [k-1:0]            IndexNextF, IndexM;
  logic [1:0]              PredictionMemory;
  logic                    DoForwarding, DoForwardingF;
  logic [1:0]              BPDirD, BPDirE;
  logic [1:0]              NewBPDirE, NewBPDirM;

  // hashing function for indexing the PC
  // We have k bits to index, but XLEN bits as the input.
  // bit 0 is always 0, bit 1 is 0 if using 4 byte instructions, but is not always 0 if
  // using compressed instructions.  XOR bit 1 with the MSB of index.
  assign IndexNextF = {PCNextF[k+1] ^ PCNextF[1], PCNextF[k:2]};
  assign IndexM = {PCM[k+1] ^ PCM[1], PCM[k:2]};


  ram2p1r1wbe #(.USE_SRAM(P.USE_SRAM), .DEPTH(2**k), .WIDTH(2)) BHT(.clk(clk),
    .ce1(~StallF), .ce2(~StallW & ~FlushW),
    .ra1(IndexNextF),
    .rd1(BPDirF),
    .wa2(IndexM),
    .wd2(NewBPDirM),
    .we2(BranchM),
    .bwe2(1'b1));

  flopenrc #(2) PredictionRegD(clk, reset,  FlushD, ~StallD, BPDirF, BPDirD);
  flopenrc #(2) PredictionRegE(clk, reset,  FlushE, ~StallE, BPDirD, BPDirE);

  assign BPDirWrongE = PCSrcE != BPDirE[1] & BranchE;

  satCounter2 BPDirUpdateE(.BrDir(PCSrcE), .OldState(BPDirE), .NewState(NewBPDirE));
  flopenrc #(2) NewPredictionRegM(clk, reset,  FlushM, ~StallM, NewBPDirE, NewBPDirM);


endmodule
