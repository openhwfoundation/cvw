///////////////////////////////////////////
// aesinvmixcolumns32.sv
//
// Written: kelvin.tran@okstate.edu, james.stine@okstate.edu
// Created: 05 March 2024
//
// Purpose: AES Inverted Mix Column Function for use with AES
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

module aesinvmixcolumns32(
   input  logic [31:0] a,
   output logic [31:0] y
);

   logic [7:0] a0, a1, a2, a3, temp;
   logic [10:0] xor0, xor1, xor2, xor3;

   assign {a0, a1, a2, a3} = a;
   assign temp = a0 ^ a1 ^ a2 ^ a3;

   assign xor0 = {temp, 3'b0} ^ {1'b0, a3^a1, 2'b0} ^ {2'b0, a3^a2, 1'b0} ^ {3'b0, temp} ^ {3'b0, a3};
   assign xor1 = {temp, 3'b0} ^ {1'b0, a2^a0, 2'b0} ^ {2'b0, a2^a1, 1'b0} ^ {3'b0, temp} ^ {3'b0, a2};
   assign xor2 = {temp, 3'b0} ^ {1'b0, a1^a3, 2'b0} ^ {2'b0, a1^a0, 1'b0} ^ {3'b0, temp} ^ {3'b0, a1};
   assign xor3 = {temp, 3'b0} ^ {1'b0, a0^a2, 2'b0} ^ {2'b0, a0^a3, 1'b0} ^ {3'b0, temp} ^ {3'b0, a0};

   galoismultinverse8 gm0 (xor0, y[7:0]);
   galoismultinverse8 gm1 (xor1, y[15:8]);
   galoismultinverse8 gm2 (xor2, y[23:16]);
   galoismultinverse8 gm3 (xor3, y[31:24]);
endmodule
