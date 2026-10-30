///////////////////////////////////////////
// RASPredictor.sv
//
// Written:  Rose Thompson rose@rosethompson.net 15 February 2021
// Modified: David Harris
//
// Purpose: Return address stack.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module RASPredictor import cvw::*; #(parameter cvw_t P) (
  input  logic              clk,
  input  logic              reset,
  input  logic              StallD, StallE, StallM, FlushD, FlushE, FlushM, // Stall and flush Decode, Execute, Memory stages
  input  logic              BPReturnWrongD, // Return prediction was wrong in Decode stage
  input  logic              BPReturnD,      // Instruction in Decode stage was predicted to be a return, so it popped the RAS when fetched
  input  logic              ReturnD,        // Return instruction in Decode stage
  input  logic              ReturnE, CallE, // Return and call instructions in Execute stage
  input  logic              BPReturnF,      // Predicted return instruction in Fetch stage
  input  logic [P.XLEN-1:0] PCLinkE,        // PC + 2 or 4 of instruction in Execute stage (link address)
  output logic [P.XLEN-1:0] RASPCF          // Return address predicted by RAS (top of stack)
);

  logic                     CounterEn;
  localparam Depth = $clog2(P.RAS_SIZE);

  logic [Depth-1:0]         NextPtr, Ptr, P1, M1, IncDecPtr;
  logic [P.RAS_SIZE-1:0]     [P.XLEN-1:0] memory;
  integer                   index;

  logic                     PopF;
  logic                     PushE;
  logic                     RepairD;
  logic                     IncrRepairD, DecRepairD;

  logic                     DecPtr;
  logic                     FlushedReturnDE;
  logic                     WrongPredReturnD;

  assign PopF = BPReturnF & ~StallD & ~FlushD;
  assign PushE = CallE & ~StallM & ~FlushM;

  assign WrongPredReturnD = (BPReturnWrongD) & ~StallE & ~FlushE;
  // Undo the pop of an instruction that is discarded: in D, the pop was made for the predicted class (the D-stage
  // repair has not run yet); in E, the D-stage repair has made it match the actual class.  A stall bubble
  // (FlushE while D is stalled, FlushM while E is stalled) does not discard the instruction.
  assign FlushedReturnDE = (~StallD & FlushE & BPReturnD) | (~StallE & FlushM & ReturnE);

  assign RepairD = WrongPredReturnD | FlushedReturnDE;

  assign IncrRepairD = FlushedReturnDE | (WrongPredReturnD & ~ReturnD); // Guessed it was a return, but it's not

  assign DecRepairD = WrongPredReturnD & ReturnD; // Guessed non return but is a return.

  assign CounterEn = PopF | PushE | RepairD;

  assign DecPtr = (PopF | DecRepairD) & ~IncrRepairD;

  assign P1 = 1;
  assign M1 = '1; // -1
  mux2 #(Depth) PtrMux(P1, M1, DecPtr, IncDecPtr);
  logic [Depth-1:0] Sum;
  assign Sum = Ptr + IncDecPtr;
  // RAS_SIZE is not a power of 2 if any of its low Depth bits are set
  if (|P.RAS_SIZE[Depth-1:0])
    assign NextPtr = Sum >= P.RAS_SIZE[Depth-1:0] ? 0 : Sum; // wrap back around if our stack is not a power of 2
  else
    assign NextPtr = Sum;

  flopenr #(Depth) ptrreg(clk, reset, CounterEn, NextPtr, Ptr);

  // RAS must be reset.
  always_ff @(posedge clk) begin
    if (reset) begin
      for (index = 0; index < P.RAS_SIZE; index++)
        memory[index] <= {P.XLEN{1'b0}};
    end else if (PushE) begin
      memory[NextPtr] <= PCLinkE;
    end
  end

  assign RASPCF = memory[Ptr];

endmodule
