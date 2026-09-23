///////////////////////////////////////////
// vfrec7special.sv
//
// Written: nfotneos@g.hmc.edu 2026-09-18
//
// Purpose: vfrec7 special cases, using the unpack unit's own classification:
//          infinity, NaN, +/- zero, and subnormal inputs whose reciprocal
//          overflows (two or more leading zeros in the fraction, so the
//          normalized output exponent exceeds 2*NativeBias).
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

module vfrec7special import cvw::*; #(parameter cvw_t P) (
  input  logic                      Xs,
  input  logic                      XNaN,
  input  logic                      XSNaN,
  input  logic                      XZero,
  input  logic                      XInf,
  input  logic                      XSubnorm,
  input  logic [$clog2(P.NF+1)-1:0] ZeroCount,
  input  logic [2:0]                Frm,

  input  logic [P.FLEN-1:0]         SignMask,      // this SEW's sign bit
  input  logic [P.FLEN-1:0]         PosInf,        // this SEW's +infinity
  input  logic [P.FLEN-1:0]         MaxFinite,     // this SEW's +max finite
  input  logic [P.FLEN-1:0]         CanonicalNan,  // this SEW's canonical NaN

  output logic                      IsSpecial,     // one of the cases below applies
  output logic [P.FLEN-1:0]         Res,
  output logic [4:0]                Flg
);

  localparam integer LOGNF = $clog2(P.NF+1);

  // Flg = {NV, DZ, OF, UF, NX}
  localparam integer NV = 4;
  localparam integer DZ = 3;
  localparam integer OF = 2;
  localparam integer NX = 0;

  localparam logic [2:0] RNE = 3'b000;
  localparam logic [2:0] RTZ = 3'b001;
  localparam logic [2:0] RDN = 3'b010;
  localparam logic [2:0] RUP = 3'b011;
  localparam logic [2:0] RMM = 3'b100;

  logic SubnormOverflow;
  logic OverflowToInf;

  assign SubnormOverflow = XSubnorm & (ZeroCount >= LOGNF'(2));
  assign IsSpecial       = XInf | XNaN | XZero | SubnormOverflow;

  always_comb begin
    Res           = '0;
    Flg           = 5'b0;
    OverflowToInf = 1'b0;

    if (XInf) // infinity -> +/- zero
      Res = Xs ? SignMask : '0;

    else if (XNaN) begin // NaN -> canonical NaN
      Res     = CanonicalNan;
      Flg[NV] = XSNaN;
    end

    else if (XZero) begin // +/- zero -> +/- infinity, divide-by-zero exception
      Res     = PosInf | (Xs ? SignMask : '0);
      Flg[DZ] = 1'b1;
    end

    else if (SubnormOverflow) begin // very small subnormal: reciprocal exponent overflows
      Flg[OF] = 1'b1;
      Flg[NX] = 1'b1;

      if (~Xs) // positive overflow
        case (Frm)
          RTZ, RDN: OverflowToInf = 1'b0; // +max finite
          default:  OverflowToInf = 1'b1; // +infinity (RNE, RUP, RMM, reserved)
        endcase
      else // negative overflow
        case (Frm)
          RTZ, RUP: OverflowToInf = 1'b0; // -max finite
          default:  OverflowToInf = 1'b1; // -infinity (RNE, RDN, RMM, reserved)
        endcase

      Res = (OverflowToInf ? PosInf : MaxFinite) | (Xs ? SignMask : '0);
    end
  end

endmodule
