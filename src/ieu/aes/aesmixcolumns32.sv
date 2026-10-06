///////////////////////////////////////////
// aesmixcolumns32.sv
//
// Written: ryan.swann@okstate.edu, james.stine@okstate.edu, David_Harris@hmc.edu
// Created: 20 February 2024
//
// Purpose: Galois field operation to an individual 32-bit word
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


module aesmixcolumns32(
   input  logic [31:0] a,
   output logic [31:0] y
);

   logic [7:0] a0, a1, a2, a3, y0, y1, y2, y3, t0, t1, t2, t3, temp;

   assign {a0, a1, a2, a3} = a;
   assign temp = a0 ^ a1 ^ a2 ^ a3;

   galoismultforward8 gm0 (a0^a1, t0);
   galoismultforward8 gm1 (a1^a2, t1);
   galoismultforward8 gm2 (a2^a3, t2);
   galoismultforward8 gm3 (a3^a0, t3);

   assign y0 = a0 ^ temp ^ t3;
   assign y1 = a1 ^ temp ^ t0;
   assign y2 = a2 ^ temp ^ t1;
   assign y3 = a3 ^ temp ^ t2;

   assign y = {y0, y1, y2, y3};
endmodule
