///////////////////////////////////////////
// lateok.sv
//
// Written: October 2026
//
// Purpose: Say whether one instruction, 16- or 32-bit, is an operation the late ALU in the Memory
//          stage implements.  Two instances:
//            - issue.sv, on slot 1's raw fetch bits: slot 1 runs late when it reads slot 0's result.
//            - ieu.sv, on slot 0's decompressed InstrD: slot 0 runs late when its operand comes from a
//              load (or another late result) in the bundle ahead.
//
//          The late ALU implements add, sub, the logical operations, shifts and set-less-than, with
//          their RV64 W forms -- but no bit-manipulation, crypto or czero.  Those share the OP/OP-IMM
//          opcodes and are told apart here by funct7 (funct6 for an RV64 shift immediate).  Every
//          compressed ALU format instrfields recognizes is a base operation; recognition also keeps
//          the compressed jumps out.  LUI and AUIPC read no register: their raw rs fields can match a
//          producer only by accident, so admitting them only removes false dependencies -- ieu.sv
//          clears the late bits for an operand that is not a register, and they execute in Execute.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
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

module lateok import cvw::*;  #(parameter cvw_t P) (
  input  logic [31:0] Instr,          // Raw instruction, aligned to bit 0
  input  logic [1:0]  MemRW,          // From instrfields: it uses the load/store unit
  input  logic        IsBranch,       // From instrfields: it is a conditional branch
  input  logic        Recognized,     // From instrfields: a compressed instruction was decoded
  output logic        LateOK          // The late ALU implements it
);

  localparam [6:0] LUI      = 7'b0110111;
  localparam [6:0] AUIPC    = 7'b0010111;
  localparam [6:0] OP       = 7'b0110011;
  localparam [6:0] OP_IMM   = 7'b0010011;
  localparam [6:0] OP_32    = 7'b0111011;   // RV64 only: addw, subw, sllw, srlw, sraw
  localparam [6:0] OP_IMM_32= 7'b0011011;   // RV64 only: addiw, slliw, srliw, sraiw

  logic [2:0] Funct3;
  logic [6:0] Funct7;
  assign Funct3 = Instr[14:12];
  assign Funct7 = Instr[31:25];

  always_comb
    if (~&Instr[1:0]) LateOK = Recognized & ~|MemRW & ~IsBranch;
    else case (Instr[6:0])
      LUI, AUIPC: LateOK = 1'b1;
      OP_IMM:     case (Funct3)
                    3'b001:  LateOK = (Instr[31:26] == 6'b000000);                                    // slli
                    3'b101:  LateOK = (Instr[31:26] == 6'b000000) | (Instr[31:26] == 6'b010000);     // srli, srai
                    default: LateOK = 1'b1;                                                           // addi, slti(u), xori, ori, andi
                  endcase
      OP_IMM_32:  case (Funct3)
                    3'b000:  LateOK = (P.XLEN == 64);                                                 // addiw
                    3'b001:  LateOK = (P.XLEN == 64) & (Funct7 == 7'b0000000);                        // slliw
                    3'b101:  LateOK = (P.XLEN == 64) & ((Funct7 == 7'b0000000) | (Funct7 == 7'b0100000)); // srliw, sraiw
                    default: LateOK = 1'b0;
                  endcase
      // add, sll, slt, sltu, xor, srl, or, and at funct7 = 0; sub and sra at 0100000
      OP:         LateOK = (Funct7 == 7'b0000000) |
                           ((Funct7 == 7'b0100000) & ((Funct3 == 3'b000) | (Funct3 == 3'b101)));
      // addw, sllw, srlw at funct7 = 0; subw, sraw at 0100000
      OP_32:      LateOK = (P.XLEN == 64) &
                           (((Funct7 == 7'b0000000) & ((Funct3 == 3'b000) | (Funct3 == 3'b001) | (Funct3 == 3'b101))) |
                            ((Funct7 == 7'b0100000) & ((Funct3 == 3'b000) | (Funct3 == 3'b101))));
      default:    LateOK = 1'b0;
    endcase
endmodule
