///////////////////////////////////////////
// fdivsqrtpreproc.sv
//
// Written: David_Harris@hmc.edu, me@KatherineParry.com, cturek@hmc.edu
// Modified:13 January 2022
//
// Purpose: Divide/Square root preprocessing: integer absolute value and W64, normalization shift
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

module fdivsqrtpreproc import cvw::*;  #(parameter cvw_t P) (
  input  logic                 clk,
  input  logic                 IFDivStartE,
  input  logic [P.NF:0]        Xm, Ym,      // Floating-point significands
  input  logic [P.NE-1:0]      Xe, Ye,      // Floating-point exponents
  input  logic [P.FMTBITS-1:0] FmtE,
  input  logic [P.NE-2:0]      Bias,                               // Bias of exponent
  input  logic [P.LOGFLEN-1:0] Nf,          // Number of fractional bits in selected format
  input  logic                 SqrtE,
  input  logic                 XZeroE,
  input  logic [2:0]           Funct3E,
  output logic [P.NE+1:0]      UeM,         // biased exponent of result
  output logic [P.DIVb+3:0]    X, D,        // Q4.DIVb
  // Int-specific
  input  logic [P.XLEN-1:0]    ForwardedSrcAE, ForwardedSrcBE, // U(XLEN.0) inputs from IEU
  input  logic                 IntDivE, W64E,
  // Outputs
  output logic                 ISpecialCaseE,
  output logic [P.DURLEN-1:0]  CyclesE,
  output logic [P.DIVBLEN-1:0] IntNormShiftM,
  output logic                 ALTBM, W64M,
  output logic                 AsM, BsM, BZeroM,
  output logic [P.XLEN-1:0]    AM
);

  logic [P.DIVb:0]             Xnorm, Dnorm;
  logic [P.DIVb+3:0]           DivX, DivXShifted, SqrtX, PreShiftX; // Variations of dividend, to be muxed
  logic [P.NE+1:0]             UeE;                                 // Result Exponent (FP only)
  logic [P.DIVb:0]             IFX, IFD;                            // Correctly-sized inputs for iterator, selected from int or fp input
  logic [P.DIVBLEN-1:0]        mE, ell;                             // Leading zeros of inputs
  logic [P.DIVBLEN-1:0]        IntResultBitsE;                      // bits in integer result
  logic                        AZeroE, BZeroE;                      // A or B is Zero for integer division
  logic                        SignedDivE;                          // signed division
  logic                        AsE, BsE;                            // Signs of integer inputs
  logic [P.XLEN-1:0]           AE;                                  // input A after W64 adjustment
  logic                        ALTBE;
  logic                        EvenExp;

  //////////////////////////////////////////////////////
  // Integer Preprocessing
  //////////////////////////////////////////////////////

  if (P.IDIV_ON_FPU) begin : intpreproc // Int Supported
    logic [P.XLEN-1:0] BE, PosA, PosB;

    // Extract inputs, signs, zero, depending on W64 mode if applicable
    assign SignedDivE = ~Funct3E[0];

    // Source handling
    if (P.XLEN==64) begin // 64-bit, supports W64
      mux2 #(64)    amux(ForwardedSrcAE, {{32{ForwardedSrcAE[31] & SignedDivE}}, ForwardedSrcAE[31:0]}, W64E, AE);
      mux2 #(64)    bmux(ForwardedSrcBE, {{32{ForwardedSrcBE[31] & SignedDivE}}, ForwardedSrcBE[31:0]}, W64E, BE);
    end else begin // 32 bits only
      assign AE = ForwardedSrcAE;
      assign BE = ForwardedSrcBE;
     end
    assign AZeroE = ~(|AE);
    assign BZeroE = ~(|BE);
    assign AsE = AE[P.XLEN-1] & SignedDivE;
    assign BsE = BE[P.XLEN-1] & SignedDivE;

    // Force integer inputs to be positive
    mux2 #(P.XLEN) posamux(AE, -AE, AsE, PosA);
    mux2 #(P.XLEN) posbmux(BE, -BE, BsE, PosB);

    // Select integer or floating point inputs
    mux2 #(P.DIVb+1) ifxmux({Xm, {(P.DIVb-P.NF){1'b0}}}, {PosA, {(P.DIVb-P.XLEN+1){1'b0}}}, IntDivE, IFX);
    mux2 #(P.DIVb+1) ifdmux({Ym, {(P.DIVb-P.NF){1'b0}}}, {PosB, {(P.DIVb-P.XLEN+1){1'b0}}}, IntDivE, IFD);
  end else begin // Int not supported
    assign IFX = {Xm, {(P.DIVb-P.NF){1'b0}}};
    assign IFD = {Ym, {(P.DIVb-P.NF){1'b0}}};
  end

  //////////////////////////////////////////////////////
  // Integer & FP leading zero and normalization shift
  //////////////////////////////////////////////////////

  // count leading zeros for Subnorm FP and to normalize integer inputs
  lzc #(P.DIVb+1) lzcX (IFX, ell);
  lzc #(P.DIVb+1) lzcY (IFD, mE);

  // Normalization shift: shift leading one into most significant bit
  assign Xnorm = (IFX << ell);
  assign Dnorm = (IFD << mE);

  //////////////////////////////////////////////////////
  // Integer Right Shift to digit boundary
  //  Determine DivXShifted (X shifted to digit boundary)
  //  and nE (number of fractional digits)
  //////////////////////////////////////////////////////

  if (P.IDIV_ON_FPU) begin : intrightshift // Int Supported
    logic [P.DIVBLEN-1:0] ZeroDiff,p;

    // calculate number of fractional bits p
    assign ZeroDiff = mE - ell;         // Difference in number of leading zeros
    assign ALTBE = ZeroDiff[P.DIVBLEN-1];  // A less than B (A has more leading zeros)
    mux2 #(P.DIVBLEN) pmux(ZeroDiff, '0, ALTBE, p);

    /* verilator lint_off WIDTH */
    assign IntResultBitsE = P.LOGR + p;  // Total number of result bits (r integer bits plus p fractional bits)
    /* verilator lint_on WIDTH */

    // Integer special cases (terminate immediately)
    assign ISpecialCaseE = BZeroE | ALTBE;

    // calculate right shift amount RightShiftX to complete in discrete number of steps
    if (P.RK > 1) begin // more than 1 bit per cycle
      logic [$clog2(P.RK)-1:0] RightShiftX;
      /* verilator lint_off WIDTH */
      assign RightShiftX = P.RK - 1 - ((IntResultBitsE - 1) % P.RK); // Right shift amount
      assign DivXShifted = DivX >> RightShiftX;                     // shift X by up to R*K-1 to complete in n steps
      /* verilator lint_on WIDTH */
    end else begin // radix 2 1 copy doesn't require shifting
      assign DivXShifted = DivX;
    end
  end else begin
    assign {ISpecialCaseE, IntResultBitsE} = '0;
  end

  //////////////////////////////////////////////////////
  // Floating-Point Preprocessing
  // Extend to Q4.b format
  // shift square root to be in range [1/4, 1)
  // Normalized numbers are shifted right by 1 if the exponent is odd
  // Subnormal numbers have Xe = 0 and an unbiased exponent of 1-BIAS.  They are shifted right if the number of leading zeros is odd.
   //////////////////////////////////////////////////////

  assign DivX = {3'b000, Xnorm}; // Zero-extend numerator for division

  // Sqrt is initialized on step one as R(X-1), so depends on Radix
  // If X = 0, then special case logic sets sqrt = 0 so this portion doesn't matter
  // Otherwise, X has a leading 1 after possible normalization shift and is now in range [1, 2)
  // Next X is shifted right by 1 or 2 bits to range [1/4, 1) and exponent will be adjusted accordingly to be even
  // Now (X-1) is negative.  Formed by placing all 1s in all four integer bits (in Q4.b) form, keeping X in fraciton bits
  // Then multiply by R is left shift by r (1 or 2 for radix 2 or 4)
  // This is optimized in hardware by first right shifting by 0 or 1 bit (instead of 1 or 2), then left shifting by (r-1), then subtracting 2 or 4
  // Subtracting 2 is equivalent to adding 1110.  Subtracting 4 is equivalent to adding 1100.  Prepend leading 1s to do a free subtraction.
  // This also means only one extra fractional bit is needed because we never shift right by more than 1.
  // Radix      Exponent odd          Exponent Even
  // 2          x-2 = 2(x/2 - 1)      x/2 - 2 = 2(x/4 - 1)
  // 4          2(x)-4 = 4(x/2 - 1))  2(x/2)-4 = 4(x/4 - 1)
  // Summary: PreSqrtX = r(x/2or4 - 1)

  assign EvenExp = Xe[0] ^ ell[0]; // effective unbiased exponent after normalization is even
  mux2 #(P.DIVb+4) sqrtxmux({4'b0,Xnorm[P.DIVb:1]}, {5'b00, Xnorm[P.DIVb:2]}, EvenExp, SqrtX); // X/2 if exponent odd, X/4 if exponent even

/*
  // Attempt to optimize radix 4 to use a left shift by 1 or zero initially, followed by no more left shift
  // This saves one bit in DIVb because there is no initial right shift.
  // However, C needs to be extended further, lest it create a k with a 1 in the lsb when C is all 1s.
  // That is an optimization for another day.
  if (P.RADIX == 2) begin
    logic [P.DIVb:0] PreSqrtX;    // U1.DIVb
    mux2 #(P.DIVb+1) sqrtxmux(Xnorm, {1'b0, Xnorm[P.DIVb:1]}, EvenExp, PreSqrtX); // X if exponent odd, X/2 if exponent even
    assign SqrtX = {3'b111, PreSqrtX};                          // PreSqrtX - 2 = 2(PreSqrtX/2 - 1)
  end else begin
    logic [P.DIVb+1:0] PreSqrtX;  // U2.DIVb
    mux2 #(P.DIVb+2) sqrtxmux({Xnorm, 1'b0}, {1'b0, Xnorm}, EvenExp, PreSqrtX); // 2X if exponent odd, X if exponent even
    assign SqrtX = {2'b11, PreSqrtX};                     // PreSqrtX - 4 = 4(PreSqrtX/4 - 1)
  end
*/

  // Initialize X for division or square root
  mux2 #(P.DIVb+4) prexmux(DivX, SqrtX, SqrtE, PreShiftX);

  //////////////////////////////////////////////////////
  // Select integer or floating-point operands
  //////////////////////////////////////////////////////

  if (P.IDIV_ON_FPU) begin
    mux2 #(P.DIVb+4) xmux(PreShiftX, DivXShifted, IntDivE, X);
  end else begin
    assign X = PreShiftX;
  end

  // Divisor register
  flopen #(P.DIVb+4) dreg(clk, IFDivStartE, {3'b000, Dnorm}, D);

  // Floating-point exponent
  fdivsqrtexpcalc #(P) expcalc(.Bias, .Xe, .Ye, .Sqrt(SqrtE), .ell, .m(mE), .Ue(UeE));
  flopen #(P.NE+2) expreg(clk, IFDivStartE, UeE, UeM);

  // Number of FSM cycles (to FSM)
  fdivsqrtcycles #(P) cyclecalc(.Nf, .IntDivE, .IntResultBitsE, .CyclesE);

  if (P.IDIV_ON_FPU) begin : intpipelineregs
    logic [P.DIVBLEN-1:0] IntDivNormShiftE, IntRemNormShiftE, IntNormShiftE;
    logic               RemOpE;

    /* verilator lint_off WIDTH */
    assign IntDivNormShiftE = P.INTDIVb - (CyclesE * P.RK - P.LOGR); // b - rn, used for integer normalization right shift.  n = (Cycles * k - 1)
    assign IntRemNormShiftE = mE + (P.INTDIVb-(P.XLEN-1));           // m + b - (N-1) for remainder normalization shift
    /* verilator lint_on WIDTH */
    assign RemOpE = Funct3E[1];
    mux2 #(P.DIVBLEN) normshiftmux(IntDivNormShiftE, IntRemNormShiftE, RemOpE, IntNormShiftE);

    // pipeline registers
    flopen #(1)         altbreg(clk, IFDivStartE, ALTBE,    ALTBM);
    flopen #(1)        bzeroreg(clk, IFDivStartE, BZeroE,   BZeroM);
    flopen #(1)        asignreg(clk, IFDivStartE, AsE,      AsM);
    flopen #(1)        bsignreg(clk, IFDivStartE, BsE,      BsM);
    flopen #(P.DIVBLEN)   nsreg(clk, IFDivStartE, IntNormShiftE, IntNormShiftM);
    flopen #(P.XLEN)    srcareg(clk, IFDivStartE, AE,       AM);
    if (P.XLEN==64)
      flopen #(1)        w64reg(clk, IFDivStartE, W64E,     W64M);
    else assign W64M = 0;
  end else
    assign {ALTBM, W64M, AsM, BsM, BZeroM, AM, IntNormShiftM} = '0;

endmodule
