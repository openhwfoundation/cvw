///////////////////////////////////////////
// sha512.sv
//
// Written: james.stine@okstate.edu/emelia.kravchuk@okstate.edu
// Created: 16 October 2024
//
// Purpose: SHA-512 Module
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-25 Harvey Mudd College & Oklahoma State University
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

module top #(parameter MSG_SIZE = 112,
         parameter PADDED_SIZE = 1024)
   (input logic [MSG_SIZE-1:0] message,
    output logic [511:0] hashed);

   logic [PADDED_SIZE-1:0] padded;

   sha_padder #(.MSG_SIZE(MSG_SIZE), .PADDED_SIZE(PADDED_SIZE)) padder (.message(message), .padded(padded));
   sha512 #(.PADDED_SIZE(PADDED_SIZE)) main (.padded(padded), .hashed(hashed));

endmodule // sha_512

module sha_padder #(
    parameter int MSG_SIZE    = 112,
    parameter int PADDED_SIZE = 1024
)(
    input  logic [MSG_SIZE-1:0]    message,
    output logic [PADDED_SIZE-1:0] padded
);

    // message || 1 || zeros || 128-bit length
    localparam int zero_width = PADDED_SIZE - MSG_SIZE - 1 - 128;

    logic [127:0] msg_len;
    assign msg_len = 128'(MSG_SIZE);  // explicit cast for lint

    assign padded = {message, 1'b1, {zero_width{1'b0}},  msg_len
    };

endmodule

module sha512 #(parameter PADDED_SIZE = 1024)
   (input logic [PADDED_SIZE-1:0] padded,
    output logic [511:0] hashed);

   logic [511:0]     H = {64'h6a09e667f3bcc908, 64'hbb67ae8584caa73b,
                  64'h3c6ef372fe94f82b, 64'ha54ff53a5f1d36f1,
                  64'h510e527fade682d1, 64'h9b05688c2b3e6c1f,
                  64'h1f83d9abfb41bd6b, 64'h5be0cd19137e2179};

   logic [5119:0]    K = {64'h428a2f98d728ae22, 64'h7137449123ef65cd,
                  64'hb5c0fbcfec4d3b2f, 64'he9b5dba58189dbbc,
                  64'h3956c25bf348b538, 64'h59f111f1b605d019,
                  64'h923f82a4af194f9b, 64'hab1c5ed5da6d8118,
                  64'hd807aa98a3030242, 64'h12835b0145706fbe,
                  64'h243185be4ee4b28c, 64'h550c7dc3d5ffb4e2,
                  64'h72be5d74f27b896f, 64'h80deb1fe3b1696b1,
                  64'h9bdc06a725c71235, 64'hc19bf174cf692694,
                  64'he49b69c19ef14ad2, 64'hefbe4786384f25e3,
                  64'h0fc19dc68b8cd5b5, 64'h240ca1cc77ac9c65,
                  64'h2de92c6f592b0275, 64'h4a7484aa6ea6e483,
                  64'h5cb0a9dcbd41fbd4, 64'h76f988da831153b5,
                  64'h983e5152ee66dfab, 64'ha831c66d2db43210,
                  64'hb00327c898fb213f, 64'hbf597fc7beef0ee4,
                  64'hc6e00bf33da88fc2, 64'hd5a79147930aa725,
                  64'h06ca6351e003826f, 64'h142929670a0e6e70,
                  64'h27b70a8546d22ffc, 64'h2e1b21385c26c926,
                  64'h4d2c6dfc5ac42aed, 64'h53380d139d95b3df,
                  64'h650a73548baf63de, 64'h766a0abb3c77b2a8,
                  64'h81c2c92e47edaee6, 64'h92722c851482353b,
                  64'ha2bfe8a14cf10364, 64'ha81a664bbc423001,
                  64'hc24b8b70d0f89791, 64'hc76c51a30654be30,
                  64'hd192e819d6ef5218, 64'hd69906245565a910,
                  64'hf40e35855771202a, 64'h106aa07032bbd1b8,
                  64'h19a4c116b8d2d0c8, 64'h1e376c085141ab53,
                  64'h2748774cdf8eeb99, 64'h34b0bcb5e19b48a8,
                  64'h391c0cb3c5c95a63, 64'h4ed8aa4ae3418acb,
                  64'h5b9cca4f7763e373, 64'h682e6ff3d6b2b8a3,
                  64'h748f82ee5defb2fc, 64'h78a5636f43172f60,
                  64'h84c87814a1f0ab72, 64'h8cc702081a6439ec,
                  64'h90befffa23631e28, 64'ha4506cebde82bde9,
                  64'hbef9a3f7b2c67915, 64'hc67178f2e372532b,
                  64'hca273eceea26619c, 64'hd186b8c721c0c207,
                  64'heada7dd6cde0eb1e, 64'hf57d4f7fee6ed178,
                  64'h06f067aa72176fba, 64'h0a637dc5a2c898a6,
                  64'h113f9804bef90dae, 64'h1b710b35131c471b,
                  64'h28db77f523047d84, 64'h32caab7b40c72493,
                  64'h3c9ebe0a15c9bebc, 64'h431d67c49c100d4c,
                  64'h4cc5d4becb3e42b6, 64'h597f299cfc657e2a,
                  64'h5fcb6fab3ad6faec, 64'h6c44198c4a475817};

   logic [63:0]      a, b, c, d, e, f, g, h;

   logic [63:0]      a0_out, b0_out, c0_out, d0_out, e0_out, f0_out, g0_out, h0_out;
   logic [63:0]      a1_out, b1_out, c1_out, d1_out, e1_out, f1_out, g1_out, h1_out;
   logic [63:0]      a2_out, b2_out, c2_out, d2_out, e2_out, f2_out, g2_out, h2_out;
   logic [63:0]      a3_out, b3_out, c3_out, d3_out, e3_out, f3_out, g3_out, h3_out;
   logic [63:0]      a4_out, b4_out, c4_out, d4_out, e4_out, f4_out, g4_out, h4_out;
   logic [63:0]      a5_out, b5_out, c5_out, d5_out, e5_out, f5_out, g5_out, h5_out;
   logic [63:0]      a6_out, b6_out, c6_out, d6_out, e6_out, f6_out, g6_out, h6_out;
   logic [63:0]      a7_out, b7_out, c7_out, d7_out, e7_out, f7_out, g7_out, h7_out;
   logic [63:0]      a8_out, b8_out, c8_out, d8_out, e8_out, f8_out, g8_out, h8_out;
   logic [63:0]      a9_out, b9_out, c9_out, d9_out, e9_out, f9_out, g9_out, h9_out;
   logic [63:0]      a10_out, b10_out, c10_out, d10_out, e10_out, f10_out, g10_out, h10_out;
   logic [63:0]      a11_out, b11_out, c11_out, d11_out, e11_out, f11_out, g11_out, h11_out;
   logic [63:0]      a12_out, b12_out, c12_out, d12_out, e12_out, f12_out, g12_out, h12_out;
   logic [63:0]      a13_out, b13_out, c13_out, d13_out, e13_out, f13_out, g13_out, h13_out;
   logic [63:0]      a14_out, b14_out, c14_out, d14_out, e14_out, f14_out, g14_out, h14_out;
   logic [63:0]      a15_out, b15_out, c15_out, d15_out, e15_out, f15_out, g15_out, h15_out;
   logic [63:0]      a16_out, b16_out, c16_out, d16_out, e16_out, f16_out, g16_out, h16_out;
   logic [63:0]      a17_out, b17_out, c17_out, d17_out, e17_out, f17_out, g17_out, h17_out;
   logic [63:0]      a18_out, b18_out, c18_out, d18_out, e18_out, f18_out, g18_out, h18_out;
   logic [63:0]      a19_out, b19_out, c19_out, d19_out, e19_out, f19_out, g19_out, h19_out;
   logic [63:0]      a20_out, b20_out, c20_out, d20_out, e20_out, f20_out, g20_out, h20_out;
   logic [63:0]      a21_out, b21_out, c21_out, d21_out, e21_out, f21_out, g21_out, h21_out;
   logic [63:0]      a22_out, b22_out, c22_out, d22_out, e22_out, f22_out, g22_out, h22_out;
   logic [63:0]      a23_out, b23_out, c23_out, d23_out, e23_out, f23_out, g23_out, h23_out;
   logic [63:0]      a24_out, b24_out, c24_out, d24_out, e24_out, f24_out, g24_out, h24_out;
   logic [63:0]      a25_out, b25_out, c25_out, d25_out, e25_out, f25_out, g25_out, h25_out;
   logic [63:0]      a26_out, b26_out, c26_out, d26_out, e26_out, f26_out, g26_out, h26_out;
   logic [63:0]      a27_out, b27_out, c27_out, d27_out, e27_out, f27_out, g27_out, h27_out;
   logic [63:0]      a28_out, b28_out, c28_out, d28_out, e28_out, f28_out, g28_out, h28_out;
   logic [63:0]      a29_out, b29_out, c29_out, d29_out, e29_out, f29_out, g29_out, h29_out;
   logic [63:0]      a30_out, b30_out, c30_out, d30_out, e30_out, f30_out, g30_out, h30_out;
   logic [63:0]      a31_out, b31_out, c31_out, d31_out, e31_out, f31_out, g31_out, h31_out;
   logic [63:0]      a32_out, b32_out, c32_out, d32_out, e32_out, f32_out, g32_out, h32_out;
   logic [63:0]      a33_out, b33_out, c33_out, d33_out, e33_out, f33_out, g33_out, h33_out;
   logic [63:0]      a34_out, b34_out, c34_out, d34_out, e34_out, f34_out, g34_out, h34_out;
   logic [63:0]      a35_out, b35_out, c35_out, d35_out, e35_out, f35_out, g35_out, h35_out;
   logic [63:0]      a36_out, b36_out, c36_out, d36_out, e36_out, f36_out, g36_out, h36_out;
   logic [63:0]      a37_out, b37_out, c37_out, d37_out, e37_out, f37_out, g37_out, h37_out;
   logic [63:0]      a38_out, b38_out, c38_out, d38_out, e38_out, f38_out, g38_out, h38_out;
   logic [63:0]      a39_out, b39_out, c39_out, d39_out, e39_out, f39_out, g39_out, h39_out;
   logic [63:0]      a40_out, b40_out, c40_out, d40_out, e40_out, f40_out, g40_out, h40_out;
   logic [63:0]      a41_out, b41_out, c41_out, d41_out, e41_out, f41_out, g41_out, h41_out;
   logic [63:0]      a42_out, b42_out, c42_out, d42_out, e42_out, f42_out, g42_out, h42_out;
   logic [63:0]      a43_out, b43_out, c43_out, d43_out, e43_out, f43_out, g43_out, h43_out;
   logic [63:0]      a44_out, b44_out, c44_out, d44_out, e44_out, f44_out, g44_out, h44_out;
   logic [63:0]      a45_out, b45_out, c45_out, d45_out, e45_out, f45_out, g45_out, h45_out;
   logic [63:0]      a46_out, b46_out, c46_out, d46_out, e46_out, f46_out, g46_out, h46_out;
   logic [63:0]      a47_out, b47_out, c47_out, d47_out, e47_out, f47_out, g47_out, h47_out;
   logic [63:0]      a48_out, b48_out, c48_out, d48_out, e48_out, f48_out, g48_out, h48_out;
   logic [63:0]      a49_out, b49_out, c49_out, d49_out, e49_out, f49_out, g49_out, h49_out;
   logic [63:0]      a50_out, b50_out, c50_out, d50_out, e50_out, f50_out, g50_out, h50_out;
   logic [63:0]      a51_out, b51_out, c51_out, d51_out, e51_out, f51_out, g51_out, h51_out;
   logic [63:0]      a52_out, b52_out, c52_out, d52_out, e52_out, f52_out, g52_out, h52_out;
   logic [63:0]      a53_out, b53_out, c53_out, d53_out, e53_out, f53_out, g53_out, h53_out;
   logic [63:0]      a54_out, b54_out, c54_out, d54_out, e54_out, f54_out, g54_out, h54_out;
   logic [63:0]      a55_out, b55_out, c55_out, d55_out, e55_out, f55_out, g55_out, h55_out;
   logic [63:0]      a56_out, b56_out, c56_out, d56_out, e56_out, f56_out, g56_out, h56_out;
   logic [63:0]      a57_out, b57_out, c57_out, d57_out, e57_out, f57_out, g57_out, h57_out;
   logic [63:0]      a58_out, b58_out, c58_out, d58_out, e58_out, f58_out, g58_out, h58_out;
   logic [63:0]      a59_out, b59_out, c59_out, d59_out, e59_out, f59_out, g59_out, h59_out;
   logic [63:0]      a60_out, b60_out, c60_out, d60_out, e60_out, f60_out, g60_out, h60_out;
   logic [63:0]      a61_out, b61_out, c61_out, d61_out, e61_out, f61_out, g61_out, h61_out;
   logic [63:0]      a62_out, b62_out, c62_out, d62_out, e62_out, f62_out, g62_out, h62_out;
   logic [63:0]      a63_out, b63_out, c63_out, d63_out, e63_out, f63_out, g63_out, h63_out;
   logic [63:0]      a64_out, b64_out, c64_out, d64_out, e64_out, f64_out, g64_out, h64_out;
   logic [63:0]      a65_out, b65_out, c65_out, d65_out, e65_out, f65_out, g65_out, h65_out;
   logic [63:0]      a66_out, b66_out, c66_out, d66_out, e66_out, f66_out, g66_out, h66_out;
   logic [63:0]      a67_out, b67_out, c67_out, d67_out, e67_out, f67_out, g67_out, h67_out;
   logic [63:0]      a68_out, b68_out, c68_out, d68_out, e68_out, f68_out, g68_out, h68_out;
   logic [63:0]      a69_out, b69_out, c69_out, d69_out, e69_out, f69_out, g69_out, h69_out;
   logic [63:0]      a70_out, b70_out, c70_out, d70_out, e70_out, f70_out, g70_out, h70_out;
   logic [63:0]      a71_out, b71_out, c71_out, d71_out, e71_out, f71_out, g71_out, h71_out;
   logic [63:0]      a72_out, b72_out, c72_out, d72_out, e72_out, f72_out, g72_out, h72_out;
   logic [63:0]      a73_out, b73_out, c73_out, d73_out, e73_out, f73_out, g73_out, h73_out;
   logic [63:0]      a74_out, b74_out, c74_out, d74_out, e74_out, f74_out, g74_out, h74_out;
   logic [63:0]      a75_out, b75_out, c75_out, d75_out, e75_out, f75_out, g75_out, h75_out;
   logic [63:0]      a76_out, b76_out, c76_out, d76_out, e76_out, f76_out, g76_out, h76_out;
   logic [63:0]      a77_out, b77_out, c77_out, d77_out, e77_out, f77_out, g77_out, h77_out;
   logic [63:0]      a78_out, b78_out, c78_out, d78_out, e78_out, f78_out, g78_out, h78_out;
   logic [63:0]      a79_out, b79_out, c79_out, d79_out, e79_out, f79_out, g79_out, h79_out;

   logic [63:0]      W0, W1, W2, W3, W4, W5, W6, W7, W8, W9, W10, W11, W12, W13, W14, W15;
   logic [63:0]      W16, W17, W18, W19, W20, W21, W22, W23, W24, W25, W26, W27, W28, W29, W30, W31;
   logic [63:0]      W32, W33, W34, W35, W36, W37, W38, W39, W40, W41, W42, W43, W44, W45, W46, W47, W48;
   logic [63:0]      W49, W50, W51, W52, W53, W54, W55, W56, W57, W58, W59, W60, W61, W62, W63;
   logic [63:0]      W64, W65, W66, W67, W68, W69, W70, W71, W72, W73, W74, W75, W76, W77, W78, W79;

   logic [63:0]      h0, h1, h2, h3, h4, h5, h6, h7;

   prepare p1 (padded[1023:960], padded[959:896], padded[895:832],
           padded[831:768], padded[767:704], padded[703:640],
           padded[639:576], padded[575:512], padded[511:448],
           padded[447:384], padded[383:320], padded[319:256],
           padded[255:192], padded[191:128], padded[127:64],
           padded[63:0], W0, W1, W2, W3, W4, W5, W6, W7, W8, W9,
               W10, W11, W12, W13, W14, W15, W16, W17, W18, W19,
               W20, W21, W22, W23, W24, W25, W26, W27, W28, W29,
               W30, W31, W32, W33, W34, W35, W36, W37, W38, W39,
               W40, W41, W42, W43, W44, W45, W46, W47, W48, W49,
               W50, W51, W52, W53, W54, W55, W56, W57, W58, W59,
               W60, W61, W62, W63,  W64, W65, W66, W67, W68, W69, W70, W71, W72, W73, W74, W75, W76, W77, W78, W79);

   assign a = H[511:448];
   assign b = H[447:384];
   assign c = H[383:320];
   assign d = H[319:256];
   assign e = H[255:192];
   assign f = H[191:128];
   assign g = H[127:64];
   assign h = H[63:0];

   // 80 hash computations
   // Each main_comp block computes according to Sec 2.3.3

   main_comp mc01 (a, b, c, d,
                   e, f, g, h,
           K[5119:5056], W0,
                   a0_out, b0_out, c0_out, d0_out,
                   e0_out, f0_out, g0_out, h0_out);

   main_comp mc02 (a0_out, b0_out, c0_out, d0_out,
                   e0_out, f0_out, g0_out, h0_out,
           K[5055:4992], W1,
                   a1_out, b1_out, c1_out, d1_out,
                   e1_out, f1_out, g1_out, h1_out);

   main_comp mc03 (a1_out, b1_out, c1_out, d1_out,
                   e1_out, f1_out, g1_out, h1_out,
           K[4991:4928], W2,
                   a2_out, b2_out, c2_out, d2_out,
                   e2_out, f2_out, g2_out, h2_out);

   main_comp mc04 (a2_out, b2_out, c2_out, d2_out,
                   e2_out, f2_out, g2_out, h2_out,
           K[4927:4864], W3,
                   a3_out, b3_out, c3_out, d3_out,
                   e3_out, f3_out, g3_out, h3_out);

   main_comp mc05 (a3_out, b3_out, c3_out, d3_out,
                   e3_out, f3_out, g3_out, h3_out,
           K[4863:4800], W4,
                   a4_out, b4_out, c4_out, d4_out,
                   e4_out, f4_out, g4_out, h4_out);

   main_comp mc06 (a4_out, b4_out, c4_out, d4_out,
                   e4_out, f4_out, g4_out, h4_out,
           K[4799:4736], W5,
                   a5_out, b5_out, c5_out, d5_out,
                   e5_out, f5_out, g5_out, h5_out);

   main_comp mc07 (a5_out, b5_out, c5_out, d5_out,
                   e5_out, f5_out, g5_out, h5_out,
           K[4735:4672], W6,
                   a6_out, b6_out, c6_out, d6_out,
                   e6_out, f6_out, g6_out, h6_out);

   main_comp mc08 (a6_out, b6_out, c6_out, d6_out,
                   e6_out, f6_out, g6_out, h6_out,
           K[4671:4608], W7,
                   a7_out, b7_out, c7_out, d7_out,
                   e7_out, f7_out, g7_out, h7_out);

   main_comp mc09 (a7_out, b7_out, c7_out, d7_out,
                   e7_out, f7_out, g7_out, h7_out,
           K[4607:4544], W8,
                   a8_out, b8_out, c8_out, d8_out,
                   e8_out, f8_out, g8_out, h8_out);

   main_comp mc10 (a8_out, b8_out, c8_out, d8_out,
                   e8_out, f8_out, g8_out, h8_out,
           K[4543:4480], W9,
                   a9_out, b9_out, c9_out, d9_out,
                   e9_out, f9_out, g9_out, h9_out);

   main_comp mc11 (a9_out, b9_out, c9_out, d9_out,
                   e9_out, f9_out, g9_out, h9_out,
           K[4479:4416], W10,
                   a10_out, b10_out, c10_out, d10_out,
                   e10_out, f10_out, g10_out, h10_out);

   main_comp mc12 (a10_out, b10_out, c10_out, d10_out,
                   e10_out, f10_out, g10_out, h10_out,
           K[4415:4352], W11,
                   a11_out, b11_out, c11_out, d11_out,
                   e11_out, f11_out, g11_out, h11_out);

   main_comp mc13 (a11_out, b11_out, c11_out, d11_out,
                   e11_out, f11_out, g11_out, h11_out,
           K[4351:4288], W12,
                   a12_out, b12_out, c12_out, d12_out,
                   e12_out, f12_out, g12_out, h12_out);

   main_comp mc14 (a12_out, b12_out, c12_out, d12_out,
                   e12_out, f12_out, g12_out, h12_out,
           K[4287:4224], W13,
                   a13_out, b13_out, c13_out, d13_out,
                   e13_out, f13_out, g13_out, h13_out);

   main_comp mc15 (a13_out, b13_out, c13_out, d13_out,
                   e13_out, f13_out, g13_out, h13_out,
           K[4223:4160], W14,
                   a14_out, b14_out, c14_out, d14_out,
                   e14_out, f14_out, g14_out, h14_out);

   main_comp mc16 (a14_out, b14_out, c14_out, d14_out,
                   e14_out, f14_out, g14_out, h14_out,
           K[4159:4096], W15,
                   a15_out, b15_out, c15_out, d15_out,
                   e15_out, f15_out, g15_out, h15_out);

   main_comp mc17 (a15_out, b15_out, c15_out, d15_out,
                   e15_out, f15_out, g15_out, h15_out,
           K[4095:4032], W16,
                   a16_out, b16_out, c16_out, d16_out,
                   e16_out, f16_out, g16_out, h16_out);

   main_comp mc18 (a16_out, b16_out, c16_out, d16_out,
                   e16_out, f16_out, g16_out, h16_out,
           K[4031:3968], W17,
                   a17_out, b17_out, c17_out, d17_out,
                   e17_out, f17_out, g17_out, h17_out);

   main_comp mc19 (a17_out, b17_out, c17_out, d17_out,
                   e17_out, f17_out, g17_out, h17_out,
           K[3967:3904], W18,
                   a18_out, b18_out, c18_out, d18_out,
                   e18_out, f18_out, g18_out, h18_out);

   main_comp mc20 (a18_out, b18_out, c18_out, d18_out,
                   e18_out, f18_out, g18_out, h18_out,
           K[3903:3840], W19,
                   a19_out, b19_out, c19_out, d19_out,
                   e19_out, f19_out, g19_out, h19_out);

   main_comp mc21 (a19_out, b19_out, c19_out, d19_out,
                   e19_out, f19_out, g19_out, h19_out,
           K[3839:3776], W20,
                   a20_out, b20_out, c20_out, d20_out,
                   e20_out, f20_out, g20_out, h20_out);

   main_comp mc22 (a20_out, b20_out, c20_out, d20_out,
                   e20_out, f20_out, g20_out, h20_out,
           K[3775:3712], W21,
                   a21_out, b21_out, c21_out, d21_out,
                   e21_out, f21_out, g21_out, h21_out);

   main_comp mc23 (a21_out, b21_out, c21_out, d21_out,
                   e21_out, f21_out, g21_out, h21_out,
           K[3711:3648], W22,
                   a22_out, b22_out, c22_out, d22_out,
                   e22_out, f22_out, g22_out, h22_out);

   main_comp mc24 (a22_out, b22_out, c22_out, d22_out,
                   e22_out, f22_out, g22_out, h22_out,
           K[3647:3584], W23,
                   a23_out, b23_out, c23_out, d23_out,
                   e23_out, f23_out, g23_out, h23_out);

   main_comp mc25 (a23_out, b23_out, c23_out, d23_out,
                   e23_out, f23_out, g23_out, h23_out,
           K[3583:3520], W24,
                   a24_out, b24_out, c24_out, d24_out,
                   e24_out, f24_out, g24_out, h24_out);

   main_comp mc26 (a24_out, b24_out, c24_out, d24_out,
                   e24_out, f24_out, g24_out, h24_out,
           K[3519:3456], W25,
                   a25_out, b25_out, c25_out, d25_out,
                   e25_out, f25_out, g25_out, h25_out);

   main_comp mc27 (a25_out, b25_out, c25_out, d25_out,
                   e25_out, f25_out, g25_out, h25_out,
           K[3455:3392], W26,
                   a26_out, b26_out, c26_out, d26_out,
                   e26_out, f26_out, g26_out, h26_out);

   main_comp mc28 (a26_out, b26_out, c26_out, d26_out,
                   e26_out, f26_out, g26_out, h26_out,
           K[3391:3328], W27,
                   a27_out, b27_out, c27_out, d27_out,
                   e27_out, f27_out, g27_out, h27_out);

   main_comp mc29 (a27_out, b27_out, c27_out, d27_out,
                   e27_out, f27_out, g27_out, h27_out,
           K[3327:3264], W28,
                   a28_out, b28_out, c28_out, d28_out,
                   e28_out, f28_out, g28_out, h28_out);

   main_comp mc30 (a28_out, b28_out, c28_out, d28_out,
                   e28_out, f28_out, g28_out, h28_out,
           K[3263:3200], W29,
                   a29_out, b29_out, c29_out, d29_out,
                   e29_out, f29_out, g29_out, h29_out);

   main_comp mc31 (a29_out, b29_out, c29_out, d29_out,
                   e29_out, f29_out, g29_out, h29_out,
           K[3199:3136], W30,
                   a30_out, b30_out, c30_out, d30_out,
                   e30_out, f30_out, g30_out, h30_out);

   main_comp mc32 (a30_out, b30_out, c30_out, d30_out,
                   e30_out, f30_out, g30_out, h30_out,
           K[3135:3072], W31,
                   a31_out, b31_out, c31_out, d31_out,
                   e31_out, f31_out, g31_out, h31_out);

   main_comp mc33 (a31_out, b31_out, c31_out, d31_out,
                   e31_out, f31_out, g31_out, h31_out,
           K[3071:3008], W32,
                   a32_out, b32_out, c32_out, d32_out,
                   e32_out, f32_out, g32_out, h32_out);

   main_comp mc34 (a32_out, b32_out, c32_out, d32_out,
                   e32_out, f32_out, g32_out, h32_out,
           K[3007:2944], W33,
                   a33_out, b33_out, c33_out, d33_out,
                   e33_out, f33_out, g33_out, h33_out);

   main_comp mc35 (a33_out, b33_out, c33_out, d33_out,
                   e33_out, f33_out, g33_out, h33_out,
           K[2943:2880], W34,
                   a34_out, b34_out, c34_out, d34_out,
                   e34_out, f34_out, g34_out, h34_out);

   main_comp mc36 (a34_out, b34_out, c34_out, d34_out,
                   e34_out, f34_out, g34_out, h34_out,
           K[2879:2816], W35,
                   a35_out, b35_out, c35_out, d35_out,
                   e35_out, f35_out, g35_out, h35_out);

   main_comp mc37 (a35_out, b35_out, c35_out, d35_out,
                   e35_out, f35_out, g35_out, h35_out,
           K[2815:2752], W36,
                   a36_out, b36_out, c36_out, d36_out,
                   e36_out, f36_out, g36_out, h36_out);

   main_comp mc38 (a36_out, b36_out, c36_out, d36_out,
                   e36_out, f36_out, g36_out, h36_out,
           K[2751:2688], W37,
                   a37_out, b37_out, c37_out, d37_out,
                   e37_out, f37_out, g37_out, h37_out);

   main_comp mc39 (a37_out, b37_out, c37_out, d37_out,
                   e37_out, f37_out, g37_out, h37_out,
           K[2687:2624], W38,
                   a38_out, b38_out, c38_out, d38_out,
                   e38_out, f38_out, g38_out, h38_out);

   main_comp mc40 (a38_out, b38_out, c38_out, d38_out,
                   e38_out, f38_out, g38_out, h38_out,
           K[2623:2560], W39,
                   a39_out, b39_out, c39_out, d39_out,
                   e39_out, f39_out, g39_out, h39_out);

   main_comp mc41 (a39_out, b39_out, c39_out, d39_out,
                   e39_out, f39_out, g39_out, h39_out,
           K[2559:2496], W40,
                   a40_out, b40_out, c40_out, d40_out,
                   e40_out, f40_out, g40_out, h40_out);

   main_comp mc42 (a40_out, b40_out, c40_out, d40_out,
                   e40_out, f40_out, g40_out, h40_out,
           K[2495:2432], W41,
                   a41_out, b41_out, c41_out, d41_out,
                   e41_out, f41_out, g41_out, h41_out);

   main_comp mc43 (a41_out, b41_out, c41_out, d41_out,
                   e41_out, f41_out, g41_out, h41_out,
           K[2431:2368], W42,
                   a42_out, b42_out, c42_out, d42_out,
                   e42_out, f42_out, g42_out, h42_out);

   main_comp mc44 (a42_out, b42_out, c42_out, d42_out,
                   e42_out, f42_out, g42_out, h42_out,
           K[2367:2304], W43,
                   a43_out, b43_out, c43_out, d43_out,
                   e43_out, f43_out, g43_out, h43_out);

   main_comp mc45 (a43_out, b43_out, c43_out, d43_out,
                   e43_out, f43_out, g43_out, h43_out,
           K[2303:2240], W44,
                   a44_out, b44_out, c44_out, d44_out,
                   e44_out, f44_out, g44_out, h44_out);

   main_comp mc46 (a44_out, b44_out, c44_out, d44_out,
                   e44_out, f44_out, g44_out, h44_out,
           K[2239:2176], W45,
                   a45_out, b45_out, c45_out, d45_out,
                   e45_out, f45_out, g45_out, h45_out);

   main_comp mc47 (a45_out, b45_out, c45_out, d45_out,
                   e45_out, f45_out, g45_out, h45_out,
           K[2175:2112], W46,
                   a46_out, b46_out, c46_out, d46_out,
                   e46_out, f46_out, g46_out, h46_out);

   main_comp mc48 (a46_out, b46_out, c46_out, d46_out,
                   e46_out, f46_out, g46_out, h46_out,
           K[2111:2048], W47,
                   a47_out, b47_out, c47_out, d47_out,
                   e47_out, f47_out, g47_out, h47_out);

   main_comp mc49 (a47_out, b47_out, c47_out, d47_out,
                   e47_out, f47_out, g47_out, h47_out,
           K[2047:1984], W48,
                   a48_out, b48_out, c48_out, d48_out,
                   e48_out, f48_out, g48_out, h48_out);

   main_comp mc50 (a48_out, b48_out, c48_out, d48_out,
                   e48_out, f48_out, g48_out, h48_out,
           K[1983:1920], W49,
                   a49_out, b49_out, c49_out, d49_out,
                   e49_out, f49_out, g49_out, h49_out);

   main_comp mc51 (a49_out, b49_out, c49_out, d49_out,
                   e49_out, f49_out, g49_out, h49_out,
           K[1919:1856], W50,
                   a50_out, b50_out, c50_out, d50_out,
                   e50_out, f50_out, g50_out, h50_out);

   main_comp mc52 (a50_out, b50_out, c50_out, d50_out,
                   e50_out, f50_out, g50_out, h50_out,
           K[1855:1792], W51,
                   a51_out, b51_out, c51_out, d51_out,
                   e51_out, f51_out, g51_out, h51_out);

   main_comp mc53 (a51_out, b51_out, c51_out, d51_out,
                   e51_out, f51_out, g51_out, h51_out,
           K[1791:1728], W52,
                   a52_out, b52_out, c52_out, d52_out,
                   e52_out, f52_out, g52_out, h52_out);

   main_comp mc54 (a52_out, b52_out, c52_out, d52_out,
                   e52_out, f52_out, g52_out, h52_out,
           K[1727:1664], W53,
                   a53_out, b53_out, c53_out, d53_out,
                   e53_out, f53_out, g53_out, h53_out);

   main_comp mc55 (a53_out, b53_out, c53_out, d53_out,
                   e53_out, f53_out, g53_out, h53_out,
           K[1663:1600], W54,
                   a54_out, b54_out, c54_out, d54_out,
                   e54_out, f54_out, g54_out, h54_out);

   main_comp mc56 (a54_out, b54_out, c54_out, d54_out,
                   e54_out, f54_out, g54_out, h54_out,
           K[1599:1536], W55,
                   a55_out, b55_out, c55_out, d55_out,
                   e55_out, f55_out, g55_out, h55_out);

   main_comp mc57 (a55_out, b55_out, c55_out, d55_out,
                   e55_out, f55_out, g55_out, h55_out,
           K[1535:1472], W56,
                   a56_out, b56_out, c56_out, d56_out,
                   e56_out, f56_out, g56_out, h56_out);

   main_comp mc58 (a56_out, b56_out, c56_out, d56_out,
                   e56_out, f56_out, g56_out, h56_out,
           K[1471:1408], W57,
                   a57_out, b57_out, c57_out, d57_out,
                   e57_out, f57_out, g57_out, h57_out);

   main_comp mc59 (a57_out, b57_out, c57_out, d57_out,
                   e57_out, f57_out, g57_out, h57_out,
           K[1407:1344], W58,
                   a58_out, b58_out, c58_out, d58_out,
                   e58_out, f58_out, g58_out, h58_out);

   main_comp mc60 (a58_out, b58_out, c58_out, d58_out,
                   e58_out, f58_out, g58_out, h58_out,
           K[1343:1280], W59,
                   a59_out, b59_out, c59_out, d59_out,
                   e59_out, f59_out, g59_out, h59_out);

   main_comp mc61 (a59_out, b59_out, c59_out, d59_out,
                   e59_out, f59_out, g59_out, h59_out,
           K[1279:1216], W60,
                   a60_out, b60_out, c60_out, d60_out,
                   e60_out, f60_out, g60_out, h60_out);

   main_comp mc62 (a60_out, b60_out, c60_out, d60_out,
                   e60_out, f60_out, g60_out, h60_out,
           K[1215:1152], W61,
                   a61_out, b61_out, c61_out, d61_out,
                   e61_out, f61_out, g61_out, h61_out);

   main_comp mc63 (a61_out, b61_out, c61_out, d61_out,
                   e61_out, f61_out, g61_out, h61_out,
           K[1151:1088], W62,
                   a62_out, b62_out, c62_out, d62_out,
                   e62_out, f62_out, g62_out, h62_out);

   main_comp mc64 (a62_out, b62_out, c62_out, d62_out,
                   e62_out, f62_out, g62_out, h62_out,
           K[1087:1024], W63,
                   a63_out, b63_out, c63_out, d63_out,
                   e63_out, f63_out, g63_out, h63_out);

   main_comp mc65 (a63_out, b63_out, c63_out, d63_out,
                   e63_out, f63_out, g63_out, h63_out,
           K[1023:960], W64,
                   a64_out, b64_out, c64_out, d64_out,
                   e64_out, f64_out, g64_out, h64_out);

   main_comp mc66 (a64_out, b64_out, c64_out, d64_out,
                   e64_out, f64_out, g64_out, h64_out,
           K[959:896], W65,
                   a65_out, b65_out, c65_out, d65_out,
                   e65_out, f65_out, g65_out, h65_out);

   main_comp mc67 (a65_out, b65_out, c65_out, d65_out,
                   e65_out, f65_out, g65_out, h65_out,
           K[895:832], W66,
                   a66_out, b66_out, c66_out, d66_out,
                   e66_out, f66_out, g66_out, h66_out);

   main_comp mc68 (a66_out, b66_out, c66_out, d66_out,
                   e66_out, f66_out, g66_out, h66_out,
           K[831:768], W67,
                   a67_out, b67_out, c67_out, d67_out,
                   e67_out, f67_out, g67_out, h67_out);

   main_comp mc69 (a67_out, b67_out, c67_out, d67_out,
                   e67_out, f67_out, g67_out, h67_out,
           K[767:704], W68,
                   a68_out, b68_out, c68_out, d68_out,
                   e68_out, f68_out, g68_out, h68_out);

   main_comp mc70 (a68_out, b68_out, c68_out, d68_out,
                   e68_out, f68_out, g68_out, h68_out,
           K[703:640], W69,
                   a69_out, b69_out, c69_out, d69_out,
                   e69_out, f69_out, g69_out, h69_out);

   main_comp mc71 (a69_out, b69_out, c69_out, d69_out,
                   e69_out, f69_out, g69_out, h69_out,
           K[639:576], W70,
                   a70_out, b70_out, c70_out, d70_out,
                   e70_out, f70_out, g70_out, h70_out);

   main_comp mc72 (a70_out, b70_out, c70_out, d70_out,
                   e70_out, f70_out, g70_out, h70_out,
           K[575:512], W71,
                   a71_out, b71_out, c71_out, d71_out,
                   e71_out, f71_out, g71_out, h71_out);

   main_comp mc73 (a71_out, b71_out, c71_out, d71_out,
                   e71_out, f71_out, g71_out, h71_out,
           K[511:448], W72,
                   a72_out, b72_out, c72_out, d72_out,
                   e72_out, f72_out, g72_out, h72_out);

   main_comp mc74 (a72_out, b72_out, c72_out, d72_out,
                   e72_out, f72_out, g72_out, h72_out,
           K[447:384], W73,
                   a73_out, b73_out, c73_out, d73_out,
                   e73_out, f73_out, g73_out, h73_out);

   main_comp mc75 (a73_out, b73_out, c73_out, d73_out,
                   e73_out, f73_out, g73_out, h73_out,
           K[383:320], W74,
                   a74_out, b74_out, c74_out, d74_out,
                   e74_out, f74_out, g74_out, h74_out);

   main_comp mc76 (a74_out, b74_out, c74_out, d74_out,
                   e74_out, f74_out, g74_out, h74_out,
           K[319:256], W75,
                   a75_out, b75_out, c75_out, d75_out,
                   e75_out, f75_out, g75_out, h75_out);

   main_comp mc77 (a75_out, b75_out, c75_out, d75_out,
                   e75_out, f75_out, g75_out, h75_out,
           K[255:192], W76,
                   a76_out, b76_out, c76_out, d76_out,
                   e76_out, f76_out, g76_out, h76_out);

   main_comp mc78 (a76_out, b76_out, c76_out, d76_out,
                   e76_out, f76_out, g76_out, h76_out,
           K[191:128], W77,
                   a77_out, b77_out, c77_out, d77_out,
                   e77_out, f77_out, g77_out, h77_out);

   main_comp mc79 (a77_out, b77_out, c77_out, d77_out,
                   e77_out, f77_out, g77_out, h77_out,
           K[127:64], W78,
                   a78_out, b78_out, c78_out, d78_out,
                   e78_out, f78_out, g78_out, h78_out);

   main_comp mc80 (a78_out, b78_out, c78_out, d78_out,
                   e78_out, f78_out, g78_out, h78_out ,
           K[63:0], W79,
                   a79_out, b79_out, c79_out, d79_out,
                   e79_out, f79_out, g79_out, h79_out);

   intermediate_hash ih1 (a79_out, b79_out, c79_out, d79_out,
                      e79_out, f79_out, g79_out, h79_out,
              a, b, c, d, e, f, g, h,
              h0, h1, h2, h3, h4, h5, h6, h7);

   assign hashed ={h0, h1, h2, h3, h4, h5, h6, h7};

endmodule // sha_main

module prepare (input logic [63:0] M0, M1, M2, M3,
        input logic [63:0]  M4, M5, M6, M7,
        input logic [63:0]  M8, M9, M10, M11,
        input logic [63:0]  M12, M13, M14, M15,
        output logic [63:0] W0, W1, W2, W3, W4,
        output logic [63:0] W5, W6, W7, W8, W9,
        output logic [63:0] W10, W11, W12, W13, W14,
        output logic [63:0] W15, W16, W17, W18, W19,
        output logic [63:0] W20, W21, W22, W23, W24,
        output logic [63:0] W25, W26, W27, W28, W29,
        output logic [63:0] W30, W31, W32, W33, W34,
        output logic [63:0] W35, W36, W37, W38, W39,
        output logic [63:0] W40, W41, W42, W43, W44,
        output logic [63:0] W45, W46, W47, W48, W49,
        output logic [63:0] W50, W51, W52, W53, W54,
        output logic [63:0] W55, W56, W57, W58, W59,
        output logic [63:0] W60, W61, W62, W63, W64,
        output logic [63:0] W65, W66, W67, W68, W69,
        output logic [63:0] W70, W71, W72, W73, W74,
        output logic [63:0] W75, W76, W77, W78, W79);

   logic [63:0]             W14_sigma1_out, W15_sigma1_out, W16_sigma1_out, W17_sigma1_out,
                    W18_sigma1_out, W19_sigma1_out, W20_sigma1_out, W21_sigma1_out;
   logic [63:0]             W22_sigma1_out, W23_sigma1_out, W24_sigma1_out, W25_sigma1_out,
                    W26_sigma1_out, W27_sigma1_out, W28_sigma1_out, W29_sigma1_out;
   logic [63:0]             W30_sigma1_out, W31_sigma1_out, W32_sigma1_out, W33_sigma1_out,
                    W34_sigma1_out, W35_sigma1_out, W36_sigma1_out, W37_sigma1_out;
   logic [63:0]             W38_sigma1_out, W39_sigma1_out, W40_sigma1_out, W41_sigma1_out,
                    W42_sigma1_out, W43_sigma1_out, W44_sigma1_out, W45_sigma1_out;
   logic [63:0]             W46_sigma1_out, W47_sigma1_out, W48_sigma1_out, W49_sigma1_out,
                    W50_sigma1_out, W51_sigma1_out, W52_sigma1_out, W53_sigma1_out;
   logic [63:0]             W54_sigma1_out, W55_sigma1_out, W56_sigma1_out, W57_sigma1_out,
                    W58_sigma1_out, W59_sigma1_out, W60_sigma1_out, W61_sigma1_out;
   logic [63:0]             W62_sigma1_out, W63_sigma1_out;
   logic [63:0]             W64_sigma1_out, W65_sigma1_out, W66_sigma1_out, W67_sigma1_out,
                    W68_sigma1_out, W69_sigma1_out;
   logic [63:0]             W70_sigma1_out, W71_sigma1_out, W72_sigma1_out, W73_sigma1_out,
                    W74_sigma1_out, W75_sigma1_out, W76_sigma1_out, W77_sigma1_out;

   logic [63:0]             W1_sigma0_out, W2_sigma0_out, W3_sigma0_out, W4_sigma0_out,
                    W5_sigma0_out, W6_sigma0_out, W7_sigma0_out, W8_sigma0_out;
   logic [63:0]             W9_sigma0_out, W10_sigma0_out, W11_sigma0_out, W12_sigma0_out,
                    W13_sigma0_out, W14_sigma0_out, W15_sigma0_out, W16_sigma0_out;
   logic [63:0]             W17_sigma0_out, W18_sigma0_out, W19_sigma0_out, W20_sigma0_out,
                    W21_sigma0_out, W22_sigma0_out, W23_sigma0_out, W24_sigma0_out;
   logic [63:0]             W25_sigma0_out, W26_sigma0_out, W27_sigma0_out, W28_sigma0_out,
                    W29_sigma0_out, W30_sigma0_out, W31_sigma0_out, W32_sigma0_out;
   logic [63:0]             W33_sigma0_out, W34_sigma0_out, W35_sigma0_out, W36_sigma0_out,
                    W37_sigma0_out, W38_sigma0_out, W39_sigma0_out, W40_sigma0_out;
   logic [63:0]             W41_sigma0_out, W42_sigma0_out, W43_sigma0_out, W44_sigma0_out,
                    W45_sigma0_out, W46_sigma0_out, W47_sigma0_out, W48_sigma0_out;
   logic [63:0]             W49_sigma0_out, W50_sigma0_out, W51_sigma0_out, W52_sigma0_out,
                    W53_sigma0_out, W54_sigma0_out, W55_sigma0_out, W56_sigma0_out;
   logic [63:0]             W57_sigma0_out, W58_sigma0_out, W59_sigma0_out, W60_sigma0_out,
                    W61_sigma0_out, W62_sigma0_out, W63_sigma0_out, W64_sigma0_out;

   assign W0 = M0;
   assign W1 = M1;
   assign W2 = M2;
   assign W3 = M3;
   assign W4 = M4;
   assign W5 = M5;
   assign W6 = M6;
   assign W7 = M7;
   assign W8 = M8;
   assign W9 = M9;
   assign W10 = M10;
   assign W11 = M11;
   assign W12 = M12;
   assign W13 = M13;
   assign W14 = M14;
   assign W15 = M15;

   // sigma 1 (see bottom of page 6)
   sigma1 sig1_1 (W14, W14_sigma1_out);
   sigma1 sig1_2 (W15, W15_sigma1_out);
   sigma1 sig1_3 (W16, W16_sigma1_out);
   sigma1 sig1_4 (W17, W17_sigma1_out);
   sigma1 sig1_5 (W18, W18_sigma1_out);
   sigma1 sig1_6 (W19, W19_sigma1_out);
   sigma1 sig1_7 (W20, W20_sigma1_out);
   sigma1 sig1_8 (W21, W21_sigma1_out);
   sigma1 sig1_9 (W22, W22_sigma1_out);
   sigma1 sig1_10 (W23, W23_sigma1_out);
   sigma1 sig1_11 (W24, W24_sigma1_out);
   sigma1 sig1_12 (W25, W25_sigma1_out);
   sigma1 sig1_13 (W26, W26_sigma1_out);
   sigma1 sig1_14 (W27, W27_sigma1_out);
   sigma1 sig1_15 (W28, W28_sigma1_out);
   sigma1 sig1_16 (W29, W29_sigma1_out);
   sigma1 sig1_17 (W30, W30_sigma1_out);
   sigma1 sig1_18 (W31, W31_sigma1_out);
   sigma1 sig1_19 (W32, W32_sigma1_out);
   sigma1 sig1_20 (W33, W33_sigma1_out);
   sigma1 sig1_21 (W34, W34_sigma1_out);
   sigma1 sig1_22 (W35, W35_sigma1_out);
   sigma1 sig1_23 (W36, W36_sigma1_out);
   sigma1 sig1_24 (W37, W37_sigma1_out);
   sigma1 sig1_25 (W38, W38_sigma1_out);
   sigma1 sig1_26 (W39, W39_sigma1_out);
   sigma1 sig1_27 (W40, W40_sigma1_out);
   sigma1 sig1_28 (W41, W41_sigma1_out);
   sigma1 sig1_29 (W42, W42_sigma1_out);
   sigma1 sig1_30 (W43, W43_sigma1_out);
   sigma1 sig1_31 (W44, W44_sigma1_out);
   sigma1 sig1_32 (W45, W45_sigma1_out);
   sigma1 sig1_33 (W46, W46_sigma1_out);
   sigma1 sig1_34 (W47, W47_sigma1_out);
   sigma1 sig1_35 (W48, W48_sigma1_out);
   sigma1 sig1_36 (W49, W49_sigma1_out);
   sigma1 sig1_37 (W50, W50_sigma1_out);
   sigma1 sig1_38 (W51, W51_sigma1_out);
   sigma1 sig1_39 (W52, W52_sigma1_out);
   sigma1 sig1_40 (W53, W53_sigma1_out);
   sigma1 sig1_41 (W54, W54_sigma1_out);
   sigma1 sig1_42 (W55, W55_sigma1_out);
   sigma1 sig1_43 (W56, W56_sigma1_out);
   sigma1 sig1_44 (W57, W57_sigma1_out);
   sigma1 sig1_45 (W58, W58_sigma1_out);
   sigma1 sig1_46 (W59, W59_sigma1_out);
   sigma1 sig1_47 (W60, W60_sigma1_out);
   sigma1 sig1_48 (W61, W61_sigma1_out);
   sigma1 sig1_49 (W62, W62_sigma1_out);
   sigma1 sig1_50 (W63, W63_sigma1_out);
   sigma1 sig1_51 (W64, W64_sigma1_out);
   sigma1 sig1_52 (W65, W65_sigma1_out);
   sigma1 sig1_53 (W66, W66_sigma1_out);
   sigma1 sig1_54 (W67, W67_sigma1_out);
   sigma1 sig1_55 (W68, W68_sigma1_out);
   sigma1 sig1_56 (W69, W69_sigma1_out);
   sigma1 sig1_57 (W70, W70_sigma1_out);
   sigma1 sig1_58 (W71, W71_sigma1_out);
   sigma1 sig1_59 (W72, W72_sigma1_out);
   sigma1 sig1_60 (W73, W73_sigma1_out);
   sigma1 sig1_61 (W74, W74_sigma1_out);
   sigma1 sig1_62 (W75, W75_sigma1_out);
   sigma1 sig1_63 (W76, W76_sigma1_out);
   sigma1 sig1_64 (W77, W77_sigma1_out);

   sigma0 sig0_1 (W1, W1_sigma0_out);
   sigma0 sig0_2 (W2, W2_sigma0_out);
   sigma0 sig0_3 (W3, W3_sigma0_out);
   sigma0 sig0_4 (W4, W4_sigma0_out);
   sigma0 sig0_5 (W5, W5_sigma0_out);
   sigma0 sig0_6 (W6, W6_sigma0_out);
   sigma0 sig0_7 (W7, W7_sigma0_out);
   sigma0 sig0_8 (W8, W8_sigma0_out);
   sigma0 sig0_9 (W9, W9_sigma0_out);
   sigma0 sig0_10 (W10, W10_sigma0_out);
   sigma0 sig0_11 (W11, W11_sigma0_out);
   sigma0 sig0_12 (W12, W12_sigma0_out);
   sigma0 sig0_13 (W13, W13_sigma0_out);
   sigma0 sig0_14 (W14, W14_sigma0_out);
   sigma0 sig0_15 (W15, W15_sigma0_out);
   sigma0 sig0_16 (W16, W16_sigma0_out);
   sigma0 sig0_17 (W17, W17_sigma0_out);
   sigma0 sig0_18 (W18, W18_sigma0_out);
   sigma0 sig0_19 (W19, W19_sigma0_out);
   sigma0 sig0_20 (W20, W20_sigma0_out);
   sigma0 sig0_21 (W21, W21_sigma0_out);
   sigma0 sig0_22 (W22, W22_sigma0_out);
   sigma0 sig0_23 (W23, W23_sigma0_out);
   sigma0 sig0_24 (W24, W24_sigma0_out);
   sigma0 sig0_25 (W25, W25_sigma0_out);
   sigma0 sig0_26 (W26, W26_sigma0_out);
   sigma0 sig0_27 (W27, W27_sigma0_out);
   sigma0 sig0_28 (W28, W28_sigma0_out);
   sigma0 sig0_29 (W29, W29_sigma0_out);
   sigma0 sig0_30 (W30, W30_sigma0_out);
   sigma0 sig0_31 (W31, W31_sigma0_out);
   sigma0 sig0_32 (W32, W32_sigma0_out);
   sigma0 sig0_33 (W33, W33_sigma0_out);
   sigma0 sig0_34 (W34, W34_sigma0_out);
   sigma0 sig0_35 (W35, W35_sigma0_out);
   sigma0 sig0_36 (W36, W36_sigma0_out);
   sigma0 sig0_37 (W37, W37_sigma0_out);
   sigma0 sig0_38 (W38, W38_sigma0_out);
   sigma0 sig0_39 (W39, W39_sigma0_out);
   sigma0 sig0_40 (W40, W40_sigma0_out);
   sigma0 sig0_41 (W41, W41_sigma0_out);
   sigma0 sig0_42 (W42, W42_sigma0_out);
   sigma0 sig0_43 (W43, W43_sigma0_out);
   sigma0 sig0_44 (W44, W44_sigma0_out);
   sigma0 sig0_45 (W45, W45_sigma0_out);
   sigma0 sig0_46 (W46, W46_sigma0_out);
   sigma0 sig0_47 (W47, W47_sigma0_out);
   sigma0 sig0_48 (W48, W48_sigma0_out);
   sigma0 sig0_49 (W49, W49_sigma0_out);
   sigma0 sig0_50 (W50, W50_sigma0_out);
   sigma0 sig0_51 (W51, W51_sigma0_out);
   sigma0 sig0_52 (W52, W52_sigma0_out);
   sigma0 sig0_53 (W53, W53_sigma0_out);
   sigma0 sig0_54 (W54, W54_sigma0_out);
   sigma0 sig0_55 (W55, W55_sigma0_out);
   sigma0 sig0_56 (W56, W56_sigma0_out);
   sigma0 sig0_57 (W57, W57_sigma0_out);
   sigma0 sig0_58 (W58, W58_sigma0_out);
   sigma0 sig0_59 (W59, W59_sigma0_out);
   sigma0 sig0_60 (W60, W60_sigma0_out);
   sigma0 sig0_61 (W61, W61_sigma0_out);
   sigma0 sig0_62 (W62, W62_sigma0_out);
   sigma0 sig0_63 (W63, W63_sigma0_out);
   sigma0 sig0_64 (W64, W64_sigma0_out);

   // Equation for W_i (top of page 7)3
   assign W16 = W14_sigma1_out + W9 + W1_sigma0_out + W0;
   assign W17 = W15_sigma1_out + W10 + W2_sigma0_out + W1;
   assign W18 = W16_sigma1_out + W11 + W3_sigma0_out + W2;
   assign W19 = W17_sigma1_out + W12 + W4_sigma0_out + W3;
   assign W20 = W18_sigma1_out + W13 + W5_sigma0_out + W4;
   assign W21 = W19_sigma1_out + W14 + W6_sigma0_out + W5;
   assign W22 = W20_sigma1_out + W15 + W7_sigma0_out + W6;
   assign W23 = W21_sigma1_out + W16 + W8_sigma0_out + W7;
   assign W24 = W22_sigma1_out + W17 + W9_sigma0_out + W8;
   assign W25 = W23_sigma1_out + W18 + W10_sigma0_out + W9;
   assign W26 = W24_sigma1_out + W19 + W11_sigma0_out + W10;
   assign W27 = W25_sigma1_out + W20 + W12_sigma0_out + W11;
   assign W28 = W26_sigma1_out + W21 + W13_sigma0_out + W12;
   assign W29 = W27_sigma1_out + W22 + W14_sigma0_out + W13;
   assign W30 = W28_sigma1_out + W23 + W15_sigma0_out + W14;
   assign W31 = W29_sigma1_out + W24 + W16_sigma0_out + W15;
   assign W32 = W30_sigma1_out + W25 + W17_sigma0_out + W16;
   assign W33 = W31_sigma1_out + W26 + W18_sigma0_out + W17;
   assign W34 = W32_sigma1_out + W27 + W19_sigma0_out + W18;
   assign W35 = W33_sigma1_out + W28 + W20_sigma0_out + W19;
   assign W36 = W34_sigma1_out + W29 + W21_sigma0_out + W20;
   assign W37 = W35_sigma1_out + W30 + W22_sigma0_out + W21;
   assign W38 = W36_sigma1_out + W31 + W23_sigma0_out + W22;
   assign W39 = W37_sigma1_out + W32 + W24_sigma0_out + W23;
   assign W40 = W38_sigma1_out + W33 + W25_sigma0_out + W24;
   assign W41 = W39_sigma1_out + W34 + W26_sigma0_out + W25;
   assign W42 = W40_sigma1_out + W35 + W27_sigma0_out + W26;
   assign W43 = W41_sigma1_out + W36 + W28_sigma0_out + W27;
   assign W44 = W42_sigma1_out + W37 + W29_sigma0_out + W28;
   assign W45 = W43_sigma1_out + W38 + W30_sigma0_out + W29;
   assign W46 = W44_sigma1_out + W39 + W31_sigma0_out + W30;
   assign W47 = W45_sigma1_out + W40 + W32_sigma0_out + W31;
   assign W48 = W46_sigma1_out + W41 + W33_sigma0_out + W32;
   assign W49 = W47_sigma1_out + W42 + W34_sigma0_out + W33;
   assign W50 = W48_sigma1_out + W43 + W35_sigma0_out + W34;
   assign W51 = W49_sigma1_out + W44 + W36_sigma0_out + W35;
   assign W52 = W50_sigma1_out + W45 + W37_sigma0_out + W36;
   assign W53 = W51_sigma1_out + W46 + W38_sigma0_out + W37;
   assign W54 = W52_sigma1_out + W47 + W39_sigma0_out + W38;
   assign W55 = W53_sigma1_out + W48 + W40_sigma0_out + W39;
   assign W56 = W54_sigma1_out + W49 + W41_sigma0_out + W40;
   assign W57 = W55_sigma1_out + W50 + W42_sigma0_out + W41;
   assign W58 = W56_sigma1_out + W51 + W43_sigma0_out + W42;
   assign W59 = W57_sigma1_out + W52 + W44_sigma0_out + W43;
   assign W60 = W58_sigma1_out + W53 + W45_sigma0_out + W44;
   assign W61 = W59_sigma1_out + W54 + W46_sigma0_out + W45;
   assign W62 = W60_sigma1_out + W55 + W47_sigma0_out + W46;
   assign W63 = W61_sigma1_out + W56 + W48_sigma0_out + W47;
   assign W64 = W62_sigma1_out + W57 + W49_sigma0_out + W48;
   assign W65 = W63_sigma1_out + W58 + W50_sigma0_out + W49;
   assign W66 = W64_sigma1_out + W59 + W51_sigma0_out + W50;
   assign W67 = W65_sigma1_out + W60 + W52_sigma0_out + W51;
   assign W68 = W66_sigma1_out + W61 + W53_sigma0_out + W52;
   assign W69 = W67_sigma1_out + W62 + W54_sigma0_out + W53;
   assign W70 = W68_sigma1_out + W63 + W55_sigma0_out + W54;
   assign W71 = W69_sigma1_out + W64 + W56_sigma0_out + W55;
   assign W72 = W70_sigma1_out + W65 + W57_sigma0_out + W56;
   assign W73 = W71_sigma1_out + W66 + W58_sigma0_out + W57;
   assign W74 = W72_sigma1_out + W67 + W59_sigma0_out + W58;
   assign W75 = W73_sigma1_out + W68 + W60_sigma0_out + W59;
   assign W76 = W74_sigma1_out + W69 + W61_sigma0_out + W60;
   assign W77 = W75_sigma1_out + W70 + W62_sigma0_out + W61;
   assign W78 = W76_sigma1_out + W71 + W63_sigma0_out + W62;
   assign W79 = W77_sigma1_out + W72 + W64_sigma0_out + W63;

endmodule // prepare

module main_comp (input logic [63:0] a_in, b_in, c_in, d_in, e_in, f_in, g_in, h_in,
          input logic [63:0]  K_in, W_in,
          output logic [63:0] a_out, b_out, c_out, d_out, e_out, f_out, g_out,
          output logic [63:0] h_out);

   logic [63:0]               ch, maj, Sig0, Sig1;
   logic [63:0]               t1, t2;
   logic [63:0]               T1, T2;

   choice ch1 ( e_in, f_in, g_in, ch);
   majority m1(a_in, b_in, c_in, maj);
   Sigma0 S0(a_in, Sig0);
   Sigma1 S1(e_in, Sig1);

   assign t1 = (h_in+Sig1+ch+K_in+W_in)  ;
   assign t2 = (Sig0+maj) ;
   assign T1 = t1;
   assign T2 = t2;
   assign h_out = g_in;
   assign g_out = f_in;
   assign f_out = e_in;
   assign e_out = (d_in+T1);
   assign d_out = c_in;
   assign c_out = b_in;
   assign b_out = a_in;
   assign a_out = (T1+T2);

endmodule // main_comp

module intermediate_hash (input logic [63:0] a_in, b_in, c_in, d_in, e_in, f_in, g_in, h_in,
              input logic [63:0]  h0_in, h1_in, h2_in, h3_in, h4_in, h5_in, h6_in, h7_in,
              output logic [63:0] h0_out, h1_out, h2_out, h3_out, h4_out, h5_out, h6_out, h7_out);

   assign h0_out = a_in + h0_in;
   assign h1_out = b_in + h1_in;
   assign h2_out = c_in + h2_in;
   assign h3_out = d_in + h3_in;
   assign h4_out = e_in + h4_in;
   assign h5_out = f_in + h5_in;
   assign h6_out = g_in + h6_in;
   assign h7_out = h_in + h7_in;

endmodule

module majority (input logic [63:0] x, y, z, output logic [63:0] maj);

   // See Section 2.3.3, Number 4
   assign maj = (x & y) ^ (x & z) ^ (y & z);

endmodule // majority

module choice (input logic [63:0] x, y, z, output logic [63:0] ch);

   // See Section 2.3.3, Number 4
   assign ch = (x & y) ^ (~x & z);

endmodule // choice

module Sigma0 (input logic [63:0] x, output logic [63:0] Sig0);

   assign Sig0 = ({x[27:0], x[63:28]})^({x[33:0], x[63:34]})^({x[38:0], x[63:39]});

endmodule // Sigma0


module sigma0 (input logic [63:0] x, output logic [63:0] sig0);

   assign sig0 = ({x[0], x[63:1]})^({x[7:0], x[63:8]})^(x>>7);

endmodule // sigma0

module Sigma1 (input logic [63:0] x, output logic [63:0] Sig1);

   // See Section 2.3.3, Number 4
   assign Sig1 = ({x[13:0], x[63:14]})^({x[17:0], x[63:18]})^({x[40:0], x[63:41]});

endmodule // Sigma1

module sigma1 (input logic [63:0] x, output logic [63:0] sig1);

   assign sig1 = ({x[18:0], x[63:19]})^({x[60:0], x[63:61]})^(x>>6);

endmodule // sigma1
