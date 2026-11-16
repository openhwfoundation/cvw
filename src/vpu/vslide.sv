///////////////////////////////////////////
// vslide.sv
//
// Written: Sophie Khuu skhuu@g.hmc.edu
// Created: 13 Nov 2026
//
// Purpose: RISC-V Vector Slide Unit
//
// Documentation: RISC-V System on Chip Design Volume 2
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module vslide import cvw::*; #(parameter cvw_t P) (
  input  logic [P.VLEN-1:0]         Vs2,
  input  logic [BLEN-1:0]           Vd,
  input  logic [P.XLEN-1:0]         Rs1,
  input  logic [4:0]                Imm,
  input  logic [2:0]                Funct3,
  input  logic                      Down,
  input  logic [1:0]                SEW,
  input  logic [$clog2(P.VLEN):0]   Vl,
  input  logic [BEATBITLEN-1:0]     Beat,
  output logic [BLEN-1:0]           VdBeat
);

  localparam BEATBITLEN = $clog2(P.VLEN/P.ELEN) + 1;
  localparam BLEN  = P.VPU_INT_BLEN;
  localparam BEATS = P.VLEN / BLEN;

  logic [P.XLEN-1:0]                ElShftAmt;    // OFFSET in elements
  logic [P.XLEN + 6-1:0]            BitShftAmt;   // OFFSET in bits
  logic [P.XLEN + 6-1:0]            BeatShftAmt;  // OFFSET in beats, this is temporary and will become "head" once vs2 is one beat/cycle
  logic [$clog2(BLEN)-1:0]          ShftAmt;      // OFFSET bits left over after whole beats
  logic [P.XLEN + 6-1:0]            UpperIdx, LowerIdx;  // beat numbers of the two vs2 beats
  logic [BLEN-1:0]                  Upper, Lower; // the two vs2 beats
  logic [2*BLEN-1:0]                Shifted;      // {Upper, Lower} after shifter
  logic [BLEN-1:0]                  SlidBeat;     // the kept half of Shifted
  logic [$clog2(P.VLEN)+5:0]        InsertPos;    // bit where rs1 element starts
  logic [63:0]                      Rs1Ext;       // rs1 sign-extended to 64 bits
  logic [P.VLEN-1:0]                KeepOld, Insert, Rs1Placed;
  logic [BLEN-1:0]                  KeepOldMask, InsertMask, Rs1Beat, Kept; // vpu's byte mask currently all 1s, so need these for now

  always_comb // mux selects ElShftAmt
    case (Funct3)
      3'b011:  ElShftAmt = P.XLEN'(Imm);          // vslideup.vi, vslidedown.vi
      3'b100:  ElShftAmt = P.XLEN'(Rs1);          // vslideup.vx, vslidedown.vx
      default: ElShftAmt = P.XLEN'(1);            // vslide1up, vslide1down
    endcase

// Shift Amount = ElShftAmt*SEW. Multiplying is a left shift by SEW + 3
  always_comb
    case (SEW)
      2'b00:   BitShftAmt = {6'b0, ElShftAmt} << 3;   // *8
      2'b01:   BitShftAmt = {6'b0, ElShftAmt} << 4;   // *16
      2'b10:   BitShftAmt = {6'b0, ElShftAmt} << 5;   // *32
      default: BitShftAmt = {6'b0, ElShftAmt} << 6;   // *64
    endcase

// split bits into whole beats and leftover bits
  assign BeatShftAmt = BitShftAmt >> $clog2(BLEN);
  assign ShftAmt = BitShftAmt[$clog2(BLEN)-1:0];

  always_comb // pick the two vs2 beats the vd beat comes from
    if (Down) begin
      LowerIdx = (P.XLEN+6)'(Beat) + BeatShftAmt;     // Down
      UpperIdx = LowerIdx + 1;
    end else begin
      UpperIdx = (P.XLEN+6)'(Beat) - BeatShftAmt;     // Up
      LowerIdx = UpperIdx - 1;
    end

// read one beat out of Vs2: shift vs2 right until beat at bottom, then keep one beat
  always_comb begin
    if (LowerIdx < (P.XLEN+6)'(BEATS)) Lower = BLEN'(Vs2 >> (LowerIdx*BLEN));
    else Lower = '0;
    if (UpperIdx < (P.XLEN+6)'(BEATS)) Upper = BLEN'(Vs2 >> (UpperIdx*BLEN));
    else Upper = '0;
  end

// for << >> shifter, slidedown keeps the lower half of a right shift, slideup the upper half of a left shift
    always_comb
        if (Down) begin
            Shifted  = {Upper, Lower} >> ShftAmt;
            SlidBeat = Shifted[BLEN-1:0];
    end else begin
            Shifted  = {Upper, Lower} << ShftAmt;
            SlidBeat = Shifted[2*BLEN-1:BLEN];
    end

// for slideup, vd elements below OFFSET keep their old value
    always_comb
        if (Down) KeepOld = '0;
        else KeepOld = ~({P.VLEN{1'b1}} << BitShftAmt);

   assign KeepOldMask = KeepOld[Beat*BLEN +: BLEN];
   assign Kept = (KeepOldMask & Vd) | (~KeepOldMask & SlidBeat);

// rs1 sign-extended to 64 bits (when XLEN < SEW, the value is sign-extended to SEW bits)
  if (P.XLEN == 32) assign Rs1Ext = {{32{Rs1[31]}}, Rs1};
  else assign Rs1Ext = Rs1;

// vslide1up puts rs1 in element 0, vslide1down puts rs1 in element vl-1
  always_comb
    if (Down) InsertPos = ($clog2(P.VLEN)+6)'(Vl-1) << (SEW+3);
    else InsertPos = '0;

// If slide1, Insert marks the element rs1 goes into
  always_comb
    if (Funct3 == 3'b110) Insert = ~({P.VLEN{1'b1}} << (8 << SEW)) << InsertPos;
    else                  Insert = '0;

  assign Rs1Placed = P.VLEN'(Rs1Ext) << InsertPos;  //move rs1's value to that element
  assign InsertMask = Insert[Beat*BLEN +: BLEN];
  assign Rs1Beat = Rs1Placed[Beat*BLEN +: BLEN];

  // when Insert is 1 take rs1, everywhere else take Kept
  assign VdBeat = (InsertMask & Rs1Beat) | (~InsertMask & Kept);

endmodule
