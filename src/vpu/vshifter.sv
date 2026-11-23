///////////////////////////////////////////
// vshifter.sv
//
// Written: Angela Zheng angela20061015@gmail.com
// Created: 7 Nov 2026
// Modified: 20 Nov 2026
//
// Purpose: RISC-V Vector Shifter Unit: vsll, vsrl, vsra with subword parallelism
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

module vshifter import cvw::*; #(parameter cvw_t P) (
  input  logic [P.ELEN-1:0]   A,                  // vs2 data
  input  logic [P.ELEN-1:0]   B,                  // shift amount of each element in its low bits
  input  logic [2:0]          SEW,
  input  logic                Right, SubArith,    // shift right, arithmetic shift
  output logic [P.ELEN-1:0]   Y
);

  // ***written for ELEN = 64
  // Funnel shifter: every element gets a 2*SEW-bit slot in Z, and every element shifts its slot right by its
  // own amount.  A left shift by k is a right shift by SEW-1-k of the element placed SEW-1 bits higher.

  logic           Left;
  logic [63:0]    Amt;                            // shift amount byte of each element, repeated in every byte
  logic [127:0]   Z, Z32, Z16, Z8, Z4, Z2, ZShift;
  logic           C32;
  logic [1:0]     C16;
  logic [3:0]     C8;
  logic [7:0]     C4, C2, C1;

  assign Left = ~Right;

  // Amt
  // Each element's amount is cut to log2(SEW) bits, inverted for a left shift (SEW-1-k), and copied into every
  // byte of the element according to Table 22 in MAS. Bits above log2(SEW) are hard wired to 0.
  always_comb
    case (SEW)
      3'b000:  Amt = {5'b0, B[58:56] ^ {3{Left}}, 5'b0, B[50:48] ^ {3{Left}}, 5'b0, B[42:40] ^ {3{Left}},
                      5'b0, B[34:32] ^ {3{Left}}, 5'b0, B[26:24] ^ {3{Left}}, 5'b0, B[18:16] ^ {3{Left}},
                      5'b0, B[10:8]  ^ {3{Left}}, 5'b0, B[2:0]   ^ {3{Left}}};
      3'b001:  Amt = {{2{4'b0, B[51:48] ^ {4{Left}}}}, {2{4'b0, B[35:32] ^ {4{Left}}}},
                      {2{4'b0, B[19:16] ^ {4{Left}}}}, {2{4'b0, B[3:0]   ^ {4{Left}}}}};
      3'b010:  Amt = {{4{3'b0, B[36:32] ^ {5{Left}}}}, {4{3'b0, B[4:0] ^ {5{Left}}}}};
      default: Amt = {8{2'b0, B[5:0] ^ {6{Left}}}};      // 64 (1xx is reserved)
    endcase

  // Control signal of each shift stage mux
  assign C32 = Amt[5];
  assign C16 = {Amt[36], Amt[4]};
  assign C8  = {Amt[51], Amt[35], Amt[19], Amt[3]};
  assign C4  = {Amt[58], Amt[50], Amt[42], Amt[34], Amt[26], Amt[18], Amt[10], Amt[2]};
  assign C2  = {Amt[57], Amt[49], Amt[41], Amt[33], Amt[25], Amt[17], Amt[9],  Amt[1]};
  assign C1  = {Amt[56], Amt[48], Amt[40], Amt[32], Amt[24], Amt[16], Amt[8],  Amt[0]};

  // Source Generator
  // Right shift: SEW zeros (vsrl) or sign bits (vsra) above each element shift in from the top
  // Left shift:  one 0, the element, then SEW-1 zeros that shift in from the bottom
  always_comb
    case (SEW)
      3'b000:
        if (Right) Z = {{8{SubArith & A[63]}}, A[63:56], {8{SubArith & A[55]}}, A[55:48],
                        {8{SubArith & A[47]}}, A[47:40], {8{SubArith & A[39]}}, A[39:32],
                        {8{SubArith & A[31]}}, A[31:24], {8{SubArith & A[23]}}, A[23:16],
                        {8{SubArith & A[15]}}, A[15:8],  {8{SubArith & A[7]}},  A[7:0]};
        else       Z = {1'b0, A[63:56], 7'b0, 1'b0, A[55:48], 7'b0, 1'b0, A[47:40], 7'b0, 1'b0, A[39:32], 7'b0,
                        1'b0, A[31:24], 7'b0, 1'b0, A[23:16], 7'b0, 1'b0, A[15:8],  7'b0, 1'b0, A[7:0],   7'b0};
      3'b001:
        if (Right) Z = {{16{SubArith & A[63]}}, A[63:48], {16{SubArith & A[47]}}, A[47:32],
                        {16{SubArith & A[31]}}, A[31:16], {16{SubArith & A[15]}}, A[15:0]};
        else       Z = {1'b0, A[63:48], 15'b0, 1'b0, A[47:32], 15'b0, 1'b0, A[31:16], 15'b0, 1'b0, A[15:0], 15'b0};
      3'b010:
        if (Right) Z = {{32{SubArith & A[63]}}, A[63:32], {32{SubArith & A[31]}}, A[31:0]};
        else       Z = {1'b0, A[63:32], 31'b0, 1'b0, A[31:0], 31'b0};
      default:                                           // 64 (1xx is reserved)
        if (Right) Z = {{64{SubArith & A[63]}}, A};
        else       Z = {1'b0, A, 63'b0};
    endcase

  // Shift stages
  // Each segment of a stage shifts right when its control is 1, taking bits from the segment above.  Bits that
  // cross into a slot from the one above never reach the low SEW bits of the slot.
  // A stage shifts all of Z by its amount, and its mask picks the shifted bits for the segments whose control is 1.
  logic [127:0]   M16, M8, M4, M2, M1;            // control of each stage copied across its segment

  assign M16 = {{64{C16[1]}}, {64{C16[0]}}};
  assign M8  = {{32{C8[3]}}, {32{C8[2]}}, {32{C8[1]}}, {32{C8[0]}}};
  assign M4  = {{16{C4[7]}}, {16{C4[6]}}, {16{C4[5]}}, {16{C4[4]}}, {16{C4[3]}}, {16{C4[2]}}, {16{C4[1]}}, {16{C4[0]}}};
  assign M2  = {{16{C2[7]}}, {16{C2[6]}}, {16{C2[5]}}, {16{C2[4]}}, {16{C2[3]}}, {16{C2[2]}}, {16{C2[1]}}, {16{C2[0]}}};
  assign M1  = {{16{C1[7]}}, {16{C1[6]}}, {16{C1[5]}}, {16{C1[4]}}, {16{C1[3]}}, {16{C1[2]}}, {16{C1[1]}}, {16{C1[0]}}};

  assign Z32    = C32 ? Z >> 32 : Z;
  assign Z16    = (M16 & (Z32 >> 16)) | (~M16 & Z32);
  assign Z8     = (M8  & (Z16 >> 8))  | (~M8  & Z16);
  assign Z4     = (M4  & (Z8  >> 4))  | (~M4  & Z8);
  assign Z2     = (M2  & (Z4  >> 2))  | (~M2  & Z4);
  assign ZShift = (M1  & (Z2  >> 1))  | (~M1  & Z2);

  // Low SEW bits of each element's slot
  always_comb
    case (SEW)
      3'b000:  Y = {ZShift[119:112], ZShift[103:96], ZShift[87:80], ZShift[71:64],
                    ZShift[55:48],   ZShift[39:32],  ZShift[23:16], ZShift[7:0]};
      3'b001:  Y = {ZShift[111:96], ZShift[79:64], ZShift[47:32], ZShift[15:0]};
      3'b010:  Y = {ZShift[95:64], ZShift[31:0]};
      default: Y = ZShift[63:0];                         // 64 (1xx is reserved)
    endcase

endmodule
