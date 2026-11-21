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
   input logic                 StallM,          // holds the Memory stage registers
   input logic                 FlushM,          // clears the Memory stage registers
   input logic [P.ELEN-1:0]    A, B,            // A = vs1/rs1, B = vs2
   input logic [2:0]           SEW,
   input logic [1:0]           MulSelect,       // 00 = vmul, 01 = vmulh, 10 = vwmul
   input logic [1:0]           MulSign,         // {A signed, B signed}: element signedness of the instruction
   output logic [P.ELEN-1:0]   Product
   );

  // *** written for ELEN = 64
  // Each element is split into 8-, 16- and 32-bit chunks multiplied by vmulblocks.  Only the top chunk of an
  // element carries its sign, so a chunk is signed when it is the top of its element at the current SEW and
  // the instruction treats that operand as signed.

  // Top byte of each element at the current SEW
  logic [7:0] TopByte;                    // byte i of an operand is the top byte of its element
  logic [7:0] ASByte, BSByte;             // signed bytes of A and B

  always_comb
    case (SEW)
      3'b000:  TopByte = 8'b11111111; // 8
      3'b001:  TopByte = 8'b10101010; // 16
      3'b010:  TopByte = 8'b10001000; // 32
      default: TopByte = 8'b10000000; // 64 (1xx is reserved)
    endcase

  assign ASByte = {8{MulSign[1]}} & TopByte;
  assign BSByte = {8{MulSign[0]}} & TopByte;

  // Partial products of each vmulblock in Execute stage
  logic [3:0][15:0] PP_8_00E;
  logic [3:0][15:0] PP_8_01E;
  logic [3:0][15:0] PP_8_10E;
  logic [3:0][15:0] PP_8_11E;
  logic [3:0][15:0] PP_8_22E;
  logic [3:0][15:0] PP_8_23E;
  logic [3:0][15:0] PP_8_32E;
  logic [3:0][15:0] PP_8_33E;
  logic [3:0][15:0] PP_8_44E;
  logic [3:0][15:0] PP_8_45E;
  logic [3:0][15:0] PP_8_54E;
  logic [3:0][15:0] PP_8_55E;
  logic [3:0][15:0] PP_8_66E;
  logic [3:0][15:0] PP_8_67E;
  logic [3:0][15:0] PP_8_76E;
  logic [3:0][15:0] PP_8_77E;
  logic [3:0][31:0] PP_16_02E;
  logic [3:0][31:0] PP_16_20E;
  logic [3:0][31:0] PP_16_46E;
  logic [3:0][31:0] PP_16_64E;
  logic [3:0][63:0] PP_32_04E;
  logic [3:0][63:0] PP_32_40E;

  // Products in Execute stage
  logic [15:0] Prod_8_00E, Prod_8_01E, Prod_8_10E, Prod_8_11E, Prod_8_22E, Prod_8_23E, Prod_8_32E, Prod_8_33E,
               Prod_8_44E, Prod_8_45E, Prod_8_54E, Prod_8_55E, Prod_8_66E, Prod_8_67E, Prod_8_76E, Prod_8_77E;
  logic [31:0] Prod_16_02E, Prod_16_20E, Prod_16_46E, Prod_16_64E;
  logic [63:0] Prod_32_04E, Prod_32_40E;

  // Off-diagonal products may be negative and are sign-extended in the adder tree
  logic        Sig_8_01E, Sig_8_10E, Sig_8_23E, Sig_8_32E, Sig_8_45E, Sig_8_54E, Sig_8_67E, Sig_8_76E,
               Sig_16_02E, Sig_16_20E, Sig_16_46E, Sig_16_64E, Sig_32_04E, Sig_32_40E;
  logic        Sig_8_01M, Sig_8_10M, Sig_8_23M, Sig_8_32M, Sig_8_45M, Sig_8_54M, Sig_8_67M, Sig_8_76M,
               Sig_16_02M, Sig_16_20M, Sig_16_46M, Sig_16_64M, Sig_32_04M, Sig_32_40M;

  // Products in Memory stage
  logic [15:0] Prod_8_00M, Prod_8_01M, Prod_8_10M, Prod_8_11M, Prod_8_22M, Prod_8_23M, Prod_8_32M, Prod_8_33M,
               Prod_8_44M, Prod_8_45M, Prod_8_54M, Prod_8_55M, Prod_8_66M, Prod_8_67M, Prod_8_76M, Prod_8_77M;
  logic [31:0] Prod_16_00M, Prod_16_02M, Prod_16_20M, Prod_16_22M,
               Prod_16_44M, Prod_16_46M, Prod_16_64M, Prod_16_66M;
  logic [63:0] Prod_32_00M, Prod_32_04M, Prod_32_40M, Prod_32_44M;
  logic [127:0] Prod_64_00M;
  logic [2:0]   SEWM;
  logic [1:0]   MulSelectM;
  logic [2*P.ELEN-1:0] FullProductM;      // full 2*SEW product of every element
  logic [P.ELEN-1:0]   SingleProductM;    // low or high SEW bits of every element

  // Execute stage: vmulblocks
  // Prod_8_ij  = A byte i * B byte j
  vmulblock #(8) mul_8_00(.A(B[7:0]), .B(A[7:0]), .Signed({BSByte[0], ASByte[0]}),
    .PP1E(PP_8_00E[0]), .PP2E(PP_8_00E[1]), .PP3E(PP_8_00E[2]), .PP4E(PP_8_00E[3]));
  vmulblock #(8) mul_8_01(.A(B[15:8]), .B(A[7:0]), .Signed({BSByte[1], ASByte[0]}),
    .PP1E(PP_8_01E[0]), .PP2E(PP_8_01E[1]), .PP3E(PP_8_01E[2]), .PP4E(PP_8_01E[3]));
  vmulblock #(8) mul_8_10(.A(A[15:8]), .B(B[7:0]), .Signed({ASByte[1], BSByte[0]}),
    .PP1E(PP_8_10E[0]), .PP2E(PP_8_10E[1]), .PP3E(PP_8_10E[2]), .PP4E(PP_8_10E[3]));
  vmulblock #(8) mul_8_11(.A(B[15:8]), .B(A[15:8]), .Signed({BSByte[1], ASByte[1]}),
    .PP1E(PP_8_11E[0]), .PP2E(PP_8_11E[1]), .PP3E(PP_8_11E[2]), .PP4E(PP_8_11E[3]));
  vmulblock #(8) mul_8_22(.A(B[23:16]), .B(A[23:16]), .Signed({BSByte[2], ASByte[2]}),
    .PP1E(PP_8_22E[0]), .PP2E(PP_8_22E[1]), .PP3E(PP_8_22E[2]), .PP4E(PP_8_22E[3]));
  vmulblock #(8) mul_8_23(.A(B[31:24]), .B(A[23:16]), .Signed({BSByte[3], ASByte[2]}),
    .PP1E(PP_8_23E[0]), .PP2E(PP_8_23E[1]), .PP3E(PP_8_23E[2]), .PP4E(PP_8_23E[3]));
  vmulblock #(8) mul_8_32(.A(A[31:24]), .B(B[23:16]), .Signed({ASByte[3], BSByte[2]}),
    .PP1E(PP_8_32E[0]), .PP2E(PP_8_32E[1]), .PP3E(PP_8_32E[2]), .PP4E(PP_8_32E[3]));
  vmulblock #(8) mul_8_33(.A(B[31:24]), .B(A[31:24]), .Signed({BSByte[3], ASByte[3]}),
    .PP1E(PP_8_33E[0]), .PP2E(PP_8_33E[1]), .PP3E(PP_8_33E[2]), .PP4E(PP_8_33E[3]));
  vmulblock #(8) mul_8_44(.A(B[39:32]), .B(A[39:32]), .Signed({BSByte[4], ASByte[4]}),
    .PP1E(PP_8_44E[0]), .PP2E(PP_8_44E[1]), .PP3E(PP_8_44E[2]), .PP4E(PP_8_44E[3]));
  vmulblock #(8) mul_8_45(.A(B[47:40]), .B(A[39:32]), .Signed({BSByte[5], ASByte[4]}),
    .PP1E(PP_8_45E[0]), .PP2E(PP_8_45E[1]), .PP3E(PP_8_45E[2]), .PP4E(PP_8_45E[3]));
  vmulblock #(8) mul_8_54(.A(A[47:40]), .B(B[39:32]), .Signed({ASByte[5], BSByte[4]}),
    .PP1E(PP_8_54E[0]), .PP2E(PP_8_54E[1]), .PP3E(PP_8_54E[2]), .PP4E(PP_8_54E[3]));
  vmulblock #(8) mul_8_55(.A(B[47:40]), .B(A[47:40]), .Signed({BSByte[5], ASByte[5]}),
    .PP1E(PP_8_55E[0]), .PP2E(PP_8_55E[1]), .PP3E(PP_8_55E[2]), .PP4E(PP_8_55E[3]));
  vmulblock #(8) mul_8_66(.A(B[55:48]), .B(A[55:48]), .Signed({BSByte[6], ASByte[6]}),
    .PP1E(PP_8_66E[0]), .PP2E(PP_8_66E[1]), .PP3E(PP_8_66E[2]), .PP4E(PP_8_66E[3]));
  vmulblock #(8) mul_8_67(.A(B[63:56]), .B(A[55:48]), .Signed({BSByte[7], ASByte[6]}),
    .PP1E(PP_8_67E[0]), .PP2E(PP_8_67E[1]), .PP3E(PP_8_67E[2]), .PP4E(PP_8_67E[3]));
  vmulblock #(8) mul_8_76(.A(A[63:56]), .B(B[55:48]), .Signed({ASByte[7], BSByte[6]}),
    .PP1E(PP_8_76E[0]), .PP2E(PP_8_76E[1]), .PP3E(PP_8_76E[2]), .PP4E(PP_8_76E[3]));
  vmulblock #(8) mul_8_77(.A(B[63:56]), .B(A[63:56]), .Signed({BSByte[7], ASByte[7]}),
    .PP1E(PP_8_77E[0]), .PP2E(PP_8_77E[1]), .PP3E(PP_8_77E[2]), .PP4E(PP_8_77E[3]));

  // Prod_16_ij
  vmulblock #(16) mul_16_02(.A(B[31:16]), .B(A[15:0]), .Signed({BSByte[3], ASByte[1]}),
    .PP1E(PP_16_02E[0]), .PP2E(PP_16_02E[1]), .PP3E(PP_16_02E[2]), .PP4E(PP_16_02E[3]));
  vmulblock #(16) mul_16_20(.A(A[31:16]), .B(B[15:0]), .Signed({ASByte[3], BSByte[1]}),
    .PP1E(PP_16_20E[0]), .PP2E(PP_16_20E[1]), .PP3E(PP_16_20E[2]), .PP4E(PP_16_20E[3]));
  vmulblock #(16) mul_16_46(.A(B[63:48]), .B(A[47:32]), .Signed({BSByte[7], ASByte[5]}),
    .PP1E(PP_16_46E[0]), .PP2E(PP_16_46E[1]), .PP3E(PP_16_46E[2]), .PP4E(PP_16_46E[3]));
  vmulblock #(16) mul_16_64(.A(A[63:48]), .B(B[47:32]), .Signed({ASByte[7], BSByte[5]}),
    .PP1E(PP_16_64E[0]), .PP2E(PP_16_64E[1]), .PP3E(PP_16_64E[2]), .PP4E(PP_16_64E[3]));

  // Prod_32_ij
  vmulblock #(32) mul_32_04(.A(B[63:32]), .B(A[31:0]), .Signed({BSByte[7], ASByte[3]}),
    .PP1E(PP_32_04E[0]), .PP2E(PP_32_04E[1]), .PP3E(PP_32_04E[2]), .PP4E(PP_32_04E[3]));
  vmulblock #(32) mul_32_40(.A(A[63:32]), .B(B[31:0]), .Signed({ASByte[7], BSByte[3]}),
    .PP1E(PP_32_40E[0]), .PP2E(PP_32_40E[1]), .PP3E(PP_32_40E[2]), .PP4E(PP_32_40E[3]));

  // sum the partial products of each block
  assign Prod_8_00E = PP_8_00E[0] + PP_8_00E[1] + PP_8_00E[2] + PP_8_00E[3];
  assign Prod_8_01E = PP_8_01E[0] + PP_8_01E[1] + PP_8_01E[2] + PP_8_01E[3];
  assign Prod_8_10E = PP_8_10E[0] + PP_8_10E[1] + PP_8_10E[2] + PP_8_10E[3];
  assign Prod_8_11E = PP_8_11E[0] + PP_8_11E[1] + PP_8_11E[2] + PP_8_11E[3];
  assign Prod_8_22E = PP_8_22E[0] + PP_8_22E[1] + PP_8_22E[2] + PP_8_22E[3];
  assign Prod_8_23E = PP_8_23E[0] + PP_8_23E[1] + PP_8_23E[2] + PP_8_23E[3];
  assign Prod_8_32E = PP_8_32E[0] + PP_8_32E[1] + PP_8_32E[2] + PP_8_32E[3];
  assign Prod_8_33E = PP_8_33E[0] + PP_8_33E[1] + PP_8_33E[2] + PP_8_33E[3];
  assign Prod_8_44E = PP_8_44E[0] + PP_8_44E[1] + PP_8_44E[2] + PP_8_44E[3];
  assign Prod_8_45E = PP_8_45E[0] + PP_8_45E[1] + PP_8_45E[2] + PP_8_45E[3];
  assign Prod_8_54E = PP_8_54E[0] + PP_8_54E[1] + PP_8_54E[2] + PP_8_54E[3];
  assign Prod_8_55E = PP_8_55E[0] + PP_8_55E[1] + PP_8_55E[2] + PP_8_55E[3];
  assign Prod_8_66E = PP_8_66E[0] + PP_8_66E[1] + PP_8_66E[2] + PP_8_66E[3];
  assign Prod_8_67E = PP_8_67E[0] + PP_8_67E[1] + PP_8_67E[2] + PP_8_67E[3];
  assign Prod_8_76E = PP_8_76E[0] + PP_8_76E[1] + PP_8_76E[2] + PP_8_76E[3];
  assign Prod_8_77E = PP_8_77E[0] + PP_8_77E[1] + PP_8_77E[2] + PP_8_77E[3];
  assign Prod_16_02E = PP_16_02E[0] + PP_16_02E[1] + PP_16_02E[2] + PP_16_02E[3];
  assign Prod_16_20E = PP_16_20E[0] + PP_16_20E[1] + PP_16_20E[2] + PP_16_20E[3];
  assign Prod_16_46E = PP_16_46E[0] + PP_16_46E[1] + PP_16_46E[2] + PP_16_46E[3];
  assign Prod_16_64E = PP_16_64E[0] + PP_16_64E[1] + PP_16_64E[2] + PP_16_64E[3];
  assign Prod_32_04E = PP_32_04E[0] + PP_32_04E[1] + PP_32_04E[2] + PP_32_04E[3];
  assign Prod_32_40E = PP_32_40E[0] + PP_32_40E[1] + PP_32_40E[2] + PP_32_40E[3];

  // an off-diagonal product is signed when either of its chunks is
  assign Sig_8_01E = ASByte[0] | BSByte[1];
  assign Sig_8_10E = ASByte[1] | BSByte[0];
  assign Sig_8_23E = ASByte[2] | BSByte[3];
  assign Sig_8_32E = ASByte[3] | BSByte[2];
  assign Sig_8_45E = ASByte[4] | BSByte[5];
  assign Sig_8_54E = ASByte[5] | BSByte[4];
  assign Sig_8_67E = ASByte[6] | BSByte[7];
  assign Sig_8_76E = ASByte[7] | BSByte[6];
  assign Sig_16_02E = ASByte[1] | BSByte[3];
  assign Sig_16_20E = ASByte[3] | BSByte[1];
  assign Sig_16_46E = ASByte[5] | BSByte[7];
  assign Sig_16_64E = ASByte[7] | BSByte[5];
  assign Sig_32_04E = ASByte[3] | BSByte[7];
  assign Sig_32_40E = ASByte[7] | BSByte[3];

  // Pipeline registers
  flopenrc #(256) Prod8Reg(clk, reset, FlushM, ~StallM,
    {Prod_8_00E, Prod_8_01E, Prod_8_10E, Prod_8_11E, Prod_8_22E, Prod_8_23E, Prod_8_32E, Prod_8_33E,
     Prod_8_44E, Prod_8_45E, Prod_8_54E, Prod_8_55E, Prod_8_66E, Prod_8_67E, Prod_8_76E, Prod_8_77E},
    {Prod_8_00M, Prod_8_01M, Prod_8_10M, Prod_8_11M, Prod_8_22M, Prod_8_23M, Prod_8_32M, Prod_8_33M,
     Prod_8_44M, Prod_8_45M, Prod_8_54M, Prod_8_55M, Prod_8_66M, Prod_8_67M, Prod_8_76M, Prod_8_77M});

  flopenrc #(128) Prod16Reg(clk, reset, FlushM, ~StallM,
    {Prod_16_02E, Prod_16_20E, Prod_16_46E, Prod_16_64E},
    {Prod_16_02M, Prod_16_20M, Prod_16_46M, Prod_16_64M});

  flopenrc #(128) Prod32Reg(clk, reset, FlushM, ~StallM,
    {Prod_32_04E, Prod_32_40E},
    {Prod_32_04M, Prod_32_40M});

  flopenrc #(14) SigReg(clk, reset, FlushM, ~StallM,
    {Sig_8_01E, Sig_8_10E, Sig_8_23E, Sig_8_32E, Sig_8_45E, Sig_8_54E, Sig_8_67E, Sig_8_76E, Sig_16_02E, Sig_16_20E, Sig_16_46E, Sig_16_64E, Sig_32_04E, Sig_32_40E},
    {Sig_8_01M, Sig_8_10M, Sig_8_23M, Sig_8_32M, Sig_8_45M, Sig_8_54M, Sig_8_67M, Sig_8_76M, Sig_16_02M, Sig_16_20M, Sig_16_46M, Sig_16_64M, Sig_32_04M, Sig_32_40M});

  flopenrc #(5) CtrlReg(clk, reset, FlushM, ~StallM, {SEW, MulSelect}, {SEWM, MulSelectM});

  // Memory stage: adder tree
  // The [0][0] block is unsigned whenever the sum is used, and the [1][1] block fills the top bits,
  // so only the off-diagonal blocks need sign extension.
  assign Prod_16_00M = {16'b0, Prod_8_00M} + {{8{Sig_8_01M & Prod_8_01M[15]}}, Prod_8_01M, 8'b0}
                     + {{8{Sig_8_10M & Prod_8_10M[15]}}, Prod_8_10M, 8'b0} + {Prod_8_11M, 16'b0};
  assign Prod_16_22M = {16'b0, Prod_8_22M} + {{8{Sig_8_23M & Prod_8_23M[15]}}, Prod_8_23M, 8'b0}
                     + {{8{Sig_8_32M & Prod_8_32M[15]}}, Prod_8_32M, 8'b0} + {Prod_8_33M, 16'b0};
  assign Prod_16_44M = {16'b0, Prod_8_44M} + {{8{Sig_8_45M & Prod_8_45M[15]}}, Prod_8_45M, 8'b0}
                     + {{8{Sig_8_54M & Prod_8_54M[15]}}, Prod_8_54M, 8'b0} + {Prod_8_55M, 16'b0};
  assign Prod_16_66M = {16'b0, Prod_8_66M} + {{8{Sig_8_67M & Prod_8_67M[15]}}, Prod_8_67M, 8'b0}
                     + {{8{Sig_8_76M & Prod_8_76M[15]}}, Prod_8_76M, 8'b0} + {Prod_8_77M, 16'b0};

  assign Prod_32_00M = {32'b0, Prod_16_00M} + {{16{Sig_16_02M & Prod_16_02M[31]}}, Prod_16_02M, 16'b0}
                     + {{16{Sig_16_20M & Prod_16_20M[31]}}, Prod_16_20M, 16'b0} + {Prod_16_22M, 32'b0};
  assign Prod_32_44M = {32'b0, Prod_16_44M} + {{16{Sig_16_46M & Prod_16_46M[31]}}, Prod_16_46M, 16'b0}
                     + {{16{Sig_16_64M & Prod_16_64M[31]}}, Prod_16_64M, 16'b0} + {Prod_16_66M, 32'b0};

  assign Prod_64_00M = {64'b0, Prod_32_00M} + {{32{Sig_32_04M & Prod_32_04M[63]}}, Prod_32_04M, 32'b0}
                     + {{32{Sig_32_40M & Prod_32_40M[63]}}, Prod_32_40M, 32'b0} + {Prod_32_44M, 64'b0};

  // Full products for widening multiplications
  always_comb
    case (SEWM)
      3'b000:  FullProductM = {Prod_8_77M, Prod_8_66M, Prod_8_55M, Prod_8_44M, Prod_8_33M, Prod_8_22M, Prod_8_11M, Prod_8_00M};
      3'b001:  FullProductM = {Prod_16_66M, Prod_16_44M, Prod_16_22M, Prod_16_00M};
      3'b010:  FullProductM = {Prod_32_44M, Prod_32_00M};
      default: FullProductM = Prod_64_00M;              // 64 (1xx is reserved)
    endcase

  // Single width: vmul or vmulh SEW bits of each element
  always_comb
    case ({SEWM, MulSelectM[0]})
      4'b0000: SingleProductM = {Prod_8_77M[7:0],  Prod_8_66M[7:0],  Prod_8_55M[7:0],  Prod_8_44M[7:0],
                                Prod_8_33M[7:0],  Prod_8_22M[7:0],  Prod_8_11M[7:0],  Prod_8_00M[7:0]};
      4'b0001: SingleProductM = {Prod_8_77M[15:8], Prod_8_66M[15:8], Prod_8_55M[15:8], Prod_8_44M[15:8],
                                Prod_8_33M[15:8], Prod_8_22M[15:8], Prod_8_11M[15:8], Prod_8_00M[15:8]};
      4'b0010: SingleProductM = {Prod_16_66M[15:0],  Prod_16_44M[15:0],  Prod_16_22M[15:0],  Prod_16_00M[15:0]};
      4'b0011: SingleProductM = {Prod_16_66M[31:16], Prod_16_44M[31:16], Prod_16_22M[31:16], Prod_16_00M[31:16]};
      4'b0100: SingleProductM = {Prod_32_44M[31:0],  Prod_32_00M[31:0]};
      4'b0101: SingleProductM = {Prod_32_44M[63:32], Prod_32_00M[63:32]};
      4'b0110: SingleProductM = Prod_64_00M[63:0];
      4'b0111: SingleProductM = Prod_64_00M[127:64];
      default: SingleProductM = '0;                     // 1xx is reserved
    endcase

  // ***TODO: Figure out beat so we can select upper 64 bits of vwmul in one beat and lower 64 bit on th next
  assign Product = MulSelectM[1] ? FullProductM[P.ELEN-1:0] : SingleProductM;

endmodule
