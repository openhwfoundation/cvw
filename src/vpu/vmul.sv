///////////////////////////////////////////
// vmul.sv
//
// Written: Angela Zheng angela20061015@gmail.com
// Created: 31 Oct 2026
// Modified: 12 Nov 2026
//
// Purpose: RISC-V Vector Multiply Unit
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

module vmul import cvw::*; #(parameter cvw_t P)
  (
   input logic                 clk, reset,
   input logic [P.ELEN-1:0]    A, B,
   input logic [1:0]           Sew,
   input logic [1:0]           MulSelect,       // 00 = vmul, 01 = vmulh, 10 = vwmul
   output logic [P.ELEN-1:0] Product
   );

  // ***TODO: Implement sign logic
  logic [2:0] Sign;

  // Partial products in Execute stage
  logic [15:0] Prod_8_00E, Prod_8_01E, Prod_8_10E, Prod_8_11E,
               Prod_8_22E, Prod_8_23E, Prod_8_32E, Prod_8_33E,
               Prod_8_44E, Prod_8_45E, Prod_8_54E, Prod_8_55E,
               Prod_8_66E, Prod_8_67E, Prod_8_76E, Prod_8_77E;
  logic [31:0] Prod_16_02E, Prod_16_20E, Prod_16_46E, Prod_16_64E;
  logic [63:0] Prod_32_04E, Prod_32_40E;

  // Partial Products in Memory stage
  logic [15:0] Prod_8_00M, Prod_8_01M, Prod_8_10M, Prod_8_11M,
               Prod_8_22M, Prod_8_23M, Prod_8_32M, Prod_8_33M,
               Prod_8_44M, Prod_8_45M, Prod_8_54M, Prod_8_55M,
               Prod_8_66M, Prod_8_67M, Prod_8_76M, Prod_8_77M;
  logic [31:0] Prod_16_00M, Prod_16_02M, Prod_16_20M, Prod_16_22M,
               Prod_16_44M, Prod_16_46M, Prod_16_64M, Prod_16_66M;
  logic [63:0] Prod_32_00M, Prod_32_04M, Prod_32_40M, Prod_32_44M;
  logic [127:0] Prod_64_00M;
  logic [1:0]   SewM;
  logic [1:0]   MulSelectM;
  logic [2*P.ELEN-1:0] FullProductM;      // full 2*SEW product of every element
  logic [P.ELEN-1:0]   SingleProductM;    // low or high SEW bits of every element

  // Partial products in Execute stage
  assign Prod_8_00E = A[7:0] * B[7:0];
  assign Prod_8_01E = A[7:0] * B[15:8];
  assign Prod_8_10E = A[15:8] * B[7:0];
  assign Prod_8_11E = A[15:8] * B[15:8];
  assign Prod_8_22E = A[23:16] * B[23:16];
  assign Prod_8_23E = A[23:16] * B[31:24];
  assign Prod_8_32E = A[31:24] * B[23:16];
  assign Prod_8_33E = A[31:24] * B[31:24];
  assign Prod_8_44E = A[39:32] * B[39:32];
  assign Prod_8_45E = A[39:32] * B[47:40];
  assign Prod_8_54E = A[47:40] * B[39:32];
  assign Prod_8_55E = A[47:40] * B[47:40];
  assign Prod_8_66E = A[55:48] * B[55:48];
  assign Prod_8_67E = A[55:48] * B[63:56];
  assign Prod_8_76E = A[63:56] * B[55:48];
  assign Prod_8_77E = A[63:56] * B[63:56];

  assign Prod_16_02E = A[15:0] * B[31:16];
  assign Prod_16_20E = A[31:16] * B[15:0];
  assign Prod_16_46E = A[47:32] * B[63:48];
  assign Prod_16_64E = A[63:48] * B[47:32];

  assign Prod_32_04E = A[31:0] * B[63:32];
  assign Prod_32_40E = A[63:32] * B[31:0];

  // Pipeline registers
  flopr #(256) Prod8Reg(clk, reset,
    {Prod_8_00E, Prod_8_01E, Prod_8_10E, Prod_8_11E, Prod_8_22E, Prod_8_23E, Prod_8_32E, Prod_8_33E,
     Prod_8_44E, Prod_8_45E, Prod_8_54E, Prod_8_55E, Prod_8_66E, Prod_8_67E, Prod_8_76E, Prod_8_77E},
    {Prod_8_00M, Prod_8_01M, Prod_8_10M, Prod_8_11M, Prod_8_22M, Prod_8_23M, Prod_8_32M, Prod_8_33M,
     Prod_8_44M, Prod_8_45M, Prod_8_54M, Prod_8_55M, Prod_8_66M, Prod_8_67M, Prod_8_76M, Prod_8_77M});

  flopr #(128) Prod16Reg(clk, reset,
    {Prod_16_02E, Prod_16_20E, Prod_16_46E, Prod_16_64E},
    {Prod_16_02M, Prod_16_20M, Prod_16_46M, Prod_16_64M});

  flopr #(128) Prod32Reg(clk, reset,
    {Prod_32_04E, Prod_32_40E},
    {Prod_32_04M, Prod_32_40M});

  flopr #(4) CtrlReg(clk, reset, {Sew, MulSelect}, {SewM, MulSelectM});

  // Adder tree
  assign Prod_16_00M = {16'b0, Prod_8_00M} + {8'b0, Prod_8_01M, 8'b0} + {8'b0, Prod_8_10M, 8'b0} + {Prod_8_11M, 16'b0};
  assign Prod_16_22M = {16'b0, Prod_8_22M} + {8'b0, Prod_8_23M, 8'b0} + {8'b0, Prod_8_32M, 8'b0} + {Prod_8_33M, 16'b0};
  assign Prod_16_44M = {16'b0, Prod_8_44M} + {8'b0, Prod_8_45M, 8'b0} + {8'b0, Prod_8_54M, 8'b0} + {Prod_8_55M, 16'b0};
  assign Prod_16_66M = {16'b0, Prod_8_66M} + {8'b0, Prod_8_67M, 8'b0} + {8'b0, Prod_8_76M, 8'b0} + {Prod_8_77M, 16'b0};

  assign Prod_32_00M = {32'b0, Prod_16_00M} + {16'b0, Prod_16_02M, 16'b0} + {16'b0, Prod_16_20M, 16'b0} + {Prod_16_22M, 32'b0};
  assign Prod_32_44M = {32'b0, Prod_16_44M} + {16'b0, Prod_16_46M, 16'b0} + {16'b0, Prod_16_64M, 16'b0} + {Prod_16_66M, 32'b0};

  assign Prod_64_00M = {64'b0, Prod_32_00M} + {32'b0, Prod_32_04M, 32'b0} + {32'b0, Prod_32_40M, 32'b0} + {Prod_32_44M, 64'b0};

  // Full products for widening multiplications
  always_comb
    case (SewM)
      2'b00: FullProductM = {Prod_8_77M, Prod_8_66M, Prod_8_55M, Prod_8_44M, Prod_8_33M, Prod_8_22M, Prod_8_11M, Prod_8_00M};
      2'b01: FullProductM = {Prod_16_66M, Prod_16_44M, Prod_16_22M, Prod_16_00M};
      2'b10: FullProductM = {Prod_32_44M, Prod_32_00M};
      2'b11: FullProductM = Prod_64_00M;
    endcase

  // Single width: vmul or vmulh SEW bits of each element
  always_comb
    case ({SewM, MulSelectM[0]})
      3'b000: SingleProductM = {Prod_8_77M[7:0],  Prod_8_66M[7:0],  Prod_8_55M[7:0],  Prod_8_44M[7:0],
                                Prod_8_33M[7:0],  Prod_8_22M[7:0],  Prod_8_11M[7:0],  Prod_8_00M[7:0]};
      3'b001: SingleProductM = {Prod_8_77M[15:8], Prod_8_66M[15:8], Prod_8_55M[15:8], Prod_8_44M[15:8],
                                Prod_8_33M[15:8], Prod_8_22M[15:8], Prod_8_11M[15:8], Prod_8_00M[15:8]};
      3'b010: SingleProductM = {Prod_16_66M[15:0],  Prod_16_44M[15:0],  Prod_16_22M[15:0],  Prod_16_00M[15:0]};
      3'b011: SingleProductM = {Prod_16_66M[31:16], Prod_16_44M[31:16], Prod_16_22M[31:16], Prod_16_00M[31:16]};
      3'b100: SingleProductM = {Prod_32_44M[31:0],  Prod_32_00M[31:0]};
      3'b101: SingleProductM = {Prod_32_44M[63:32], Prod_32_00M[63:32]};
      3'b110: SingleProductM = Prod_64_00M[63:0];
      3'b111: SingleProductM = Prod_64_00M[127:64];
    endcase

  // ***TODO: Figure out beat so we can select upper 64 bits of vwmul in one beat and lower 64 bit on th next
  assign Product = MulSelectM[1] ? FullProductM[P.ELEN-1:0] : SingleProductM;

endmodule
