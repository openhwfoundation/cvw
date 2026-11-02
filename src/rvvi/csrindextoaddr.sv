///////////////////////////////////////////
// csrindextoaddr.sv
//
// Written: Rose Thompson rose@rosethompson.net
// Created: 24 January 2024
// Modified: 24 January 2024
//
// Purpose: Converts the rvvi CSR index into the CSR address
//
// Documentation:
//
// A component of the CORE-V-WALLY configurable RISC-V project.
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module csrindextoaddr #(parameter TOTAL_CSRS = 65) (
  input  logic [TOTAL_CSRS-1:0] CSRWen,
  output logic [11:0]            CSRAddr);

  // CSRWen is one-hot: bit i selects CSRArray[i] as assigned in testbench/common/rvvitbwrapper.sv
  // and the FPGA top levels.  Return the address of that CSR (0 if none).
  always_comb begin
    case (CSRWen)
      65'h0_0000_0000_0000_0000: CSRAddr = 12'h000;
      65'h0_0000_0000_0000_0001: CSRAddr = 12'h300;
      65'h0_0000_0000_0000_0002: CSRAddr = 12'h310;
      65'h0_0000_0000_0000_0004: CSRAddr = 12'h305;
      65'h0_0000_0000_0000_0008: CSRAddr = 12'h341;
      65'h0_0000_0000_0000_0010: CSRAddr = 12'h306;
      65'h0_0000_0000_0000_0020: CSRAddr = 12'h320;
      65'h0_0000_0000_0000_0040: CSRAddr = 12'h302;
      65'h0_0000_0000_0000_0080: CSRAddr = 12'h303;
      65'h0_0000_0000_0000_0100: CSRAddr = 12'h344;
      65'h0_0000_0000_0000_0200: CSRAddr = 12'h304;
      65'h0_0000_0000_0000_0400: CSRAddr = 12'h301;
      65'h0_0000_0000_0000_0800: CSRAddr = 12'h30A;
      65'h0_0000_0000_0000_1000: CSRAddr = 12'hF14;
      65'h0_0000_0000_0000_2000: CSRAddr = 12'h340;
      65'h0_0000_0000_0000_4000: CSRAddr = 12'h342;
      65'h0_0000_0000_0000_8000: CSRAddr = 12'h343;
      65'h0_0000_0000_0001_0000: CSRAddr = 12'hF11;
      65'h0_0000_0000_0002_0000: CSRAddr = 12'hF12;
      65'h0_0000_0000_0004_0000: CSRAddr = 12'hF13;
      65'h0_0000_0000_0008_0000: CSRAddr = 12'hF15;
      65'h0_0000_0000_0010_0000: CSRAddr = 12'h34A;
      65'h0_0000_0000_0020_0000: CSRAddr = 12'h100;
      65'h0_0000_0000_0040_0000: CSRAddr = 12'h104;
      65'h0_0000_0000_0080_0000: CSRAddr = 12'h105;
      65'h0_0000_0000_0100_0000: CSRAddr = 12'h141;
      65'h0_0000_0000_0200_0000: CSRAddr = 12'h106;
      65'h0_0000_0000_0400_0000: CSRAddr = 12'h10A;
      65'h0_0000_0000_0800_0000: CSRAddr = 12'h180;
      65'h0_0000_0000_1000_0000: CSRAddr = 12'h140;
      65'h0_0000_0000_2000_0000: CSRAddr = 12'h143;
      65'h0_0000_0000_4000_0000: CSRAddr = 12'h142;
      65'h0_0000_0000_8000_0000: CSRAddr = 12'h144;
      65'h0_0000_0001_0000_0000: CSRAddr = 12'h14D;
      65'h0_0000_0002_0000_0000: CSRAddr = 12'h001;
      65'h0_0000_0004_0000_0000: CSRAddr = 12'h002;
      65'h0_0000_0008_0000_0000: CSRAddr = 12'h003;
      65'h0_0000_0010_0000_0000: CSRAddr = 12'h34B;
      65'h0_0000_0020_0000_0000: CSRAddr = 12'h600;
      65'h0_0000_0040_0000_0000: CSRAddr = 12'h200;
      65'h0_0000_0080_0000_0000: CSRAddr = 12'h602;
      65'h0_0000_0100_0000_0000: CSRAddr = 12'h612;
      65'h0_0000_0200_0000_0000: CSRAddr = 12'h603;
      65'h0_0000_0400_0000_0000: CSRAddr = 12'h604;
      65'h0_0000_0800_0000_0000: CSRAddr = 12'h204;
      65'h0_0000_1000_0000_0000: CSRAddr = 12'h605;
      65'h0_0000_2000_0000_0000: CSRAddr = 12'h615;
      65'h0_0000_4000_0000_0000: CSRAddr = 12'h606;
      65'h0_0000_8000_0000_0000: CSRAddr = 12'h607;
      65'h0_0001_0000_0000_0000: CSRAddr = 12'h60A;
      65'h0_0002_0000_0000_0000: CSRAddr = 12'h61A;
      65'h0_0004_0000_0000_0000: CSRAddr = 12'h643;
      65'h0_0008_0000_0000_0000: CSRAddr = 12'h644;
      65'h0_0010_0000_0000_0000: CSRAddr = 12'h645;
      65'h0_0020_0000_0000_0000: CSRAddr = 12'h64A;
      65'h0_0040_0000_0000_0000: CSRAddr = 12'h680;
      65'h0_0080_0000_0000_0000: CSRAddr = 12'hE12;
      65'h0_0100_0000_0000_0000: CSRAddr = 12'h205;
      65'h0_0200_0000_0000_0000: CSRAddr = 12'h240;
      65'h0_0400_0000_0000_0000: CSRAddr = 12'h241;
      65'h0_0800_0000_0000_0000: CSRAddr = 12'h242;
      65'h0_1000_0000_0000_0000: CSRAddr = 12'h243;
      65'h0_2000_0000_0000_0000: CSRAddr = 12'h244;
      65'h0_4000_0000_0000_0000: CSRAddr = 12'h280;
      65'h0_8000_0000_0000_0000: CSRAddr = 12'h24D;
      65'h1_0000_0000_0000_0000: CSRAddr = 12'h25D;
      default                  : CSRAddr = 12'h000;
    endcase
  end
endmodule
