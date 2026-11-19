///////////////////////////////////////////
// svrf.sv
//
// Written: Georgia Tai ytai@g.hmc.edu
// Created: 10 November 2026
//
// Purpose: Speculative vector register file
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

module svrf #(parameter VLEN, BLEN, EU, ENTRYBITS, BEATBITS) (
  input  logic                 clk, reset,
  // result beats from the EUs
  input  logic [EU-1:0]        BeatValidW, LastBeatW, VRegWriteW,
  input  logic [ENTRYBITS-1:0] OrderW [EU-1:0],
  input  logic [BEATBITS-1:0]  BeatW [EU-1:0],
  input  logic [BLEN-1:0]      ResultBeatW [EU-1:0],
  input  logic [BLEN/8-1:0]    ByteMaskW [EU-1:0],
  input  logic [4:0]           VdW [EU-1:0],
  // old vd beats from the VRF, one per bank
  input  logic [VLEN/BLEN-1:0] OldVdValidW,
  input  logic [ENTRYBITS-1:0] OldVdOrderW [VLEN/BLEN-1:0],
  input  logic [BLEN-1:0]      OldVdDataW [VLEN/BLEN-1:0],
  // commit of the entry at the order queue head
  input  logic [ENTRYBITS-1:0] HeadOrderW,
  input  logic                 CommitW,
  output logic                 HeadCompleteW, HeadVRegWriteW,
  output logic [4:0]           HeadVdW,
  output logic [VLEN-1:0]      HeadDataW
);

  localparam ENTRIES = 2**ENTRYBITS;
  localparam BEATS   = VLEN/BLEN;
  localparam BYTES   = BLEN/8;

  logic [VLEN-1:0]    Data [ENTRIES-1:0];
  logic [4:0]         Vd [ENTRIES-1:0];
  logic [ENTRIES-1:0] VRegWrite, Complete;

  genvar entry, eu, beat, index;

  for (entry = 0; entry < ENTRIES; entry++) begin : entries
    logic [EU-1:0] EntryHitW, LastHitW;
    logic [5:0]    EUCtrlW [EU-1:0];
    logic [5:0]    CtrlW;
    logic          ClearW;

    for (eu = 0; eu < EU; eu++) begin : eucontrol
      assign EntryHitW[eu] = BeatValidW[eu] & (OrderW[eu] == ENTRYBITS'(entry));
      assign LastHitW[eu]  = EntryHitW[eu] & LastBeatW[eu];
      assign EUCtrlW[eu]   = {6{EntryHitW[eu]}} & {VdW[eu], VRegWriteW[eu]};
    end

    or_rows #(EU, 6) ctrlmux(.a(EUCtrlW), .y(CtrlW));
    flopenr #(6) ctrlreg(clk, reset, |EntryHitW, CtrlW, {Vd[entry], VRegWrite[entry]});

    // set by last beat, cleared by commit
    assign ClearW = CommitW & (HeadOrderW == ENTRYBITS'(entry));
    flopr #(1) completereg(clk, reset, |LastHitW | (Complete[entry] & ~ClearW), Complete[entry]);

    for (beat = 0; beat < BEATS; beat++) begin : beats
      logic [EU-1:0]     BeatHitW;
      logic [BLEN-1:0]   EUDataW [EU-1:0];
      logic [BYTES-1:0]  EUByteMaskW [EU-1:0];
      logic [BLEN-1:0]   ResultW, NextDataW;
      logic [BYTES-1:0]  ResultByteMaskW, WriteByteMaskW;
      logic              OldVdHitW;

      for (eu = 0; eu < EU; eu++) begin : eudata
        assign BeatHitW[eu]    = EntryHitW[eu] & (BeatW[eu] == BEATBITS'(beat));
        assign EUDataW[eu]     = {BLEN{BeatHitW[eu]}} & ResultBeatW[eu];
        assign EUByteMaskW[eu] = {BYTES{BeatHitW[eu]}} & ByteMaskW[eu];
      end

      or_rows #(EU, BLEN)  datamux(.a(EUDataW), .y(ResultW));
      or_rows #(EU, BYTES) bytemux(.a(EUByteMaskW), .y(ResultByteMaskW));

      // old vd beat always lands before its result
      assign OldVdHitW      = OldVdValidW[beat] & (OldVdOrderW[beat] == ENTRYBITS'(entry));
      assign WriteByteMaskW = ResultByteMaskW | {BYTES{OldVdHitW}};
      mux2 #(BLEN) oldvdmux(OldVdDataW[beat], ResultW, |BeatHitW, NextDataW);

      for (index = 0; index < BYTES; index++) begin : bytes
        flopenr #(8) bytereg(clk, reset, WriteByteMaskW[index], NextDataW[index*8 +: 8], Data[entry][beat*BLEN + index*8 +: 8]);
      end
    end
  end

  assign HeadCompleteW  = Complete[HeadOrderW];
  assign HeadVRegWriteW = VRegWrite[HeadOrderW];
  assign HeadVdW        = Vd[HeadOrderW];
  assign HeadDataW      = Data[HeadOrderW];

endmodule
