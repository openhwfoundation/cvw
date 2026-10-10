///////////////////////////////////////////
// rom1p1r_128x32.sv
//
// Written:  James Stine james.stine@okstate.edu 28 January 2023
// Modified:
//
// Purpose: Wrapper that instantiates a 128x32 ROM macro.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2023-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module rom1p1r_128x32(
  input  logic          CLK,
  input  logic           CEB,
  input  logic [6:0]    A,
  output logic [31:0]   Q
);

   // replace "generic128x32ROM" with "TS3N..128X32.." module from your memory vendor
   generic64x128ROM sramIP (.CLK, .CEB, .A, .Q);

endmodule
