///////////////////////////////////////////
// fmaadd.sv
//
// Written:  6/23/2021 me@KatherineParry.com, David_Harris@hmc.edu
// Modified:
//
// Purpose: FMA significand adder
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

module fmaadd import cvw::*;  #(parameter cvw_t P) (
  input  logic [3*P.NF+5:0]    Am,         // aligned addend's mantissa for addition in U(NF+5.2NF+1)
  input  logic [P.NE-1:0]      Ze,         // exponent of Z
  input  logic                 Ps,         // the product sign and the alligend addeded's sign (Modified Z sign for other operations)
  input  logic [P.NE+1:0]      Pe,         // product's exponent
  input  logic [2*P.NF+1:0]    Pm,         // the product's mantissa
  input  logic                 InvA,       // invert the aligned addend
  input  logic                 KillProd,   // should the product be set to 0
  input  logic                 ASticky,    // Aligned addend's sticky bit
  output logic [3*P.NF+5:0]    AmInv,      // aligned addend possibly inverted
  output logic [2*P.NF+1:0]    PmKilled,   // the product's mantissa possibly killed
  output logic                 Ss,         // sum's sign
  output logic [P.NE+1:0]      Se,         // sum's exponent
  output logic [3*P.NF+5:0]    Sm          // the positive sum
);

  logic [3*P.NF+5:0]    PreSum, NegPreSum; // possibly negative sum
  logic                 NegSum;            // was the sum negative

  ///////////////////////////////////////////////////////////////////////////////
  // Addition
  ///////////////////////////////////////////////////////////////////////////////

  // Choose an inverted or non-inverted addend.  Put carry into adder/LZA for addition
  assign AmInv = InvA ? ~Am : Am;
  // Kill the product if the product is too small to effect the addition (determined in fma1.sv)
  assign PmKilled = KillProd ? 0 : Pm;
  // Do the addition
  //      - calculate a positive and negative sum in parallel
  // if there was a small negative number killed in the alignment stage one needs to be subtracted from the sum
  //      prod - addend where some of the addend is put into the sticky bit then don't add +1 from negation
  //          ie ~(InvA&ASticky&~KillProd)&InvA = (~ASticky|KillProd)&InvA
  //      addend - prod where product is killed (and not exactly zero) then don't add +1 from negation
  //          ie ~(InvA&ASticky&KillProd)&InvA = (~ASticky|~KillProd)&InvA
  //          in this case this result is only ever selected when InvA=1 so we can remove &InvA
  assign {NegSum, PreSum} = {{P.NF+3{1'b0}}, PmKilled, 2'b0} + {InvA, AmInv} + {{3*P.NF+5{1'b0}}, (~ASticky|KillProd)&InvA};
  assign NegPreSum = Am + {{P.NF+2{1'b1}}, ~PmKilled, 2'b0} + {(3*P.NF+3)'(0), ~ASticky|~KillProd, 2'b0};

  // Choose the positive sum and accompanying LZA result.
  assign Sm = NegSum ? NegPreSum : PreSum;
  // is the result negative
  //  if p - z is the Sum negative
  //  if -p + z is the Sum positive
  //  if -p - z then the Sum is negative
  assign Ss = NegSum^Ps;
  assign Se = KillProd ? {2'b0, Ze} : Pe;
endmodule
