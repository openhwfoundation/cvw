///////////////////////////////////////////
// pmpadrdec.sv
//
// Written:  Thomas Fleming tfleming@hmc.edu 28 April 2021
// Modified: David Harris, Kip Macsai-Goren, Madeleine Masser-Frye
//
// Purpose: Address match for one PMP entry.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module pmpadrdec import cvw::*; #(parameter cvw_t P) (
  input  logic [P.PA_BITS-1:0]  PhysicalAddress,
  input  logic [7:0]            PMPCfg,
  input  logic [P.PA_BITS-3:0]  PMPAdr,
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
  // PMPAdr holds address bits PA_BITS-1:2, so the two lsbs of PhysicalAddress cannot change the comparison
  assign PAltPMPAdr = PhysicalAddress[P.PA_BITS-1:2] < PMPAdr; // unsigned comparison
  assign PAgePMPAdrOut = ~PAltPMPAdr;
  assign TORMatch = PAgePMPAdrIn & PAltPMPAdr; // exclusion-tag: PAgePMPAdrIn

  // Naturally aligned regions
  logic [P.PA_BITS-3:0] NAMask;

  // form a mask of the address bits (above the two lsbs) that lie inside the region: the trailing 1s of PMPAdr
  // and the 0 above them for NAPOT, none for NA4.  The region is 2^(k+2) bytes when the mask has k 1s.
  assign NAMask = (PMPAdr + {{(P.PA_BITS-3){1'b0}}, (AdrMode == NAPOT)}) ^ PMPAdr;
  assign NAMatch = &((PMPAdr ~^ PhysicalAddress[P.PA_BITS-1:2]) | NAMask); // check if upper bits of address match, ignore lower bits corresponding to inside the memory range

  // finally pick the appropriate match for the access type
  assign Match = (AdrMode == TOR) ? TORMatch :
                 (AdrMode[1]) ? NAMatch : // NA4 or NAPOT
                 1'b0; // OFF never matches

  assign L = PMPCfg[7];
  assign X = PMPCfg[2];
  assign W = PMPCfg[1];
  assign R = PMPCfg[0];

endmodule
