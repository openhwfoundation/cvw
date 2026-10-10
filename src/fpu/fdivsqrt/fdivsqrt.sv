///////////////////////////////////////////
// fdivsqrt.sv
//
// Written:  David Harris David_Harris@hmc.edu, Katherine Parry me@KatherineParry.com, Cedar Turek cturek@hmc.edu, Alessandro Maiuolo amaiuolo@hmc.edu 7 July 2022
// Modified: Kevin Kim kekim@hmc.edu
//
// Purpose: Top level of the unified floating-point divide/square root and integer divide/remainder unit.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2022-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module fdivsqrt import cvw::*;  #(parameter cvw_t P) (
  input  logic                 clk,
  input  logic                 reset,
  input  logic [P.FMTBITS-1:0] FmtE,
  input  logic                 XsE,
  input  logic [P.NF:0]        XmE, YmE,
  input  logic [P.NE-1:0]      XeE, YeE,
  input  logic                 XInfE, YInfE,
  input  logic                 XZeroE, YZeroE,
  input  logic                 XNaNE, YNaNE,
  input  logic [P.NE-2:0]      BiasE,                               // Bias of exponent
  input  logic [P.LOGFLEN-1:0] NfE,                          // Number of fractional bits in selected format
  input  logic                 FDivStartE, IDivStartE,
  input  logic                 StallM,
  input  logic                 FlushE,
  input  logic                 SqrtE, SqrtM,
  input  logic [P.XLEN-1:0]    ForwardedSrcAE, ForwardedSrcBE, // these are the src A/B outputs before the mux choosing between them and PCE to put in srcA/B
  input  logic [2:0]           Funct3E, Funct3M,
  input  logic                 IntDivE, W64E,
  output logic                 DivStickyM,
  output logic                 FDivBusyE, IFDivStartE, FDivDoneE,
  output logic [P.NE+1:0]      UeM,                         // Exponent result
  output logic [P.DIVb:0]      UmM,                         // Significand result
  output logic [P.XLEN-1:0]    FIntDivResultM               // Integer division result (IntDivResult in figure)
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
  logic [P.DIVBLEN-1:0]        IntNormShiftM;                // Integer normalizatoin shift amount
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
    // Int-specific
    .IntNormShiftM, .ALTBM, .AsM, .BsM, .BZeroM, .W64M, .RemOpM(Funct3M[1]), .AM,
    .FIntDivResultM);
endmodule
