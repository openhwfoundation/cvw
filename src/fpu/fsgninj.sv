///////////////////////////////////////////
// fsgninj.sv
//
// Written: me@KatherineParry.com
// Modified: 6/23/2021
//
// Purpose: FPU Sign Injection instructions
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

module fsgninj import cvw::*;  #(parameter cvw_t P) (
  input  logic                 Xs, Ys, // X and Y sign bits
  input  logic [P.FLEN-1:0]    X,      // X
  input  logic [P.FMTBITS-1:0] Fmt,    // format
  input  logic [1:0]           OpCtrl, // operation control
  output logic [P.FLEN-1:0]    SgnRes  // result
);

  logic ResSgn;  // result sign

  // OpCtrl:
  //     00 - fsgnj  - directly copy over sign value of Y
  //     01 - fsgnjn - negate sign value of Y
  //     10 - fsgnjx - XOR sign values of X and Y

  // calculate the result's sign
  assign ResSgn = (OpCtrl[1] ? Xs : OpCtrl[0]) ^ Ys;

  // format final result based on precision
  //    - uses NaN-blocking format
  //        - if there are any unused bits the most significant bits are filled with 1s

  if (P.FPSIZES == 1)
    assign SgnRes = {ResSgn, X[P.FLEN-2:0]};
  else if (P.FPSIZES == 2)
    assign SgnRes = {~Fmt|ResSgn, X[P.FLEN-2:P.LEN1], Fmt ? X[P.LEN1-1] : ResSgn, X[P.LEN1-2:0]};
  else if (P.FPSIZES ==  3) begin
    logic [2:0] SgnBits;
    always_comb
      case (Fmt)
        P.FMT:    SgnBits = {ResSgn, X[P.LEN1-1], X[P.LEN2-1]};
        P.FMT1:   SgnBits = {1'b1, ResSgn, X[P.LEN2-1]};
        P.FMT2:   SgnBits = {2'b11, ResSgn};
        default: SgnBits = {3{1'bx}};
      endcase
    assign SgnRes = {SgnBits[2], X[P.FLEN-2:P.LEN1], SgnBits[1], X[P.LEN1-2:P.LEN2], SgnBits[0], X[P.LEN2-2:0]};
  end else if (P.FPSIZES == 4) begin
    logic [3:0] SgnBits;
    always_comb
      case (Fmt)
        P.Q_FMT: SgnBits = {ResSgn, X[P.D_LEN-1], X[P.S_LEN-1], X[P.H_LEN-1]};
        P.D_FMT: SgnBits = {1'b1, ResSgn, X[P.S_LEN-1], X[P.H_LEN-1]};
        P.S_FMT: SgnBits = {2'b11, ResSgn, X[P.H_LEN-1]};
        P.H_FMT: SgnBits = {3'b111, ResSgn};
      endcase
    assign SgnRes = {SgnBits[3], X[P.Q_LEN-2:P.D_LEN], SgnBits[2], X[P.D_LEN-2:P.S_LEN], SgnBits[1], X[P.S_LEN-2:P.H_LEN], SgnBits[0], X[P.H_LEN-2:0]};
  end
endmodule
