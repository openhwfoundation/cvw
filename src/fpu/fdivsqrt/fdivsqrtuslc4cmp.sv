///////////////////////////////////////////
// fdivsqrtuslc4cmp.sv
//
// Written: David_Harris@hmc.edu, me@KatherineParry.com, cturek@hmc.edu
// Modified:13 January 2022
//
// Purpose: Comparator-based Radix 4 Unified Quotient/Square Root Digit Selection
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

module fdivsqrtuslc4cmp (
  input  logic [2:0] Dmsbs,             // U0.3 fractional bits after implicit leading 1
  input  logic [4:0] Smsbs,             // U1.4 leading bits of square root approximation
  input  logic [7:0] WSmsbs, WCmsbs,    // Q4.4 residual most significant bits
  input  logic       SqrtE,
  input  logic       j0, j1,            // are we on first (j0) or second step (j1) of digit selection
  output logic [3:0] udigit             // {2, 1, -1, -2} digit is 0 if none are hot
);
  logic [6:0] Wmsbs;
  logic [7:0] PreWmsbs;
  logic [2:0] A;

  assign PreWmsbs = WCmsbs + WSmsbs;
  assign Wmsbs = PreWmsbs[7:1];
  // D = 0001.xxx...
  // Dmsbs = |   |
  // W =      xxxx.xxx...
  // Wmsbs = |        |

  logic [6:0] mk2, mk1, mk0, mkm1;
  logic [6:0] mkj2, mkj1;
  logic [6:0] mks2[7:0], mks1[7:0], mks0[7:0], mksm1[7:0];
  logic sqrtspecial;

  // Prepopulate table of mks for comparison
  assign mks2[0] = 12;
  assign mks2[1] = 14;
  assign mks2[2] = 16;
  assign mks2[3] = 17;
  assign mks2[4] = 18;
  assign mks2[5] = 20;
  assign mks2[6] = 22;
  assign mks2[7] = 23;
  assign mks1[0] = 4;
  assign mks1[1] = 4;
  assign mks1[2] = 6;
  assign mks1[3] = 6;
  assign mks1[4] = 6;
  assign mks1[5] = 8; // is the logic any cheaper if this is a 6?
  assign mks1[6] = 8;
  assign mks1[7] = 8;

  assign mks0[0] = -4;
  assign mks0[1] = -4;
  assign mks0[2] = -6;
  assign mks0[3] = -6;
  assign mks0[4] = -6;
  assign mks0[5] = -8;
  assign mks0[6] = -8;
  assign mks0[7] = -8;
  assign mksm1[0] = -13;
  assign mksm1[1] = -14;
  assign mksm1[2] = -16;
  assign mksm1[3] = -17;
  assign mksm1[4] = -18;
  assign mksm1[5] = -20;
  assign mksm1[6] = -22;
  assign mksm1[7] = -23;


  // handles special case when j = 0 or j = 1 for sqrt
  assign mkj2 = 20; // when j = 1 use mk2[101] when j = 0 use anything bigger than 7.
  assign mkj1 = j0 ? 0 : 8; // when j = 1 use mk1[101] = 8 and when j = 0 use 0 so we choose u_0 = 1
  assign sqrtspecial = SqrtE & (j1 | j0);

  // Choose A for current operation
 always_comb
    if (SqrtE) begin
      if (Smsbs[4]) A = 3'b111; // for S = 1.0000
      else A = Smsbs[2:0];
    end else A = Dmsbs;

  // Choose selection constants based on a

  assign mk2 = sqrtspecial ? mkj2 : mks2[A];
  assign mk1 = sqrtspecial ? mkj1 : mks1[A];
  assign mk0 = sqrtspecial ? -mkj1 : mks0[A];
  assign mkm1 = sqrtspecial ? -mkj2 : mksm1[A];

/* Nannarelli12 design to exploit symmetry is slower because of negation and mux for special case of A = 000
  assign mk0 = -mk1;
  assign mkm1 = (A == 3'b000) ? -13 : -mk2; // asymmetry in table
  */

  // Compare residual W to selection constants to choose digit
  always_comb
    if      ($signed(Wmsbs) >= $signed(mk2))  udigit = 4'b1000; // choose 2
    else if ($signed(Wmsbs) >= $signed(mk1))  udigit = 4'b0100; // choose 1
    else if ($signed(Wmsbs) >= $signed(mk0))  udigit = 4'b0000; // choose 0
    else if ($signed(Wmsbs) >= $signed(mkm1)) udigit = 4'b0010; // choose -1
    else                                      udigit = 4'b0001; // choose -2
endmodule
