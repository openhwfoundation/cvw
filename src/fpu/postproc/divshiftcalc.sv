///////////////////////////////////////////
// divshiftcalc.sv
//
// Written: me@KatherineParry.com
// Modified: 7/5/2022
//
// Purpose: Division shift calculation
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

module divshiftcalc import cvw::*;  #(parameter cvw_t P) (
  input  logic [P.NE+1:0]              DivUe,              // divsqrt exponent
  output logic [P.LOGNORMSHIFTSZ-1:0]  DivShiftAmt,        // divsqrt shift amount
  output logic                         DivResSubnorm,      // is the divsqrt result subnormal
  output logic                         DivSubnormShiftPos  // is the subnormal shift amount positive
);

  logic [P.LOGNORMSHIFTSZ-1:0]         NormShift;          // normalized result shift amount
  logic [P.LOGNORMSHIFTSZ-1:0]         DivSubnormShiftAmt; // subnormal result shift amount (killed if negative)
  logic [P.NE+1:0]                     DivSubnormShift;    // subnormal result shift amount

  // is the result subnormal
  // if the exponent is 1 then the result needs to be normalized then the result is Subnormalizes
  assign DivResSubnorm = DivUe[P.NE+1]|(~|DivUe[P.NE+1:0]);

  // if the result is subnormal
  //  00000000x.xxxxxx...                     Exp = DivUe
  //  .00000000xxxxxxx... >> NF+1             Exp = DivUe+NF+1
  //  .00xxxxxxxxxxxxx... << DivUe+NF+1       Exp = +1
  //  .0000xxxxxxxxxxx... >> 1                Exp = 1
  // Left shift amount      = DivUe+NF+1-1
  assign DivSubnormShift    = (P.NE+2)'(P.NF)+DivUe;
  assign DivSubnormShiftPos = ~DivSubnormShift[P.NE+1];

  // if the result is normalized
  //  00000000x.xxxxxx...                     Exp = DivUe
  //  .00000000xxxxxxx... >> NF+1             Exp = DivUe+NF+1
  //  00000000.xxxxxxx... << NF               Exp = DivUe+1
  //  00000000x.xxxxxx... << NF               Exp = DivUe (extra shift done afterwards)
  //  00000000xx.xxxxx... << 1?               Exp = DivUe-1 (determined after)
  // initial Left shift amount  = NF
  // shift one more if the it's a minimally redundant radix 4 - one entire cycle needed for integer bit
  assign NormShift = (P.LOGNORMSHIFTSZ)'(P.NF);

  // if the shift amount is negative then don't shift (keep sticky bit)
  // need to multiply the early termination shift by LOGR*DIVCOPIES =  left shift of log2(LOGR*DIVCOPIES)
  assign DivSubnormShiftAmt = DivSubnormShiftPos ? DivSubnormShift[P.LOGNORMSHIFTSZ-1:0] : '0;
  assign DivShiftAmt        = DivResSubnorm ? DivSubnormShiftAmt : NormShift;

endmodule
