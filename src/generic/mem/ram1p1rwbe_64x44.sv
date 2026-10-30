///////////////////////////////////////////
// ram1p1rwbe_64x44.sv
//
// Written:  James Stine james.stine@okstate.edu 28 January 2023
// Modified: David Harris
//
// Purpose: 64x44 single-port SRAM macro wrapper.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2023-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module ram1p1rwbe_64x44(
  input  logic          CLK,  // SRAM clock
  input  logic          CEB,  // SRAM chip enable (active low)
  input  logic          WEB,  // SRAM write enable (active low)
  input  logic [5:0]    A,    // SRAM address
  input  logic [43:0]   D,    // SRAM write data
  input  logic [43:0]   BWEB, // SRAM bit write enables (active low)
  output logic [43:0]   Q     // SRAM read data
);

  // replace "generic64x44RAM" with "TS1N..64X44.." module from your memory vendor
  // generic64x44RAM sramIP (.CLK, .CEB, .WEB, .A, .D, .BWEB, .Q);
  TS1N28HPCPSVTB64X44M4SW sramIP(.CLK, .CEB, .WEB, .A, .D, .BWEB, .Q);

endmodule
