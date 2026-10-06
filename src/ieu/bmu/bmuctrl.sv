///////////////////////////////////////////
// bmuctrl.sv
//
// Written: Kevin Kim <kekim@hmc.edu>, kelvin.tran@okstate.edu
// Created: 16 February 2023
// Modified: 6 March 2023, 9 March 2024
//
// Purpose: Top level bit manipulation instruction decoder
//
// Documentation: RISC-V System on Chip Design
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

module bmuctrl import cvw::*;  #(parameter cvw_t P) (
  input  logic        clk, reset,
  // Decode stage control signals
  input  logic [31:0] InstrD,                  // Instruction in Decode stage
  input  logic        ALUOpD,                  // Regular ALU Operation
  output logic        BRegWriteD,              // Indicates if it is a R type B instruction in Decode Stage
  output logic        BALUSrcBD,               // Indicates if it is an I/IW (non auipc) type B instruction in Decode Stage
  output logic        BW64D,                   // Indicates if it is a W type B instruction in Decode Stage
  output logic        BUW64D,                  // Indicates if it is a .uw type B instruction in Decode Stage
  output logic        BSubArithD,              // TRUE if ext, clr, andn, orn, xnor instruction in Decode Stage
  output logic        IllegalBitmanipInstrD,   // Indicates if it is unrecognized B instruction in Decode Stage
  // Execute stage control signals
  input  logic        StallE, FlushE,          // Stall, flush Execute stage
  output logic [2:0]  ALUSelectD,              // ALU select
  output logic [3:0]  BSelectE,                // Indicates if ZBA_ZBB_ZBC_ZBS instruction in one-hot encoding
  output logic [3:0]  ZBBSelectE,              // ZBB mux select signal
  output logic [2:0]  BALUControlE,            // ALU Control signals for B instructions in Execute Stage
  output logic        BMUActiveE               // Bit manipulation instruction being executed
);

  logic [6:0] OpD;                             // Opcode in Decode stage
  logic [2:0] Funct3D;                         // Funct3 field in Decode stage
  logic [6:0] Funct7D;                         // Funct7 field in Decode stage
  logic [4:0] Rs2D;                            // Rs2 source register in Decode stage
  logic       RotateD;                         // Indicates if rotate instruction in Decode Stage
  logic       MaskD;                           // Indicates if zbs instruction in Decode Stage
  logic       PreShiftD;                       // Indicates if sh1add, sh2add, sh3add instruction in Decode Stage
  logic [2:0] BALUControlD;                    // ALU Control signals for B instructions
  logic [2:0] BALUSelectD;                     // ALU Mux select signal in Decode Stage for BMU operations
  logic       BALUOpD;                         // Indicates if it is an ALU B instruction in Decode Stage
  logic [3:0] BSelectD;                        // Indicates if ZBA_ZBB_ZBC_ZBS instruction in one-hot encoding in Decode stage
  logic [3:0] ZBBSelectD;                      // ZBB mux select signal in Decode stage

  `define BMUCTRLW 21

  logic [`BMUCTRLW-1:0] BMUControlsD;          // Main B Instructions Decoder control signals

  // Extract fields
  assign OpD = InstrD[6:0];
  assign Funct3D = InstrD[14:12];
  assign Funct7D = InstrD[31:25];
  assign Rs2D = InstrD[24:20];

  // Main Instruction Decoder
  always_comb begin
    // BALUSelect_BSelect_ZBBSelect_BRegWrite_BALUSrcB_BW64_BUW64_BALUOp_BSubArithD_RotateD_MaskD_PreShiftD_IllegalBitmanipInstrD
    BMUControlsD = `BMUCTRLW'b000_00_000_0_0_0_0_0_0_0_0_1;  // default: Illegal bmu instruction;
    if (P.ZBA_SUPPORTED) begin
      casez({OpD, Funct7D, Funct3D})
        17'b0110011_0010000_010: BMUControlsD = `BMUCTRLW'b000_0001_0000_1_0_0_0_1_0_0_0_1_0;  // sh1add
        17'b0110011_0010000_100: BMUControlsD = `BMUCTRLW'b000_0001_0000_1_0_0_0_1_0_0_0_1_0;  // sh2add
        17'b0110011_0010000_110: BMUControlsD = `BMUCTRLW'b000_0001_0000_1_0_0_0_1_0_0_0_1_0;  // sh3add
      endcase
      if (P.XLEN==64)
        casez({OpD, Funct7D, Funct3D})
          17'b0111011_0010000_010: BMUControlsD = `BMUCTRLW'b000_0001_0000_1_0_0_1_1_0_0_0_1_0;  // sh1add.uw
          17'b0111011_0010000_100: BMUControlsD = `BMUCTRLW'b000_0001_0000_1_0_0_1_1_0_0_0_1_0;  // sh2add.uw
          17'b0111011_0010000_110: BMUControlsD = `BMUCTRLW'b000_0001_0000_1_0_0_1_1_0_0_0_1_0;  // sh3add.uw
          17'b0111011_0000100_000: BMUControlsD = `BMUCTRLW'b000_0001_0000_1_0_0_1_1_0_0_0_0_0;  // add.uw
          17'b0011011_000010?_001: BMUControlsD = `BMUCTRLW'b001_0001_0000_1_1_0_1_1_0_0_0_0_0;  // slli.uw
        endcase
    end

    if (P.ZBB_SUPPORTED) begin
      casez({OpD, Funct7D, Funct3D})
        17'b0010011_0110000_001: if ((Rs2D[4:1] == 4'b0010))
                                  BMUControlsD = `BMUCTRLW'b000_0010_0001_1_1_0_0_1_0_0_0_0_0;  // sign extend instruction
                                else if ((Rs2D[4:2]==3'b000) & ~(Rs2D[1] & Rs2D[0]))
                                  BMUControlsD = `BMUCTRLW'b000_0010_0000_1_1_0_0_1_0_0_0_0_0;  // count instruction
        17'b0010011_0010100_101: if (Rs2D[4:0] == 5'b00111)
                                 BMUControlsD = `BMUCTRLW'b000_0010_0010_1_1_0_0_1_0_0_0_0_0;  // orc.b
        17'b0110011_0000101_110: BMUControlsD = `BMUCTRLW'b000_0010_0111_1_0_0_0_1_1_0_0_0_0;  // max
        17'b0110011_0000101_111: BMUControlsD = `BMUCTRLW'b000_0010_0111_1_0_0_0_1_1_0_0_0_0;  // maxu
        17'b0110011_0000101_100: BMUControlsD = `BMUCTRLW'b000_0010_0011_1_0_0_0_1_1_0_0_0_0;  // min
        17'b0110011_0000101_101: BMUControlsD = `BMUCTRLW'b000_0010_0011_1_0_0_0_1_1_0_0_0_0;  // minu
      endcase
      if (P.XLEN==32)
        casez({OpD, Funct7D, Funct3D})
          17'b0110011_0000100_100: if (Rs2D == 5'b0) BMUControlsD = `BMUCTRLW'b000_0010_0001_1_1_0_0_1_0_0_0_0_0;  // zexth (rv32)
        endcase
      else if (P.XLEN==64)
        casez({OpD, Funct7D, Funct3D})
          17'b0111011_0000100_100: if (Rs2D == 5'b0) BMUControlsD = `BMUCTRLW'b000_0010_0001_1_0_0_0_1_0_0_0_0_0;  // zexth (rv64)
          17'b0011011_0110000_001: if ((Rs2D[4:2]==3'b000) & ~(Rs2D[1] & Rs2D[0]))
                                   BMUControlsD = `BMUCTRLW'b000_0010_0000_1_1_1_1_0_0_0_0_0_0;  // count word instruction (clzw/ctzw/cpopw)
        endcase
    end

    if (P.ZBC_SUPPORTED)
      casez({OpD, Funct7D, Funct3D})
        17'b0110011_0000101_010: BMUControlsD = `BMUCTRLW'b000_0011_0001_1_0_0_0_1_0_0_0_0_0;  // clmulr
        17'b0110011_0000101_0?1: BMUControlsD = `BMUCTRLW'b000_0011_0000_1_0_0_0_1_0_0_0_0_0;  // clmul/clmulh
      endcase
    if (P.ZBKC_SUPPORTED) begin
      casez({OpD, Funct7D, Funct3D})
        17'b0110011_0000101_0?1: BMUControlsD = `BMUCTRLW'b000_0011_0000_1_0_0_0_1_0_0_0_0_0;  // clmul/clmulh
      endcase
    end

    if (P.ZBS_SUPPORTED) begin // ZBS
      casez({OpD, Funct7D, Funct3D})
        17'b0110011_0100100_001: BMUControlsD = `BMUCTRLW'b111_0001_0000_1_0_0_0_1_1_0_1_0_0;  // bclr
        17'b0110011_0100100_101: BMUControlsD = `BMUCTRLW'b101_0001_0000_1_0_0_0_1_0_0_1_0_0;  // bext
        17'b0110011_0110100_001: BMUControlsD = `BMUCTRLW'b100_0001_0000_1_0_0_0_1_0_0_1_0_0;  // binv
        17'b0110011_0010100_001: BMUControlsD = `BMUCTRLW'b110_0001_0000_1_0_0_0_1_0_0_1_0_0;  // bset
      endcase
      if (P.XLEN==32) // ZBS 64-bit
        casez({OpD, Funct7D, Funct3D})
          17'b0010011_0100100_001: BMUControlsD = `BMUCTRLW'b111_0001_0000_1_1_0_0_1_1_0_1_0_0;  // bclri
          17'b0010011_0100100_101: BMUControlsD = `BMUCTRLW'b101_0001_0000_1_1_0_0_1_0_0_1_0_0;  // bexti
          17'b0010011_0110100_001: BMUControlsD = `BMUCTRLW'b100_0001_0000_1_1_0_0_1_0_0_1_0_0;  // binvi
          17'b0010011_0010100_001: BMUControlsD = `BMUCTRLW'b110_0001_0000_1_1_0_0_1_0_0_1_0_0;  // bseti
        endcase
      else if (P.XLEN==64) // ZBS 64-bit
        casez({OpD, Funct7D, Funct3D})
          17'b0010011_010010?_001: BMUControlsD = `BMUCTRLW'b111_0001_0000_1_1_0_0_1_1_0_1_0_0;  // bclri (rv64)
          17'b0010011_010010?_101: BMUControlsD = `BMUCTRLW'b101_0001_0000_1_1_0_0_1_0_0_1_0_0;  // bexti (rv64)
          17'b0010011_011010?_001: BMUControlsD = `BMUCTRLW'b100_0001_0000_1_1_0_0_1_0_0_1_0_0;  // binvi (rv64)
          17'b0010011_001010?_001: BMUControlsD = `BMUCTRLW'b110_0001_0000_1_1_0_0_1_0_0_1_0_0;  // bseti (rv64)
        endcase
    end
    if (P.ZBB_SUPPORTED | P.ZBS_SUPPORTED) // rv32i/64i shift instructions need BMU ALUSelect when BMU shifter is used
      casez({OpD, Funct7D, Funct3D})
        // variable shifts don't encode shift amount in funct7
        17'b0110011_0000000_001: BMUControlsD = `BMUCTRLW'b001_0000_0000_1_0_0_0_1_0_0_0_0_0;  // sll
        17'b0110011_0?00000_101: BMUControlsD = `BMUCTRLW'b001_0000_0000_1_0_0_0_1_0_0_0_0_0;  // sra, srl
        // Immediate Shifts by more than 32 (Funct7[0]) are only supported in RV64
        17'b0010011_000000?_001: if (P.XLEN == 64 | !Funct7D[0]) BMUControlsD = `BMUCTRLW'b001_0000_0000_1_1_0_0_1_0_0_0_0_0;  // slli
        17'b0010011_0?0000?_101: if (P.XLEN == 64 | !Funct7D[0]) BMUControlsD = `BMUCTRLW'b001_0000_0000_1_1_0_0_1_0_0_0_0_0;  // srai, srli
        // w-type shifts only supported in RV64 and must have Funct7[0] = 0 because the shift amount is < 32
        17'b0111011_0000000_001: if (P.XLEN == 64) BMUControlsD = `BMUCTRLW'b001_0000_0000_1_0_1_0_1_0_0_0_0_0;  // sllw
        17'b0111011_0?00000_101: if (P.XLEN == 64) BMUControlsD = `BMUCTRLW'b001_0000_0000_1_0_1_0_1_0_0_0_0_0;  // sraw, srlw
        17'b0011011_0000000_001: if (P.XLEN == 64) BMUControlsD = `BMUCTRLW'b001_0000_0000_1_1_1_0_1_0_0_0_0_0;  // slliw
        17'b0011011_0?00000_101: if (P.XLEN == 64) BMUControlsD = `BMUCTRLW'b001_0000_0000_1_1_1_0_1_0_0_0_0_0;  // sraiw, srliw
      endcase

    if (P.ZBKB_SUPPORTED) begin // ZBKB Bitmanip
      casez({OpD,Funct7D, Funct3D})
        17'b0110011_0000100_100: BMUControlsD = `BMUCTRLW'b000_0100_0001_1_0_0_0_1_0_0_0_0_0;  // pack
        17'b0110011_0000100_111: BMUControlsD = `BMUCTRLW'b000_0100_0001_1_0_0_0_1_0_0_0_0_0;  // packh
        17'b0010011_0110100_101: if (Rs2D == 5'b00111)
                                 BMUControlsD = `BMUCTRLW'b000_0100_0000_1_1_0_0_1_0_0_0_0_0;  // brev8
      endcase
      if (P.XLEN==32)
        casez({OpD, Funct7D, Funct3D})
          17'b0010011_0000100_001: if (Rs2D == 5'b01111)
                                   BMUControlsD = `BMUCTRLW'b000_0100_0011_1_1_0_0_1_0_0_0_0_0;  //zip
          17'b0010011_0000100_101: if (Rs2D == 5'b01111)
                                   BMUControlsD = `BMUCTRLW'b000_0100_0011_1_1_0_0_1_0_0_0_0_0;  //unzip
        endcase
      else if (P.XLEN==64)
        casez({OpD,Funct7D, Funct3D})
          17'b0111011_0000100_100: BMUControlsD = `BMUCTRLW'b000_0100_0101_1_0_1_0_1_0_0_0_0_0; //packw
        endcase
    end
    if (P.ZBB_SUPPORTED | P.ZBKB_SUPPORTED) begin  // ZBB and ZBKB shared instructions
      casez({OpD, Funct7D, Funct3D})
        17'b0110011_0110000_001: BMUControlsD = `BMUCTRLW'b001_0001_0111_1_0_0_0_1_0_1_0_0_0;  // rol
        17'b0110011_0110000_101: BMUControlsD = `BMUCTRLW'b001_0001_0111_1_0_0_0_1_0_1_0_0_0;  // ror
        17'b0110011_0100000_111: BMUControlsD = `BMUCTRLW'b111_0001_0111_1_0_0_0_1_1_0_0_0_0;  // andn
        17'b0110011_0100000_110: BMUControlsD = `BMUCTRLW'b110_0001_0111_1_0_0_0_1_1_0_0_0_0;  // orn
        17'b0110011_0100000_100: BMUControlsD = `BMUCTRLW'b100_0001_0111_1_0_0_0_1_1_0_0_0_0;  // xnor
        17'b0010011_011010?_101: if ((P.XLEN == 32 ^ Funct7D[0]) & (Rs2D == 5'b11000))
                                 BMUControlsD = `BMUCTRLW'b000_0010_0010_1_1_0_0_1_0_0_0_0_0;  // rev8
      endcase
      if (P.XLEN==32)
        casez({OpD, Funct7D, Funct3D})
          17'b0010011_0110000_101: BMUControlsD = `BMUCTRLW'b001_0000_0111_1_1_0_0_1_0_1_0_0_0;  // rori (rv32)
        endcase
      else if (P.XLEN==64)
        casez({OpD, Funct7D, Funct3D})
          17'b0111011_0110000_001: BMUControlsD = `BMUCTRLW'b001_0000_0111_1_0_1_0_1_0_1_0_0_0;  // rolw
          17'b0111011_0110000_101: BMUControlsD = `BMUCTRLW'b001_0000_0111_1_0_1_0_1_0_1_0_0_0;  // rorw
          17'b0010011_011000?_101: BMUControlsD = `BMUCTRLW'b001_0000_0111_1_1_0_0_1_0_1_0_0_0;  // rori (rv64)
          17'b0011011_0110000_101: BMUControlsD = `BMUCTRLW'b001_0000_0111_1_1_1_0_1_0_1_0_0_0;  // roriw
        endcase
    end

    if (P.ZBKX_SUPPORTED) begin  //ZBKX
      casez({OpD, Funct7D, Funct3D})
        17'b0110011_0010100_100: BMUControlsD = `BMUCTRLW'b000_0110_0000_1_0_0_0_1_0_0_0_0_0;  // xperm8
        17'b0110011_0010100_010: BMUControlsD = `BMUCTRLW'b000_0110_0001_1_0_0_0_1_0_0_0_0_0;  // xperm4
      endcase
    end

    if (P.ZKND_SUPPORTED) begin //ZKND
      if (P.XLEN==32)
        casez({OpD, Funct7D, Funct3D})
          17'b0110011_??10101_000: BMUControlsD = `BMUCTRLW'b000_0111_0100_1_0_0_0_1_0_0_0_0_0;  // aes32dsi - final round decrypt
          17'b0110011_??10111_000: BMUControlsD = `BMUCTRLW'b000_0111_0000_1_0_0_0_1_0_0_0_0_0;  // aes32dsmi - mid round decrypt
        endcase
      else if (P.XLEN==64)
        casez({OpD, Funct7D, Funct3D})
          17'b0110011_0011101_000: BMUControlsD = `BMUCTRLW'b000_0111_0100_1_0_0_0_1_0_0_0_0_0;  // aes64ds - decrypt final round
          17'b0110011_0011111_000: BMUControlsD = `BMUCTRLW'b000_0111_0000_1_0_0_0_1_0_0_0_0_0;  // aes64dsm - decrypt mid round
          17'b0010011_0011000_001: if (Rs2D == 5'b00000)
                                   BMUControlsD = `BMUCTRLW'b000_0111_1000_1_1_0_0_1_0_0_0_0_0;  // aes64im - decrypt keyschdule mixcolumns
        endcase
    end

    if (P.ZKNE_SUPPORTED) begin //ZKNE
      if (P.XLEN==32)
        casez({OpD, Funct7D, Funct3D})
          17'b0110011_??10001_000: BMUControlsD = `BMUCTRLW'b000_0111_0101_1_0_0_0_1_0_0_0_0_0;  // aes32esi - final round encrypt
          17'b0110011_??10011_000: BMUControlsD = `BMUCTRLW'b000_0111_0001_1_0_0_0_1_0_0_0_0_0;  // aes32esmi - mid round encrypt
        endcase
      else if (P.XLEN==64)
        casez({OpD, Funct7D, Funct3D})
          17'b0110011_0011001_000: BMUControlsD = `BMUCTRLW'b000_0111_0101_1_0_0_0_1_0_0_0_0_0;  // aes64es - encrypt final round
          17'b0110011_0011011_000: BMUControlsD = `BMUCTRLW'b000_0111_0001_1_0_0_0_1_0_0_0_0_0;  // aes64esm - encrypt mid round
        endcase
    end

    if ((P.ZKND_SUPPORTED | P.ZKNE_SUPPORTED) & P.XLEN == 64) begin // ZKND and ZKNE shared instructions
      casez({OpD, Funct7D, Funct3D})
        17'b0010011_0011000_001: if (Rs2D[4] == 1'b1 & $unsigned(Rs2D[3:0]) <= 10)
                                   BMUControlsD = `BMUCTRLW'b000_0111_0010_1_0_0_0_1_0_0_0_0_0;  // aes64ks1i - key schedule istr1
          17'b0110011_0111111_000: BMUControlsD = `BMUCTRLW'b000_0111_0011_1_0_0_0_1_0_0_0_0_0;  // aes64ks2 - key schedule istr2
      endcase
    end

    if (P.ZKNH_SUPPORTED) begin // ZKNH
      casez({OpD, Funct7D, Funct3D})
        17'b0010011_0001000_001:
          if      (Rs2D == 5'b00010)   BMUControlsD = `BMUCTRLW'b000_1000_0000_1_0_0_0_1_0_0_0_0_0;  // sha256sig0
          else if (Rs2D == 5'b00011)   BMUControlsD = `BMUCTRLW'b000_1000_0001_1_0_0_0_1_0_0_0_0_0;  // sha256sig1
          else if (Rs2D == 5'b00000)   BMUControlsD = `BMUCTRLW'b000_1000_0010_1_0_0_0_1_0_0_0_0_0;  // sha256sum0
          else if (Rs2D == 5'b00001)   BMUControlsD = `BMUCTRLW'b000_1000_0011_1_0_0_0_1_0_0_0_0_0;  // sha256sum1
      endcase

      if (P.XLEN==32)
        casez({OpD, Funct7D, Funct3D})
          17'b0110011_0101110_000:     BMUControlsD = `BMUCTRLW'b000_1000_1000_1_0_0_0_1_0_0_0_0_0;  // sha512sig0h
          17'b0110011_0101010_000:     BMUControlsD = `BMUCTRLW'b000_1000_1001_1_0_0_0_1_0_0_0_0_0;  // sha512sig0l
          17'b0110011_0101111_000:     BMUControlsD = `BMUCTRLW'b000_1000_1010_1_0_0_0_1_0_0_0_0_0;  // sha512sig1h
          17'b0110011_0101011_000:     BMUControlsD = `BMUCTRLW'b000_1000_1011_1_0_0_0_1_0_0_0_0_0;  // sha512sig1l
          17'b0110011_0101000_000:     BMUControlsD = `BMUCTRLW'b000_1000_1100_1_0_0_0_1_0_0_0_0_0;  // sha512sum0r
          17'b0110011_0101001_000:     BMUControlsD = `BMUCTRLW'b000_1000_1110_1_0_0_0_1_0_0_0_0_0;  // sha512sum1r
        endcase

      else if (P.XLEN==64)
        casez({OpD, Funct7D, Funct3D})
          17'b0010011_0001000_001:
            if      (Rs2D == 5'b00110) BMUControlsD = `BMUCTRLW'b000_1000_1000_1_0_0_0_1_0_0_0_0_0;  // sha512sig0
            else if (Rs2D == 5'b00111) BMUControlsD = `BMUCTRLW'b000_1000_1001_1_0_0_0_1_0_0_0_0_0;  // sha512sig1
            else if (Rs2D == 5'b00100) BMUControlsD = `BMUCTRLW'b000_1000_1010_1_0_0_0_1_0_0_0_0_0;  // sha512sum0
            else if (Rs2D == 5'b00101) BMUControlsD = `BMUCTRLW'b000_1000_1011_1_0_0_0_1_0_0_0_0_0;  // sha512sum1
        endcase
    end
  end

  // Unpack Control Signals
  assign {BALUSelectD, BSelectD, ZBBSelectD, BRegWriteD,BALUSrcBD, BW64D, BUW64D, BALUOpD, BSubArithD, RotateD, MaskD, PreShiftD, IllegalBitmanipInstrD} = BMUControlsD;

  // Pack BALUControl Signals
  assign BALUControlD = {RotateD, MaskD, PreShiftD};

  // Choose ALUSelect brom BMU for BMU operations, Funct3 for IEU operations, or 0 for addition
  assign ALUSelectD = BALUOpD ? BALUSelectD : (ALUOpD ? Funct3D : 3'b000);

  // BMU Execute stage pipieline control register
  flopenrc #(12) controlregBMU(clk, reset, FlushE, ~StallE, {BSelectD, ZBBSelectD, BALUControlD, ~IllegalBitmanipInstrD}, {BSelectE, ZBBSelectE, BALUControlE, BMUActiveE});
endmodule
