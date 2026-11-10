///////////////////////////////////////////
// vcpop.sv
//
// Written: Malina Andrews mandrews@g.hmc.edu
// Modified: Georgia Tai   ytai@g.hmc.edu
// Created: 2 November 2026
// Modified: 2 November 2026
//
// Purpose: Vector mask scan and count
//
// Documentation: RISC-V System on Chip Design Volume 2
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
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

// Larger module needed for all Mask scan and count instructions, just adding vcpop with this commit

module vcpop import cvw::*; #(parameter cvw_t P) (
input logic [P.ELEN-1:0] vs2,           // mask source register
input logic [P.ELEN-1:0] v0,            // mask register
input logic              vm,            // 1 bit parameter controlling if v0 is used or not, vm = 1 means unmasked, vm = 0 means masked
input logic [$clog2(P.ELEN):0] vl,      // number of active elements, for elements > vl, we will  need to mask them so unrelated 1s are not counted
output logic [$clog2(P.ELEN):0] VPopCnt // 7 bit scalar result (up to 64)
);


  logic [P.ELEN-1:0] elem_mask;         // Element mask: all active if vm=1, else v0
  assign elem_mask = v0 | {P.ELEN{vm}}; // when vm=1 is true instruction is unmasked, when vm=0, only enabled when v0[i] = 1

  logic [P.ELEN-1:0] tail_mask;           // Tail mask: active if element < v1
  always_comb begin
   for (int i = 0; i < P.ELEN; i++)
    tail_mask[i] = (vl > i);            // sets any element i greater than vl to 0
  end                                   // need workaround for multiple beats, e.g. if vl = 70 and ELEN = 64 all 64 bits of the second beat will pass when only 6 should. this would require some sort of beat count logic & needs to be fixed

  logic [P.ELEN-1:0] active;
  assign active = vs2 & elem_mask & tail_mask; // anding all active elements before counting

  assign VPopCnt = $countones(active);
endmodule
