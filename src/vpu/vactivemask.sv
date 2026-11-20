///////////////////////////////////////////
// vactivemask.sv
//
// Written: Georgia Tai ytai@g.hmc.edu
// Created: 13 November 2026
//
// Purpose: Creates a VLEN/8 byte mask from vl and the v0 mask
//
// Documentation: RISC-V System on Chip Design Volume 2
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Skyworks Solutions
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
////////////////////////////////////////////////////////////////////////////////////////////////

module vactivemask #(parameter VLEN) (
  input  logic [$clog2(VLEN):0] VLD,
  input  logic [2:0]            VdEEWD,           // log2(EEW) of vd: 011 8b ... 110 64b
  input  logic [2:0]            MicroOpIndexD,    // register of the vd group
  input  logic                  VMaskedD,         // v0 masks the write
  input  logic [1:0]            VWriteElementsD,  // 00 below vl, 01 element 0, 10 mask result, 11 whole register
  input  logic [VLEN-1:0]       v0D,
  output logic [VLEN/8-1:0]     ActiveByteMaskD   // bytes of vd themicro-op writes
);

  localparam BYTES     = VLEN/8;
  localparam BYTEBITS  = $clog2(BYTES);
  localparam LIMITBITS = $clog2(VLEN) + 4;

  logic [1:0]           ElementShiftD;            // log2 bytes per element
  logic [LIMITBITS-1:0] VlBytesD;                 // vl in bytes
  logic [LIMITBITS-1:0] ElementBytesD;            // bytes in one element
  logic [VLEN-1:0]      V0GroupD;                 // v0 from the first element of this register
  logic [BYTES-1:0]     BodyD, Element0D;
  logic                 VlNonzeroD;

  assign ElementShiftD = 2'(VdEEWD - 3'd3);
  assign VlBytesD      = LIMITBITS'(VLD) << ElementShiftD;
  assign ElementBytesD = LIMITBITS'(1) << ElementShiftD;
  assign V0GroupD      = v0D >> ({MicroOpIndexD, {BYTEBITS{1'b0}}} >> ElementShiftD);
  assign VlNonzeroD    = |VLD;

  // is byte in body (element index < vl)
  genvar b;
  for (b = 0; b < BYTES; b++) begin : bytes
    logic [LIMITBITS-1:0] GroupByteD;             // byte position in the vd group
    logic                 V0BitD;                 // v0 bit of this byte's element

    assign GroupByteD = LIMITBITS'({MicroOpIndexD, BYTEBITS'(b)});
    mux4 #(1) v0mux(V0GroupD[b], V0GroupD[b/2], V0GroupD[b/4], V0GroupD[b/8], ElementShiftD, V0BitD);
    assign BodyD[b]     = (GroupByteD < VlBytesD) & (~VMaskedD | V0BitD);
    assign Element0D[b] = (GroupByteD < ElementBytesD) & VlNonzeroD;
  end

  // *** mask result write r | ~v0 or merge with old vd when masked
  // *** vstart not applied yet
  mux4 #(BYTES) writemux(BodyD, Element0D, {BYTES{VlNonzeroD}}, '1, VWriteElementsD, ActiveByteMaskD);

endmodule
