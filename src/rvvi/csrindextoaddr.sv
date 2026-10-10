///////////////////////////////////////////
// csrindextoaddr.sv
//
// Written:  Rose Thompson rose@rosethompson.net 24 January 2024
// Modified:
//
// Purpose: Converts a one-hot RVVI CSR write index into the CSR address.
//
// Documentation:
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module csrindextoaddr #(parameter TOTAL_CSRS = 36) (
  input logic [TOTAL_CSRS-1:0]  CSRWen,
  output logic [11:0] CSRAddr);

  always_comb begin
    case(CSRWen)
      36'h0_0000_0000: CSRAddr = 12'h000;
      36'h0_0000_0001: CSRAddr = 12'h300;
      36'h0_0000_0002: CSRAddr = 12'h310;
      36'h0_0000_0004: CSRAddr = 12'h305;
      36'h0_0000_0008: CSRAddr = 12'h341;
      36'h0_0000_0010: CSRAddr = 12'h306;
      36'h0_0000_0020: CSRAddr = 12'h320;
      36'h0_0000_0040: CSRAddr = 12'h302;
      36'h0_0000_0080: CSRAddr = 12'h303;
      36'h0_0000_0100: CSRAddr = 12'h344;
      36'h0_0000_0200: CSRAddr = 12'h304;
      36'h0_0000_0400: CSRAddr = 12'h301;
      36'h0_0000_0800: CSRAddr = 12'h30A;
      36'h0_0000_1000: CSRAddr = 12'hF14;
      36'h0_0000_2000: CSRAddr = 12'h340;
      36'h0_0000_4000: CSRAddr = 12'h342;
      36'h0_0000_8000: CSRAddr = 12'h343;
      36'h0_0001_0000: CSRAddr = 12'hF11;
      36'h0_0002_0000: CSRAddr = 12'hF12;
      36'h0_0004_0000: CSRAddr = 12'hF13;
      36'h0_0008_0000: CSRAddr = 12'hF15;
      36'h0_0010_0000: CSRAddr = 12'h34A;
      36'h0_0020_0000: CSRAddr = 12'h100;
      36'h0_0040_0000: CSRAddr = 12'h104;
      36'h0_0080_0000: CSRAddr = 12'h105;
      36'h0_0100_0000: CSRAddr = 12'h141;
      36'h0_0200_0000: CSRAddr = 12'h106;
      36'h0_0400_0000: CSRAddr = 12'h10A;
      36'h0_0800_0000: CSRAddr = 12'h180;
      36'h0_1000_0000: CSRAddr = 12'h140;
      36'h0_2000_0000: CSRAddr = 12'h143;
      36'h0_4000_0000: CSRAddr = 12'h142;
      36'h0_8000_0000: CSRAddr = 12'h144;
      36'h1_0000_0000: CSRAddr = 12'h14D;
      36'h2_0000_0000: CSRAddr = 12'h001;
      36'h4_0000_0000: CSRAddr = 12'h002;
      36'h8_0000_0000: CSRAddr = 12'h003;
      default        : CSRAddr = 12'h000;
    endcase
  end
endmodule
