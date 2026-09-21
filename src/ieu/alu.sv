///////////////////////////////////////////
// alu.sv
//
// Written: David_Harris@hmc.edu, Sarah.Harris@unlv.edu, kekim@hmc.edu
// Created: 9 January 2021
// Modified: 3 March 2023
//
// Purpose: RISC-V Arithmetic/Logic Unit
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
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

module alu import cvw::*; #(parameter cvw_t P) (
  input  logic [P.XLEN-1:0] A, B,        // Operands
  input  logic              W64, UW64,   // W64/.uw-type instruction
  input  logic              SubArith,    // Subtraction or arithmetic shift
  input  logic [2:0]        ALUSelect,   // ALU mux select signal
  input  logic [3:0]        BSelect,     // Binary encoding of if it's a ZBA_ZBB_ZBC_ZBS instruction
  input  logic [3:0]        ZBBSelect,   // ZBB mux select signal
  input  logic [2:0]        Funct3,      // For BMU decoding
  input  logic [6:0]        Funct7,      // For ZKNE and ZKND computation
  input  logic [4:0]        Rs2E,        // For ZKNE and ZKND computation
  input  logic [2:0]        BALUControl, // ALU Control signals for B instructions in Execute Stage
  input  logic              BMUActive,   // Bit manipulation instruction being executed
  input  logic [1:0]        CZero,       // {czero.nez, czero.eqz} instructions active
  output logic [P.XLEN-1:0] ALUResult,   // ALU result
  output logic [P.XLEN-1:0] Sum);        // Sum of operands

  // CondInvB = ~B when subtracting, B otherwise. Shift = shift result. SLT/U = result of a slt/u instruction.
  // FullResult = ALU result before adjusting for a RV64 w-suffix instruction.
  logic [P.XLEN-1:0] CondMaskInvB, Shift, FullResult, PreALUResult;               // Intermediate Signals
  logic [P.XLEN-1:0] CondMaskB;                                                   // Result of B mask select mux
  logic [P.XLEN-1:0] CondShiftA;                                                  // Result of A shifted select mux
  logic [P.XLEN-1:0] ZeroCondMaskInvB;                                            // B input to AND gate, accounting for czero.* instructions
  logic [P.XLEN-1:0] AndResult;                                                   // AND result
  logic              Carry, Neg;                                                  // Flags: carry out, negative
  logic              LT, LTU;                                                     // Less than, Less than unsigned
  logic              Asign, Bsign;                                                // Sign bits of A, B

  // Addition
  // CondMaskB is B for add/sub, or a masked version of B for certain bit manipulation instructions
  // CondShiftA is A for add/sub or a shifted version of A for shift-and-add BMU instructions
  assign CondMaskInvB = SubArith ? ~CondMaskB : CondMaskB;
  assign {Carry, Sum} = CondShiftA + CondMaskInvB + {{(P.XLEN-1){1'b0}}, SubArith};

  // Zicond block conditionally zeros B
  if (P.ZICOND_SUPPORTED) begin : zicond
    logic  BZero;

    assign BZero = (B == 0); // check if rs2 = 0
    // Create a signal that is 0 when czero.* instruction should clear result
    // If B = 0 for czero.eqz or if B != 0 for czero.nez
    always_comb
      case (CZero)
        2'b01:   ZeroCondMaskInvB = {P.XLEN{~BZero}}; // czero.eqz: kill if B = 0
        2'b10:   ZeroCondMaskInvB = {P.XLEN{BZero}};  // czero.nez: kill if B != 0
        default: ZeroCondMaskInvB = CondMaskInvB;     // otherwise normal behavior
      endcase
  end else assign ZeroCondMaskInvB = CondMaskInvB; // no masking if Zicond is not supported

  // Shifts (configurable for rotation)
  shifter #(P) sh(.A(CondShiftA), .Amt(B[P.LOG_XLEN-1:0]), .Right(Funct3[2]), .W64, .SubArith, .Y(Shift), .Rotate(BALUControl[2]));

  // Condition code flags are based on subtraction output Sum = A-B.
  // Overflow occurs when the numbers being subtracted have the opposite sign
  // and the result has the opposite sign of A.
  // LT is simplified from Overflow = Asign & Bsign & Asign & Neg; LT = Neg ^ Overflow
  assign Neg  = Sum[P.XLEN-1];
  assign Asign = A[P.XLEN-1];
  assign Bsign = B[P.XLEN-1];
  assign LT = Asign & ~Bsign | Asign & Neg | ~Bsign & Neg;
  assign LTU = ~Carry;
  assign AndResult = A & ZeroCondMaskInvB;

  // Select appropriate ALU Result
  always_comb
    case (ALUSelect)
      3'b000: FullResult = Sum;                            // add or sub (including address generation)
      3'b001: FullResult = Shift;                          // sll, sra, or srl
      3'b010: FullResult = {{(P.XLEN-1){1'b0}}, LT};       // slt
      3'b011: FullResult = {{(P.XLEN-1){1'b0}}, LTU};      // sltu
      3'b100: FullResult = A ^ CondMaskInvB;               // xor, xnor, binv
      3'b101: FullResult = (P.ZBS_SUPPORTED) ? {{(P.XLEN-1){1'b0}},{|(AndResult)}} : Shift; // bext (or IEU shift when BMU not supported)
      3'b110: FullResult = A | CondMaskInvB;               // or, orn, bset
      3'b111: FullResult = AndResult;                      // and, bclr, czero.*
    endcase

  // Support RV64I W-type addw/subw/addiw/shifts that discard upper 32 bits and sign-extend 32-bit result to 64 bits
  if (P.XLEN == 64) assign PreALUResult = W64 ? {{32{FullResult[31]}}, FullResult[31:0]} : FullResult;
  else              assign PreALUResult = FullResult;

  // Bit manipulation muxing
  if (P.ZBC_SUPPORTED  | P.ZBS_SUPPORTED  | P.ZBA_SUPPORTED  | P.ZBB_SUPPORTED |
      P.ZBKB_SUPPORTED | P.ZBKC_SUPPORTED | P.ZBKX_SUPPORTED |
      P.ZKND_SUPPORTED | P.ZKNE_SUPPORTED | P.ZKNH_SUPPORTED) begin : bitmanipalu
    bitmanipalu #(P) balu(
      .A, .B, .W64, .UW64, .BSelect, .ZBBSelect, .BMUActive,
      .Funct3, .Funct7, .Rs2E, .LT,.LTU, .BALUControl, .PreALUResult, .FullResult,
      .CondMaskB, .CondShiftA, .ALUResult);
  end else begin
    assign ALUResult = PreALUResult;
    assign CondMaskB = B;
    assign CondShiftA = A;
  end

endmodule
