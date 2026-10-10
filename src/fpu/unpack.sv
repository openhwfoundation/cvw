///////////////////////////////////////////
// unpack.sv
//
// Written: me@KatherineParry.com
// Modified: 7/5/2022
//
// Purpose: unpack X, Y, Z floating-point inputs
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

module unpack import cvw::*; #(parameter cvw_t P) (
  input  logic [P.FLEN-1:0]       X, Y, Z,              // Inputs from FP register file
  input  logic [P.FMTBITS-1:0]    Fmt,                  // FP format: 00 single, 01 double, 10 half, 11 quad
  input  logic                    XEn, YEn, ZEn,        // X, Y, Z inputs used
  input  logic                    FPUActive,            // Kill inputs when FPU is not active
  output logic                    Xs, Ys, Zs,           // X, Y, Z signs
  output logic [P.NE-1:0]         Xe, Ye, Ze,           // X, Y, Z exponents
  output logic [P.NF:0]           Xm, Ym, Zm,           // X, Y, Z significands
  output logic                    XNaN, YNaN, ZNaN,     // X, Y, Z are NaN
  output logic                    XSNaN, YSNaN, ZSNaN,  // X, Y, Z are signaling NaN
  output logic                    XSubnorm,             // X is subnormal
  output logic                    XZero, YZero, ZZero,  // X, Y, Z are zero
  output logic                    XInf, YInf, ZInf,     // X, Y, Z are infinity
  output logic                    XExpMax,              // does X have the maximum exponent (NaN or Inf)
  output logic [P.FLEN-1:0]       XPostBox,             // X after being properly NaN-boxed
  output logic [P.NE-2:0]         Bias,                 // Exponent bias
  output logic [P.LOGFLEN-1:0]    Nf                    // Number of fractional bits in selected format
);

  logic YExpMax, ZExpMax;                               // is the exponent all 1s

  unpackinput #(P) unpackinputX (.A(X), .Fmt, .Sgn(Xs), .Exp(Xe), .Man(Xm), .En(XEn), .FPUActive,
                          .NaN(XNaN), .SNaN(XSNaN),
                          .Zero(XZero), .Inf(XInf), .ExpMax(XExpMax),
                          .Subnorm(XSubnorm), .PostBox(XPostBox));

  unpackinput #(P) unpackinputY (.A(Y), .Fmt, .Sgn(Ys), .Exp(Ye), .Man(Ym), .En(YEn), .FPUActive,
                          .NaN(YNaN), .SNaN(YSNaN),
                          .Zero(YZero), .Inf(YInf), .ExpMax(YExpMax),
                          .Subnorm(), .PostBox());

  unpackinput #(P) unpackinputZ (.A(Z), .Fmt, .Sgn(Zs), .Exp(Ze), .Man(Zm), .En(ZEn), .FPUActive,
                          .NaN(ZNaN), .SNaN(ZSNaN),
                          .Zero(ZZero), .Inf(ZInf), .ExpMax(ZExpMax),
                          .Subnorm(), .PostBox());

  // look up bias and fractional bits for the given format
  fmtparams #(P) fmtparams(Fmt, Bias, Nf);

endmodule
