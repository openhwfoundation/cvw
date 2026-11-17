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
  input  logic                      NextBeat,  // vector destination
  input  logic [P.VLEN-1:0]         B,         // SrcB
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

  logic [P.XLEN-1:0]                ElementShftAmt;    // OFFSET in elements
  logic [P.XLEN + 6-1:0]            BitShftAmt;        // OFFSET in bits
  logic [P.XLEN + 6-1:0]            BeatShftAmt;       // OFFSET in beats, this is temporary and will become "head" once vs2 is one beat/cycle
  logic [$clog2(BLEN)-1:0]          ShftAmt;           // OFFSET bits left over after whole beats
  logic [P.XLEN + 6-1:0]            UpperIdx, LowerIdx;// beat numbers of the two vs2 beats
  logic [BLEN-1:0]                  Upper, Lower;      // the two vs2 beats
  logic [2*BLEN-2:0]                Z, ZShift;         // shifter input
  logic [$clog2(BLEN)-1:0]          Offset;            // right-shift amount
  logic [BLEN-1:0]                  SlidBeat;          // the bottom beat of ZShift
  logic [63:0]                      Rs1Ext;            // rs1 sign-extended to 64 bits
  logic [P.VLEN-1:0]                KeepOld;
  logic [$clog2(P.VLEN)+1:0]        ElPerBeat;         // elements in one beat
  logic [$clog2(P.VLEN)+1:0]        VlCount;           // counts backwards from vl
  logic [$clog2(P.VLEN)+1:0]        NextVlCount, SavedVlCount;
  logic                             Stopped;           // VlCount reached 0 or is negative
  logic                             LastBeat;          // VlCount reaches 0 or goes negative on this beat
  logic [$clog2(P.VLEN)+1:0]        ElementPos;        // NextVlCount with ElPerBeat added back
  logic                             Rs1Here;           // rs1 goes into this beat
  logic [$clog2(BLEN)-1:0]          Rs1Pos;            // bit in this beat where the rs1 element starts
  logic [BLEN-1:0]                  KeepOldMask, Kept; // vpu's byte mask currently all 1s, so need these for now

  always_comb // mux selects ElementShftAmt
    case (Funct3)
      3'b011:  ElementShftAmt = P.XLEN'(Imm);          // vslideup.vi, vslidedown.vi
      3'b100:  ElementShftAmt = P.XLEN'(Rs1);          // vslideup.vx, vslidedown.vx
      default: ElementShftAmt = P.XLEN'(1);            // vslide1up, vslide1down
    endcase

// Shift Amount = ElementShftAmt*SEW. Multiplying is a left shift by SEW + 3
  always_comb
    case (SEW)
      2'b00:   BitShftAmt = {6'b0, ElementShftAmt} << 3;   // *8
      2'b01:   BitShftAmt = {6'b0, ElementShftAmt} << 4;   // *16
      2'b10:   BitShftAmt = {6'b0, ElementShftAmt} << 5;   // *32
      default: BitShftAmt = {6'b0, ElementShftAmt} << 6;   // *64
    endcase

// split bits into whole beats and leftover bits.
// the shifter only sees two beats of B at a time (upper and lower), so it can only shift by less than one beat.
// to slide farther, we can split BitShftAmt into whole beats and the leftover bits (which the shifter handles.)
  assign BeatShftAmt = BitShftAmt >> $clog2(BLEN);
  assign ShftAmt = BitShftAmt[$clog2(BLEN)-1:0];

  always_comb // pick the two SrcB beats the vd beat comes from
    if (Down) begin
      LowerIdx = (P.XLEN+6)'(Beat) + BeatShftAmt;     // Down
      UpperIdx = LowerIdx + 1;
    end else begin
      UpperIdx = (P.XLEN+6)'(Beat) - BeatShftAmt;     // Up
      LowerIdx = UpperIdx - 1;
    end

// read one beat out of SrcB: shift B right until beat at bottom, then keep one beat
  always_comb begin
    if (LowerIdx < (P.XLEN+6)'(BEATS)) Lower = BLEN'(B >> (LowerIdx*BLEN));
    else Lower = '0;
    if (UpperIdx < (P.XLEN+6)'(BEATS)) Upper = BLEN'(B >> (UpperIdx*BLEN));
    else Upper = '0;
  end

// << >> shifter built like scalar shifter, A slidedown shifts right by ShftAmt, a slideup shifts right by BLEN-1-ShftAmt (~ShftAmt)
  always_comb
    if (Down) Z = {Upper[BLEN-2:0], Lower};  // Down
    else      Z = {Upper, Lower[BLEN-1:1]};  // Up

  always_comb
      if (Down) Offset = ShftAmt;
      else      Offset = ~ShftAmt;

  assign ZShift = Z >> Offset;
  assign SlidBeat = ZShift[BLEN-1:0];

// for slideup, vd elements below OFFSET keep their old value ***SK convert to byte mask
    always_comb
        if (Down) KeepOld = '0;
        else KeepOld = ~({P.VLEN{1'b1}} << BitShftAmt);

   assign KeepOldMask = KeepOld[Beat*BLEN +: BLEN];
   assign Kept = (KeepOldMask & Vd) | (~KeepOldMask & SlidBeat);

// rs1 sign-extended to 64 bits (when XLEN < SEW, the value is sign-extended to SEW bits)
  if (P.XLEN == 32) assign Rs1Ext = {{32{Rs1[31]}}, Rs1};
  else assign Rs1Ext = Rs1;

// number of elements operated on each beat
  always_comb
    case (SEW)
      2'b00:   ElPerBeat = ($clog2(P.VLEN)+2)'(BLEN/8);
      2'b01:   ElPerBeat = ($clog2(P.VLEN)+2)'(BLEN/16);
      2'b10:   ElPerBeat = ($clog2(P.VLEN)+2)'(BLEN/32);
      default: ElPerBeat = ($clog2(P.VLEN)+2)'(BLEN/64);
    endcase

// VlCount used to keep track of how far along we are for vl
  always_comb
    if (Beat == '0) VlCount = {1'b0, Vl};
    else            VlCount = SavedVlCount;

// each beat subtracts number of elements operated on
  assign Stopped = VlCount[$clog2(P.VLEN)+1] | (VlCount == '0);

  always_comb
    if (Stopped) NextVlCount = VlCount;
    else         NextVlCount = VlCount - ElPerBeat;

  flopenr #($clog2(P.VLEN)+2) vlcountreg(clk, reset, NextBeat, NextVlCount, SavedVlCount);

// when total becomes negative or 0, add the number of elements back to get the element position
  assign LastBeat = ~Stopped & (NextVlCount[$clog2(P.VLEN)+1] | (NextVlCount == '0));
  assign ElementPos = NextVlCount + ElPerBeat;

// vslide1up puts rs1 in element 0 of the first beat, vslide1down puts rs1 in vl-1, which is the one below ElPos in the last beat
  always_comb
    if (Down) begin
      Rs1Here = LastBeat;
      Rs1Pos  = ($clog2(BLEN))'(ElementPos - 1) << (SEW+3);
    end else begin
      Rs1Here = (Beat == '0);
      Rs1Pos  = '0;
    end

// if slide1 and rs1 goes into this beat, write rs1
always_comb begin
    VdBeat = Kept;
    if ((Funct3 == 3'b110) & Rs1Here)
      case (SEW)
        2'b00:   VdBeat[Rs1Pos +: 8]  = Rs1Ext[7:0];
        2'b01:   VdBeat[Rs1Pos +: 16] = Rs1Ext[15:0];
        2'b10:   VdBeat[Rs1Pos +: 32] = Rs1Ext[31:0];
        default: VdBeat[Rs1Pos +: 64] = Rs1Ext;
      endcase
  end

endmodule
