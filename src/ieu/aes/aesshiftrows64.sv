///////////////////////////////////////////
// aesshiftrows64.sv
//
// Written:  Ryan Swann ryan.swann@okstate.edu, James Stine james.stine@okstate.edu 20 February 2024
// Modified: Kelvin Tran kelvin.tran@okstate.edu, David Harris David_Harris@hmc.edu
//
// Purpose: AES ShiftRows on a 128-bit state, producing the low 64 bits of the result.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module aesshiftrows64(
   /* verilator lint_off UNUSEDSIGNAL */
   input  logic [127:0] a,
   /* verilator lint_on UNUSEDSIGNAL */
   output logic [63:0] y
);

   assign y = {a[31:24],   a[119:112], a[79:72],   a[39:32],
               a[127:120], a[87:80],   a[47:40],   a[7:0]};
endmodule
