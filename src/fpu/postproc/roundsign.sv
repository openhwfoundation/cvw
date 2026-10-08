///////////////////////////////////////////
// roundsign.sv
//
// Written: me@KatherineParry.com
// Modified: 7/5/2022
//
// Purpose: Sign calculation for rounding
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

module roundsign(
  input logic         Xs,     // x sign
  input logic         Ys,     // y sign
  input logic         CvtCs,  // convert result sign
  input logic         FmaSs,  // fma sum sign
  input logic         Sqrt,   // sqrt oppertion? (when using divsqrt unit)
  input logic         FmaOp,  // is fma operation
  input logic         DivOp,  // is divsqrt operation
  input logic         CvtOp,  // is cvt operation
  output logic        Ms      // normalized result sign
);

  logic               Qs;     // divsqrt result sign

  // calculate divsqrt sign
  assign Qs = Xs^(Ys&~Sqrt);

  // Select sign for rounding calculation
  assign Ms = (FmaSs&FmaOp) | (CvtCs&CvtOp) | (Qs&DivOp);

endmodule
