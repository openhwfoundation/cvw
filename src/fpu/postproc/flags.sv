///////////////////////////////////////////
// flags.sv
//
// Written: me@KatherineParry.com
// Modified: 7/5/2022
//
// Purpose: Post-Processing flag calculation
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

module flags import cvw::*;  #(parameter cvw_t P) (
  input  logic                 Xs,                     // X sign
  input  logic [P.FMTBITS-1:0] OutFmt,                 // output format
  input  logic                 InfIn,                  // An input is infinity
  input  logic                 XInf, YInf, ZInf,       // X, Y, Z are infinity
  input  logic                 NaNIn,                  // An input is a NaN
  input  logic                 XSNaN, YSNaN, ZSNaN,    // X, Y, Z are signaling NaN
  input  logic                 XZero, YZero,           // X, Y are zero
  input  logic [P.NE+1:0]      FullRe,                 // Result exponent with extra bits for sign and overflow
  input  logic [P.NE+1:0]      Me,                     // Normalized exponent
  // rounding
  input  logic                 Plus1,                  // Add one for rounding
  input  logic                 Round, Guard, Sticky,   // Round, guard, and sticky bits for rounding
  input  logic                 UfPlus1,                // Add one for rounding with unbounded exponent
  // convert
  input  logic                 CvtOp,                  // Conversion operation
  input  logic                 ToInt,                  // FP to integer conversion
  input  logic                 IntToFp,                // Integer to FP conversion
  input  logic                 Int64,                  // 64-bit integer conversion
  input  logic                 Signed,                 // Signed integer conversion
  input  logic [P.NE:0]        CvtCe,                  // Conversion calculated exponent
  input  logic [1:0]           CvtNegResMsbs,          // Most significant bits of possibly negated integer result
  // divsqrt
  input  logic                 DivOp,                  // Divide or square root operation
  input  logic                 Sqrt,                   // Square root operation
  // fma
  input  logic                 FmaOp,                  // FMA operation
  input  logic                 FmaAs, FmaPs,           // FMA aligned addend and product signs
  // flags
  output logic                 DivByZero,              // divide by zero flag
  output logic                 Overflow,               // overflow flag to select result
  output logic                 Invalid,                // invalid flag to select the result
  output logic                 IntInvalid,             // Integer conversion invalid flag
  output logic [4:0]           PostProcFlg             // Postprocessor exception flags
);

  logic                        SigNaN;                 // is an input a signaling NaN
  logic                        Inexact;                // final inexact flag
  logic                        FpInexact;              // floating point inexact flag
  logic                        IntInexact;             // integer inexact flag
  logic                        FmaInvalid;             // fma invalid flag
  logic                        DivInvalid;             // divsqrt invalid flag
  logic                        Underflow;              // Underflow flag
  logic                        ResExpGteMax;           // is the result greater than or equal to the maximum floating point exponent
  logic                        ShiftGtIntSz;           // is the shift greater than the integer size (use Re to account for possible rounding "shift")

  ///////////////////////////////////////////////////////////////////////////////
  // Overflow
  ///////////////////////////////////////////////////////////////////////////////

  // determine if the result exponent is greater than or equal to the maximum exponent or
  // the shift amount is greater than the integer size (for cvt to int)
  // ShiftGtIntSz calculation:
  //      a left shift of intlen+1 is still in range but any more than that is an overflow
  //             initial: |      64 0's         |    XLEN     |
  //                      |      64 0's         |    XLEN     | << 64
  //                      |      XLEN           |    00000... |
  //      65 = ...0 0 0 0   0 1 0 0   0 0 0 1
  //          |     or      | |     or      |
  //      33 = ...0 0 0 0   0 0 1 0   0 0 0 1
  //          |     or      | |     or      |
  //      larger or equal if:
  //          - any of the bits after the most significant 1 is one
  //          - the most significant in 65 or 33 is still a one in the number and
  //            one of the later bits is one
  //      i.e. ignoring the sign bit, ShiftGtIntSz = (FullRe >= 65) for 64-bit integers or (FullRe >= 33) for 32-bit integers
  if (P.FPSIZES == 1) begin
      assign ResExpGteMax = &FullRe[P.NE-1:0] | FullRe[P.NE];
      assign ShiftGtIntSz = (|FullRe[P.NE:7] | (FullRe[6] & ~Int64)) | ((|FullRe[4:0] | (FullRe[5] & Int64)) & ((FullRe[5] & ~Int64) | FullRe[6] & Int64));

  end else if (P.FPSIZES == 2) begin
      assign ResExpGteMax = OutFmt ? &FullRe[P.NE-1:0] | FullRe[P.NE] : &FullRe[P.NE1-1:0] | (|FullRe[P.NE:P.NE1]);

      assign ShiftGtIntSz = (|FullRe[P.NE:7] | (FullRe[6] & ~Int64)) | ((|FullRe[4:0] | (FullRe[5] & Int64)) & ((FullRe[5] & ~Int64) | FullRe[6] & Int64));
  end else if (P.FPSIZES == 3) begin
      always_comb
          case (OutFmt)
              P.FMT: ResExpGteMax   = &FullRe[P.NE-1:0]  | FullRe[P.NE];
              P.FMT1: ResExpGteMax  = &FullRe[P.NE1-1:0] | (|FullRe[P.NE:P.NE1]);
              P.FMT2: ResExpGteMax  = &FullRe[P.NE2-1:0] | (|FullRe[P.NE:P.NE2]);
              default: ResExpGteMax = 1'bx;
          endcase
      assign ShiftGtIntSz = (|FullRe[P.NE:7] | (FullRe[6] & ~Int64)) | ((|FullRe[4:0] | (FullRe[5] & Int64)) & ((FullRe[5] & ~Int64) | FullRe[6] & Int64));

  end else if (P.FPSIZES == 4) begin
      always_comb
          case (OutFmt)
              P.Q_FMT: ResExpGteMax = &FullRe[P.Q_NE-1:0] | FullRe[P.Q_NE];
              P.D_FMT: ResExpGteMax = &FullRe[P.D_NE-1:0] | (|FullRe[P.Q_NE:P.D_NE]);
              P.S_FMT: ResExpGteMax = &FullRe[P.S_NE-1:0] | (|FullRe[P.Q_NE:P.S_NE]);
              P.H_FMT: ResExpGteMax = &FullRe[P.H_NE-1:0] | (|FullRe[P.Q_NE:P.H_NE]);
          endcase
      assign ShiftGtIntSz = (|FullRe[P.Q_NE:7] | (FullRe[6] & ~Int64)) | ((|FullRe[4:0] | (FullRe[5] & Int64)) & ((FullRe[5] & ~Int64) | FullRe[6] & Int64));
  end

  // calculate overflow flag:
  //                if the result is greater than or equal to the max exponent (not taking into account sign)
  //                |              and the exponent isn't negative
  //                |              |                 and the input isn't infinity or NaN and not divide by zero
  //                |              |                 |
  assign Overflow = ResExpGteMax & ~FullRe[P.NE+1] & ~(InfIn | NaNIn | DivByZero);

  ///////////////////////////////////////////////////////////////////////////////
  // Underflow
  ///////////////////////////////////////////////////////////////////////////////

  // calculate underflow flag: detecting tininess after rounding
  //                   the exponent is negative
  //                   |                the result is subnormal
  //                   |                |               the result is normal and rounded from a subnormal
  //                   |                |               |                            and if given an unbounded exponent the result does not round
  //                   |                |               |                            |                      and if the result is not exact
  //                   |                |               |                            |                      |                           and not Inf/NaN input, divide by zero, or invalid
  //                   |                |               |                            |                      |                           |
  assign Underflow = ((FullRe[P.NE+1] | (FullRe == 0) | ((FullRe == 1) & (Me == 0) & ~(UfPlus1 & Guard))) & (Round | Sticky | Guard)) & ~(InfIn | NaNIn | DivByZero | Invalid);

  ///////////////////////////////////////////////////////////////////////////////
  // Inexact
  ///////////////////////////////////////////////////////////////////////////////

  // Set Inexact flag if the result is different from what would be outputted given infinite precision
  //      - not set for Inf or NaN inputs, divide by zero, or invalid operations
  assign FpInexact = (Sticky | Guard | Overflow | Round) & ~(InfIn | NaNIn | DivByZero | Invalid);

  //                   if the res is too small to be represented and not 0
  //                   |                                                  and if the res is not invalid (outside the integer bounds)
  //                   |                                                  |
  assign IntInexact = ((CvtCe[P.NE] & ~XZero) | Sticky | Round | Guard) & ~IntInvalid;

  // select the inexact flag to output
  assign Inexact = ToInt ? IntInexact : FpInexact;

  ///////////////////////////////////////////////////////////////////////////////
  // Invalid
  ///////////////////////////////////////////////////////////////////////////////

  // Set Invalid flag for following cases:
  //   1) any input is a signaling NaN
  //   2) Inf - Inf (unless x or y is NaN)
  //   3) 0 * Inf

  // invalid flag for integer result
  //                  if the input is NaN or infinity
  //                  |               or the integer result overflows (out of range) and the exponent isn't negative
  //                  |               |                                  or the input is negative but the output is unsigned
  //                  |               |                                  |                 and the result doesn't round to zero
  //                  |               |                                  |                 |                                          or the rounded result is out of range (msbs differ)
  //                  |               |                                  |                 |                                          |
  assign IntInvalid = NaNIn | InfIn | (ShiftGtIntSz & ~FullRe[P.NE+1]) | ((Xs & ~Signed) & (~((CvtCe[P.NE] | (~|CvtCe)) & ~Plus1))) | (CvtNegResMsbs[1] ^ CvtNegResMsbs[0]);

  // signaling NaN inputs: X is not a float for int->fp conversions, Y is unused by conversions, and Z is used only by FMA
  assign SigNaN = (XSNaN & ~(IntToFp & CvtOp)) | (YSNaN & ~CvtOp) | (ZSNaN & FmaOp);

  // invalid flag for fma
  assign FmaInvalid = ((XInf | YInf) & ZInf & (FmaPs ^ FmaAs) & ~NaNIn) | (XZero & YInf) | (YZero & XInf);

  // invalid flag for divsqrt: 0/0, Inf/Inf, or sqrt of a negative nonzero number
  assign DivInvalid = ((XInf & YInf) | (XZero & YZero)) & ~Sqrt | (Xs & Sqrt & ~NaNIn & ~XZero);

  assign Invalid = SigNaN | (FmaInvalid & FmaOp) | (DivInvalid & DivOp);

  ///////////////////////////////////////////////////////////////////////////////
  // Divide by Zero
  ///////////////////////////////////////////////////////////////////////////////

  // if dividing by zero and not 0/0
  //  - don't set flag if an input is NaN or Inf (IEEE says it has to be a finite numerator)
  assign DivByZero = YZero & DivOp & ~Sqrt & ~(XZero | NaNIn | InfIn);

  ///////////////////////////////////////////////////////////////////////////////
  // final flags
  ///////////////////////////////////////////////////////////////////////////////

  // Combine flags
  //      - to integer results do not set the underflow or overflow flags
  assign PostProcFlg = {Invalid | (IntInvalid & CvtOp & ToInt), DivByZero, Overflow & ~(ToInt & CvtOp), Underflow & ~(ToInt & CvtOp), Inexact};

endmodule
