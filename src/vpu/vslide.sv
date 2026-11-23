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
  input  logic [BLEN-1:0]           VSrcB,
  input  logic [P.XLEN-1:0]         SrcA,
  input  logic [4:0]                Imm,
  input  logic [2:0]                Funct3,
  input  logic                      Down,
  input  logic [1:0]                SEW,
  input  logic [$clog2(P.VLEN):0]   Vl,
  input  logic [BEATBITLEN-1:0]     Beat,      // number of the VSrcB beat arriving this cycle
  output logic [BLEN-1:0]           VSlideResult, // one vd beat
  output logic [BEATBITLEN-1:0]     VSlideBeat, // which vd beat VSlideResult is written to
  output logic [BLEN/8-1:0]         VSlideByteMask  // Bytes of the vd beat to write, others keep old vd
);

  localparam BEATBITLEN = $clog2(P.VLEN/P.ELEN) + 1;
  localparam BLEN  = P.VPU_INT_BLEN;
  localparam BEATS = P.VLEN / BLEN;
  localparam BYTES = BLEN / 8;

  logic [P.XLEN-1:0]                ElementShftAmt;    // OFFSET in elements
  logic [P.XLEN + 3-1:0]            ByteShftAmt;        // OFFSET in bytes
  logic [P.XLEN + 3-1:0]            BeatShftAmt;       // OFFSET in whole beats
  logic [$clog2(BLEN)-1:0]          ShftAmt;           // OFFSET bits left over after whole beats
  logic [BLEN-1:0]                  Current, Head;     // current VSrcB beat, head is VSrcB beat from last cycle
  logic [P.XLEN + 3-1:0]            VdIdx;             // vd beat that this cycle makes
  logic                             InRange;           // VdIdx is a real vd beat (not below 0 or past end)
  logic [2*BLEN-2:0]                Z, ZShift;         // shifter input (Z) and shifter output (ZShift)
  logic [$clog2(BLEN)-1:0]          Offset;            // right-shift amount
  logic [BLEN-1:0]                  SlidBeat;          // the bottom beat of ZShift
  logic [BLEN-1:0]                  Result;            // SlidBeat, or 0 when VSrcB data it would copy is past the end of VSrcB
  logic [BYTES-1:0]                 DataMask;          // bytes of Result to write
  logic [63:0]                      SrcAExt;            // SrcA sign-extended to 64 bits
  logic [$clog2(P.VLEN)+5:0]        InsertPos;         // bit in the vd register where SrcA goes
  logic                             SrcAInsert;           // SrcA goes into this vd beat
  logic [$clog2(BLEN)-1:0]          SrcAPos;            // bit in this vd beat where SrcA element starts
  logic [BYTES-1:0]                 SrcAMask;           // bytes of the SrcA element

  always_comb
    case (Funct3)
      3'b011:  ElementShftAmt = P.XLEN'(Imm);          // vslideup.vi, vslidedown.vi
      3'b100:  ElementShftAmt = (SrcA);          // vslideup.vx, vslidedown.vx
      default: ElementShftAmt = P.XLEN'(1);            // vslide1up, vslide1down
    endcase

// Shift Amount = ElementShftAmt*bytes per element. multiplying = a left shift by SEW
  always_comb
    case (SEW)
      2'b00:   ByteShftAmt = {3'b0, ElementShftAmt}; // *1
      2'b01:   ByteShftAmt = {3'b0, ElementShftAmt} << 1;   // *2
      2'b10:   ByteShftAmt = {3'b0, ElementShftAmt} << 2;   // *4
      default: ByteShftAmt = {3'b0, ElementShftAmt} << 3;   // *8
    endcase

// the shifter only sees two beats of VSrcB at a time (Current and Head), so it can only shift by less than one beat.
// to slide farther, we can split ByteShftAmt into whole beats and the leftover bytes.
// whole beats handled by writing the result to a different vd beat, leftover bytes handled by the shifter
  assign BeatShftAmt = ByteShftAmt >> $clog2(BYTES);
  assign ShftAmt = {ByteShftAmt[$clog2(BYTES)-1:0], 3'b0};

// Slidedown runs one extra cycle past the end of VSrcB. No VSrcB beat on that cycle, so uses 0
  always_comb
    if (Beat < BEATBITLEN'(BEATS)) Current = VSrcB;
    else                           Current = '0;

  flopenr #(BLEN) headreg(clk, reset, NextBeat, Current, Head);  // head saves current VSrcB beat for the next cycle. on beat 0, head still holds a beat from the instruction before, but those bits are not written (below OFFSET for slideup).

// for slideup, vd beat Beat+BeatShftAmt is made of this VSrcB beat and the previous one shifted up
// for slidedown: vd beat Beat-1-BeatShftAmt is made of the previous VSrcB beat and this one shifted down
  always_comb
    if (Down) begin
      VdIdx   = (P.XLEN+3)'(Beat) - 1 - BeatShftAmt;
      InRange = (P.XLEN+3)'(Beat) > BeatShftAmt;              // VdIdx >= 0
    end else begin
      VdIdx   = (P.XLEN+3)'(Beat) + BeatShftAmt;
      InRange = VdIdx < (P.XLEN+3)'(BEATS);
    end

// keeps only the bits that count beats, vd beat below 0 or past the end wraps around to other end
  assign VSlideBeat = BEATBITLEN'(VdIdx) & BEATBITLEN'(BEATS-1);

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
    else         Result = '0; //vd beats that no VSrcB data reaches get 0

// which bytes to write (bytes not written keep old vd)
// slideup: first vd beat the elements below OFFSET keep old vd, beats that wrap past the end are not written
// slidedown: every beat written & beats that wrap around get 0. first cycle's beat is wrong (the next VSrcB beat isn't there yet) but the extra cycle writes it again
  always_comb
    if (Down)            DataMask = '1;     //slidedown
    else if (~InRange)   DataMask = '0;     //slideup: beats past end write nothing
    else if (Beat == '0) DataMask = {BYTES{1'b1}} << (ShftAmt >> 3); //slideup first beat: skip bytes below OFFSET
    else                 DataMask = '1;     // slideup other beats: write every byte

// SrcA sign-extended to 64 bits (when XLEN < SEW, the value is sign-extended to SEW bits)
  if (P.XLEN == 32) assign SrcAExt = {{32{SrcA[31]}}, SrcA};
  else assign SrcAExt = SrcA;

// vslide1up puts SrcA in element 0, vslide1down puts SrcA in element vl-1
  always_comb
    if (Down) InsertPos = ($clog2(P.VLEN)+6)'(Vl-1) << (SEW+3);
    else      InsertPos = '0;


  assign SrcAInsert = (Funct3 == 3'b110) & (VSlideBeat == BEATBITLEN'(InsertPos >> $clog2(BLEN))); // vd beat we're writing is the one SrcA belongs in
  assign SrcAPos  = InsertPos[$clog2(BLEN)-1:0];                                     // which bit in that beat

  always_comb
    if (SrcAInsert) SrcAMask = ~({BYTES{1'b1}} << (1 << SEW)) << (SrcAPos >> 3);
    else         SrcAMask = '0;

// if slide1 and SrcA goes into this beat, write SrcA
  always_comb begin
    VSlideResult = Result;
    if (SrcAInsert)
      case (SEW)
        2'b00:   VSlideResult[SrcAPos +: 8]  = SrcAExt[7:0];
        2'b01:   VSlideResult[SrcAPos +: 16] = SrcAExt[15:0];
        2'b10:   VSlideResult[SrcAPos +: 32] = SrcAExt[31:0];
        default: VSlideResult[SrcAPos +: 64] = SrcAExt;
      endcase
  end

  assign VSlideByteMask = DataMask | SrcAMask;

endmodule
