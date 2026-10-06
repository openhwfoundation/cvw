///////////////////////////////////////////
// decompress.sv
//
// Written: David_Harris@hmc.edu
// Created: 9 January 2021
// Modified: 18 January 2023
//
// Purpose: Expand 16-bit compressed instructions to 32 bits
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
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


module decompress import cvw::*;  #(parameter cvw_t P) (
  input  logic [31:0] InstrRawD,         // 32-bit instruction or raw compressed 16-bit instruction in bottom half
  output logic [31:0] InstrD,            // Decompressed instruction
  output logic        IllegalCompInstrD  // Invalid decompressed instruction
);

  logic [32:0]        LInstrD; // decompressed instruction with illegal flag in [32]
  logic [15:0]        instr16;
  logic [4:0]         rds1, rs2, rs1p, rs2p, rds1p, rdp;
  logic [11:0]        immCILSP, immCILSPD, immCSS, immCSSD, immCL, immCLD, immCI, immCS, immCSD, immCB, immCIASP, immCIW;
  logic [19:0]        immCJ, immCILUI;
  logic [5:0]         immSH;
  logic [1:0]         op;
  logic               LegalCompInstrD;

  // Extract op and register source/destination fields
  assign instr16 = InstrRawD[15:0]; // instruction is already aligned
  assign op = instr16[1:0];
  assign rds1 = instr16[11:7];
  assign rs2 = instr16[6:2];
  assign rs1p = {2'b01, instr16[9:7]};
  assign rds1p = {2'b01, instr16[9:7]};
  assign rs2p = {2'b01, instr16[4:2]};
  assign rdp = {2'b01, instr16[4:2]};

  // extract compressed immediate formats
  assign immCILSP = {4'b0000, instr16[3:2], instr16[12], instr16[6:4], 2'b00};
  assign immCILSPD = {3'b000, instr16[4:2], instr16[12], instr16[6:5], 3'b000};
  assign immCSS = {4'b0000, instr16[8:7], instr16[12:9], 2'b00};
  assign immCSSD = {3'b000, instr16[9:7], instr16[12:10], 3'b000};
  assign immCL = {5'b0, instr16[5], instr16[12:10], instr16[6], 2'b00};
  assign immCLD = {4'b0, instr16[6:5], instr16[12:10], 3'b000};
  assign immCS = {5'b0, instr16[5], instr16[12:10], instr16[6], 2'b00};
  assign immCSD = {4'b0, instr16[6:5], instr16[12:10], 3'b000};
  assign immCJ = {instr16[12], instr16[8], instr16[10:9], instr16[6], instr16[7], instr16[2], instr16[11], instr16[5:3], {9{instr16[12]}}};
  assign immCB = {{4{instr16[12]}}, instr16[6:5], instr16[2], instr16[11:10], instr16[4:3], instr16[12]};
  assign immCI = {{7{instr16[12]}}, instr16[6:2]};
  assign immCILUI = {{15{instr16[12]}}, instr16[6:2]};                                                    // c.lui
  assign immCIASP = {{3{instr16[12]}}, instr16[4:3], instr16[5], instr16[2], instr16[6], 4'b0000};        // c.addi16sp
  assign immCIW = {2'b00, instr16[10:7], instr16[12:11], instr16[5], instr16[6], 2'b00};
  assign immSH = {instr16[12], instr16[6:2]};                                                             // c. shift instructions: c.srli, c.srai, c.slli

// only for RV128
//      assign immCILSPQ = {2{instr16[5]}, instr16[5:2], instr16[12], instr16[6], 4'b0000};
//      assign immCSSQ = {2{instr16[10]}, instr16[10:7], instr16[12:11], 4'b0000};
//      assign immCLQ = {4{instr16[10]}, instr16[6:5], instr16[12:11], 4'b0000};
//      assign immCSQ = {4{instr16[10]}, instr16[6:5], instr16[12:11], 4'b0000};

  always_comb
    if (op == 2'b11) begin // noncompressed instruction
      LInstrD = {1'b1, InstrRawD};
    end else begin  // convert compressed instruction into uncompressed
      LInstrD = {1'b0, 16'b0, instr16}; // if a legal instruction is not decoded, default to illegal and preserve 16-bit value for xtval
      case ({op, instr16[15:13]})
        5'b00000: if (immCIW != 0)                      LInstrD = {1'b1, immCIW, 5'b00010, 3'b000, rdp, 7'b0010011};                      // c.addi4spn
        5'b00001: if (P.ZCD_SUPPORTED)                  LInstrD = {1'b1, immCLD, rs1p, 3'b011, rdp, 7'b0000111};                          // c.fld
        5'b00010:                                       LInstrD = {1'b1, immCL, rs1p, 3'b010, rdp, 7'b0000011};                           // c.lw
        5'b00011: if (P.XLEN==32) begin
                    if (P.ZCF_SUPPORTED)                LInstrD = {1'b1, immCL, rs1p, 3'b010, rdp, 7'b0000111};                           // c.flw
                  end else                              LInstrD = {1'b1, immCLD, rs1p, 3'b011, rdp, 7'b0000011};                          // c.ld
        5'b00100: if (P.ZCB_SUPPORTED)
                    if (instr16[12:10] == 3'b000)       LInstrD = {1'b1, 10'b0, instr16[5], instr16[6], rs1p, 3'b100, rdp, 7'b0000011};   // c.lbu
                    else if (instr16[12:10] == 3'b001) begin
                      if (instr16[6])                   LInstrD = {1'b1, 10'b0, instr16[5], 1'b0, rs1p, 3'b001, rdp, 7'b0000011};         // c.lh
                      else                              LInstrD = {1'b1, 10'b0, instr16[5], 1'b0, rs1p, 3'b101, rdp, 7'b0000011};         // c.lhu
                    end else if (instr16[12:10] == 3'b010)
                                                        LInstrD = {1'b1, 7'b0, rs2p, rs1p, 3'b000, 3'b000, instr16[5], instr16[6], 7'b0100011}; // c.sb
                    else if (instr16[12:10] == 3'b011 & instr16[6] == 1'b0)
                                                        LInstrD = {1'b1, 7'b0, rs2p, rs1p, 3'b001, 3'b000, instr16[5], 1'b0, 7'b0100011}; // c.sh
        5'b00101: if (P.ZCD_SUPPORTED)                  LInstrD = {1'b1, immCSD[11:5], rs2p, rs1p, 3'b011, immCSD[4:0], 7'b0100111};      // c.fsd
        5'b00110:                                       LInstrD = {1'b1, immCS[11:5], rs2p, rs1p, 3'b010, immCS[4:0], 7'b0100011};        // c.sw
        5'b00111: if (P.XLEN==32) begin
                    if (P.ZCF_SUPPORTED)                LInstrD = {1'b1, immCS[11:5], rs2p, rs1p, 3'b010, immCS[4:0], 7'b0100111};        // c.fsw
                  end else                              LInstrD = {1'b1, immCSD[11:5], rs2p, rs1p, 3'b011, immCSD[4:0], 7'b0100011};      // c.sd
        5'b01000: if (rds1 != 5'b0)
                    if (immCI[5:0] != 0)                LInstrD = {1'b1, immCI, rds1, 3'b000, rds1, 7'b0010011};                          // c.addi
                    else                                LInstrD = {1'b1, 25'b0, 7'b0010011};                                              // c.addi with imm = 0 is a HINT, treated as nop
                  else if (immCI[5:0] == 6'b0)          LInstrD = {1'b1, 25'b0, 7'b0010011};                                              // c.nop = addi x0, x0, 0
                  else                                  LInstrD = {1'b1, 25'b0, 7'b0010011};                                              // c.nop with imm != 0 is a HINT, treated as nop
        5'b01001: if (P.XLEN==32)                       LInstrD = {1'b1, immCJ, 5'b00001, 7'b1101111};                                    // c.jal
                  else if (rds1 != 5'b0)                LInstrD = {1'b1, immCI, rds1, 3'b000, rds1, 7'b0011011};                          // c.addiw
        5'b01010: if (rds1 != 5'b0)                     LInstrD = {1'b1, immCI, 5'b00000, 3'b000, rds1, 7'b0010011};                      // c.li
                  else                                  LInstrD = {1'b1, 25'b0, 7'b0010011};                                              // c.li with rd = 0 is a HINT, treated as nop
        5'b01011: if (rds1 == 5'b00010) begin
                     if (immCIASP[9:4] != 6'b0)         LInstrD = {1'b1, immCIASP, rds1, 3'b000, rds1, 7'b0010011};                       // c.addi16sp
                  end else if (immCILUI[5:0] != 0)
                    if (rds1 != 5'b0)                   LInstrD = {1'b1, immCILUI, rds1, 7'b0110111};                                     // c.lui
                    else                                LInstrD = {1'b1, 25'b0, 7'b0010011};                                              // c.lui with rd = 0, imm!=0 is a HINT, treated as nop
        5'b01100: if (instr16[11:10] == 2'b00) begin
                    if (P.XLEN > 32 | ~immSH[5])        LInstrD = {1'b1, 6'b000000, immSH, rds1p, 3'b101, rds1p, 7'b0010011};             // c.srli; shamt[5] must be 0 in RV32C
                  end else if (instr16[11:10] == 2'b01) begin
                    if (P.XLEN > 32 | ~immSH[5])        LInstrD = {1'b1, 6'b010000, immSH, rds1p, 3'b101, rds1p, 7'b0010011};             // c.srai; shamt[5] must be 0 in RV32C
                  end else if (instr16[11:10] == 2'b10) LInstrD = {1'b1, immCI, rds1p, 3'b111, rds1p, 7'b0010011};                        // c.andi
                  else if (instr16[12:10] == 3'b011) begin
                    if (instr16[6:5] == 2'b00)          LInstrD = {1'b1, 7'b0100000, rs2p, rds1p, 3'b000, rds1p, 7'b0110011};             // c.sub
                    else if (instr16[6:5] == 2'b01)     LInstrD = {1'b1, 7'b0000000, rs2p, rds1p, 3'b100, rds1p, 7'b0110011};             // c.xor
                    else if (instr16[6:5] == 2'b10)     LInstrD = {1'b1, 7'b0000000, rs2p, rds1p, 3'b110, rds1p, 7'b0110011};             // c.or
                    else                                LInstrD = {1'b1, 7'b0000000, rs2p, rds1p, 3'b111, rds1p, 7'b0110011};             // c.and
                  end else begin // (instr16[12:10] == 3'b111)
                    if (instr16[6:5] == 2'b00 & P.XLEN > 32)
                                                        LInstrD = {1'b1, 7'b0100000, rs2p, rds1p, 3'b000, rds1p, 7'b0111011};             // c.subw
                    else if (instr16[6:5] == 2'b01 & P.XLEN > 32)
                                                        LInstrD = {1'b1, 7'b0000000, rs2p, rds1p, 3'b000, rds1p, 7'b0111011};             // c.addw
                    else if (instr16[6:2] == 5'b11000 & P.ZCB_SUPPORTED)
                                                        LInstrD = {1'b1, 12'b000011111111, rds1p, 3'b111, rds1p, 7'b0010011};             // c.zext.b = andi rd, rs1, 255
                    else if (instr16[6:2] == 5'b11001 & P.ZCB_SUPPORTED & P.ZBB_SUPPORTED)
                                                        LInstrD = {1'b1, 12'b011000000100, rds1p, 3'b001, rds1p, 7'b0010011};             // c.sext.b
                    else if (instr16[6:2] == 5'b11010 & P.ZCB_SUPPORTED & P.ZBB_SUPPORTED)
                                                        LInstrD = {1'b1, 7'b0000100, 5'b00000, rds1p, 3'b100, rds1p, 3'b011, P.XLEN > 32, 3'b011};  // c.zext.h
                    else if (instr16[6:2] == 5'b11011 & P.ZCB_SUPPORTED & P.ZBB_SUPPORTED)
                                                        LInstrD = {1'b1, 12'b011000000101, rds1p, 3'b001, rds1p, 7'b0010011};             // c.sext.h
                    else if (instr16[6:2] == 5'b11101 & P.ZCB_SUPPORTED)
                                                        LInstrD = {1'b1, 12'b111111111111, rds1p, 3'b100, rds1p, 7'b0010011};             // c.not = xori
                    else if (instr16[6:2] == 5'b11100 & P.ZCB_SUPPORTED & P.ZBA_SUPPORTED & P.XLEN > 32)
                                                        LInstrD = {1'b1, 7'b0000100, 5'b00000, rds1p, 3'b000, rds1p, 7'b0111011};         // c.zext.w = add.uw rd, rs1, 0
                    else if (instr16[6:5] == 2'b10 & P.ZCB_SUPPORTED & P.ZMMUL_SUPPORTED)
                                                        LInstrD = {1'b1, 7'b0000001, rs2p, rds1p, 3'b000, rds1p, 7'b0110011};             // c.mul
                  end
        5'b01101:                                       LInstrD = {1'b1, immCJ, 5'b00000, 7'b1101111}; // c.j
        5'b01110:                                       LInstrD = {1'b1, immCB[11:5], 5'b00000, rs1p, 3'b000, immCB[4:0], 7'b1100011};    // c.beqz
        5'b01111:                                       LInstrD = {1'b1, immCB[11:5], 5'b00000, rs1p, 3'b001, immCB[4:0], 7'b1100011};    // c.bnez
        5'b10000: if (immSH != 0) begin
                    if (P.XLEN > 32 | ~immSH[5]) begin                                                                                    // shamt[5] = 1 is reserved in RV32C
                      if (rds1 != 5'b0)                 LInstrD = {1'b1, 6'b000000, immSH, rds1, 3'b001, rds1, 7'b0010011};               // c.slli
                      else                              LInstrD = {1'b1, 25'b0, 7'b0010011};                                              // c.slli with rd = 0 is a HINT, treated as nop
                    end
                  end else                              LInstrD = {1'b1, 25'b0, 7'b0010011};                                              // c.slli with immm = 0 is a HINT, treated as nop
        5'b10001: if (P.ZCD_SUPPORTED)                  LInstrD = {1'b1, immCILSPD, 5'b00010, 3'b011, rds1, 7'b0000111};                  // c.fldsp
        5'b10010: if (rds1 != 5'b0)                     LInstrD = {1'b1, immCILSP, 5'b00010, 3'b010, rds1, 7'b0000011};                   // c.lwsp
        5'b10011: if (P.XLEN == 32) begin
                    if (P.ZCF_SUPPORTED)                LInstrD = {1'b1, immCILSP, 5'b00010, 3'b010, rds1, 7'b0000111};                   // c.flwsp
                  end else if (rds1 != 5'b0)            LInstrD = {1'b1, immCILSPD, 5'b00010, 3'b011, rds1, 7'b0000011};                  // c.ldsp
        5'b10100: if (instr16[12] == 0)
                    if (rs2 == 5'b00000) begin
                      if (rds1 != 5'b0)                 LInstrD = {1'b1, 7'b0000000, 5'b00000, rds1, 3'b000, 5'b00000, 7'b1100111};       // c.jr
                    end else
                      if (rds1 != 5'b0)                 LInstrD = {1'b1, 7'b0000000, rs2, 5'b00000, 3'b000, rds1, 7'b0110011};            // c.mv
                      else                              LInstrD = {1'b1, 25'b0, 7'b0010011};                                              // c.mv with rd = 0 is a HINT, treated as nop
                  else
                    if (rs2 == 5'b00000) begin
                      if (rds1 == 5'b00000)             LInstrD = {1'b1, 12'b1, 5'b00000, 3'b000, 5'b00000, 7'b1110011};                  // c.ebreak
                      else                              LInstrD = {1'b1, 12'b0, rds1, 3'b000, 5'b00001, 7'b1100111};                      // c.jalr
                    end else
                      if (rds1 != 0)                    LInstrD = {1'b1, 7'b0000000, rs2, rds1, 3'b000, rds1, 7'b0110011};                // c.add
                      else                              LInstrD = {1'b1, 25'b0, 7'b0010011};                                              // c.add with rd = 0 is a HINT, treated as nop, even if it is a C.NTL
        5'b10101: if (P.ZCD_SUPPORTED)                  LInstrD = {1'b1, immCSSD[11:5], rs2, 5'b00010, 3'b011, immCSSD[4:0], 7'b0100111}; // c.fsdsp
        5'b10110:                                       LInstrD = {1'b1, immCSS[11:5], rs2, 5'b00010, 3'b010, immCSS[4:0], 7'b0100011};   // c.swsp
        5'b10111: if (P.XLEN==32) begin
                    if (P.ZCF_SUPPORTED)                LInstrD = {1'b1, immCSS[11:5], rs2, 5'b00010, 3'b010, immCSS[4:0], 7'b0100111};   // c.fswsp
                  end else                              LInstrD = {1'b1, immCSSD[11:5], rs2, 5'b00010, 3'b011, immCSSD[4:0], 7'b0100011}; // c.sdsp
        default: ; // illegal instruction
      endcase
    end

  // extract instruction and illegal from LInstrD
  assign {LegalCompInstrD, InstrD} = LInstrD;
  assign IllegalCompInstrD = ~LegalCompInstrD;

endmodule
