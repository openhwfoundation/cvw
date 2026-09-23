///////////////////////////////////////////
// vfrec7norm.sv
//
// Written: nfotneos@g.hmc.edu 2026-09-18
//
// Purpose: Normalize vfrec7's input operand and generate the seven-bit LUT
//          index. Xm is already left-justified into the MSBs of the shared
//          P.NF-bit field regardless of SEW, so one leading-zero count and
//          one shift/slice serve every SEW.
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

module vfrec7norm import cvw::*; #(parameter cvw_t P) (
  input  logic [P.NE-1:0]           Xe,
  input  logic [P.NF:0]             Xm,
  input  logic                      XSubnorm,
  input  logic signed [12:0]        NativeBias,    // this SEW's native exponent bias

  output logic signed [12:0]        NormInExp,     // normalized input exponent, rebiased to NativeBias
  output logic [6:0]                LutIdx,        // seven MSBs of the normalized input fraction
  output logic [$clog2(P.NF+1)-1:0] ZeroCount      // leading zeros of Xm's fraction
);

  localparam integer LOGNF = $clog2(P.NF+1);

  // Only meaningful when the input is subnormal; the special-case unit uses
  // it to detect subnormal reciprocal overflow.
  lzc #(.WIDTH(P.NF)) lzcfrac (
    .num     (Xm[P.NF-1:0]),
    .ZeroCnt (ZeroCount)
  );

  // Subnormal: normalized input exponent = -ZeroCount, and the fraction
  // shifts left by ZeroCount+1 to remove the newly-created leading 1.
  // Normal: Xe is already biased to the shared internal bias (P.D_BIAS);
  // rebias it to this SEW's native bias.
  logic [P.NF-1:0] NormFrac;

  always_comb
    if (XSubnorm) begin
      NormInExp = -$signed({{(13-LOGNF){1'b0}}, ZeroCount});
      NormFrac  = Xm[P.NF-1:0] << (ZeroCount + 1'b1);
    end else begin
      NormInExp = $signed({{(13-P.NE){1'b0}}, Xe}) + NativeBias - 13'(P.D_BIAS);
      NormFrac  = Xm[P.NF-1:0];
    end

  assign LutIdx = NormFrac[P.NF-1 -: 7];

endmodule
