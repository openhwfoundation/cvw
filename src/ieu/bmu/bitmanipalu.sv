///////////////////////////////////////////
// bitmanipalu.sv
//
// Written: Kevin Kim <kekim@hmc.edu>, kelvin.tran@okstate.edu
// Created: 23 March 2023
// Modified: 9 March 2024
//
// Purpose: RISC-V Arithmetic/Logic Unit Bit-Manipulation Extension and K extension
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
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

module bitmanipalu import cvw::*; #(parameter cvw_t P) (
  input logic [P.XLEN-1:0] A, B,                    // Operands
  input logic              W64, UW64,               // W64/.uw-type instruction
  input logic [3:0]        BSelect,                 // Binary encoding of if it's a ZBA_ZBB_ZBC_ZBS instruction
  input logic [3:0]        ZBBSelect,               // ZBB mux select signal
  input logic [2:0]        Funct3,                  // Funct3 field of opcode indicates operation to perform
  input logic [6:0]        Funct7,                  // Funct7 field for ZKND and ZKNE operations
  input logic [4:0]        Rs2E,                    // Register source2 for RNUM of ZKNE/ZKND
  input logic              LT,                      // less than flag
  input logic              LTU,                     // less than unsigned flag
  input logic [2:0]        BALUControl,             // ALU Control signals for B instructions in Execute Stage
  input logic              BMUActive,               // Bit manipulation instruction being executed
  input logic  [P.XLEN-1:0] PreALUResult,           // PreALUResult signals
  input  logic [P.XLEN-1:0] FullResult,             // FullResult signals
  output logic [P.XLEN-1:0] CondMaskB,              // B is conditionally masked for ZBS instructions
  output logic [P.XLEN-1:0] CondShiftA,             // A is conditionally shifted for ShAdd instructions
  output logic [P.XLEN-1:0] ALUResult);             // Result

  logic [P.XLEN-1:0]        ZBBResult;               // ZBB Result
  logic [P.XLEN-1:0]        ZBCResult;               // ZBC Result
  logic [P.XLEN-1:0]        ZBKBResult;              // ZBKB Result
  logic [P.XLEN-1:0]        ZBKXResult;              // ZBKX Result
  logic [P.XLEN-1:0]        ZKNHResult;              // ZKNH Result
  logic [P.XLEN-1:0]        ZKNDEResult;             // ZKNE or ZKND Result
  logic [P.XLEN-1:0]        MaskB;                   // BitMask of B
  logic [P.XLEN-1:0]        RevA;                    // Bit-reversed A
  logic                     Mask;                    // Indicates if it is ZBS instruction
  logic                     PreShift;                // Indicates if it is sh1add, sh2add, sh3add instruction
  logic [1:0]               PreShiftAmt;             // Amount to Pre-Shift A
  logic [P.XLEN-1:0]        CondZextA;               // A Conditional Extend Intermediary Signal
  logic [P.XLEN-1:0]        ABMU, BBMU;              // Gated data inputs to reduce BMU activity

  // gate data inputs to BMU to only operate when BMU is active
  assign ABMU = A & {P.XLEN{BMUActive}};
  assign BBMU = B & {P.XLEN{BMUActive}};

  // Extract control signals from bitmanip ALUControl.
  assign {Mask, PreShift} = BALUControl[1:0];

  // Mask Generation Mux
  if (P.ZBS_SUPPORTED) begin : zbsdec
    decoder #($clog2(P.XLEN)) maskgen(BBMU[$clog2(P.XLEN)-1:0], MaskB);
    mux2 #(P.XLEN) maskmux(B, MaskB, Mask, CondMaskB);
  end else assign CondMaskB = B;

  // 0-3 bit Pre-Shift Mux
  if (P.ZBA_SUPPORTED) begin : zbapreshift
    if (P.XLEN == 64) begin
      mux2 #(64) zextmux(A, {{32{1'b0}}, A[31:0]}, UW64, CondZextA);
    end else assign CondZextA = A;
    assign PreShiftAmt = Funct3[2:1] & {2{PreShift}};
    assign CondShiftA = CondZextA << (PreShiftAmt);
  end else begin
    assign PreShiftAmt = 2'b0;
    assign CondShiftA = A;
  end

  // Bit reverse needed for some ZBB, ZBC instructions
  if (P.ZBC_SUPPORTED | P.ZBKC_SUPPORTED | P.ZBB_SUPPORTED) begin : bitreverse
    bitreverse #(P.XLEN) brA(.A(ABMU), .RevA);
  end

  // ZBC and ZBKCUnit
  if (P.ZBC_SUPPORTED | P.ZBKC_SUPPORTED) begin : zbc
    zbc #(P) ZBC(.A(ABMU), .RevA, .B(BBMU), .Funct3(Funct3[1:0]), .ZBCResult);
  end else assign ZBCResult = '0;

  // ZBB Unit
  if (P.ZBB_SUPPORTED) begin : zbb
    zbb #(P.XLEN) ZBB(.A(ABMU), .RevA, .B(BBMU), .W64, .LT, .LTU, .BUnsigned(Funct3[0]), .ZBBSelect(ZBBSelect[2:0]), .ZBBResult);
  end else if (P.ZBKB_SUPPORTED) begin : zbkbonly // only needs rev8 portion
    genvar i;
    for (i=0;i<P.XLEN;i+=8) begin : byteloop
      assign ZBBResult[P.XLEN-i-1:P.XLEN-i-8] = ABMU[i+7:i]; // Rev8
    end
  end else assign ZBBResult = '0;

  // ZBKB Unit
  if (P.ZBKB_SUPPORTED) begin : zbkb
    zbkb #(P.XLEN) ZBKB(.A(ABMU), .B(BBMU[P.XLEN/2-1:0]), .Funct3, .ZBKBSelect(ZBBSelect[2:0]), .ZBKBResult);
  end else assign ZBKBResult = '0;

  // ZBKX Unit
  if (P.ZBKX_SUPPORTED) begin : zbkx
    zbkx #(P.XLEN) ZBKX(.A(ABMU), .B(BBMU), .ZBKXSelect(ZBBSelect[0]), .ZBKXResult);
  end else assign ZBKXResult = '0;

  // ZKND and ZKNE AES decryption and encryption
  if (P.ZKND_SUPPORTED | P.ZKNE_SUPPORTED) begin : zknde
    if (P.XLEN == 32) zknde32 #(P) ZKN32(.A(ABMU), .B(BBMU), .bs(Funct7[6:5]), .round(Rs2E[3:0]), .ZKNSelect(ZBBSelect[3:0]), .ZKNDEResult);
    else              zknde64 #(P) ZKN64(.A(ABMU), .B(BBMU),                   .round(Rs2E[3:0]), .ZKNSelect(ZBBSelect[3:0]), .ZKNDEResult);
  end else assign ZKNDEResult = '0;

  // ZKNH Unit
  if (P.ZKNH_SUPPORTED) begin : zknh
    if (P.XLEN == 32) zknh32 ZKNH32(.A(ABMU), .B(BBMU), .ZKNHSelect(ZBBSelect), .ZKNHResult(ZKNHResult));
    else              zknh64 ZKNH64(.A(ABMU),           .ZKNHSelect(ZBBSelect), .ZKNHResult(ZKNHResult));
  end else assign ZKNHResult = '0;

  // Result Select Mux
  always_comb
    case (BSelect)
      // 0000: ALU, 0001: ZBA/ZBS, 0010: ZBB, 0011: ZBC/ZBKC, 0100: ZBKB, 0110: ZBKX
      // 0111: ZKND, 1000: ZKNE, 1001: ZKNH, 1010: ZKSED, 1011: ZKSH...
      4'b0000: ALUResult = PreALUResult;
      4'b0001: ALUResult = FullResult;  // NOTE: don't use ALUResult since ZBA/ZBS doesnt sext the MSB of RH word
      4'b0010: ALUResult = ZBBResult;
      4'b0011: ALUResult = ZBCResult;
      4'b0100: ALUResult = ZBKBResult;
      4'b0110: ALUResult = ZBKXResult;
      4'b0111: ALUResult = ZKNDEResult;
      4'b1000: ALUResult = ZKNHResult;
      default: ALUResult = PreALUResult;
    endcase
endmodule
