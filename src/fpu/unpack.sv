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

module unpack import cvw::*;  #(parameter cvw_t P) (
  input  logic [P.FLEN-1:0]       X, Y, Z,              // inputs from register file
  input  logic [P.FMTBITS-1:0]    Fmt,                  // format signal 00 - single 01 - double 11 - quad 10 - half
  input  logic                    XEn, YEn, ZEn,        // input enables
  input  logic                    FPUActive,            // Kill inputs when FPU is not active
  input  logic                    Bf16Src,              // Zfbfmin: X holds a BF16 value (fcvt.s.bf16)
  output logic                    Xs, Ys, Zs,           // sign bits of XYZ
  output logic [P.NE-1:0]         Xe, Ye, Ze,           // exponents of XYZ (converted to largest supported precision)
  output logic [P.NF:0]           Xm, Ym, Zm,           // mantissas of XYZ (converted to largest supported precision)
  output logic                    XNaN, YNaN, ZNaN,     // is XYZ a NaN
  output logic                    XSNaN, YSNaN, ZSNaN,  // is XYZ a signaling NaN
  output logic                    XSubnorm,             // is X subnormal
  output logic                    XZero, YZero, ZZero,  // is XYZ zero
  output logic                    XInf, YInf, ZInf,     // is XYZ infinity
  output logic                    XExpMax,              // does X have the maximum exponent (NaN or Inf)
  output logic [P.FLEN-1:0]       XPostBox,             // X after being properly NaN-boxed
  output logic [P.NE-2:0]         Bias,                 // Exponent bias
  output logic [P.LOGFLEN-1:0]    Nf                    // Number of fractional bits
);

  logic YExpMax, ZExpMax;                               // is the exponent all 1s
  logic [P.FLEN-1:0] XIn;                               // X, with a BF16 source widened to single

  localparam BF16LEN = 1 + P.S_NE + P.BF16_NF;          // BF16 is single precision with a 7 bit fraction

  // A BF16 value is bit-identical to the top half of a single, so widening it lets the single
  // precision path unpack it unchanged.  unpackinput cannot check the box itself because single
  // is the widest format when FLEN is 32, so an improperly boxed source becomes the canonical NaN here.
  assign XIn = Bf16Src ? {{P.FLEN-P.S_LEN{1'b1}}, (&X[P.FLEN-1:BF16LEN] ? {X[BF16LEN-1:0], {P.S_LEN-BF16LEN{1'b0}}} : 32'h7FC00000)} : X;

  unpackinput #(P) unpackinputX (.A(XIn), .Fmt, .Sgn(Xs), .Exp(Xe), .Man(Xm), .En(XEn), .FPUActive,
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
