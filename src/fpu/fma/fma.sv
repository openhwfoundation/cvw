///////////////////////////////////////////
// fma.sv
//
// Written:  6/23/2021 me@KatherineParry.com, David_Harris@hmc.edu
// Modified:
//
// Purpose: Floating point multiply-accumulate of configurable size
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

module fma import cvw::*;  #(parameter cvw_t P) (
  input  logic                         Xs, Ys, Zs,             // X, Y, Z signs
  input  logic [P.NE-1:0]              Xe, Ye, Ze,             // X, Y, Z biased exponents (B(NE.0))
  input  logic [P.NF:0]                Xm, Ym, Zm,             // X, Y, Z significands (U1.NF)
  input  logic                         XZero, YZero, ZZero,    // X, Y, Z are zero
  input  logic [2:0]                   OpCtrl,                 // FPU operation control
  output logic                         ASticky,                // Sticky bit from the aligned addend
  output logic [P.FMALEN-1:0]          Sm,                     // Positive sum significand
  output logic                         InvA,                   // Invert addend for effective subtraction
  output logic                         As,                     // Aligned addend sign (Z sign adjusted for the operation)
  output logic                         Ps,                     // Product sign
  output logic                         Ss,                     // Sum sign
  output logic [P.NE+1:0]              Se,                     // Sum exponent
  output logic [$clog2(P.FMALEN+1)-1:0] SCnt                    // Normalization shift count
);

  //  OpCtrl:
  //    Fma: {not multiply-add?, negate prod? (multiply-add) or add/sub? (otherwise), negate Z?}
  //        000 - fmadd
  //        001 - fmsub
  //        010 - fnmsub
  //        011 - fnmadd
  //        100 - mul
  //        110 - add
  //        111 - sub

  logic [2*P.NF+1:0]   Pm;         // the product's significand in U(2.2Nf) format
  logic [P.FMALEN-1:0] Am;         // addend aligned's mantissa for addition in U(NF+4.2NF)
  logic [P.FMALEN-1:0] AmInv;      // aligned addend's mantissa possibly inverted
  logic [2*P.NF+1:0]   PmKilled;   // the product's mantissa possibly killed U(2.2Nf)
  logic                KillProd;   // set the product to zero before addition if the product is too small to matter
  logic [P.NE+1:0]     Pe;         // the product's exponent B(NE+2.0) format; adds 2 bits to allow for size of number and negative sign

  ///////////////////////////////////////////////////////////////////////////////
  // Calculate the product
  //      - When multiplying two fp numbers, add the exponents
  //      - Subtract the bias (XExp + YExp has two biases, one from each exponent)
  //      - If the product is zero then kill the exponent
  //      - Multiply the mantissas
  ///////////////////////////////////////////////////////////////////////////////

  // calculate the product's exponent
  fmaexpadd #(P) expadd(.Xe, .Ye, .XZero, .YZero, .Pe);

  // multiplication of the mantissas
  fmamult #(P) mult(.Xm, .Ym, .Pm);

  // calculate the signs and take the operation into account
  fmasign sign(.OpCtrl, .Xs, .Ys, .Zs, .Ps, .As, .InvA);

  ///////////////////////////////////////////////////////////////////////////////
  // Alignment shifter
  ///////////////////////////////////////////////////////////////////////////////

  fmaalign #(P) align(.Ze, .Zm, .XZero, .YZero, .ZZero, .Xe, .Ye, .Am, .ASticky, .KillProd);

  // ///////////////////////////////////////////////////////////////////////////////
  // // Addition/LZA
  // ///////////////////////////////////////////////////////////////////////////////

  fmaadd #(P) add(.Am, .Pm, .Ze, .Pe, .Ps, .KillProd, .ASticky, .AmInv, .PmKilled, .InvA, .Sm, .Se, .Ss);

  // LZA carry-in matches the +1 of the adder's two's complement negation of A (see fmaadd)
  fmalza #(P.FMALEN, P.NF) lza(.A(AmInv), .Pm(PmKilled), .Cin(InvA & (~ASticky | KillProd)), .sub(InvA), .SCnt);

endmodule
