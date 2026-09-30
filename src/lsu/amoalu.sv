///////////////////////////////////////////
// amoalu.sv
//
// Written: David_Harris@hmc.edu
// Created: 10 March 2021
// Modified: 18 January 2023
//
// Purpose: Performs AMO operations
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

module amoalu import cvw::*;  #(parameter cvw_t P) (
  input  logic [P.XLEN-1:0] ReadDataM,    // LSU's ReadData
  input  logic [P.XLEN-1:0] IHWriteDataM, // LSU's WriteData
  input  logic [6:0]        LSUFunct7M,   // ALU Operation
  input  logic [2:0]        LSUFunct3M,   // Memoy access width
  input  logic              CASMatchM,    // amocas comparison succeeded (sized in the LSU)
  output logic [P.XLEN-1:0] AMOResultM    // ALU output
);

  logic [P.XLEN-1:0] a, b, y;
  logic               lt, cmp, sngd, w64;
  logic               eqB0, ltB0, eqB1, ltB1, eqH1, ltH1; // per-lane compares, always unsigned
  logic               ltu16, ltu32;                       // unsigned compares assembled from the lanes
  logic               lt8, lt16, lt32, lt64;              // compare at each access width
  logic               SelA;                               // result is a (the loaded value) rather than b (rs2)

  // Rename inputs
  assign a = ReadDataM;
  assign b = IHWriteDataM;

  // Share hardware among the four amomin/amomax comparators.  Compare each lane unsigned; only the
  // lane holding the sign bit of the operation's width cares about signedness, and that is applied
  // when the lane results are assembled, so the operands never need extending.
  assign sngd = ~LSUFunct7M[5]; // Funct7[5] = 0 for signed amomin/max
  // operation is narrower than 64 bits, so sign extend the result; funct3 100 is the 128-bit amocas.q
  assign w64 = (LSUFunct3M[1:0] != 2'b11) & ~(P.ZACAS_SUPPORTED & LSUFunct3M[2]);

  comparator #(8)  cmpb0(a[7:0],   b[7:0],   1'b0, {eqB0, ltB0});
  comparator #(8)  cmpb1(a[15:8],  b[15:8],  1'b0, {eqB1, ltB1});
  comparator #(16) cmph1(a[31:16], b[31:16], 1'b0, {eqH1, ltH1});

  // A wider unsigned compare is the upper lane's result, or the lower one when the upper lanes tie.
  // Signed compares differ only when the sign bits disagree, in which case the negative operand is smaller.
  assign ltu16 = ltB1 | (eqB1 & ltB0);
  assign ltu32 = ltH1 | (eqH1 & ltu16);
  assign lt8   = (sngd & (a[7]  ^ b[7]))  ? a[7]  : ltB0;
  assign lt16  = (sngd & (a[15] ^ b[15])) ? a[15] : ltu16;
  assign lt32  = (sngd & (a[31] ^ b[31])) ? a[31] : ltu32;

  if (P.XLEN == 32) begin : comp
    assign lt64 = lt32; // RV32 has no doubleword AMOs
  end else begin : comp
    logic eqW1, ltW1, ltu64;

    comparator #(32) cmpw1(a[63:32], b[63:32], 1'b0, {eqW1, ltW1});
    assign ltu64 = ltW1 | (eqW1 & ltu32);
    assign lt64  = (sngd & (a[63] ^ b[63])) ? a[63] : ltu64;
  end

  // Pick the compare matching the access width.  Without Zabha the byte and halfword cases are
  // don't-cares; lt32 is chosen there as a synthesis optimization so lt8 and lt16 are trimmed.
  always_comb
    case (LSUFunct3M[1:0])
      2'b00:   lt = P.ZABHA_SUPPORTED ? lt8  : lt32; // amo*.b
      2'b01:   lt = P.ZABHA_SUPPORTED ? lt16 : lt32; // amo*.h
      2'b10:   lt = lt32;                            // amo*.w
      default: lt = lt64;                            // amo*.d
    endcase

  assign cmp = lt ^ LSUFunct7M[4]; // flip sense of comparison for maximums

  // One a/b mux serves every comparing operation: amomin/amomax keep the loaded value when the
  // comparison says so, and amocas keeps it when the compare operand did not match.  An unmatched
  // amocas therefore writes the loaded value back, which the spec permits and which leaves the
  // ordinary AMO store path untouched.
  assign SelA = (P.ZACAS_SUPPORTED & (LSUFunct7M[6:2] == 5'b00101)) ? ~CASMatchM : cmp;

  // AMO ALU
  always_comb
    case (LSUFunct7M[6:2])
      5'b00001: y = b;           // amoswap
      5'b00000: y = a + b;       // amoadd
      5'b00100: y = a ^ b;       // amoxor
      5'b01100: y = a & b;       // amoand
      5'b01000: y = a | b;       // amoor
      5'b00101,                  // amocas
      5'b10000,                  // amomin
      5'b10100,                  // amomax
      5'b11000,                  // amominu
      5'b11100: y = SelA ? a : b; // amomaxu
      default:  y = 'x;          // undefined
    endcase

  // sign extend output if necessary for w64
  if (P.XLEN == 32) begin : sext
    assign AMOResultM = y;
  end else begin : sext // P.XLEN = 64
    always_comb
      if (w64) begin // sign-extend word-length operations
        AMOResultM = {{32{y[31]}}, y[31:0]};
      end else begin
        AMOResultM = y;
      end
  end
endmodule
