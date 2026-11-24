///////////////////////////////////////////
// vshiftround.sv
//
// Written: David Harris David_Harris@hmc.edu 24 November 2026
// Modified:
//
// Purpose: Fixed-point rounding (vxrm) for vssrl, vssra, vnclip, vnclipu, and clipping for vnclip, vnclipu
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

module vshiftround import cvw::*; #(parameter cvw_t P) (
  input  logic [P.ELEN-1:0]   Sh,                 // shifted elements
  input  logic [P.ELEN-1:0]   GV, TV,             // per element: OR of GV bits is the guard bit, OR of TV bits the sticky bit
  input  logic [1:0]          EW,                 // element width
  input  logic                Round, Clip, Signed,// round (vssrl, vssra, vnclip*); clip to EW/2 bits (vnclip*); signed clip
  input  logic [1:0]          Vxrm,               // rounding mode: rnu, rne, rdn, rod
  output logic [P.ELEN-1:0]   Y,
  output logic [P.ELEN/8-1:0] SatB                // per byte: its element saturated (sets vxsat)
);
  localparam NSEW = (P.ELEN == 64) ? 4 : 3;       // element widths 8, 16, 32 (, 64)

  logic [P.ELEN-1:0]   RIncS [NSEW-1:0], TopS [NSEW-1:0], YS [NSEW-1:0];
  logic [P.ELEN/8-1:0] SatS  [NSEW-1:0];
  logic [P.ELEN-1:0]   RInc, Top, Rnd;

  // Rounding increment of each element, placed at its least significant bit
  for (genvar s = 0; s < NSEW; s++) begin: inc
    localparam W = 8 << s;
    for (genvar e = 0; e < P.ELEN/W; e++) begin: elem
      logic G, T, L, R;
      assign G = |GV[e*W +: W];
      assign T = |TV[e*W +: W];
      assign L = Sh[e*W];
      always_comb
        case (Vxrm)
          2'b00:   R = G;                 // rnu: round to nearest up
          2'b01:   R = G & (T | L);       // rne: round to nearest even
          2'b10:   R = 1'b0;              // rdn: round down (truncate)
          default: R = ~L & (G | T);      // rod: round to odd
        endcase
      assign RIncS[s][e*W +: W] = {{(W-1){1'b0}}, R & Round};
      assign TopS[s][e*W +: W]  = {1'b1, {(W-1){1'b0}}};
    end
  end
  assign RInc = RIncS[EW];
  assign Top  = TopS[EW];

  // Add the increments; clearing each element's top bit before the add keeps carries inside the element
  assign Rnd = ((Sh & ~Top) + RInc) ^ (Sh & Top);

  // Clip to EW/2 bits (vnclip, vnclipu), sign- or zero-extended back to EW
  assign YS[0]   = Rnd;                           // no clip from 8 bits
  assign SatS[0] = '0;
  for (genvar s = 1; s < NSEW; s++) begin: clamp
    localparam W = 8 << s;
    localparam N = W/2;
    for (genvar e = 0; e < P.ELEN/W; e++) begin: elem
      logic [W-1:0] El;
      logic         Fits, Sat;
      assign El   = Rnd[e*W +: W];
      assign Fits = Signed ? (El[W-1:N-1] == '0) | (El[W-1:N-1] == '1) : (El[W-1:N] == '0);
      assign Sat  = Clip & ~Fits;
      assign YS[s][e*W +: W] = ~Sat ? El :
                               ~Signed  ? {{N{1'b0}}, {N{1'b1}}} :                 // unsigned max
                               El[W-1]  ? {{(N+1){1'b1}}, {(N-1){1'b0}}} :         // signed min
                                          {{(N+1){1'b0}}, {(N-1){1'b1}}};          // signed max
      assign SatS[s][e*W/8 +: W/8] = {(W/8){Sat}};
    end
  end
  assign Y    = YS[EW];
  assign SatB = SatS[EW];
endmodule
