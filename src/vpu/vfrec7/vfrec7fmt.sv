///////////////////////////////////////////
// vfrec7fmt.sv
//
// Written: nfotneos@g.hmc.edu 2026-09-18
//
// Purpose: Per-SEW format selection for vfrec7: native exponent bias and the
//          special-case result constants, each placed in the shared P.FLEN field.
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
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

module vfrec7fmt import cvw::*; #(parameter cvw_t P) (
  input  logic [2:0]         Vsew,

  output logic                ValidSew,      // Vsew is one of the supported encodings below
  output logic signed [12:0]  NativeBias,    // this SEW's native exponent bias
  output logic [P.FLEN-1:0]   SignMask,      // this SEW's sign bit, placed in the shared field
  output logic [P.FLEN-1:0]   PosInf,        // this SEW's +infinity, placed in the shared field
  output logic [P.FLEN-1:0]   MaxFinite,     // this SEW's +max finite, placed in the shared field
  output logic [P.FLEN-1:0]   CanonicalNan   // this SEW's canonical NaN, placed in the shared field
);

  localparam logic [2:0] VSEW_16 = 3'b001;
  localparam logic [2:0] VSEW_32 = 3'b010;
  localparam logic [2:0] VSEW_64 = 3'b011;

  // SEW=8 and reserved encodings are unsupported by vfrec7
  always_comb
    case (Vsew)
      VSEW_16, VSEW_32, VSEW_64: ValidSew = 1'b1;
      default:                   ValidSew = 1'b0;
    endcase

  always_comb
    case (Vsew)
      VSEW_16: begin
        NativeBias   = 13'(P.H_BIAS);
        SignMask     = {{(P.FLEN-16){1'b0}}, 16'h8000};
        PosInf       = {{(P.FLEN-16){1'b0}}, 16'h7C00};
        MaxFinite    = {{(P.FLEN-16){1'b0}}, 16'h7BFF};
        CanonicalNan = {{(P.FLEN-16){1'b0}}, 16'h7E00};
      end

      VSEW_32: begin
        NativeBias   = 13'(P.S_BIAS);
        SignMask     = {{(P.FLEN-32){1'b0}}, 32'h8000_0000};
        PosInf       = {{(P.FLEN-32){1'b0}}, 32'h7F80_0000};
        MaxFinite    = {{(P.FLEN-32){1'b0}}, 32'h7F7F_FFFF};
        CanonicalNan = {{(P.FLEN-32){1'b0}}, 32'h7FC0_0000};
      end

      VSEW_64: begin
        NativeBias   = 13'(P.D_BIAS);
        SignMask     = {{(P.FLEN-64){1'b0}}, 64'h8000_0000_0000_0000};
        PosInf       = {{(P.FLEN-64){1'b0}}, 64'h7FF0_0000_0000_0000};
        MaxFinite    = {{(P.FLEN-64){1'b0}}, 64'h7FEF_FFFF_FFFF_FFFF};
        CanonicalNan = {{(P.FLEN-64){1'b0}}, 64'h7FF8_0000_0000_0000};
      end

      default: begin
        NativeBias   = 13'sd0;
        SignMask     = '0;
        PosInf       = '0;
        MaxFinite    = '0;
        CanonicalNan = '0;
      end
    endcase

endmodule
