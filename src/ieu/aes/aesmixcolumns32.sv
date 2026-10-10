///////////////////////////////////////////
// aesmixcolumns32.sv
//
// Written:  Ryan Swann ryan.swann@okstate.edu, James Stine james.stine@okstate.edu, David Harris David_Harris@hmc.edu 20 February 2024
// Modified: Kelvin Tran kelvin.tran@okstate.edu
//
// Purpose: AES MixColumns transformation of one 32-bit column.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
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
