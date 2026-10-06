///////////////////////////////////////////
// RASPredictor.sv
//
// Written: Rose Thomposn rose@rosethompson.net
// Created: 15 February 2021
// Modified: 25 January 2023
//
// Purpose: 2 bit saturating counter predictor with parameterized table depth.
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

module RASPredictor import cvw::*;  #(parameter cvw_t P)(
  input  logic             clk,
  input  logic             reset,
  input  logic             StallD, StallE, StallM, FlushD, FlushE, FlushM,
  input  logic             BPReturnWrongD,                      // Prediction class is wrong
  input  logic             ReturnD,
  input  logic             ReturnE, CallE,                  // Instr class
  input  logic             BPReturnF,
  input  logic [P.XLEN-1:0] PCLinkE,                                   // PC of instruction after a call
  output logic [P.XLEN-1:0] RASPCF                                     // Top of the stack
   );

  logic                     CounterEn;
  localparam Depth = $clog2(P.RAS_SIZE);

  logic [Depth-1:0]         NextPtr, Ptr, P1, M1, IncDecPtr;
  logic [P.RAS_SIZE-1:0]     [P.XLEN-1:0] memory;
  integer        index;

  logic      PopF;
  logic      PushE;
  logic      RepairD;
  logic      IncrRepairD, DecRepairD;

  logic      DecPtr;
  logic      FlushedReturnDE;
  logic      WrongPredReturnD;


  assign PopF = BPReturnF & ~StallD & ~FlushD;
  assign PushE = CallE & ~StallM & ~FlushM;

  assign WrongPredReturnD = (BPReturnWrongD) & ~StallE & ~FlushE;
  assign FlushedReturnDE = (~StallE & FlushE & ReturnD) | (FlushM & ReturnE); // flushed return

  assign RepairD = WrongPredReturnD | FlushedReturnDE ;

  assign IncrRepairD = FlushedReturnDE | (WrongPredReturnD & ~ReturnD); // Guessed it was a return, but its not

  assign DecRepairD =  WrongPredReturnD & ReturnD; // Guessed non return but is a return.

  assign CounterEn = PopF | PushE | RepairD;

  assign DecPtr = (PopF | DecRepairD) & ~IncrRepairD;

  assign P1 = 1;
  assign M1 = '1; // -1
  mux2 #(Depth) PtrMux(P1, M1, DecPtr, IncDecPtr);
  logic [Depth-1:0] Sum;
  assign Sum = Ptr + IncDecPtr;
  if(|P.RAS_SIZE[Depth-1:0])
    assign NextPtr = Sum >= P.RAS_SIZE[Depth-1:0] ? 0 : Sum; // wrap back around if our stack is not a power of 2
  else
    assign NextPtr = Sum;
  //assign NextPtr = Ptr + IncDecPtr;

  flopenr #(Depth) ptrreg(clk, reset, CounterEn, NextPtr, Ptr);

  // RAS must be reset.
  always_ff @ (posedge clk) begin
    if(reset) begin
      for(index=0; index<P.RAS_SIZE; index++)
    memory[index] <= {P.XLEN{1'b0}};
    end else if(PushE) begin
      memory[NextPtr] <= PCLinkE;
    end
  end

  assign RASPCF = memory[Ptr];


endmodule
