///////////////////////////////////////////
// rom1p1r_128x64.sv
//
// Written:  James Stine james.stine@okstate.edu 28 January 2023
// Modified: Rose Thompson
//
// Purpose: 128x64 ROM macro wrapper.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2023-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module rom1p1r_128x64(
  input  logic        CLK, // SRAM clock
  input  logic        CEB, // SRAM chip enable (active low)
  input  logic [6:0]  A,   // SRAM address
  output logic [63:0] Q    // SRAM read data
);

  // replace "generic128x64ROM" with "TS3N..128X64.." module from your memory vendor
  ts3n28hpcpa128x64m8m romIP (.CLK, .CEB, .A, .Q);
  // generic128x64ROM romIP (.CLK, .CEB, .A, .Q);

endmodule
