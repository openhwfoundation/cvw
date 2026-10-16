///////////////////////////////////////////
// fdivsqrt.sv
//
// Written: David_Harris@hmc.edu, me@KatherineParry.com, cturek@hmc.edu, amaiuolo@hmc.edu
// Modified:13 January 2022
//
// Purpose: Combined Divide and Square Root Floating Point and Integer Unit
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

module fdivsqrt import cvw::*; #(parameter cvw_t P) (
  input  logic                 clk,                               // Clock
  input  logic                 reset,                             // Reset
  input  logic [P.FMTBITS-1:0] FmtE,                              // FP format in Execute stage
  input  logic                 XsE,                               // X sign
  input  logic [P.NF:0]        XmE, YmE,                          // X and Y significands
  input  logic [P.NE-1:0]      XeE, YeE,                          // X and Y exponents
  input  logic                 XInfE, YInfE,                      // X, Y are infinity
  input  logic                 XZeroE, YZeroE,                    // X, Y are zero
  input  logic                 XNaNE, YNaNE,                      // X, Y are NaN
  input  logic [P.NE-2:0]      BiasE,                             // Bias of exponent
  input  logic [P.LOGFLEN-1:0] NfE,                               // Number of fractional bits in selected format
  input  logic                 FDivStartE, IDivStartE,            // Start FP divide/sqrt, start integer divide
  input  logic                 StallM,                            // Stall Memory stage
  input  logic                 FlushE,                            // Flush Execute stage
  input  logic                 SqrtE, SqrtM,                      // Square root operation in Execute, Memory stages
  input  logic [P.XLEN-1:0]    ForwardedSrcAE, ForwardedSrcBE,    // Source operands A and B after forwarding, before ALU source select
  input  logic [2:0]           Funct3E, Funct3M,                  // funct3 field of instruction in Execute, Memory stages
  input  logic                 IntDivE, W64E,                     // Integer divide or remainder, RV64 W-type instruction
  output logic                 DivStickyM,                        // Divide/sqrt sticky bit
  output logic                 FDivBusyE, IFDivStartE, FDivDoneE, // FPU divider busy, starting, done
  output logic [P.NE+1:0]      UeM,                               // Divide/sqrt result exponent (biased)
  output logic [P.DIVb:0]      UmM,                               // Divide/sqrt result significand (U1.DIVb)
  output logic [P.XLEN-1:0]    FIntDivResultM                     // Integer divide result from FPU divider in Memory stage
);

  // Floating-point division and square root module, with optional integer division and remainder
  // Computes X/Y, sqrt(X), A/B, or A%B

  logic [P.DIVb+3:0]           WS, WC;                       // Partial remainder components
  logic [P.DIVb+3:0]           X;                            // Iterator Initial Value (from dividend)
  logic [P.DIVb+3:0]           D;                            // Iterator Divisor
  logic [P.DIVb:0]             FirstU, FirstUM;              // Intermediate result values
  logic [P.DIVb+1:0]           FirstC;                       // Step tracker
  logic                        WZeroE;                       // Early termination flag
  logic [P.DURLEN-1:0]         CyclesE;                      // FSM cycles
  logic                        SpecialCaseM;                 // Divide by zero, square root of negative, etc.

  // Integer div/rem signals
  logic                        BZeroM;                       // Denominator is zero
  logic [P.DIVBLEN-1:0]        IntNormShiftM;                // Integer normalization shift amount
  logic                        ALTBM, AsM, BsM, W64M;        // Special handling for postprocessor
  logic [P.XLEN-1:0]           AM;                           // Original Numerator for postprocessor
  logic                        ISpecialCaseE;                // Integer div/remainder special cases

  fdivsqrtpreproc #(P) fdivsqrtpreproc(                          // Preprocessor
    .clk, .IFDivStartE, .Xm(XmE), .Ym(YmE), .Xe(XeE), .Ye(YeE),
    .FmtE, .Bias(BiasE), .Nf(NfE), .SqrtE, .XZeroE, .Funct3E, .UeM, .X, .D, .CyclesE,
    // Int-specific
    .ForwardedSrcAE, .ForwardedSrcBE, .IntDivE, .W64E, .ISpecialCaseE,
    .BZeroM, .IntNormShiftM, .AM, .W64M, .ALTBM, .AsM, .BsM);

  fdivsqrtfsm #(P) fdivsqrtfsm(                                  // FSM
    .clk, .reset, .XInfE, .YInfE, .XZeroE, .YZeroE, .XNaNE, .YNaNE,
    .FDivStartE, .XsE, .SqrtE, .WZeroE, .FlushE, .StallM,
    .FDivBusyE, .IFDivStartE, .FDivDoneE, .SpecialCaseM, .CyclesE,
    // Int-specific
    .IDivStartE, .ISpecialCaseE, .IntDivE);

  fdivsqrtiter #(P) fdivsqrtiter(                                // CSA Iterator
    .clk, .IFDivStartE, .FDivBusyE, .SqrtE, .X, .D,
    .FirstU, .FirstUM, .FirstC, .FirstWS(WS), .FirstWC(WC));

  fdivsqrtpostproc #(P) fdivsqrtpostproc(                        // Postprocessor
    .clk, .reset, .StallM, .WS, .WC, .D, .FirstU, .FirstUM, .FirstC,
    .SqrtE, .SqrtM, .SpecialCaseM,
    .UmM, .WZeroE, .DivStickyM,
    // Int-specific; Funct3M[1] = 1 for REM/REMU, 0 for DIV/DIVU
    .IntNormShiftM, .ALTBM, .AsM, .BsM, .BZeroM, .W64M, .RemOpM(Funct3M[1]), .AM,
    .FIntDivResultM);
endmodule
