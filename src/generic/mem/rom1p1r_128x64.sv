///////////////////////////////////////////
// rom1p1r_128x64.sv
//
// Written: james.stine@okstate.edu 28 January 2023
// Modified:
//
// Purpose: ROM wrapper for instantiating ROM IP
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

module rom1p1r_128x64(
  input  logic        CLK,
  input  logic        CEB,
  input  logic [6:0]  A,
  output logic [63:0] Q
);

   // replace "generic64x128RAM" with "TS3N..64X128.." module from your memory vendor
  ts3n28hpcpa128x64m8m romIP (.CLK, .CEB, .A, .Q);
//   generic64x128ROM romIP (.CLK, .CEB, .A, .Q);

endmodule
