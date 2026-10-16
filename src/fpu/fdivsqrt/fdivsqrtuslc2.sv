///////////////////////////////////////////
// fdivsqrtuslc2.sv
//
// Written: David_Harris@hmc.edu, me@KatherineParry.com, cturek@hmc.edu
// Modified:13 January 2022
//
// Purpose: Radix 2 Unified Quotient/Square Root Digit Selection
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
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
