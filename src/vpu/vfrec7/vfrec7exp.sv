///////////////////////////////////////////
// vfrec7exp.sv
//
// Written: nfotneos@g.hmc.edu 2026-09-18
//
// Purpose: vfrec7 reciprocal exponent: normalized output exponent =
//          2*NativeBias - 1 - normalized input exponent. An output exponent
//          of 0 or -1 means the reciprocal result itself is subnormal.
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

module vfrec7exp (
  input  logic signed [12:0] NormInExp,      // normalized input exponent
  input  logic signed [12:0] NativeBias,     // this SEW's native exponent bias

  output logic signed [12:0] NormOutExp,     // normalized reciprocal exponent
  output logic               IsDenormResult, // reciprocal result is itself subnormal
  output logic [1:0]         DenormShift     // shift to fold the implicit 1 into the fraction
);

  logic signed [12:0] ExpConstant;    // 2*NativeBias - 1

  assign ExpConstant = 2 * NativeBias - 13'sd1;
  assign NormOutExp  = ExpConstant - NormInExp;

  assign IsDenormResult = (NormOutExp == 13'sd0) | (NormOutExp == -13'sd1);
  assign DenormShift    = (NormOutExp == 13'sd0) ? 2'd1 : 2'd2;

endmodule
