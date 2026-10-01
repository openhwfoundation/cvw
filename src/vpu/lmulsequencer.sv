///////////////////////////////////////////
// lmulsequencer.sv
//
// Written: Rose Thompson rose.thompson@skyworksinc.com
// Created: 1 September 2026
// Modified: 1 September 2026
//
// Purpose: sequence multiple micro-op vector instructions based on lmul
//
// Documentation: RISC-V System on Chip Design Volume 2
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University & Skyworks Solutions Inc.
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

module lmulsequencer
  (
   input logic       clk, reset,
   // Decode stage control signals
   input logic       StallVectorD, FlushVectorD, // Stall, flush Decode stage
   input logic       VectorD,        // This instruction is a vector
   input logic [4:0] Vs1D, Vs2D, VdD,
   input logic [6:0] lmulDecodedD,
   // hand shaking controls
   input logic       AnyExecutionUnitReadyD,
   // output micro vector instruction
   output logic [4:0] Vs1FinalD, Vs2FinalD, VdFinalD,
   output logic MicroVectorD,
   output logic LMULExpansionD
);


  logic        IncrD;
  logic [4:0]  Vs1P1D, Vs2P1D, VdP1D;
  logic [4:0]  Vs1P1QD, Vs2P1QD, VdP1QD;
  logic [3:0]  lmulCntrD, lmulCntrP1;
  logic        lmulCntrDone, lmulCntrLoad;
  logic        lmulCntrFirstCaptureD;
  logic [3:0]  lmulIntD;

  typedef enum logic {STATE_BEGIN, STATE_INCR} statetype;
  statetype CurrState, NextState;

  assign lmulIntD = lmulDecodedD[6:3];
  assign lmulCntrFirstCaptureD = lmulCntrD > 1;

  assign Vs1P1D = Vs1FinalD + 5'b00001;
  flopenr #(5) Vs1IncrReg (clk, reset, IncrD, Vs1P1D, Vs1P1QD);
  mux2 #(5) Vs1Mux (Vs1D, Vs1P1QD, lmulCntrFirstCaptureD, Vs1FinalD);

  assign Vs2P1D = Vs2FinalD + 5'b00001;
  flopenr #(5) Vs2IncrReg (clk, reset, IncrD, Vs2P1D, Vs2P1QD);
  mux2 #(5) Vs2Mux (Vs2D, Vs2P1QD, lmulCntrFirstCaptureD, Vs2FinalD);

  assign VdP1D = VdFinalD + 5'b00001;
  flopenr #(5) VdIncrReg  (clk, reset, IncrD, VdP1D,  VdP1QD);
  mux2 #(5) VdMux (VdD, VdP1QD, lmulCntrFirstCaptureD, VdFinalD);


  flopenl #(4) counter (clk, lmulCntrLoad | reset, IncrD, lmulCntrP1, 4'b0001, lmulCntrD);
  assign lmulCntrDone = lmulCntrD == lmulIntD; // *** this is a bug for lmul less than 1
  assign lmulCntrP1 = lmulCntrD + 4'b0001;

  always_ff @(posedge clk)
    if(reset | FlushVectorD) CurrState <= STATE_BEGIN;
    else CurrState <= NextState;


  always_comb begin
    NextState = STATE_BEGIN;
    case(CurrState)
      STATE_BEGIN: if(VectorD & (lmulIntD > 4'd1) & IncrD) NextState = STATE_INCR;
      STATE_INCR:  if(lmulCntrDone) NextState = STATE_BEGIN;
      else NextState = STATE_INCR;
      default: NextState = STATE_BEGIN;
    endcase
  end

  //assign lmulCntrLoad = CurrState == STATE_BEGIN & VectorD;
  assign lmulCntrLoad = CurrState == STATE_INCR & lmulCntrDone;
  //assign LMULExpansionD = AnyExecutionUnitReadyD & (CurrState == STATE_INCR);
  assign LMULExpansionD = (CurrState == STATE_INCR & ~lmulCntrDone) | (CurrState == STATE_BEGIN & lmulIntD > 4'd1 & VectorD);
  assign IncrD = (AnyExecutionUnitReadyD & VectorD) | LMULExpansionD;

  assign MicroVectorD = IncrD | VectorD;

endmodule
