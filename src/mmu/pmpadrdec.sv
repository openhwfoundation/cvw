///////////////////////////////////////////
// pmpadrdec.sv
//
// Written: tfleming@hmc.edu 28 April 2021
// Modified:
//
// Purpose: Address decoder for the PMP checker. Decides whether a given address
//          falls within the PMP range for each address-matching mode
//          (top-of-range/TOR, naturally aligned four-byte region/NA4, and
//          naturally aligned power-of-two region/NAPOT), then selects the
//          output based on which mode is input.
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

module pmpadrdec import cvw::*;  #(parameter cvw_t P) (
  input  logic [P.PA_BITS-1:0]  PhysicalAddress,
  input  logic [1:0]            Size,
  input  logic [7:0]            PMPCfg,
  input  logic [P.PA_BITS-3:0]  PMPAdr,
  input  logic                  FirstMatch,
  input  logic                  PAgePMPAdrIn,
  output logic                  PAgePMPAdrOut,
  output logic                  Match,
  output logic                  L, X, W, R
);

  // define PMP addressing mode codes
  localparam                    TOR   = 2'b01;
  localparam                    NAPOT = 2'b11;

  logic                         TORMatch, NAMatch;
  logic                         PAltPMPAdr;
  logic [1:0]                   AdrMode;

  assign AdrMode = PMPCfg[4:3];

  // Top-of-range (TOR)
  // Append two implicit trailing 0's to PMPAdr value
  assign PAltPMPAdr = {1'b0, PhysicalAddress} < {1'b0, PMPAdr, 2'b00}; // unsigned comparison
  assign PAgePMPAdrOut = ~PAltPMPAdr;
  assign TORMatch = PAgePMPAdrIn & PAltPMPAdr; // exclusion-tag: PAgePMPAdrIn

  // Naturally aligned regions
  logic [P.PA_BITS-1:0] NAMask, NABase;

  assign NAMask[1:0] = {2'b11};
  assign NAMask[P.PA_BITS-1:2] = (PMPAdr + {{(P.PA_BITS-3){1'b0}}, (AdrMode == NAPOT)}) ^ PMPAdr;
  // form a mask where the bottom k bits are 1, corresponding to a size of 2^k bytes for this memory region.
  // This assumes we're using at least an NA4 region, but works for any size NAPOT region.
  assign NABase = {(PMPAdr & ~NAMask[P.PA_BITS-1:2]), 2'b00}; // base physical address of the pmp region
  assign NAMatch = &((NABase ~^ PhysicalAddress) | NAMask); // check if upper bits of base address match, ignore lower bits corresponding to inside the memory range

  // finally pick the appropriate match for the access type
  assign Match = (AdrMode == TOR) ? TORMatch :
                 (AdrMode[1]) ? NAMatch : // NA4 or NAPOT
                 1'b0; // OFF never matches

  assign L = PMPCfg[7];
  assign X = PMPCfg[2];
  assign W = PMPCfg[1];
  assign R = PMPCfg[0];

endmodule
