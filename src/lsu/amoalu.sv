///////////////////////////////////////////
// amoalu.sv
//
// Written:  David Harris David_Harris@hmc.edu 10 March 2021
// Modified:
//
// Purpose: AMO ALU.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module amoalu import cvw::*;  #(parameter cvw_t P, parameter bit ZABHA_SUPPORTED = 0) (
  input  logic [P.XLEN-1:0] ReadDataM,    // LSU's ReadData
  input  logic [P.XLEN-1:0] IHWriteDataM, // LSU's WriteData
  input  logic [6:0]        LSUFunct7M,   // ALU Operation
  input  logic [2:0]        LSUFunct3M,   // Memory access width
  output logic [P.XLEN-1:0] AMOResultM    // ALU output
);

  logic [P.XLEN-1:0] a, b, y;
  logic              ltAMO, lt, cmp, sngd, sngd32, eq32, lt32, w64;

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

  // Optional narrow comparisons use the operand's sign bit, not XLEN's sign bit.
  // Zabha adds byte/halfword comparators and selection logic.
  if (ZABHA_SUPPORTED) begin : byteamo
    logic eq8, lt8, eq16, lt16;
    comparator #(8) cmp8(a[7:0], b[7:0], sngd, {eq8, lt8});
    comparator #(16) cmp16(a[15:0], b[15:0], sngd, {eq16, lt16});
    mux4 #(1) ltMux(lt8, lt16, lt, lt, LSUFunct3M[1:0], ltAMO);
  end else begin : wordamo
    assign ltAMO = lt;
  end

  assign cmp = ltAMO ^ LSUFunct7M[4]; // flip sense of comparison for maximums

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

  // Only the low operand-width bits are stored; subwordwrite replicates those bits.
  // Register writeback uses the separately formatted OLD memory value in the LSU.
  assign AMOResultM = y;
endmodule
