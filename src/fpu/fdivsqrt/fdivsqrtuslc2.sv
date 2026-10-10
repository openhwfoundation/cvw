///////////////////////////////////////////
// fdivsqrtuslc2.sv
//
// Written:  David Harris David_Harris@hmc.edu, Katherine Parry me@KatherineParry.com, Cedar Turek cturek@hmc.edu 20 September 2022
// Modified:
//
// Purpose: Radix-2 unified quotient and square root digit selection from the leading bits of the redundant residual.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2022-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module fdivsqrtuslc2 (
  input  logic [3:0] WS, WC,      // Q4.0 most significant bits of redundant residual
  output logic       up, uz, un   // {+1, 0, -1}
);

  logic        sign;

  // Carry chain logic determines if W = WS + WC = -1, < -1, > -1 to choose 0, -1, 1 respectively

  //if p2 * p1 * p0, W = -1 and choose digit of 0
  assign uz = ((WS[2]^WC[2]) & (WS[1]^WC[1]) &
        (WS[0]^WC[0]));

  // Otherwise determine sign using carry chain: sign = p3 ^ g_2:0
  assign sign = (WS[3]^WC[3])^
      (WS[2] & WC[2] | ((WS[2]^WC[2]) &
          (WS[1]&WC[1] | ((WS[1]^WC[1]) &
            (WS[0]&WC[0])))));

  // Produce digit = +1, 0, or -1
  assign up = ~uz & ~sign;
  assign un = ~uz & sign;
endmodule
