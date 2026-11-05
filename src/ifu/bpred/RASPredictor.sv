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
  input  logic              StallD, StallE, StallM, FlushD, FlushE, FlushM,
  input  logic              BPReturnWrongD, // Prediction class is wrong
  input  logic              BPReturnD,      // the instruction in D popped the RAS when it was fetched
  input  logic              ReturnD,
  input  logic              ReturnE, CallE, // Instr class
  input  logic              BPCallD,        // the instruction in D was predicted to be a call
  input  logic [P.XLEN-1:0] PCLinkD,        // PC of the instruction after the one in D
  input  logic              BPReturnF,
  input  logic [P.XLEN-1:0] PCLinkE,        // PC of instruction after a call
  output logic [P.XLEN-1:0] RASPCF          // Top of the stack
);

  localparam Depth = $clog2(P.RAS_SIZE);

  logic [Depth-1:0]         NextPtr, Ptr, PushPtr;
  logic [P.RAS_SIZE-1:0]     [P.XLEN-1:0] memory;
  integer                   index;

  logic                     PopF;
  logic                     PushE;
  logic                     FlushedReturnD, FlushedReturnE;
  logic                     WrongPredReturnD;
  logic                     IncrRepairD, DecRepairD;
  logic                     IncrE, IncrD;
  logic                     CounterEn;

  assign PopF = BPReturnF & ~StallD & ~FlushD;
  assign PushE = CallE & ~StallM & ~FlushM;

  assign WrongPredReturnD = (BPReturnWrongD) & ~StallE & ~FlushE;
  // Undo the pop of an instruction that is discarded: in D, the pop was made for the predicted class (the D-stage
  // repair has not run yet); in E, the D-stage repair has made it match the actual class.  A stall bubble
  // (FlushE while D is stalled, FlushM while E is stalled) does not discard the instruction.
  assign FlushedReturnD = ~StallD & FlushE & BPReturnD;
  assign FlushedReturnE = ~StallE & FlushM & ReturnE;
  assign IncrRepairD = WrongPredReturnD & ~ReturnD; // Guessed it was a return, but it's not
  assign DecRepairD = WrongPredReturnD & ReturnD;   // Guessed non return but is a return.

  // Instructions in E, D, and F can each update the pointer in the same cycle.  Sum the updates so that none is lost:
  //   E: a push, or the undo of a flushed return (exclusive: PushE needs ~FlushM)
  //   D: the undo of a flushed predicted return, or a class repair (exclusive: the repair needs ~FlushE)
  //   F: a pop (exclusive with both undos, which come with FlushD)
  assign IncrE = PushE | FlushedReturnE;
  assign IncrD = FlushedReturnD | IncrRepairD;
  assign CounterEn = IncrE | IncrD | DecRepairD | PopF;

  // The sum ranges from Ptr-2 to Ptr+2.  Two extra bits hold its sign and carry.
  logic [Depth+1:0] Sum;
  assign Sum = {2'b0, Ptr} + {{(Depth+1){1'b0}}, IncrE} + {{(Depth+1){1'b0}}, IncrD}
                           - {{(Depth+1){1'b0}}, DecRepairD} - {{(Depth+1){1'b0}}, PopF};
  // RAS_SIZE is not a power of 2 if any of its low Depth bits are set; then wrap around explicitly
  if (|P.RAS_SIZE[Depth-1:0])
    assign NextPtr = Sum[Depth+1]                ? Depth'(Sum + (Depth+2)'(P.RAS_SIZE)) :  // below 0
                     Sum >= (Depth+2)'(P.RAS_SIZE) ? Depth'(Sum - (Depth+2)'(P.RAS_SIZE)) :  // above the top
                     Sum[Depth-1:0];
  else
    assign NextPtr = Sum[Depth-1:0];

  flopenr #(Depth) ptrreg(clk, reset, CounterEn, NextPtr, Ptr);

  // A call in E is older than the instruction in D.  If that instruction was predicted to be a return, it has
  // already popped, so the call pushes just above the entry it popped instead of overwriting it.
  logic [Depth:0] PushSum;
  assign PushSum = {1'b0, Ptr} + 1 + {{Depth{1'b0}}, BPReturnD};
  if (|P.RAS_SIZE[Depth-1:0])
    assign PushPtr = PushSum >= (Depth+1)'(P.RAS_SIZE) ? Depth'(PushSum - (Depth+1)'(P.RAS_SIZE)) : PushSum[Depth-1:0];
  else
    assign PushPtr = PushSum[Depth-1:0];

  // RAS must be reset.
  always_ff @(posedge clk) begin
    if (reset) begin
      for (index = 0; index < P.RAS_SIZE; index++)
        memory[index] <= {P.XLEN{1'b0}};
    end else if (PushE) begin
      memory[PushPtr] <= PCLinkE;
    end
  end

  // A call pushes in E, so a return fetched right behind it reads its link address from the call:
  // from D when the function is just a return, from E when it is one instruction and a return.
  // (When the instruction in D was predicted to be a return, it is the one returning to the call in E,
  // and the return in F would need the entry below.)
  assign RASPCF = BPCallD ? PCLinkD : CallE & ~BPReturnD ? PCLinkE : memory[Ptr];

endmodule
