
///////////////////////////////////////////
// packoutput.sv
//
// Written: David_Harris@hmc.edu
// Modified: 5/11/24
//
// Purpose: Pack the output of the FPU
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

module packoutput import cvw::*;  #(parameter cvw_t P) (
  input  logic [P.FLEN-1:0]       Unpacked,
  input  logic [P.FMTBITS-1:0]    Fmt,
  output logic [P.FLEN-1:0]       Packed
);

  logic             Sign;
  logic [P.NE1-1:0] Exp1;
  logic [P.NF1-1:0] Fract1;
  logic [P.NE2-1:0] Exp2;
  logic [P.NF2-1:0] Fract2;
  logic [P.H_NE-1:0] Exp3;
  logic [P.H_NF-1:0] Fract3;

  // Pack exponent and fraction, with NaN-boxing to full FLEN

  assign Sign = Unpacked[P.FLEN-1];
  if (P.FPSIZES == 1) begin
    assign Packed = Unpacked;
  end else if (P.FPSIZES == 2) begin
    always_comb begin
      {Exp1, Fract1} = '0; // default if not used, to prevent latch
      case (Fmt)
        1'b1: Packed = Unpacked;
        1'b0: begin
                Exp1 = {Unpacked[P.FLEN-2], Unpacked[P.NF+P.NE1-2:P.NF]};
                Fract1 = Unpacked[P.NF-1:P.NF-P.NF1];
                Packed = {{(P.FLEN-P.LEN1){1'b1}}, Sign, Exp1, Fract1};
              end
      endcase
    end
  end else if (P.FPSIZES == 3) begin
    always_comb begin
      {Exp1, Fract1, Exp2, Fract2} = '0; // default if not used, to prevent latch
      case (Fmt)
        P.FMT: Packed = Unpacked;
        P.FMT1: begin
                Exp1 = {Unpacked[P.FLEN-2], Unpacked[P.NF+P.NE1-2:P.NF]};
                Fract1 = Unpacked[P.NF-1:P.NF-P.NF1];
                Packed = {{(P.FLEN-P.LEN1){1'b1}}, Sign, Exp1, Fract1};
              end
        P.FMT2: begin
                Exp2 = {Unpacked[P.FLEN-2], Unpacked[P.NF+P.NE2-2:P.NF]};
                Fract2 = Unpacked[P.NF-1:P.NF-P.NF2];
                Packed = {{(P.FLEN-P.LEN2){1'b1}}, Sign, Exp2, Fract2};
              end
        default: Packed = 'x;
      endcase
    end
  end else if (P.FPSIZES == 4) begin
    always_comb begin
      {Exp1, Fract1, Exp2, Fract2, Exp3, Fract3} = '0; // default if not used, to prevent latch
      case (Fmt)
        2'h3: Packed = Unpacked;  // Quad
        2'h1: begin // double
                Exp1 = {Unpacked[P.FLEN-2], Unpacked[P.NF+P.NE1-2:P.NF]};
                Fract1 = Unpacked[P.NF-1:P.NF-P.NF1];
                Packed = {{(P.FLEN-P.LEN1){1'b1}}, Sign, Exp1, Fract1};
              end
        2'h0: begin // float
                Exp2 = {Unpacked[P.FLEN-2], Unpacked[P.NF+P.NE2-2:P.NF]};
                Fract2 = Unpacked[P.NF-1:P.NF-P.NF2];
                Packed = {{(P.FLEN-P.LEN2){1'b1}}, Sign, Exp2, Fract2};
              end
        2'h2: begin // half
                Exp3 = {Unpacked[P.FLEN-2], Unpacked[P.NF+P.H_NE-2:P.NF]};
                Fract3 = Unpacked[P.NF-1:P.NF-P.H_NF];
                Packed = {{(P.FLEN-P.H_LEN){1'b1}}, Sign, Exp3, Fract3};
              end
      endcase
    end
  end
endmodule
