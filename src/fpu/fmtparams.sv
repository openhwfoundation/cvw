
///////////////////////////////////////////
// fmtparams.sv
//
// Written: David_Harris@hmc.edu
// Modified: 5/11/24
//
// Purpose: Look up bias of exponent and number of fractional bits for the selected format
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

module fmtparams import cvw::*;  #(parameter cvw_t P, parameter V=0,        // V = 1 uses VPU's formats instead of FPU's
  localparam FMTBITS = V ? P.VFMTBITS  : P.FMTBITS,
  localparam NE      = V ? P.VFNE      : P.NE,
  localparam LOGFLEN = V ? P.VFLOGFLEN : P.LOGFLEN) (
  input  logic [FMTBITS-1:0]   Fmt,
  output logic [NE-2:0]        Bias,
  output logic [LOGFLEN-1:0]   Nf
);

  localparam FPSIZES = V ? P.VFPSIZES : P.FPSIZES;
  localparam NF      = V ? P.VFNF     : P.NF;
  localparam FMT     = V ? P.VFMT     : P.FMT;
  localparam BIAS    = V ? P.VFBIAS   : P.BIAS;
  localparam NF1     = V ? P.VFNF1    : P.NF1;
  localparam FMT1    = V ? P.VFMT1    : P.FMT1;
  localparam BIAS1   = V ? P.VFBIAS1  : P.BIAS1;
  localparam NF2     = V ? P.VFNF2    : P.NF2;
  localparam FMT2    = V ? P.VFMT2    : P.FMT2;
  localparam BIAS2   = V ? P.VFBIAS2  : P.BIAS2;

  if (FPSIZES == 1) begin
    assign Bias = (NE-1)'(BIAS);
  end else if (FPSIZES == 2) begin
    assign Bias = Fmt ? (NE-1)'(BIAS) : (NE-1)'(BIAS1);
  end else if (FPSIZES == 3) begin
    always_comb
      case (Fmt)
        FMT:    Bias =  (NE-1)'(BIAS);
        FMT1:   Bias = (NE-1)'(BIAS1);
        FMT2:   Bias = (NE-1)'(BIAS2);
        default: Bias = 'x;
      endcase
  end else if (FPSIZES == 4) begin
    always_comb
      case (Fmt)
        2'h3: Bias =  (NE-1)'(P.Q_BIAS);
        2'h1: Bias =  (NE-1)'(P.D_BIAS);
        2'h0: Bias =  (NE-1)'(P.S_BIAS);
        2'h2: Bias =  (NE-1)'(P.H_BIAS);
      endcase
  end

  /* verilator lint_off WIDTH */
  if (FPSIZES == 1)
    assign Nf = NF;
  else if (FPSIZES == 2)
    always_comb
      case (Fmt)
        1'b0: Nf = NF1;
        1'b1: Nf = NF;
      endcase
  else if (FPSIZES == 3)
    always_comb
      case (Fmt)
        FMT:     Nf = NF;
        FMT1:    Nf = NF1;
        FMT2:    Nf = NF2;
        default: Nf = 'x; // shouldn't happen
      endcase
  else if (FPSIZES == 4)
    always_comb
      case(Fmt)
        P.S_FMT: Nf = P.S_NF;
        P.D_FMT: Nf = P.D_NF;
        P.H_FMT: Nf = P.H_NF;
        P.Q_FMT: Nf = P.Q_NF;
      endcase
  /* verilator lint_on WIDTH */

endmodule
