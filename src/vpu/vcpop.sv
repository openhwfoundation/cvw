///////////////////////////////////////////
// vcpop.sv
//
// Written: Malina Andrews mandrews@g.hmc.edu
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

// ***Larger module needed for all Mask scan and count instructions, just adding vcpop with this commit

module vcpop import cvw::*; #(parameter cvw_t P) (
input logic [P.ELEN-1:0] B,           // mask source register, vs2 = B
input logic [P.ELEN-1:0] v0,            // mask register
//output logic [$clog2(P.ELEN):0] VPopCnt // 7 bit scalar result (up to 64)
output logic VPopCnt
);

  logic active;
  assign active = B[0] & v0[0]; // anding active elements before counting ***assuming that B and v0 have been passed through ElemMask and TailMask in vieu.sv
  assign VPopCnt = active;
endmodule
