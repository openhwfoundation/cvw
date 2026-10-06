
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

module fmtparams import cvw::*;  #(parameter cvw_t P) (
  input  logic [P.FMTBITS-1:0] Fmt,
  output logic [P.NE-2:0]      Bias,
  output logic [P.LOGFLEN-1:0] Nf
);

  if (P.FPSIZES == 1) begin
    assign Bias = (P.NE-1)'(P.BIAS);
  end else if (P.FPSIZES == 2) begin
    assign Bias = Fmt ? (P.NE-1)'(P.BIAS) : (P.NE-1)'(P.BIAS1);
  end else if (P.FPSIZES == 3) begin
    always_comb
      case (Fmt)
        P.FMT:  Bias =  (P.NE-1)'(P.BIAS);
        P.FMT1: Bias = (P.NE-1)'(P.BIAS1);
        P.FMT2: Bias = (P.NE-1)'(P.BIAS2);
        default: Bias = 'x;
      endcase
  end else if (P.FPSIZES == 4) begin
    always_comb
      case (Fmt)
        2'h3: Bias =  (P.NE-1)'(P.Q_BIAS);
        2'h1: Bias =  (P.NE-1)'(P.D_BIAS);
        2'h0: Bias =  (P.NE-1)'(P.S_BIAS);
        2'h2: Bias =  (P.NE-1)'(P.H_BIAS);
      endcase
  end

  /* verilator lint_off WIDTH */
  if (P.FPSIZES == 1)
    assign Nf = P.NF;
  else if (P.FPSIZES == 2)
    always_comb
      case (Fmt)
        1'b0: Nf = P.NF1;
        1'b1: Nf = P.NF;
      endcase
  else if (P.FPSIZES == 3)
    always_comb
      case (Fmt)
        P.FMT:   Nf = P.NF;
        P.FMT1:  Nf = P.NF1;
        P.FMT2:  Nf = P.NF2;
        default: Nf = 'x; // shouldn't happen
      endcase
  else if (P.FPSIZES == 4)
    always_comb
      case(Fmt)
        P.S_FMT: Nf = P.S_NF;
        P.D_FMT: Nf = P.D_NF;
        P.H_FMT: Nf = P.H_NF;
        P.Q_FMT: Nf = P.Q_NF;
      endcase
  /* verilator lint_on WIDTH */

endmodule
