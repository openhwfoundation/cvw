///////////////////////////////////////////
// unpackinput.sv
//
// Written: me@KatherineParry.com
// Modified: 7/5/2022
//
// Purpose: unpack input: extract sign, exponent, significand, characteristics
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

module unpackinput import cvw::*; #(parameter cvw_t P) (
  input  logic [P.FLEN-1:0]        A,          // Input from FP register file
  input  logic                     En,         // enable the input
  input  logic [P.FMTBITS-1:0]     Fmt,        // FP format: 00 single, 01 double, 10 half, 11 quad
  input  logic                     FPUActive,  // Kill inputs when FPU is not active
  output logic                     Sgn,        // sign bits of the number
  output logic [P.NE-1:0]          Exp,        // exponent of the number  (converted to largest supported precision)
  output logic [P.NF:0]            Man,        // mantissa of the number  (converted to largest supported precision)
  output logic                     NaN,        // is the number a NaN
  output logic                     SNaN,       // is the number a signaling NaN
  output logic                     Zero,       // is the number zero
  output logic                     Inf,        // is the number infinity
  output logic                     ExpMax,     // Exponent is all ones (NaN or Inf)
  output logic                     Subnorm,    // is the number subnormal
  output logic [P.FLEN-1:0]        PostBox     // Number reboxed correctly as a NaN
);

  logic [P.NF-1:0]   Frac;        // Fraction of XYZ
  logic              BadNaNBox;   // incorrectly NaN Boxed
  logic              FracZero;    // is the fraction zero
  logic              ExpNonZero;  // is the exponent non-zero
  logic [P.NE-1:0]   BiasedExp;   // exponent converted to the largest supported precision, before the subnormal adjustment
  logic [P.FLEN-1:0] In;

  // Inputs in a smaller format are converted to the largest supported precision:
  //   - the fraction gets trailing zeros
  //   - the exponent is re-biased by keeping its msb, inserting NE-NEx copies of ~msb, and keeping the low bits.
  //     Example single to double conversion, adding the bias difference 1023 - 127 = 896:
  //       1023 = 0011 1111 1111
  //       127  = 0000 0111 1111 (subtract this)
  //       896  = 0011 1000 0000
  //       sexp = 0000 bbbb bbbb (add this) b = bit d = ~b
  //       dexp = 0bdd dbbb bbbb
  //   - zero, subnormal, infinity, and NaN are detected from the unconverted exponent (ExpNonZero, ExpMax)
  //   - a subnormal number has an effective biased exponent of 1, so the exponent lsb is forced to 1 when the exponent is zero

  // Gate input when FPU is not active to save power and simulation
  assign In = A & {P.FLEN{FPUActive}};

  if (P.FPSIZES == 1) begin        // if there is only one floating point format supported
    assign BadNaNBox = 1'b0;
    assign Sgn = In[P.FLEN-1];  // sign bit
    assign Frac = In[P.NF-1:0];  // fraction (no assumed 1)
    assign ExpNonZero = |In[P.FLEN-2:P.NF];  // is the exponent non-zero
    assign BiasedExp = In[P.FLEN-2:P.NF];  // exponent
    assign ExpMax = &In[P.FLEN-2:P.NF];  // is the exponent all 1's
    assign PostBox = In;

  end else if (P.FPSIZES == 2) begin   // if there are 2 floating point formats supported
    // largest format | smaller format
    //----------------------------------
    //      P.FLEN     |     P.LEN1       length of floating point number
    //      P.NE       |     P.NE1        length of exponent
    //      P.NF       |     P.NF1        length of fraction
    //      P.BIAS     |     P.BIAS1      exponent's bias value
    //      P.FMT      |     P.FMT1       precision's format value - Q=11 D=01 S=00 H=10

    // Possible combinations specified by spec:
    //      double and single
    //      single and half

    // Not needed but can also handle:
    //      quad   and double
    //      quad   and single
    //      quad   and half
    //      double and half

    assign BadNaNBox = ~(Fmt | (&In[P.FLEN-1:P.LEN1])); // Check NaN boxing: the smaller format (Fmt = 0) needs all upper bits set
    always_comb
      if (BadNaNBox) begin // replace an improperly boxed input with a NaN-boxed quiet NaN
        PostBox = {{(P.FLEN-P.LEN1){1'b1}}, 1'b1, {(P.NE1+1){1'b1}}, {(P.LEN1-P.NE1-2){1'b0}}};
      end else
        PostBox = In;

    // choose sign bit depending on format - 1=larger precision 0=smaller precision
    assign Sgn = Fmt ? In[P.FLEN-1] : (BadNaNBox ? 0 : In[P.LEN1-1]); // improperly boxed NaNs are treated as positive

    // extract the fraction, add trailing zeroes to the mantissa if necessary
    assign Frac = Fmt ? In[P.NF-1:0] : {In[P.NF1-1:0], (P.NF-P.NF1)'(0)};

    // is the exponent non-zero
    assign ExpNonZero = Fmt ? |In[P.FLEN-2:P.NF] : |In[P.LEN1-2:P.NF1];

    // extract the exponent, converting the smaller exponent into the larger precision if necessary
    assign BiasedExp = Fmt ? In[P.FLEN-2:P.NF] : {In[P.LEN1-2], {P.NE-P.NE1{~In[P.LEN1-2]}}, In[P.LEN1-3:P.NF1]};

    // is the exponent all 1's
    assign ExpMax = Fmt ? &In[P.FLEN-2:P.NF] : &In[P.LEN1-2:P.NF1];

  end else if (P.FPSIZES == 3) begin       // three floating point precisions supported

    // largest format | larger format  | smallest format
    //---------------------------------------------------
    //      P.FLEN     |     P.LEN1      |    P.LEN2       length of floating point number
    //      P.NE       |     P.NE1       |    P.NE2        length of exponent
    //      P.NF       |     P.NF1       |    P.NF2        length of fraction
    //      P.BIAS     |     P.BIAS1     |    P.BIAS2      exponent's bias value
    //      P.FMT      |     P.FMT1      |    P.FMT2       precision's format value - Q=11 D=01 S=00 H=10

    // Possible combinations specified by spec:
    //      quad   and double and single
    //      double and single and half

    // Not needed but can also handle:
    //      quad   and double and half
    //      quad   and single and half

    // Check NaN boxing
    always_comb
      case (Fmt)
        P.FMT:  BadNaNBox = 1'b0;
        P.FMT1: BadNaNBox = ~&In[P.FLEN-1:P.LEN1];
        P.FMT2: BadNaNBox = ~&In[P.FLEN-1:P.LEN2];
        default: BadNaNBox = 1'bx;
      endcase

    always_comb
      if (BadNaNBox & Fmt == P.FMT1)
        PostBox = {{(P.FLEN-P.LEN1){1'b1}}, 1'b1, {(P.NE1+1){1'b1}}, {(P.LEN1-P.NE1-2){1'b0}}};
      else if (BadNaNBox) // Fmt == P.FMT2
        PostBox = {{(P.FLEN-P.LEN2){1'b1}}, 1'b1, {(P.NE2+1){1'b1}}, {(P.LEN2-P.NE2-2){1'b0}}};
      else
        PostBox = In;

    // extract the sign bit
    always_comb
      if (BadNaNBox) Sgn = 1'b0; // improperly boxed NaNs are treated as positive
      else
        case (Fmt)
          P.FMT:   Sgn = In[P.FLEN-1];
          P.FMT1:  Sgn = In[P.LEN1-1];
          P.FMT2:  Sgn = In[P.LEN2-1];
          default: Sgn = 1'bx;
        endcase

    // extract the fraction
    always_comb
      case (Fmt)
        P.FMT:   Frac = In[P.NF-1:0];
        P.FMT1:  Frac = {In[P.NF1-1:0], (P.NF-P.NF1)'(0)};
        P.FMT2:  Frac = {In[P.NF2-1:0], (P.NF-P.NF2)'(0)};
        default: Frac = {P.NF{1'bx}};
      endcase

    // is the exponent non-zero
    always_comb
      case (Fmt)
        P.FMT:   ExpNonZero = |In[P.FLEN-2:P.NF];   // if input is largest precision (P.FLEN - ie quad or double)
        P.FMT1:  ExpNonZero = |In[P.LEN1-2:P.NF1];  // if input is larger precision (P.LEN1 - double or single)
        P.FMT2:  ExpNonZero = |In[P.LEN2-2:P.NF2];  // if input is smallest precision (P.LEN2 - single or half)
        default: ExpNonZero = 1'bx;
      endcase

    // convert the exponent to use the largest precision's bias
    always_comb
      case (Fmt)
        P.FMT:   BiasedExp = In[P.FLEN-2:P.NF];
        P.FMT1:  BiasedExp = {In[P.LEN1-2], {P.NE-P.NE1{~In[P.LEN1-2]}}, In[P.LEN1-3:P.NF1]};
        P.FMT2:  BiasedExp = {In[P.LEN2-2], {P.NE-P.NE2{~In[P.LEN2-2]}}, In[P.LEN2-3:P.NF2]};
        default: BiasedExp = {P.NE{1'bx}};
      endcase

    // is the exponent all 1's
    always_comb
      case (Fmt)
        P.FMT:   ExpMax = &In[P.FLEN-2:P.NF];
        P.FMT1:  ExpMax = &In[P.LEN1-2:P.NF1];
        P.FMT2:  ExpMax = &In[P.LEN2-2:P.NF2];
        default: ExpMax = 1'bx;
      endcase

  end else if (P.FPSIZES == 4) begin      // if all precisions are supported - quad, double, single, and half

    //    quad    |  double   |  single   |  half
    //-------------------------------------------------------------------
    //   P.Q_LEN  |  P.D_LEN  |  P.S_LEN  |  P.H_LEN     length of floating point number
    //   P.Q_NE   |  P.D_NE   |  P.S_NE   |  P.H_NE      length of exponent
    //   P.Q_NF   |  P.D_NF   |  P.S_NF   |  P.H_NF      length of fraction
    //   P.Q_BIAS |  P.D_BIAS |  P.S_BIAS |  P.H_BIAS    exponent's bias value
    //   P.Q_FMT  |  P.D_FMT  |  P.S_FMT  |  P.H_FMT     precision's format value - Q=11 D=01 S=00 H=10

    // Check NaN boxing
    always_comb
      case (Fmt)
        P.Q_FMT: BadNaNBox = 1'b0;
        P.D_FMT: BadNaNBox = ~&In[P.Q_LEN-1:P.D_LEN];
        P.S_FMT: BadNaNBox = ~&In[P.Q_LEN-1:P.S_LEN];
        P.H_FMT: BadNaNBox = ~&In[P.Q_LEN-1:P.H_LEN];
      endcase

    always_comb
      if (BadNaNBox) begin
        case (Fmt)
          P.Q_FMT: PostBox = In;
          P.D_FMT: PostBox = {{(P.Q_LEN-P.D_LEN){1'b1}}, 1'b1, {(P.D_NE+1){1'b1}}, {(P.D_LEN-P.D_NE-2){1'b0}}};
          P.S_FMT: PostBox = {{(P.Q_LEN-P.S_LEN){1'b1}}, 1'b1, {(P.S_NE+1){1'b1}}, {(P.S_LEN-P.S_NE-2){1'b0}}};
          P.H_FMT: PostBox = {{(P.Q_LEN-P.H_LEN){1'b1}}, 1'b1, {(P.H_NE+1){1'b1}}, {(P.H_LEN-P.H_NE-2){1'b0}}};
        endcase
      end else
        PostBox = In;

    // extract sign bit
    always_comb
      if (BadNaNBox) Sgn = 1'b0; // improperly boxed NaNs are treated as positive
      else
        case (Fmt)
          P.Q_FMT: Sgn = In[P.Q_LEN-1];
          P.D_FMT: Sgn = In[P.D_LEN-1];
          P.S_FMT: Sgn = In[P.S_LEN-1];
          P.H_FMT: Sgn = In[P.H_LEN-1];
        endcase

    // extract the fraction
    always_comb
      case (Fmt)
        P.Q_FMT: Frac = In[P.Q_NF-1:0];
        P.D_FMT: Frac = {In[P.D_NF-1:0], (P.Q_NF-P.D_NF)'(0)};
        P.S_FMT: Frac = {In[P.S_NF-1:0], (P.Q_NF-P.S_NF)'(0)};
        P.H_FMT: Frac = {In[P.H_NF-1:0], (P.Q_NF-P.H_NF)'(0)};
      endcase

    // is the exponent non-zero
    always_comb
      case (Fmt)
        P.Q_FMT: ExpNonZero = |In[P.Q_LEN-2:P.Q_NF];
        P.D_FMT: ExpNonZero = |In[P.D_LEN-2:P.D_NF];
        P.S_FMT: ExpNonZero = |In[P.S_LEN-2:P.S_NF];
        P.H_FMT: ExpNonZero = |In[P.H_LEN-2:P.H_NF];
      endcase

    // convert the exponent into quad precision
    always_comb
      case (Fmt)
        P.Q_FMT: BiasedExp = In[P.Q_LEN-2:P.Q_NF];
        P.D_FMT: BiasedExp = {In[P.D_LEN-2], {P.Q_NE-P.D_NE{~In[P.D_LEN-2]}}, In[P.D_LEN-3:P.D_NF]};
        P.S_FMT: BiasedExp = {In[P.S_LEN-2], {P.Q_NE-P.S_NE{~In[P.S_LEN-2]}}, In[P.S_LEN-3:P.S_NF]};
        P.H_FMT: BiasedExp = {In[P.H_LEN-2], {P.Q_NE-P.H_NE{~In[P.H_LEN-2]}}, In[P.H_LEN-3:P.H_NF]};
      endcase

    // is the exponent all 1's
    always_comb
      case (Fmt)
        P.Q_FMT: ExpMax = &In[P.Q_LEN-2:P.Q_NF];
        P.D_FMT: ExpMax = &In[P.D_LEN-2:P.D_NF];
        P.S_FMT: ExpMax = &In[P.S_LEN-2:P.S_NF];
        P.H_FMT: ExpMax = &In[P.H_LEN-2:P.H_NF];
      endcase

  end

  // Output logic
  assign Exp = {BiasedExp[P.NE-1:1], BiasedExp[0] | ~ExpNonZero}; // subnormal numbers have effective biased exponent of 1
  assign FracZero = ~|Frac & ~BadNaNBox; // is the fraction zero?
  assign Man = {ExpNonZero, Frac}; // add the assumed one (or zero if Subnormal or zero) to create the significand
  assign NaN = ((ExpMax & ~FracZero) | BadNaNBox) & En; // is the input a NaN?
  assign SNaN = NaN & ~Frac[P.NF-1] & ~BadNaNBox; // is the input a signaling NaN? (quiet bit clear)
  assign Inf = ExpMax & FracZero & En; // is the input infinity?
  assign Zero = ~ExpNonZero & FracZero; // is the input zero?
  assign Subnorm = ~ExpNonZero & ~FracZero & ~BadNaNBox; // is the input subnormal

endmodule
