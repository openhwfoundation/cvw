///////////////////////////////////////////
// vieufsm.sv
//
// Written: Rose Thompson rose@rosethompson.net
// Created: 10 Sept 2026
// Modified: 10 Sept 2026
//
// Purpose: Sequences beats of an integer vector instruction
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
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

module vieufsm import cvw::*;  #(parameter     cvw_t P,
                                 parameter int BEATBITLEN)
  (
   input logic                   clk,
   input logic                   reset,
   input logic                   LocalStallE,
   input logic                   FlushVectorE,
   input logic                   ControllerValidD,
   input logic                   NotConsummedW,
   output logic                  ExecutionUnitReadyD,
   output logic [BEATBITLEN-1:0] BeatE,
   output logic                  ExecutionUnitResultValidE,
   output logic                  BeatValidE,
   input logic [BEATBITLEN-1:0]  vlE
   );


  typedef enum logic {STATE_RDY, STATE_BEAT} statetype;
  statetype CurrState, NextState;
  logic BeatResetD, BeatIncrD;
  logic [BEATBITLEN-1:0] BeatLength;

  localparam             SPLIT = $clog2(P.VPU_INT_EU);

  logic                  BeatNotValidE;
  logic                  DoneE, ReadyE;
  logic                  CaptureInstrD;

  // computes vl / how many ELEN elements are consummed each beat.
  // vl / # Lanes. If there is a remainder, there is one extra beat.
  assign BeatLength = vlE[BEATBITLEN-1:SPLIT] + (BEATBITLEN-SPLIT)'(|(vlE[SPLIT-1:0]));



  flopenr #(1) validreg(clk, CaptureInstrD, BeatResetD, '1, BeatNotValidE); // SR flop with set priority
  assign BeatValidE = ~BeatNotValidE;
  flopenr #(1) readyreg(clk, CaptureInstrD, BeatResetD, '1, ReadyE); // SR flop with reset priority
  assign CaptureInstrD = ControllerValidD & ExecutionUnitReadyD;

  assign BeatResetD = (ExecutionUnitReadyD & ~LocalStallE) | reset;

  counterval #(BEATBITLEN) beatcounter(clk, BeatResetD, BeatIncrD, P.VPU_INT_LANES[BEATBITLEN-1:0], BeatE);

  assign BeatIncrD = BeatValidE & ~LocalStallE;
  assign DoneE = BeatE >= BeatLength - 1; // *** optimize
  assign ExecutionUnitReadyD = ((DoneE & ExecutionUnitResultValidE) | ReadyE) & ~NotConsummedW;
  assign ExecutionUnitResultValidE = DoneE & BeatValidE;

endmodule
