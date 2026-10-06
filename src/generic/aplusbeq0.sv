///////////////////////////////////////////
// aplusbeq0.sv
//
// Written: David_Harris@hmc.edu 9/7/2022
// Modified:
//
// Purpose: Determine if A+B = 0.  Used in FP divider.
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

module aplusbeq0 #(parameter WIDTH = 8) (
  input  logic [WIDTH-1:0] a, b,
  output logic             zero
);

  logic [WIDTH-1:0] x;
  logic [WIDTH-1:0] orshift;

  // The sum is zero if the bitwise XOR is equal to the bitwise OR shifted left by 1, for all columns
  // See J. A. Prabhu and G. Zyner, "167 MHz radix-8 divide and square root using overlapped radix-2 stages," IEEE Symp. Computer Arithmetic, 1995, pp. 155-162.

  assign x = a ^ b;
  assign orshift = {a[WIDTH-2:0] | b[WIDTH-2:0], 1'b0};
  assign zero = (x == orshift);
endmodule
