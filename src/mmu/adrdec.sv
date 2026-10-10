///////////////////////////////////////////
// adrdec.sv
//
// Written:  David Harris David_Harris@hmc.edu 29 January 2021
// Modified:
//
// Purpose: Decodes whether a physical address falls within one memory region and the access size is supported.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module adrdec #(parameter PA_BITS) (
  input  logic [PA_BITS-1:0]  PhysicalAddress,  // Physical address to decode
  input  logic [PA_BITS-1:0]  Base, Range,      // Base and range of peripheral addresses
  input  logic                Supported,        // Is this peripheral supported?
  input  logic                AccessValid,      // Is the access type valid?
  input  logic [1:0]          Size,             // Size of access
  input  logic [3:0]          SizeMask,         // List of supported sizes: 0 = 8, 1 = 16, 2 = 32, 3 = 64-bit
  output logic                Sel               // Decoder selects this peripheral
);

  logic                       Match;            // Address matches in range
  logic                       SizeValid;        // Size of access is valid

  // determine if an address is in a range starting at the base
  // for example, if Base = 0x04002000 and range = 0x00000FFF,
  // then anything address between 0x04002000 and 0x04002FFF should match (HSEL=1)
  assign Match = &((PhysicalAddress ~^ Base) | Range);

  // determine if legal size of access is being made (byte, halfword, word, doubleword)
  assign SizeValid = SizeMask[Size];

  // Select this peripheral if the address matches, the peripheral is supported, and the type and size of access is ok
  assign Sel = Match & Supported & AccessValid & SizeValid; // exclusion-tag: adrdecSel
endmodule
