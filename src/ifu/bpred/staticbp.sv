///////////////////////////////////////////
// staticbp.sv
//
// Written:  David Harris David_Harris@hmc.edu 6 November 2026
// Modified:
//
// Purpose: Static branch predictor in the Decode stage, with no BTB.
//          JAL and backward conditional branches (negative offset) are predicted taken and
//          redirect fetch to PCD + offset, costing one bubble instead of two.
//          The Execute stage corrects a wrong prediction as it would with no predictor.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module staticbp import cvw::*; #(parameter cvw_t P) (
  input  logic              clk, reset,
  input  logic              StallD, StallE,
  input  logic              FlushE,
  input  logic [31:0]       InstrD,                    // Decompressed decode stage instruction
  input  logic [P.XLEN-1:0] PCD,                       // Decode stage instruction address
  input  logic [P.XLEN-1:0] PCPlus2or4F,               // PCF+2/4
  input  logic              PCSrcE,                    // Execution stage branch is taken
  input  logic [P.XLEN-1:0] IEUAdrE,                   // The branch/jump target address
  input  logic [P.XLEN-1:0] PCLinkE,                   // The address following the branch instruction
  output logic [P.XLEN-1:0] PC1NextF,                  // Predicted or corrected fetch address
  output logic              BPWrongE,                  // Prediction is wrong
  output logic              BPRedirectD                // Decode stage redirects fetch; flush the instruction in Fetch
);

  logic              BranchInstrD, JalD, PredTakenD, PredTakenE;
  logic [P.XLEN-1:0] OffsetD, PredPCD, CorrectPCE, PCDecodeF;

  assign BranchInstrD = InstrD[6:0] == 7'b1100011;
  assign JalD = InstrD[6:0] == 7'b1101111;
  assign OffsetD = JalD ? {{(P.XLEN-20){InstrD[31]}}, InstrD[19:12], InstrD[20], InstrD[30:21], 1'b0}
                        : {{(P.XLEN-12){InstrD[31]}}, InstrD[7], InstrD[30:25], InstrD[11:8], 1'b0};
  assign PredTakenD = JalD | BranchInstrD & InstrD[31];
  assign PredPCD = PCD + OffsetD;
  assign BPRedirectD = PredTakenD & ~StallD;

  // a branch or JAL predicted taken is wrong only if not taken; anything else is wrong if taken
  flopenrc #(1) PredTakenEReg(clk, reset, FlushE, ~StallE, PredTakenD, PredTakenE);
  assign BPWrongE = PCSrcE ^ PredTakenE;

  mux2 #(P.XLEN) correctmux(.d0(IEUAdrE), .d1(PCLinkE), .s(PredTakenE), .y(CorrectPCE));
  mux2 #(P.XLEN) decodemux(.d0(PCPlus2or4F), .d1(PredPCD), .s(PredTakenD), .y(PCDecodeF));
  mux2 #(P.XLEN) pcmux1(.d0(PCDecodeF), .d1(CorrectPCE), .s(BPWrongE), .y(PC1NextF));

endmodule
