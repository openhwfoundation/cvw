///////////////////////////////////////////
// ram1p1rwbe_64x22.sv
//
// Written: james.stine@okstate.edu 2 February 2023
// Modified:
//
// Purpose: RAM wrapper for instantiating RAM IP
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

module ram1p1rwbe_64x22(
  input  logic          CLK,
  input  logic          CEB,
  input  logic          WEB,
  input  logic [5:0]    A,
  input  logic [21:0]   D,
  input  logic [21:0]   BWEB,
  output logic [21:0]   Q
);

   // replace "generic64x22RAM" with "TS1N..64X22.." module from your memory vendor
   // use part of a larger RAM to avoid generating more flavors of RAM
  logic [43:0] Qfull;
  TS1N28HPCPSVTB64X44M4SW sramIP(.CLK, .CEB, .WEB, .A, .D({22'b0, D[21:0]}), .BWEB({22'b0, BWEB[21:0]}), .Q(Qfull));
  assign Q = Qfull[21:0];
   // genericRAM #(64, 22) sramIP (.CLK, .CEB, .WEB, .A, .D, .BWEB, .Q);

endmodule
