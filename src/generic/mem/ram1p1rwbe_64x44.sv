///////////////////////////////////////////
// ram1p1rwbe_64x44.sv
//
// Written: james.stine@okstate.edu 28 January 2023
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
////////////////////////////////////////////////////////////////////////////////////////////////

module ram1p1rwbe_64x44(
  input  logic          CLK,
  input  logic          CEB,
  input  logic          WEB,
  input  logic [5:0]    A,
  input  logic [43:0]   D,
  input  logic [43:0]   BWEB,
  output logic [43:0]   Q
);

   // replace "generic64x44RAM" with "TS1N..64X44.." module from your memory vendor
   // generic64x44RAM sramIP (.CLK, .CEB, .WEB, .A, .D, .BWEB, .Q);
   TS1N28HPCPSVTB64X44M4SW sramIP(.CLK, .CEB, .WEB, .A, .D, .BWEB, .Q);

endmodule
