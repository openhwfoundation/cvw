///////////////////////////////////////////
// rom1p1r_128x64.sv
//
// Written: james.stine@okstate.edu 28 January 2023
// Modified:
//
// Purpose: ROM wrapper for instantiating ROM IP
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module rom1p1r_128x64(
  input  logic        CLK,
  input  logic        CEB,
  input  logic [6:0]  A,
  output logic [63:0] Q
);

  // replace "generic128x64ROM" with "TS3N..128X64.." module from your memory vendor
  ts3n28hpcpa128x64m8m romIP (.CLK, .CEB, .A, .Q);
  // generic128x64ROM romIP (.CLK, .CEB, .A, .Q);

endmodule
