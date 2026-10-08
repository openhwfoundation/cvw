///////////////////////////////////////////
// normshift.sv
//
// Written: me@KatherineParry.com
// Modified: 7/5/2022
//
// Purpose: normalization shifter
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

    // convert shift
    //      fp -> int:  | `XLEN  zeros      |     Mantissa      | 0's if necessary | << CalcExp
    //          process:
    //              - start - CalcExp = 1 + XExp - Largest Bias
    //                  | `XLEN  zeros      |     Mantissa      | 0's if necessary |
    //
    //              - shift left 1 (1)
    //                  | `XLEN-1 zeros |bit|     frac          | 0's if necessary |
    //                                      . <- binary point
    //
    //              - shift left till unbiased exponent is 0 (XExp - Largest Bias)
    //                  |  0's |     Mantissa      |      0's if necessary     |
    //                  |     keep          |
    //
    //      fp -> fp:
    //          - if result is subnormal or underflowed:
    //              |  `NF-1  zeros   |     Mantissa      | 0's if necessary | << NF+CalcExp-1
    //          process:
    //             - start
    //                 |     mantissa      | 0's |
    //
    //             - shift right by NF-1 (NF-1)
    //                 |    `NF-1  zeros   |     mantissa      | 0's |
    //
    //             - shift left by CalcExp = XExp - Largest bias + new bias
    //                 |   0's  |     mantissa      |     0's      |
    //                 |       keep      |
    //
    //          - if the input is subnormal:
    //                 |     lzcIn      | 0's if necessary | << ZeroCnt+1
    //              - plus 1 to shift out the first 1
    //
    //      int -> fp: |     lzcIn      | 0's if necessary | << ZeroCnt+1
    //              - plus 1 to shift out the first 1

    // fma shift
    //      |   00   |           Sm           | << LZA output
    //             .
    //      - two extra bits so we can correct for an LZA error of 1 or 2

    // divsqrt shift
    //      | Nf 0's |           Qm           | << calculated shift amount
    //        .

module normshift import cvw::*;  #(parameter cvw_t P) (
  input  logic [P.LOGNORMSHIFTSZ-1:0]  ShiftAmt,   // shift amount
  input  logic [P.NORMSHIFTSZ-1:0]     ShiftIn,    // number to be shifted
  output logic [P.NORMSHIFTSZ-1:0]     Shifted     // shifted result
);

  assign Shifted = ShiftIn << ShiftAmt;
endmodule
