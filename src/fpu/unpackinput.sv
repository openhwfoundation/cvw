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

module unpackinput import cvw::*;  #(parameter cvw_t P, parameter V=0,      // V = 1 uses VPU's formats instead of FPU's
  localparam FLEN    = V ? P.VFLEN    : P.FLEN,
  localparam NE      = V ? P.VFNE     : P.NE,
  localparam NF      = V ? P.VFNF     : P.NF,
  localparam FMTBITS = V ? P.VFMTBITS : P.FMTBITS) (
  input  logic [FLEN-1:0]          A,          // inputs from register file
  input  logic                     En,         // enable the input
  input  logic [FMTBITS-1:0]       Fmt,        // format signal 00 - single 01 - double 11 - quad 10 - half
  input  logic                     FPUActive,  // Kill inputs when FPU is not active
  output logic                     Sgn,        // sign bits of the number
  output logic [NE-1:0]            Exp,        // exponent of the number  (converted to largest supported precision)
  output logic [NF:0]              Man,        // mantissa of the number  (converted to largest supported precision)
  output logic                     NaN,        // is the number a NaN
  output logic                     SNaN,       // is the number a signaling NaN
  output logic                     Zero,       // is the number zero
  output logic                     Inf,        // is the number infinity
  output logic                     ExpMax,     // does In have the maximum exponent (NaN or Inf)
  output logic                     Subnorm,    // is the number subnormal
  output logic [FLEN-1:0]          PostBox     // Number reboxed correctly as a NaN
);

  localparam FPSIZES = V ? P.VFPSIZES : P.FPSIZES;
  localparam FMT     = V ? P.VFMT     : P.FMT;
  localparam LEN1    = V ? P.VFLEN1   : P.LEN1;
  localparam NE1     = V ? P.VFNE1    : P.NE1;
  localparam NF1     = V ? P.VFNF1    : P.NF1;
  localparam FMT1    = V ? P.VFMT1    : P.FMT1;
  localparam LEN2    = V ? P.VFLEN2   : P.LEN2;
  localparam NE2     = V ? P.VFNE2    : P.NE2;
  localparam NF2     = V ? P.VFNF2    : P.NF2;
  localparam FMT2    = V ? P.VFMT2    : P.FMT2;

  logic [NF-1:0]   Frac;        // Fraction of XYZ
  logic            BadNaNBox;   // incorrectly NaN Boxed
  logic            FracZero;    // is the fraction zero
  logic            ExpNonZero;  // is the exponent non-zero
  logic [FLEN-1:0] In;

  // Gate input when FPU is not active to save power and simulation
  assign In = A & {FLEN{FPUActive}};

  if (FPSIZES == 1) begin          // if there is only one floating point format supported
      assign BadNaNBox = 1'b0;
      assign Sgn = In[FLEN-1];  // sign bit
      assign Frac = In[NF-1:0];  // fraction (no assumed 1)
      assign ExpNonZero = |In[FLEN-2:NF];  // is the exponent non-zero
      assign Exp = {In[FLEN-2:NF+1], In[NF]|~ExpNonZero};  // exponent.  subnormal numbers have effective biased exponent of 1
      assign ExpMax = &In[FLEN-2:NF];  // is the exponent all 1's
      assign PostBox = In;

  end else if (FPSIZES == 2) begin     // if there are 2 floating point formats supported
      //  largest format | smaller format
      //----------------------------------
      //      FLEN       |     LEN1         length of floating point number
      //      NE         |     NE1          length of exponent
      //      NF         |     NF1          length of fraction
      //      BIAS       |     BIAS1        exponent's bias value
      //      FMT        |     FMT1         precision's format value - Q=11 D=01 Sticky=00 H=10

      // Possible combinantions specified by spec:
      //      double and single
      //      single and half

      // Not needed but can also handle:
      //      quad   and double
      //      quad   and single
      //      quad   and half
      //      double and half

      assign BadNaNBox = ~(Fmt|(&In[FLEN-1:LEN1])); // Check NaN boxing
      always_comb
        if (BadNaNBox) begin
          PostBox = {{(FLEN-LEN1){1'b1}}, 1'b1, {(NE1+1){1'b1}}, {(LEN1-NE1-2){1'b0}}};
        end else
          PostBox = In;

      // choose sign bit depending on format - 1=larger precision 0=smaller precision
      assign Sgn = Fmt ? In[FLEN-1] : (BadNaNBox ? 0 : In[LEN1-1]); // improperly boxed NaNs are treated as positive

      // extract the fraction, add trailing zeroes to the mantissa if necessary
      assign Frac = Fmt ? In[NF-1:0] : {In[NF1-1:0], (NF-NF1)'(0)};

      // is the exponent non-zero
      assign ExpNonZero = Fmt ? |In[FLEN-2:NF] : |In[LEN1-2:NF1];

      // example double to single conversion:
      // 1023 = 0011 1111 1111
      // 127  = 0000 0111 1111 (subtract this)
      // 896  = 0011 1000 0000
      // sexp = 0000 bbbb bbbb (add this) b = bit d = ~b
      // dexp = 0bdd dbbb bbbb
      // also need to take into account possible zero/Subnorm/inf/NaN values

      // extract the exponent, converting the smaller exponent into the larger precision if necessary
      //      - if the original precision had a Subnormal number convert the exponent value 1
      assign Exp = Fmt ? {In[FLEN-2:NF+1], In[NF]|~ExpNonZero} : {In[LEN1-2], {NE-NE1{~In[LEN1-2]}}, In[LEN1-3:NF1+1], In[NF1]|~ExpNonZero};

      // is the exponent all 1's
      assign ExpMax = Fmt ? &In[FLEN-2:NF] : &In[LEN1-2:NF1];

  end else if (FPSIZES == 3) begin         // three floating point precisions supported

      //  largest format |  larger format  | smallest format
      //---------------------------------------------------
      //      FLEN       |     LEN1        |    LEN2         length of floating point number
      //      NE         |     NE1         |    NE2          length of exponent
      //      NF         |     NF1         |    NF2          length of fraction
      //      BIAS       |     BIAS1       |    BIAS2        exponent's bias value
      //      FMT        |     FMT1        |    FMT2         precision's format value - Q=11 D=01 Sticky=00 H=10

      // Possible combinantions specified by spec:
      //      quad   and double and single
      //      double and single and half

      // Not needed but can also handle:
      //      quad   and double and half
      //      quad   and single and half

      // Check NaN boxing
      always_comb
          case (Fmt)
              FMT:    BadNaNBox = 1'b0;
              FMT1:   BadNaNBox = ~&In[FLEN-1:LEN1];
              FMT2:   BadNaNBox = ~&In[FLEN-1:LEN2];
              default: BadNaNBox = 1'bx;
          endcase

      always_comb
        if (BadNaNBox & Fmt == FMT1)
            PostBox = {{(FLEN-LEN1){1'b1}}, 1'b1, {(NE1+1){1'b1}}, {(LEN1-NE1-2){1'b0}}};
        else if (BadNaNBox) // Fmt == FMT2
            PostBox = {{(FLEN-LEN2){1'b1}}, 1'b1, {(NE2+1){1'b1}}, {(LEN2-NE2-2){1'b0}}};
        else
            PostBox = In;

      // extract the sign bit
      always_comb
        if (BadNaNBox) Sgn = 1'b0; // improperly boxed NaNs are treated as positive
        else
          case (Fmt)
              FMT:     Sgn = In[FLEN-1];
              FMT1:    Sgn = In[LEN1-1];
              FMT2:    Sgn = In[LEN2-1];
              default: Sgn = 1'bx;
          endcase

       // extract the fraction
      always_comb
          case (Fmt)
              FMT:     Frac = In[NF-1:0];
              FMT1:    Frac = {In[NF1-1:0], (NF-NF1)'(0)};
              FMT2:    Frac = {In[NF2-1:0], (NF-NF2)'(0)};
              default: Frac = {NF{1'bx}};
          endcase

      // is the exponent non-zero
      always_comb
          case (Fmt)
              FMT:     ExpNonZero = |In[FLEN-2:NF];   // if input is largest precision (FLEN - ie quad or double)
              FMT1:    ExpNonZero = |In[LEN1-2:NF1];  // if input is larger precision (LEN1 - double or single)
              FMT2:    ExpNonZero = |In[LEN2-2:NF2];  // if input is smallest precision (LEN2 - single or half)
              default: ExpNonZero = 1'bx;
          endcase

      // example double to single conversion:
      // 1023 = 0011 1111 1111
      // 127  = 0000 0111 1111 (subtract this)
      // 896  = 0011 1000 0000
      // sexp = 0000 bbbb bbbb (add this) b = bit d = ~b
      // dexp = 0bdd dbbb bbbb
      // also need to take into account possible zero/Subnorm/inf/NaN values

      // convert the larger precision's exponent to use the largest precision's bias
      always_comb
          case (Fmt)
              FMT:    Exp = {In[FLEN-2:NF+1], In[NF]|~ExpNonZero};
              FMT1:   Exp = {In[LEN1-2], {NE-NE1{~In[LEN1-2]}}, In[LEN1-3:NF1+1], In[NF1]|~ExpNonZero};
              FMT2:   Exp = {In[LEN2-2], {NE-NE2{~In[LEN2-2]}}, In[LEN2-3:NF2+1], In[NF2]|~ExpNonZero};
              default: Exp = {NE{1'bx}};
          endcase

      // is the exponent all 1's
      always_comb
          case (Fmt)
              FMT:    ExpMax = &In[FLEN-2:NF];
              FMT1:   ExpMax = &In[LEN1-2:NF1];
              FMT2:   ExpMax = &In[LEN2-2:NF2];
              default: ExpMax = 1'bx;
          endcase

  end else if (FPSIZES == 4) begin        // if all precsisons are supported - quad, double, single, and half

      //    quad    |    double    |  single   |  half
      //-------------------------------------------------------------------
      //   P.Q_LEN  |  P.D_LEN     |  P.S_LEN  |  P.H_LEN     length of floating point number
      //   P.Q_NE   |  P.D_NE      |  P.S_NE   |  P.H_NE      length of exponent
      //   P.Q_NF   |  P.D_NF      |  P.S_NF   |  P.H_NF      length of fraction
      //   P.Q_BIAS |  P.D_= 1'b1; |  P.S_BIAS |  P.H_BIAS    exponent's bias value
      //   P.Q_FMT  |  P.D_FMT     |  P.S_FMT  |  P.H_FMT     precision's format value - Q=11 D=01 Sticky=00 H=10

      // Check NaN boxing
      always_comb
          case (Fmt)
              2'b11: BadNaNBox = 1'b0;
              2'b01: BadNaNBox = ~&In[P.Q_LEN-1:P.D_LEN];
              2'b00: BadNaNBox = ~&In[P.Q_LEN-1:P.S_LEN];
              2'b10: BadNaNBox = ~&In[P.Q_LEN-1:P.H_LEN];
          endcase

      always_comb
        if (BadNaNBox) begin
          case (Fmt)
            2'b11: PostBox = In;
            2'b01: PostBox = {{(P.Q_LEN-P.D_LEN){1'b1}}, 1'b1, {(P.D_NE+1){1'b1}}, {(P.D_LEN-P.D_NE-2){1'b0}}};
            2'b00: PostBox = {{(P.Q_LEN-P.S_LEN){1'b1}}, 1'b1, {(P.S_NE+1){1'b1}}, {(P.S_LEN-P.S_NE-2){1'b0}}};
            2'b10: PostBox = {{(P.Q_LEN-P.H_LEN){1'b1}}, 1'b1, {(P.H_NE+1){1'b1}}, {(P.H_LEN-P.H_NE-2){1'b0}}};
          endcase
        end else
          PostBox = In;

      // extract sign bit
      always_comb
        if (BadNaNBox) Sgn = 1'b0; // improperly boxed NaNs are treated as positive
        else
          case (Fmt)
              2'b11: Sgn = In[P.Q_LEN-1];
              2'b01: Sgn = In[P.D_LEN-1];
              2'b00: Sgn = In[P.S_LEN-1];
              2'b10: Sgn = In[P.H_LEN-1];
          endcase

      // extract the fraction
      always_comb
          case (Fmt)
              2'b11: Frac = In[P.Q_NF-1:0];
              2'b01: Frac = {In[P.D_NF-1:0], (P.Q_NF-P.D_NF)'(0)};
              2'b00: Frac = {In[P.S_NF-1:0], (P.Q_NF-P.S_NF)'(0)};
              2'b10: Frac = {In[P.H_NF-1:0], (P.Q_NF-P.H_NF)'(0)};
          endcase

      // is the exponent non-zero
      always_comb
          case (Fmt)
              2'b11: ExpNonZero = |In[P.Q_LEN-2:P.Q_NF];
              2'b01: ExpNonZero = |In[P.D_LEN-2:P.D_NF];
              2'b00: ExpNonZero = |In[P.S_LEN-2:P.S_NF];
              2'b10: ExpNonZero = |In[P.H_LEN-2:P.H_NF];
          endcase

      // example double to single conversion:
      // 1023 = 0011 1111 1111
      // 127  = 0000 0111 1111 (subtract this)
      // 896  = 0011 1000 0000
      // sexp = 0000 bbbb bbbb (add this) b = bit d = ~b
      // dexp = 0bdd dbbb bbbb
      // also need to take into account possible zero/Subnorm/inf/NaN values

      // convert the double precision exponent into quad precision
      // 1 is added to the exponent if the input is zero or subnormal
      always_comb
          case (Fmt)
              2'b11: Exp = {In[P.Q_LEN-2:P.Q_NF+1], In[P.Q_NF]|~ExpNonZero};
              2'b01: Exp = {In[P.D_LEN-2], {P.Q_NE-P.D_NE{~In[P.D_LEN-2]}}, In[P.D_LEN-3:P.D_NF+1], In[P.D_NF]|~ExpNonZero};
              2'b00: Exp = {In[P.S_LEN-2], {P.Q_NE-P.S_NE{~In[P.S_LEN-2]}}, In[P.S_LEN-3:P.S_NF+1], In[P.S_NF]|~ExpNonZero};
              2'b10: Exp = {In[P.H_LEN-2], {P.Q_NE-P.H_NE{~In[P.H_LEN-2]}}, In[P.H_LEN-3:P.H_NF+1], In[P.H_NF]|~ExpNonZero};
          endcase

      // is the exponent all 1's
      always_comb
          case (Fmt)
              2'b11: ExpMax = &In[P.Q_LEN-2:P.Q_NF];
              2'b01: ExpMax = &In[P.D_LEN-2:P.D_NF];
              2'b00: ExpMax = &In[P.S_LEN-2:P.S_NF];
              2'b10: ExpMax = &In[P.H_LEN-2:P.H_NF];
          endcase

  end

  // Output logic
  assign FracZero = ~|Frac & ~BadNaNBox; // is the fraction zero?
  assign Man = {ExpNonZero, Frac}; // add the assumed one (or zero if Subnormal or zero) to create the significand
  assign NaN = ((ExpMax & ~FracZero)|BadNaNBox)&En; // is the input a NaN?
  assign SNaN = NaN&~Frac[NF-1]&~BadNaNBox; // is the input a signaling NaN?
  assign Inf = ExpMax & FracZero & En; // is the input infinity?
  assign Zero = ~ExpNonZero & FracZero; // is the input zero?
  assign Subnorm = ~ExpNonZero & ~FracZero & ~BadNaNBox; // is the input subnormal

endmodule
