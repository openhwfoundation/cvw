///////////////////////////////////////////
// aesinvsbox8.sv
//
// Written: ryan.swann@okstate.edu, james.stine@okstate.edu
// Created: 20 February 2024
//
// Purpose: Rinjdael Inverted S-BOX in form of a LUT
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

module aesinvsbox8(
  input  logic [7:0] a,
  output logic [7:0] y
);

  always_comb
  case(a)
    8'h00 : y = 8'h52;
    8'h01 : y = 8'h09;
    8'h02 : y = 8'h6A;
    8'h03 : y = 8'hD5;
    8'h04 : y = 8'h30;
    8'h05 : y = 8'h36;
    8'h06 : y = 8'hA5;
    8'h07 : y = 8'h38;
    8'h08 : y = 8'hBF;
    8'h09 : y = 8'h40;
    8'h0A : y = 8'hA3;
    8'h0B : y = 8'h9E;
    8'h0C : y = 8'h81;
    8'h0D : y = 8'hF3;
    8'h0E : y = 8'hD7;
    8'h0F : y = 8'hFB;
    8'h10 : y = 8'h7C;
    8'h11 : y = 8'hE3;
    8'h12 : y = 8'h39;
    8'h13 : y = 8'h82;
    8'h14 : y = 8'h9B;
    8'h15 : y = 8'h2F;
    8'h16 : y = 8'hFF;
    8'h17 : y = 8'h87;
    8'h18 : y = 8'h34;
    8'h19 : y = 8'h8E;
    8'h1A : y = 8'h43;
    8'h1B : y = 8'h44;
    8'h1C : y = 8'hC4;
    8'h1D : y = 8'hDE;
    8'h1E : y = 8'hE9;
    8'h1F : y = 8'hCB;
    8'h20 : y = 8'h54;
    8'h21 : y = 8'h7B;
    8'h22 : y = 8'h94;
    8'h23 : y = 8'h32;
    8'h24 : y = 8'hA6;
    8'h25 : y = 8'hC2;
    8'h26 : y = 8'h23;
    8'h27 : y = 8'h3D;
    8'h28 : y = 8'hEE;
    8'h29 : y = 8'h4C;
    8'h2A : y = 8'h95;
    8'h2B : y = 8'h0B;
    8'h2C : y = 8'h42;
    8'h2D : y = 8'hFA;
    8'h2E : y = 8'hC3;
    8'h2F : y = 8'h4E;
    8'h30 : y = 8'h08;
    8'h31 : y = 8'h2E;
    8'h32 : y = 8'hA1;
    8'h33 : y = 8'h66;
    8'h34 : y = 8'h28;
    8'h35 : y = 8'hD9;
    8'h36 : y = 8'h24;
    8'h37 : y = 8'hB2;
    8'h38 : y = 8'h76;
    8'h39 : y = 8'h5B;
    8'h3A : y = 8'hA2;
    8'h3B : y = 8'h49;
    8'h3C : y = 8'h6D;
    8'h3D : y = 8'h8B;
    8'h3E : y = 8'hD1;
    8'h3F : y = 8'h25;
    8'h40 : y = 8'h72;
    8'h41 : y = 8'hF8;
    8'h42 : y = 8'hF6;
    8'h43 : y = 8'h64;
    8'h44 : y = 8'h86;
    8'h45 : y = 8'h68;
    8'h46 : y = 8'h98;
    8'h47 : y = 8'h16;
    8'h48 : y = 8'hD4;
    8'h49 : y = 8'hA4;
    8'h4A : y = 8'h5C;
    8'h4B : y = 8'hCC;
    8'h4C : y = 8'h5D;
    8'h4D : y = 8'h65;
    8'h4E : y = 8'hB6;
    8'h4F : y = 8'h92;
    8'h50 : y = 8'h6C;
    8'h51 : y = 8'h70;
    8'h52 : y = 8'h48;
    8'h53 : y = 8'h50;
    8'h54 : y = 8'hFD;
    8'h55 : y = 8'hED;
    8'h56 : y = 8'hB9;
    8'h57 : y = 8'hDA;
    8'h58 : y = 8'h5E;
    8'h59 : y = 8'h15;
    8'h5A : y = 8'h46;
    8'h5B : y = 8'h57;
    8'h5C : y = 8'hA7;
    8'h5D : y = 8'h8D;
    8'h5E : y = 8'h9D;
    8'h5F : y = 8'h84;
    8'h60 : y = 8'h90;
    8'h61 : y = 8'hD8;
    8'h62 : y = 8'hAB;
    8'h63 : y = 8'h00;
    8'h64 : y = 8'h8C;
    8'h65 : y = 8'hBC;
    8'h66 : y = 8'hD3;
    8'h67 : y = 8'h0A;
    8'h68 : y = 8'hF7;
    8'h69 : y = 8'hE4;
    8'h6A : y = 8'h58;
    8'h6B : y = 8'h05;
    8'h6C : y = 8'hB8;
    8'h6D : y = 8'hB3;
    8'h6E : y = 8'h45;
    8'h6F : y = 8'h06;
    8'h70 : y = 8'hD0;
    8'h71 : y = 8'h2C;
    8'h72 : y = 8'h1E;
    8'h73 : y = 8'h8F;
    8'h74 : y = 8'hCA;
    8'h75 : y = 8'h3F;
    8'h76 : y = 8'h0F;
    8'h77 : y = 8'h02;
    8'h78 : y = 8'hC1;
    8'h79 : y = 8'hAF;
    8'h7A : y = 8'hBD;
    8'h7B : y = 8'h03;
    8'h7C : y = 8'h01;
    8'h7D : y = 8'h13;
    8'h7E : y = 8'h8A;
    8'h7F : y = 8'h6B;
    8'h80 : y = 8'h3A;
    8'h81 : y = 8'h91;
    8'h82 : y = 8'h11;
    8'h83 : y = 8'h41;
    8'h84 : y = 8'h4F;
    8'h85 : y = 8'h67;
    8'h86 : y = 8'hDC;
    8'h87 : y = 8'hEA;
    8'h88 : y = 8'h97;
    8'h89 : y = 8'hF2;
    8'h8A : y = 8'hCF;
    8'h8B : y = 8'hCE;
    8'h8C : y = 8'hF0;
    8'h8D : y = 8'hB4;
    8'h8E : y = 8'hE6;
    8'h8F : y = 8'h73;
    8'h90 : y = 8'h96;
    8'h91 : y = 8'hAC;
    8'h92 : y = 8'h74;
    8'h93 : y = 8'h22;
    8'h94 : y = 8'hE7;
    8'h95 : y = 8'hAD;
    8'h96 : y = 8'h35;
    8'h97 : y = 8'h85;
    8'h98 : y = 8'hE2;
    8'h99 : y = 8'hF9;
    8'h9A : y = 8'h37;
    8'h9B : y = 8'hE8;
    8'h9C : y = 8'h1C;
    8'h9D : y = 8'h75;
    8'h9E : y = 8'hDF;
    8'h9F : y = 8'h6E;
    8'hA0 : y = 8'h47;
    8'hA1 : y = 8'hF1;
    8'hA2 : y = 8'h1A;
    8'hA3 : y = 8'h71;
    8'hA4 : y = 8'h1D;
    8'hA5 : y = 8'h29;
    8'hA6 : y = 8'hC5;
    8'hA7 : y = 8'h89;
    8'hA8 : y = 8'h6F;
    8'hA9 : y = 8'hB7;
    8'hAA : y = 8'h62;
    8'hAB : y = 8'h0E;
    8'hAC : y = 8'hAA;
    8'hAD : y = 8'h18;
    8'hAE : y = 8'hBE;
    8'hAF : y = 8'h1B;
    8'hB0 : y = 8'hFC;
    8'hB1 : y = 8'h56;
    8'hB2 : y = 8'h3E;
    8'hB3 : y = 8'h4B;
    8'hB4 : y = 8'hC6;
    8'hB5 : y = 8'hD2;
    8'hB6 : y = 8'h79;
    8'hB7 : y = 8'h20;
    8'hB8 : y = 8'h9A;
    8'hB9 : y = 8'hDB;
    8'hBA : y = 8'hC0;
    8'hBB : y = 8'hFE;
    8'hBC : y = 8'h78;
    8'hBD : y = 8'hCD;
    8'hBE : y = 8'h5A;
    8'hBF : y = 8'hF4;
    8'hC0 : y = 8'h1F;
    8'hC1 : y = 8'hDD;
    8'hC2 : y = 8'hA8;
    8'hC3 : y = 8'h33;
    8'hC4 : y = 8'h88;
    8'hC5 : y = 8'h07;
    8'hC6 : y = 8'hC7;
    8'hC7 : y = 8'h31;
    8'hC8 : y = 8'hB1;
    8'hC9 : y = 8'h12;
    8'hCA : y = 8'h10;
    8'hCB : y = 8'h59;
    8'hCC : y = 8'h27;
    8'hCD : y = 8'h80;
    8'hCE : y = 8'hEC;
    8'hCF : y = 8'h5F;
    8'hD0 : y = 8'h60;
    8'hD1 : y = 8'h51;
    8'hD2 : y = 8'h7F;
    8'hD3 : y = 8'hA9;
    8'hD4 : y = 8'h19;
    8'hD5 : y = 8'hB5;
    8'hD6 : y = 8'h4A;
    8'hD7 : y = 8'h0D;
    8'hD8 : y = 8'h2D;
    8'hD9 : y = 8'hE5;
    8'hDA : y = 8'h7A;
    8'hDB : y = 8'h9F;
    8'hDC : y = 8'h93;
    8'hDD : y = 8'hC9;
    8'hDE : y = 8'h9C;
    8'hDF : y = 8'hEF;
    8'hE0 : y = 8'hA0;
    8'hE1 : y = 8'hE0;
    8'hE2 : y = 8'h3B;
    8'hE3 : y = 8'h4D;
    8'hE4 : y = 8'hAE;
    8'hE5 : y = 8'h2A;
    8'hE6 : y = 8'hF5;
    8'hE7 : y = 8'hB0;
    8'hE8 : y = 8'hC8;
    8'hE9 : y = 8'hEB;
    8'hEA : y = 8'hBB;
    8'hEB : y = 8'h3C;
    8'hEC : y = 8'h83;
    8'hED : y = 8'h53;
    8'hEE : y = 8'h99;
    8'hEF : y = 8'h61;
    8'hF0 : y = 8'h17;
    8'hF1 : y = 8'h2B;
    8'hF2 : y = 8'h04;
    8'hF3 : y = 8'h7E;
    8'hF4 : y = 8'hBA;
    8'hF5 : y = 8'h77;
    8'hF6 : y = 8'hD6;
    8'hF7 : y = 8'h26;
    8'hF8 : y = 8'hE1;
    8'hF9 : y = 8'h69;
    8'hFA : y = 8'h14;
    8'hFB : y = 8'h63;
    8'hFC : y = 8'h55;
    8'hFD : y = 8'h21;
    8'hFE : y = 8'h0C;
    8'hFF : y = 8'h7D;
  endcase
endmodule
