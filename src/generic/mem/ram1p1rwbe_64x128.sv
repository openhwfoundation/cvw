///////////////////////////////////////////
// ram1p1rwbe_64x128.sv
//
// Written:  James Stine james.stine@okstate.edu 28 January 2023
// Modified: David Harris David_Harris@hmc.edu
//
// Purpose: Wrapper that instantiates a 64x128 single-port SRAM macro with bit write enables.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2023-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module ram1p1rwbe_64x128(
  input  logic          CLK,
  input  logic          CEB,
  input  logic          WEB,
  input  logic [5:0]    A,
  input  logic [127:0]  D,
  input  logic [127:0]  BWEB,
  output logic [127:0]  Q
);

   // replace "generic64x128RAM" with "TS1N..64X128.." module from your memory vendor
   //generic64x128RAM sramIP (.CLK, .CEB, .WEB, .A, .D, .BWEB, .Q);
   TS1N28HPCPSVTB64X128M4SW sramIP(.CLK, .CEB, .WEB, .A, .D, .BWEB, .Q);

endmodule
