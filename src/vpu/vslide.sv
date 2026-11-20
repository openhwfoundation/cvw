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
  input  logic                      clk, reset,
  input  logic                      NextBeat,  // 1 = move to next beat
  input  logic [BLEN-1:0]           B,         // SrcB
  input  logic [P.XLEN-1:0]         Rs1,
  input  logic [4:0]                Imm,
  input  logic [2:0]                Funct3,
  input  logic                      Down,
  input  logic [1:0]                SEW,
  input  logic [$clog2(P.VLEN):0]   Vl,
  input  logic [BEATBITLEN-1:0]     Beat,      // number of the B beat arriving this cycle
  output logic [BLEN-1:0]           VdBeat,
  output logic [BEATBITLEN-1:0]     VdBeatNum, // which vd beat VdBeat is written to
  output logic [BLEN/8-1:0]         VdByteMask  // Bytes of the vd beat to write, others keep old vd
);

  localparam BEATBITLEN = $clog2(P.VLEN/P.ELEN) + 1;
  localparam BLEN  = P.VPU_INT_BLEN;
  localparam BEATS = P.VLEN / BLEN;
  localparam BYTES = BLEN / 8;

  logic [P.XLEN-1:0]                ElementShftAmt;    // OFFSET in elements
  logic [P.XLEN + 6-1:0]            BitShftAmt;        // OFFSET in bits
  logic [P.XLEN + 6-1:0]            BeatShftAmt;       // OFFSET in whole beats
  logic [$clog2(BLEN)-1:0]          ShftAmt;           // OFFSET bits left over after whole beats
  logic [BLEN-1:0]                  Current, Head;     // current B beat, head is B beat from last cycle
  logic [P.XLEN + 6-1:0]            VdIdx;             // vd beat that this cycle makes
  logic                             InRange;           // VdIdx is a real vd beat (not below 0 or past end)
  logic [2*BLEN-2:0]                Z, ZShift;         // shifter input (Z) and shifter output (ZShift)
  logic [$clog2(BLEN)-1:0]          Offset;            // right-shift amount
  logic [BLEN-1:0]                  SlidBeat;          // the bottom beat of ZShift
  logic [BLEN-1:0]                  Result;            // SlidBeat, or 0 when B data it would copy is past the end of B
  logic [BYTES-1:0]                 DataMask;          // bytes of Result to write
  logic [63:0]                      Rs1Ext;            // rs1 sign-extended to 64 bits
  logic [$clog2(P.VLEN)+5:0]        InsertPos;         // bit in the vd register where rs1 goes
  logic                             Rs1Here;           // rs1 goes into this vd beat
  logic [$clog2(BLEN)-1:0]          Rs1Pos;            // bit in this vd beat where the rs1 element starts
  logic [BYTES-1:0]                 Rs1Mask;           // bytes of the rs1 element

  always_comb
    case (Funct3)
      3'b011:  ElementShftAmt = P.XLEN'(Imm);          // vslideup.vi, vslidedown.vi
      3'b100:  ElementShftAmt = P.XLEN'(Rs1);          // vslideup.vx, vslidedown.vx
      default: ElementShftAmt = P.XLEN'(1);            // vslide1up, vslide1down
    endcase

// Shift Amount = ElementShftAmt*SEW. multiplying = a left shift by SEW + 3
  always_comb
    case (SEW)
      2'b00:   BitShftAmt = {6'b0, ElementShftAmt} << 3;   // *8
      2'b01:   BitShftAmt = {6'b0, ElementShftAmt} << 4;   // *16
      2'b10:   BitShftAmt = {6'b0, ElementShftAmt} << 5;   // *32
      default: BitShftAmt = {6'b0, ElementShftAmt} << 6;   // *64
    endcase

// the shifter only sees two beats of B at a time (Current and Head), so it can only shift by less than one beat.
// to slide farther, we can split BitShftAmt into whole beats and the leftover bits.
// whole beats handled by writing the result to a different vd beat, leftover bits handled by the shifter
  assign BeatShftAmt = BitShftAmt >> $clog2(BLEN);
  assign ShftAmt = BitShftAmt[$clog2(BLEN)-1:0];

// Slidedown runs one extra cycle past the end of B. No B beat on that cycle, so uses 0
  always_comb
    if (Beat < BEATBITLEN'(BEATS)) Current = B;
    else                           Current = '0;

  flopenr #(BLEN) headreg(clk, reset, NextBeat, Current, Head);  // head saves current B beat for the next cycle. on beat 0, head still holds a beat from the instruction before, but those bits are not written (below OFFSET for slideup).

// for slideup, vd beat Beat+BeatShftAmt is made of this B beat and the previous one shifted up
// for slidedown: vd beat Beat-1-BeatShftAmt is made of the previous B beat and this one shifted down
  always_comb
    if (Down) begin
      VdIdx   = (P.XLEN+6)'(Beat) - 1 - BeatShftAmt;
      InRange = (P.XLEN+6)'(Beat) > BeatShftAmt;              // VdIdx >= 0
    end else begin
      VdIdx   = (P.XLEN+6)'(Beat) + BeatShftAmt;
      InRange = VdIdx < (P.XLEN+6)'(BEATS);
    end

// keeps only the bits that count beats. vd beat below 0 or past the end wraps around to other end
  assign VdBeatNum = BEATBITLEN'(VdIdx) & BEATBITLEN'(BEATS-1);

// << >> shifter built like scalar shifter, A slidedown shifts right by ShftAmt, a slideup shifts right by BLEN-1-ShftAmt (~ShftAmt)
  always_comb
    if (Down) Z = {Current[BLEN-2:0], Head};      // Down
    else      Z = {Current, Head[BLEN-1:1]};      // Up

  always_comb
    if (Down) Offset = ShftAmt;
    else      Offset = ~ShftAmt;

  assign ZShift = Z >> Offset;
  assign SlidBeat = ZShift[BLEN-1:0];

  always_comb
    if (InRange) Result = SlidBeat;
    else         Result = '0; //vd beats that no B data reaches get 0

// which bytes to write (bytes not written keep old vd)
// slideup: first vd beat the elements below OFFSET keep old vd, beats that wrap past the end are not written
// slidedown: every beat written & beats that wrap around get 0. first cycle's beat is wrong (the next B beat isn't there yet) but the extra cycle writes it again
  always_comb
    if (Down)            DataMask = '1;     //slidedown
    else if (~InRange)   DataMask = '0;     //slideup: beats past end write nothing
    else if (Beat == '0) DataMask = {BYTES{1'b1}} << (ShftAmt >> 3); //slideup first beat: skip bytes below OFFSET
    else                 DataMask = '1;     // slideup other beats: write every byte

// rs1 sign-extended to 64 bits (when XLEN < SEW, the value is sign-extended to SEW bits)
  if (P.XLEN == 32) assign Rs1Ext = {{32{Rs1[31]}}, Rs1};
  else assign Rs1Ext = Rs1;

// vslide1up puts rs1 in element 0, vslide1down puts rs1 in element vl-1
  always_comb
    if (Down) InsertPos = ($clog2(P.VLEN)+6)'(Vl-1) << (SEW+3);
    else      InsertPos = '0;


  assign Rs1Here = (Funct3 == 3'b110) & (VdBeatNum == BEATBITLEN'(InsertPos >> $clog2(BLEN))); // split InsertPos into which vd beat
  assign Rs1Pos  = InsertPos[$clog2(BLEN)-1:0];                                                // and which bit in that beat

  always_comb
    if (Rs1Here) Rs1Mask = ~({BYTES{1'b1}} << (1 << SEW)) << (Rs1Pos >> 3);
    else         Rs1Mask = '0;

// if slide1 and rs1 goes into this beat, write rs1
  always_comb begin
    VdBeat = Result;
    if (Rs1Here)
      case (SEW)
        2'b00:   VdBeat[Rs1Pos +: 8]  = Rs1Ext[7:0];
        2'b01:   VdBeat[Rs1Pos +: 16] = Rs1Ext[15:0];
        2'b10:   VdBeat[Rs1Pos +: 32] = Rs1Ext[31:0];
        default: VdBeat[Rs1Pos +: 64] = Rs1Ext;
      endcase
  end

  assign VdByteMask = DataMask | Rs1Mask;

endmodule
