///////////////////////////////////////////
// aesmixcolumns8.sv
//
// Written: ryan.swann@okstate.edu, james.stine@okstate.edu, David_Harris@hmc.edu
// Created: 20 February 2024
//
// Purpose: Galois field operation to byte in an individual 32-bit word
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
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


module aesmixcolumns8(
   input  logic [7:0]  a,
   output logic [31:0] y
);

   logic [7:0] xa, xapa;

   galoismultforward8 gm(a, xa); // xa
   assign xapa = a ^ xa;         // a ^ xa
   assign y = {xapa, a, a, xa};
endmodule
