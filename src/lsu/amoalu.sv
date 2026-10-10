///////////////////////////////////////////
// amoalu.sv
//
// Written:  David Harris David_Harris@hmc.edu 10 March 2021
// Modified:
//
// Purpose: Computes the result of atomic memory operations (AMOs).
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module amoalu import cvw::*;  #(parameter cvw_t P) (
  input  logic [P.XLEN-1:0] ReadDataM,    // LSU's ReadData
  input  logic [P.XLEN-1:0] IHWriteDataM, // LSU's WriteData
  input  logic [6:0]        LSUFunct7M,   // ALU Operation
  input  logic [2:0]        LSUFunct3M,   // Memoy access width
  output logic [P.XLEN-1:0] AMOResultM    // ALU output
);

  logic [P.XLEN-1:0] a, b, y;
  logic               lt, cmp, sngd, sngd32, eq32, lt32, w64;

  // Rename inputs
  assign a = ReadDataM;
  assign b = IHWriteDataM;

  // Share hardware among the four amomin/amomax comparators
  assign sngd = ~LSUFunct7M[5]; // Funct7[5] = 0 for signed amomin/max
  assign w64 = (LSUFunct3M[1:0] == 2'b10); // operate on bottom 32 bits
  assign sngd32 = sngd & (P.XLEN == 32 | w64); // flip sign in lower 32 bits on 32-bit comparisons only

  comparator #(32) cmp32(a[31:0], b[31:0], sngd32, {eq32, lt32});
  if (P.XLEN == 32) begin
    assign lt = lt32;
  end else begin
    logic equpper, ltupper, lt64;

    comparator #(32) cmpupper(a[63:32], b[63:32], sngd, {equpper, ltupper});
    assign lt64 = ltupper | equpper & lt32;
    assign lt = w64 ? lt32 : lt64;
  end

  assign cmp = lt ^ LSUFunct7M[4]; // flip sense of comparison for maximums

  // AMO ALU
  always_comb
    case (LSUFunct7M[6:2])
      5'b00001: y = b;           // amoswap
      5'b00000: y = a + b;       // amoadd
      5'b00100: y = a ^ b;       // amoxor
      5'b01100: y = a & b;       // amoand
      5'b01000: y = a | b;       // amoor
      5'b10000: y = cmp ? a : b; // amomin
      5'b10100: y = cmp ? a : b; // amomax
      5'b11000: y = cmp ? a : b; // amominu
      5'b11100: y = cmp ? a : b; // amomaxu
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
