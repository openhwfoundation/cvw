///////////////////////////////////////////
// vfrec7pack.sv
//
// Written: nfotneos@g.hmc.edu 2026-09-18
//
// Purpose: Assemble vfrec7's finite, nonzero, non-overflow result. The
//          reciprocal fraction is built once in the same left-justified,
//          P.NF-bit canonical form the input arrives in, then placed into
//          Res truncated to each SEW's native fraction width.
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
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

module vfrec7pack import cvw::*; #(parameter cvw_t P) (
  input  logic [2:0]         Vsew,
  input  logic                Xs,
  input  logic [6:0]          LutOut,          // seven MSBs of the normalized reciprocal fraction
  input  logic signed [12:0]  NormOutExp,      // normalized reciprocal exponent
  input  logic                IsDenormResult,  // reciprocal result is itself subnormal
  input  logic [1:0]          DenormShift,     // shift to fold the implicit 1 into the fraction

  output logic [P.FLEN-1:0]   Res
);

  localparam logic [2:0] VSEW_16 = 3'b001;
  localparam logic [2:0] VSEW_32 = 3'b010;
  localparam logic [2:0] VSEW_64 = 3'b011;

  logic [P.NF:0]   SubFrac;
  logic [P.NF-1:0] OutFrac;

  // SubFrac[P.NF] is always 0 after the shift and is dropped.
  assign SubFrac = {1'b1, LutOut, {(P.NF-7){1'b0}}} >> DenormShift;

  assign OutFrac = IsDenormResult ? SubFrac[P.NF-1:0] : {LutOut, {(P.NF-7){1'b0}}};

  always_comb
    case (Vsew)
      VSEW_16: Res = {
        {(P.FLEN-16){1'b0}},
        Xs,
        (IsDenormResult ? {P.H_NE{1'b0}} : NormOutExp[P.H_NE-1:0]),
        OutFrac[P.NF-1 -: P.H_NF]
      };

      VSEW_32: Res = {
        {(P.FLEN-32){1'b0}},
        Xs,
        (IsDenormResult ? {P.S_NE{1'b0}} : NormOutExp[P.S_NE-1:0]),
        OutFrac[P.NF-1 -: P.S_NF]
      };

      VSEW_64: Res = {
        {(P.FLEN-64){1'b0}},
        Xs,
        (IsDenormResult ? {P.D_NE{1'b0}} : NormOutExp[P.D_NE-1:0]),
        OutFrac[P.NF-1:0]
      };

      default: Res = '0;
    endcase

endmodule
