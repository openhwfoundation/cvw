///////////////////////////////////////////
// vshifter.sv
//
// Written: Angela Zheng angela20061015@gmail.com
// Created: 7 Nov 2026
// Modified: 24 Nov 2026 David Harris David_Harris@hmc.edu: masked subword shifter for all vector shifts
//
// Purpose: RISC-V vector shifter: vsll, vsrl, vsra, vssrl, vssra, vnsrl, vnsra, vnclip, vnclipu, vwsll, vror, vrol
//          on every element of an ELEN-bit lane in parallel
//
// Documentation: RISC-V System on Chip Design Volume 2
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
////////////////////////////////////////////////////////////////////////////////////////////////

// A logarithmic shifter as wide as the lane.  Each stage shifts an element right by k (32, 16, 8, 4, 2, 1) when its
// shift amount has bit k.  At each element's top, the bits that enter from above are the fill (0, or the sign for an
// arithmetic shift), or the element's own low bits for a rotate.  A left shift reverses the word, shifts right, and
// reverses the result.  Narrowing shifts (vnsrl, vnsra, vnclip*) work on their 2*SEW-bit source elements and widening
// vwsll on its 2*SEW-bit result elements, so the element width EW is SEW or 2*SEW; widening the operands and packing
// the narrowed results happen outside.  vshiftround rounds (vssrl, vssra, vnclip*) and clips (vnclip*).

module vshifter import cvw::*; #(parameter cvw_t P) (
  input  logic [P.ELEN-1:0]   A,                  // elements to shift (vs2)
  input  logic [P.ELEN-1:0]   B,                  // shift amount of each element in its low bits (vs1, rs1, or uimm5)
  input  logic [1:0]          EW,                 // element width: 8, 16, 32, 64 bits; legal because vtype.vill blocks the rest
  input  logic                Right, SubArith,    // shift right, arithmetic shift (only set with Right)
  input  logic                Rotate,             // vror, vrol (Zvbb, Zvkb)
  input  logic                Round, Clip,        // round by vxrm (right shifts only), clip to EW/2 bits (vnclip*)
  input  logic [1:0]          Vxrm,               // fixed-point rounding mode
  output logic [P.ELEN-1:0]   Y,
  output logic [P.ELEN/8-1:0] SatB                // per byte: its element saturated (sets vxsat)
);
  localparam NSEW = (P.ELEN == 64) ? 4 : 3;       // element widths 8, 16, 32 (, 64)

  // Signals for every element width, selected by EW below: each element's sign and shift-amount bits, copied into
  // every bit of the element (C1..C32), and for each shift k, a mask of the bits whose source k bits higher is still
  // in the same element (M1..M32)
  logic [P.ELEN-1:0] SignS [NSEW-1:0];
  logic [P.ELEN-1:0] C1S [NSEW-1:0], C2S [NSEW-1:0], C4S [NSEW-1:0], C8S [NSEW-1:0], C16S [NSEW-1:0], C32S [NSEW-1:0];
  logic [P.ELEN-1:0] M1S [NSEW-1:0], M2S [NSEW-1:0], M4S [NSEW-1:0], M8S [NSEW-1:0], M16S [NSEW-1:0], M32S [NSEW-1:0];
  // Signals for the current element width; the data, guard, and sticky vectors entering each stage
  logic [P.ELEN-1:0] C1, C2, C4, C8, C16, C32, M1, M2, M4, M8, M16, M32;
  logic [P.ELEN-1:0] Fill, F1, F2, F4, F8, F16, F32;
  logic [P.ELEN-1:0] ARev, ShRev, Sh, S32, S16, S8, S4, S2, S1, S0;
  logic [P.ELEN-1:0] GV16, GV8, GV4, GV2, GV1, GV0, TV16, TV8, TV4, TV2, TV1, TV0;
  logic              RotateEn;

  // Rotates exist only with Zvbb or Zvkb; otherwise synthesis removes the wrap logic
  assign RotateEn = (P.ZVBB_SUPPORTED | P.ZVKB_SUPPORTED) & Rotate;

  // Build the sign, control, and mask vectors for each element width
  for (genvar s = 0; s < NSEW; s++) begin: sizes
    localparam W = 8 << s;                        // element width

    // In-element masks: in each element, all but the top k bits
    assign M1S[s]  = {(P.ELEN/W){{W{1'b1}} >> 1}};
    assign M2S[s]  = {(P.ELEN/W){{W{1'b1}} >> 2}};
    assign M4S[s]  = {(P.ELEN/W){{W{1'b1}} >> 4}};
    assign M8S[s]  = {(P.ELEN/W){{W{1'b1}} >> 8}};
    assign M16S[s] = {(P.ELEN/W){{W{1'b1}} >> 16}};
    assign M32S[s] = {(P.ELEN/W){{W{1'b1}} >> 32}};

    // For each element: its shift amount, then its sign and amount bits copied across the element
    for (genvar e = 0; e < P.ELEN/W; e++) begin: elem
      logic [5:0] K;                              // shift amount; reversing the word for a left shift reverses elements
      assign K = Right ? B[e*W +: 6] : B[(P.ELEN/W-1-e)*W +: 6];
      assign SignS[s][e*W +: W] = {W{A[e*W+W-1]}};
      assign C1S[s][e*W +: W]   = {W{K[0]}};
      assign C2S[s][e*W +: W]   = {W{K[1]}};
      assign C4S[s][e*W +: W]   = {W{K[2]}};
      assign C8S[s][e*W +: W]   = {W{K[3] & (W > 8)}};    // amount bits above log2(EW) are ignored
      assign C16S[s][e*W +: W]  = {W{K[4] & (W > 16)}};
      assign C32S[s][e*W +: W]  = {W{K[5] & (W > 32)}};
    end
  end

  // Select the fill, controls, and masks for the current element width
  assign Fill = SignS[EW] & {P.ELEN{SubArith}};       // arithmetic shifts fill with the sign, others with 0
  assign {C1, C2, C4, C8, C16, C32} = {C1S[EW], C2S[EW], C4S[EW], C8S[EW], C16S[EW], C32S[EW]};
  assign {M1, M2, M4, M8, M16, M32} = {M1S[EW], M2S[EW], M4S[EW], M8S[EW], M16S[EW], M32S[EW]};

  // Bits entering the top of each element at each stage: Fill for shifts, the element's own low bits for rotates
  always_comb begin
    {F1, F2, F4, F8, F16, F32} = {6{Fill}};
    if (RotateEn)
      case (EW)
        2'b00:   begin                                  F4 = S4 << 4;  F2 = S2 << 6;  F1 = S1 << 7;  end
        2'b01:   begin                   F8 = S8 << 8;  F4 = S4 << 12; F2 = S2 << 14; F1 = S1 << 15; end
        2'b10:   begin F16 = S16 << 16;  F8 = S8 << 24; F4 = S4 << 28; F2 = S2 << 30; F1 = S1 << 31; end
        default: begin F32 = S32 << 32; F16 = S16 << 48; F8 = S8 << 56; F4 = S4 << 60; F2 = S2 << 62; F1 = S1 << 63; end
      endcase
  end

  // A left shift reverses the word, shifts right, and reverses back
  assign ARev  = {<<{A}};
  assign ShRev = {<<{S0}};
  assign S32   = Right ? A : ARev;
  assign Sh    = Right ? S0 : ShRev;

  // Shift stages; each also keeps the last bit shifted out of each element (guard) and the OR of the earlier ones
  // (sticky) for rounding.  Shift by 32 exists only when ELEN = 64.
  if (P.ELEN == 64) begin: stage32
    vshiftstage #(P, 32) st32(.Sin(S32), .C(C32), .M(M32), .F(F32), .GVin('0), .TVin('0), .Sout(S16), .GVout(GV16), .TVout(TV16));
  end else begin: stage32
    assign {S16, GV16, TV16} = {S32, {(2*P.ELEN){1'b0}}};
  end
  vshiftstage #(P, 16) st16(.Sin(S16), .C(C16), .M(M16), .F(F16), .GVin(GV16), .TVin(TV16), .Sout(S8), .GVout(GV8), .TVout(TV8));
  vshiftstage #(P, 8)  st8 (.Sin(S8),  .C(C8),  .M(M8),  .F(F8),  .GVin(GV8),  .TVin(TV8),  .Sout(S4), .GVout(GV4), .TVout(TV4));
  vshiftstage #(P, 4)  st4 (.Sin(S4),  .C(C4),  .M(M4),  .F(F4),  .GVin(GV4),  .TVin(TV4),  .Sout(S2), .GVout(GV2), .TVout(TV2));
  vshiftstage #(P, 2)  st2 (.Sin(S2),  .C(C2),  .M(M2),  .F(F2),  .GVin(GV2),  .TVin(TV2),  .Sout(S1), .GVout(GV1), .TVout(TV1));
  vshiftstage #(P, 1)  st1 (.Sin(S1),  .C(C1),  .M(M1),  .F(F1),  .GVin(GV1),  .TVin(TV1),  .Sout(S0), .GVout(GV0), .TVout(TV0));

  // Fixed-point rounding and clipping
  vshiftround #(P) vshiftround(.Sh, .GV(GV0), .TV(TV0), .EW, .Round, .Clip, .Signed(SubArith), .Vxrm, .Y, .SatB);
endmodule
