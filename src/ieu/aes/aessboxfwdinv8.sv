///////////////////////////////////////////
// aessboxfwdinv8.sv
//
// Written:  David Harris 24 November 2026
// Modified:
//
// Purpose: AES forward or inverse S-box sharing one GF(2^8) inversion between the two directions.
//          S(a) = M(a^-1) ^ 63 and S^-1(a) = (M^-1(a ^ 63))^-1, where M is the AES affine matrix.
//          The inversion is a 256-entry table shared by both directions; the affine maps are XOR
//          networks before (inverse) or after (forward) it.  Checked exhaustively against FIPS-197.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module aessboxfwdinv8 (
  input  logic [7:0] a,
  input  logic       inv,   // 1: inverse S-box, 0: forward S-box
  output logic [7:0] y
);
  logic [7:0] ia, x, t, at;

  // inverse direction: undo the affine transform, ia = M^-1(a ^ 63)
  assign ia[0] = ~(a[2] ^ a[5] ^ a[7]);
  assign ia[1] = a[0] ^ a[3] ^ a[6];
  assign ia[2] = ~(a[1] ^ a[4] ^ a[7]);
  assign ia[3] = a[0] ^ a[2] ^ a[5];
  assign ia[4] = a[1] ^ a[3] ^ a[6];
  assign ia[5] = a[2] ^ a[4] ^ a[7];
  assign ia[6] = a[0] ^ a[3] ^ a[5];
  assign ia[7] = a[1] ^ a[4] ^ a[6];
  assign x = inv ? ia : a;

  // GF(2^8) multiplicative inverse (0 maps to 0)
  always_comb
    case (x)
      8'h00: t = 8'h00;
      8'h01: t = 8'h01;
      8'h02: t = 8'h8D;
      8'h03: t = 8'hF6;
      8'h04: t = 8'hCB;
      8'h05: t = 8'h52;
      8'h06: t = 8'h7B;
      8'h07: t = 8'hD1;
      8'h08: t = 8'hE8;
      8'h09: t = 8'h4F;
      8'h0A: t = 8'h29;
      8'h0B: t = 8'hC0;
      8'h0C: t = 8'hB0;
      8'h0D: t = 8'hE1;
      8'h0E: t = 8'hE5;
      8'h0F: t = 8'hC7;
      8'h10: t = 8'h74;
      8'h11: t = 8'hB4;
      8'h12: t = 8'hAA;
      8'h13: t = 8'h4B;
      8'h14: t = 8'h99;
      8'h15: t = 8'h2B;
      8'h16: t = 8'h60;
      8'h17: t = 8'h5F;
      8'h18: t = 8'h58;
      8'h19: t = 8'h3F;
      8'h1A: t = 8'hFD;
      8'h1B: t = 8'hCC;
      8'h1C: t = 8'hFF;
      8'h1D: t = 8'h40;
      8'h1E: t = 8'hEE;
      8'h1F: t = 8'hB2;
      8'h20: t = 8'h3A;
      8'h21: t = 8'h6E;
      8'h22: t = 8'h5A;
      8'h23: t = 8'hF1;
      8'h24: t = 8'h55;
      8'h25: t = 8'h4D;
      8'h26: t = 8'hA8;
      8'h27: t = 8'hC9;
      8'h28: t = 8'hC1;
      8'h29: t = 8'h0A;
      8'h2A: t = 8'h98;
      8'h2B: t = 8'h15;
      8'h2C: t = 8'h30;
      8'h2D: t = 8'h44;
      8'h2E: t = 8'hA2;
      8'h2F: t = 8'hC2;
      8'h30: t = 8'h2C;
      8'h31: t = 8'h45;
      8'h32: t = 8'h92;
      8'h33: t = 8'h6C;
      8'h34: t = 8'hF3;
      8'h35: t = 8'h39;
      8'h36: t = 8'h66;
      8'h37: t = 8'h42;
      8'h38: t = 8'hF2;
      8'h39: t = 8'h35;
      8'h3A: t = 8'h20;
      8'h3B: t = 8'h6F;
      8'h3C: t = 8'h77;
      8'h3D: t = 8'hBB;
      8'h3E: t = 8'h59;
      8'h3F: t = 8'h19;
      8'h40: t = 8'h1D;
      8'h41: t = 8'hFE;
      8'h42: t = 8'h37;
      8'h43: t = 8'h67;
      8'h44: t = 8'h2D;
      8'h45: t = 8'h31;
      8'h46: t = 8'hF5;
      8'h47: t = 8'h69;
      8'h48: t = 8'hA7;
      8'h49: t = 8'h64;
      8'h4A: t = 8'hAB;
      8'h4B: t = 8'h13;
      8'h4C: t = 8'h54;
      8'h4D: t = 8'h25;
      8'h4E: t = 8'hE9;
      8'h4F: t = 8'h09;
      8'h50: t = 8'hED;
      8'h51: t = 8'h5C;
      8'h52: t = 8'h05;
      8'h53: t = 8'hCA;
      8'h54: t = 8'h4C;
      8'h55: t = 8'h24;
      8'h56: t = 8'h87;
      8'h57: t = 8'hBF;
      8'h58: t = 8'h18;
      8'h59: t = 8'h3E;
      8'h5A: t = 8'h22;
      8'h5B: t = 8'hF0;
      8'h5C: t = 8'h51;
      8'h5D: t = 8'hEC;
      8'h5E: t = 8'h61;
      8'h5F: t = 8'h17;
      8'h60: t = 8'h16;
      8'h61: t = 8'h5E;
      8'h62: t = 8'hAF;
      8'h63: t = 8'hD3;
      8'h64: t = 8'h49;
      8'h65: t = 8'hA6;
      8'h66: t = 8'h36;
      8'h67: t = 8'h43;
      8'h68: t = 8'hF4;
      8'h69: t = 8'h47;
      8'h6A: t = 8'h91;
      8'h6B: t = 8'hDF;
      8'h6C: t = 8'h33;
      8'h6D: t = 8'h93;
      8'h6E: t = 8'h21;
      8'h6F: t = 8'h3B;
      8'h70: t = 8'h79;
      8'h71: t = 8'hB7;
      8'h72: t = 8'h97;
      8'h73: t = 8'h85;
      8'h74: t = 8'h10;
      8'h75: t = 8'hB5;
      8'h76: t = 8'hBA;
      8'h77: t = 8'h3C;
      8'h78: t = 8'hB6;
      8'h79: t = 8'h70;
      8'h7A: t = 8'hD0;
      8'h7B: t = 8'h06;
      8'h7C: t = 8'hA1;
      8'h7D: t = 8'hFA;
      8'h7E: t = 8'h81;
      8'h7F: t = 8'h82;
      8'h80: t = 8'h83;
      8'h81: t = 8'h7E;
      8'h82: t = 8'h7F;
      8'h83: t = 8'h80;
      8'h84: t = 8'h96;
      8'h85: t = 8'h73;
      8'h86: t = 8'hBE;
      8'h87: t = 8'h56;
      8'h88: t = 8'h9B;
      8'h89: t = 8'h9E;
      8'h8A: t = 8'h95;
      8'h8B: t = 8'hD9;
      8'h8C: t = 8'hF7;
      8'h8D: t = 8'h02;
      8'h8E: t = 8'hB9;
      8'h8F: t = 8'hA4;
      8'h90: t = 8'hDE;
      8'h91: t = 8'h6A;
      8'h92: t = 8'h32;
      8'h93: t = 8'h6D;
      8'h94: t = 8'hD8;
      8'h95: t = 8'h8A;
      8'h96: t = 8'h84;
      8'h97: t = 8'h72;
      8'h98: t = 8'h2A;
      8'h99: t = 8'h14;
      8'h9A: t = 8'h9F;
      8'h9B: t = 8'h88;
      8'h9C: t = 8'hF9;
      8'h9D: t = 8'hDC;
      8'h9E: t = 8'h89;
      8'h9F: t = 8'h9A;
      8'hA0: t = 8'hFB;
      8'hA1: t = 8'h7C;
      8'hA2: t = 8'h2E;
      8'hA3: t = 8'hC3;
      8'hA4: t = 8'h8F;
      8'hA5: t = 8'hB8;
      8'hA6: t = 8'h65;
      8'hA7: t = 8'h48;
      8'hA8: t = 8'h26;
      8'hA9: t = 8'hC8;
      8'hAA: t = 8'h12;
      8'hAB: t = 8'h4A;
      8'hAC: t = 8'hCE;
      8'hAD: t = 8'hE7;
      8'hAE: t = 8'hD2;
      8'hAF: t = 8'h62;
      8'hB0: t = 8'h0C;
      8'hB1: t = 8'hE0;
      8'hB2: t = 8'h1F;
      8'hB3: t = 8'hEF;
      8'hB4: t = 8'h11;
      8'hB5: t = 8'h75;
      8'hB6: t = 8'h78;
      8'hB7: t = 8'h71;
      8'hB8: t = 8'hA5;
      8'hB9: t = 8'h8E;
      8'hBA: t = 8'h76;
      8'hBB: t = 8'h3D;
      8'hBC: t = 8'hBD;
      8'hBD: t = 8'hBC;
      8'hBE: t = 8'h86;
      8'hBF: t = 8'h57;
      8'hC0: t = 8'h0B;
      8'hC1: t = 8'h28;
      8'hC2: t = 8'h2F;
      8'hC3: t = 8'hA3;
      8'hC4: t = 8'hDA;
      8'hC5: t = 8'hD4;
      8'hC6: t = 8'hE4;
      8'hC7: t = 8'h0F;
      8'hC8: t = 8'hA9;
      8'hC9: t = 8'h27;
      8'hCA: t = 8'h53;
      8'hCB: t = 8'h04;
      8'hCC: t = 8'h1B;
      8'hCD: t = 8'hFC;
      8'hCE: t = 8'hAC;
      8'hCF: t = 8'hE6;
      8'hD0: t = 8'h7A;
      8'hD1: t = 8'h07;
      8'hD2: t = 8'hAE;
      8'hD3: t = 8'h63;
      8'hD4: t = 8'hC5;
      8'hD5: t = 8'hDB;
      8'hD6: t = 8'hE2;
      8'hD7: t = 8'hEA;
      8'hD8: t = 8'h94;
      8'hD9: t = 8'h8B;
      8'hDA: t = 8'hC4;
      8'hDB: t = 8'hD5;
      8'hDC: t = 8'h9D;
      8'hDD: t = 8'hF8;
      8'hDE: t = 8'h90;
      8'hDF: t = 8'h6B;
      8'hE0: t = 8'hB1;
      8'hE1: t = 8'h0D;
      8'hE2: t = 8'hD6;
      8'hE3: t = 8'hEB;
      8'hE4: t = 8'hC6;
      8'hE5: t = 8'h0E;
      8'hE6: t = 8'hCF;
      8'hE7: t = 8'hAD;
      8'hE8: t = 8'h08;
      8'hE9: t = 8'h4E;
      8'hEA: t = 8'hD7;
      8'hEB: t = 8'hE3;
      8'hEC: t = 8'h5D;
      8'hED: t = 8'h50;
      8'hEE: t = 8'h1E;
      8'hEF: t = 8'hB3;
      8'hF0: t = 8'h5B;
      8'hF1: t = 8'h23;
      8'hF2: t = 8'h38;
      8'hF3: t = 8'h34;
      8'hF4: t = 8'h68;
      8'hF5: t = 8'h46;
      8'hF6: t = 8'h03;
      8'hF7: t = 8'h8C;
      8'hF8: t = 8'hDD;
      8'hF9: t = 8'h9C;
      8'hFA: t = 8'h7D;
      8'hFB: t = 8'hA0;
      8'hFC: t = 8'hCD;
      8'hFD: t = 8'h1A;
      8'hFE: t = 8'h41;
      8'hFF: t = 8'h1C;
    endcase

  // forward direction: affine transform, at = M(t) ^ 63
  assign at[0] = ~(t[0] ^ t[4] ^ t[5] ^ t[6] ^ t[7]);
  assign at[1] = ~(t[0] ^ t[1] ^ t[5] ^ t[6] ^ t[7]);
  assign at[2] = t[0] ^ t[1] ^ t[2] ^ t[6] ^ t[7];
  assign at[3] = t[0] ^ t[1] ^ t[2] ^ t[3] ^ t[7];
  assign at[4] = t[0] ^ t[1] ^ t[2] ^ t[3] ^ t[4];
  assign at[5] = ~(t[1] ^ t[2] ^ t[3] ^ t[4] ^ t[5]);
  assign at[6] = ~(t[2] ^ t[3] ^ t[4] ^ t[5] ^ t[6]);
  assign at[7] = t[3] ^ t[4] ^ t[5] ^ t[6] ^ t[7];
  assign y = inv ? t : at;
endmodule
