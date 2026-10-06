///////////////////////////////////////////
// btb.sv
//
// Written: Rose Thompson rose@rosethompson.net
// Created: February 15, 2021
// Modified: 24 January 2023
//
// Purpose: Branch Target Buffer (BTB). The BTB predicts the target address of all control flow instructions.
//          It also guesses the type of instruction; jalr(r), return, jump (jr), or branch.
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

module btb import cvw::*;  #(parameter cvw_t P,
                             parameter Depth = 10 ) (
  input  logic             clk,
  input  logic             reset,
  input  logic             StallF, StallD, StallE, StallM, StallW, FlushD, FlushE, FlushM, FlushW,
  input  logic [P.XLEN-1:0] PCNextF, PCF, PCD, PCE, PCM, // PC at various stages
  output logic [P.XLEN-1:0] BPBTAF,                      // BTB's guess at PC
  output logic [3:0]       BTBIClassF,                  // BTB's guess at instruction class
  output logic BPBTAWrongM,
  // update
  input  logic             IClassWrongM,                // BTB's instruction class guess was wrong
  input  logic [P.XLEN-1:0] IEUAdrE,                     // Branch/jump target address to insert into btb
  input  logic [P.XLEN-1:0] IEUAdrM,                     // Branch/jump target address to insert into btb
  input  logic [3:0]       IClassD,                 // Instruction class to insert into btb
  input  logic [3:0]       IClassE,                 // Instruction class to insert into btb
  input  logic [3:0]       IClassM,                 // Instruction class to insert into btb
  input  logic [3:0]       IClassW
);

  logic [Depth-1:0]        PCNextFIndex, PCFIndex, PCDIndex, PCEIndex, PCMIndex, PCWIndex;
  logic                    MatchD, MatchE, MatchM, MatchW, MatchX;
  logic [P.XLEN+3:0]       ForwardBTBPredF;
  logic [P.XLEN+3:0]       TableBTBPredF;
  logic [P.XLEN-1:0]       IEUAdrW;
  logic [P.XLEN-1:0]       PCW;
  logic [P.XLEN-1:0]       BPBTAD, BPBTAE;
  logic                    BPBTAWrongE;
  logic                    BTBWrongM;


  // hashing function for indexing the PC
  // We have Depth bits to index, but XLEN bits as the input.
  // bit 0 is always 0, bit 1 is 0 if using 4 byte instructions, but is not always 0 if
  // using compressed instructions.  XOR bit 1 with the MSB of index.
  assign PCFIndex = {PCF[Depth+1] ^ PCF[1], PCF[Depth:2]};
  assign PCDIndex = {PCD[Depth+1] ^ PCD[1], PCD[Depth:2]};
  assign PCEIndex = {PCE[Depth+1] ^ PCE[1], PCE[Depth:2]};
  assign PCMIndex = {PCM[Depth+1] ^ PCM[1], PCM[Depth:2]};
  assign PCWIndex = {PCW[Depth+1] ^ PCW[1], PCW[Depth:2]};

  assign PCNextFIndex = {PCNextF[Depth+1] ^ PCNextF[1], PCNextF[Depth:2]};

  assign MatchD = PCFIndex == PCDIndex;
  assign MatchE = PCFIndex == PCEIndex;
  assign MatchM = PCFIndex == PCMIndex;
  assign MatchW = PCFIndex == PCWIndex;
  assign MatchX = MatchD | MatchE | MatchM | MatchW;

  assign ForwardBTBPredF = MatchD ? {IClassD, BPBTAD} :
                                 MatchE ? {IClassE, IEUAdrE} :
                                 MatchM ? {IClassM, IEUAdrM} :
                                 {IClassW, IEUAdrW} ;

  assign {BTBIClassF, BPBTAF} = MatchX ? ForwardBTBPredF : {TableBTBPredF};


  // An optimization may be using a PC relative address.
  ram2p1r1wbe #(.USE_SRAM(P.USE_SRAM), .DEPTH(2**Depth), .WIDTH(P.XLEN+4)) memory(
    .clk, .ce1(~StallF | reset), .ra1(PCNextFIndex), .rd1(TableBTBPredF),
     .ce2(~StallW & ~FlushW), .wa2(PCMIndex), .wd2({IClassM, IEUAdrM}), .we2(BTBWrongM), .bwe2('1));

  flopenrc #(P.XLEN) BTBD(clk, reset, FlushD, ~StallD, BPBTAF, BPBTAD);

  // BPBTAE is not strickly necessary.  However it is used by two parts of wally.
  // 1. It gates updates to the BTB when the prediction does not change.  This save power.
  // 2. BPBTAWrongE is used by the performance counters to track when the BTB's BPBTA or instruction class is wrong.
  flopenrc #(P.XLEN) BTBTargetEReg(clk, reset, FlushE, ~StallE, BPBTAD, BPBTAE);
  assign BPBTAWrongE = (BPBTAE != IEUAdrE) & (IClassE[0] | IClassE[1] & ~IClassE[2]);

  flopenrc #(1) BPBTAWrongMReg(clk, reset, FlushM, ~StallM, BPBTAWrongE, BPBTAWrongM);
  assign BTBWrongM = BPBTAWrongM | IClassWrongM;

  flopenr #(P.XLEN) PCWReg(clk, reset, ~StallW, PCM, PCW);
  flopenr #(P.XLEN) IEUAdrWReg(clk, reset, ~StallW, IEUAdrM, IEUAdrW);

endmodule
