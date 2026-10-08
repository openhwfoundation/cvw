///////////////////////////////////////////
// aesinvmixcolumns8.sv
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

module aesinvmixcolumns8(
   input  logic [7:0] a,
   output logic [31:0] y
);

   logic [10:0] t, x0, x1, x2, x3;

   // aes32d operates on shifted versions of the input
   assign t  = {a, 3'b0} ^ {3'b0, a};
   assign x0 = {a, 3'b0} ^ {1'b0, a, 2'b0} ^ {2'b0, a, 1'b0};
   assign x1 = t;
   assign x2 = t ^ {1'b0, a, 2'b0};
   assign x3 = t ^ {2'b0, a, 1'b0};

   galoismultinverse8 gm0 (x0, y[7:0]);
   galoismultinverse8 gm1 (x1, y[15:8]);
   galoismultinverse8 gm2 (x2, y[23:16]);
   galoismultinverse8 gm3 (x3, y[31:24]);

 endmodule
