///////////////////////////////////////////
// galoismultinverse.sv
//
// Written: kelvin.tran@okstate.edu, james.stine@okstate.edu
// Created: 20 February 2024
//
// Purpose: Galois field operations for mix columns operation
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

module galoismultinverse8(
   input  logic [10:0] a,
   output logic [7:0]  y
);

   logic [7:0] temp0, temp1;

   assign temp0 = a[8]  ? (a[7:0] ^ 8'b00011011) : a[7:0];
   assign temp1 = a[9]  ? (temp0  ^ 8'b00110110) : temp0;
   assign y     = a[10] ? (temp1  ^ 8'b01101100) : temp1;
endmodule
