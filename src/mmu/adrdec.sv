///////////////////////////////////////////
// adrdec.sv
//
// Written: David_Harris@hmc.edu 29 January 2021
// Modified:
//
// Purpose: Address decoder
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
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
