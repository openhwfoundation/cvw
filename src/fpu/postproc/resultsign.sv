///////////////////////////////////////////
// resultsign.sv
//
// Written: me@KatherineParry.com
// Modified: 7/5/2022
//
// Purpose: calculating the result's sign
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

module resultsign(
  input  logic [2:0]  Frm,        // Rounding mode: 000 RNE, 001 RTZ, 010 RDN, 011 RUP, 100 RMM
  input  logic        FmaOp,      // FMA operation
  input  logic        Mult,       // is the fma operation multiply
  input  logic        ZInf,       // is Z infinity
  input  logic        InfIn,      // An input is infinity
  input  logic        FmaSZero,   // FMA sum is zero
  input  logic        Ms,         // Normalized result sign
  input  logic        FmaPs,      // FMA product sign
  input  logic        FmaAs,      // FMA aligned addend sign
  input  logic        Guard,      // guard bit for rounding
  input  logic        Round,      // round bit for rounding
  input  logic        Sticky,     // Sticky bit for rounding
  output logic        Rs          // Result sign
);

  logic Zeros;    // zero result sign
  logic Infs;     // infinity result sign

  // determine the sign for a result of 0
  //  The IEEE754-2019 standard specifies:
  //      - the sign of an exact zero sum (with operands of different signs) should be positive unless rounding toward negative infinity
  //      - when the exact result of an FMA operation is non-zero, but is zero due to rounding, use the sign of the exact result
  //      - if x = +0 or -0 then x+x=x and x-(-x)=x
  //      - the sign of a product is the exclusive or of the operands' signs
  //  Zero sign will only be selected if:
  //      - P=Z and a cancellation occurs - exact zero
  //      - Z is zero and P is zero - exact zero
  //      - P is killed and Z is zero - Psgn
  //      - Z is killed and P is zero - impossible
  //  Zero sign calculation:
  //      - if a multiply operation is done, then use the product's sign (Ps)
  //      - if the zero sum is not exactly zero i.e. Round|Sticky use the sign of the exact result (which is the product's sign)
  //      - if an effective addition occurs (P+A or -P+-A or P--A) then use the product's sign
  //  i.e. an exact zero from an effective subtraction is -0 only when rounding down (Frm = 010)
  assign Zeros = (FmaPs ^ FmaAs) & ~(Round | Guard | Sticky) & ~Mult ? Frm[1:0] == 2'b10 : FmaPs;

  // determine the sign of an infinity result
  //  use Z's sign if Z is infinite, otherwise the product's sign
  //  (Inf - Inf is invalid and produces a NaN instead)
  assign Infs = ZInf ? FmaAs : FmaPs;

  // select the result sign
  always_comb
    if (InfIn & FmaOp)         Rs = Infs;
    else if (FmaSZero & FmaOp) Rs = Zeros;
    else                       Rs = Ms;

endmodule
