///////////////////////////////////////////
// vmulblock.sv
//
// Written: Angela Zheng angela20061015@gmail.com
// Created: 16 Nov 2026
// Modified: 16 Nov 2026
//
// Purpose: Signed/unsigned multiplier block for the vector multiply unit
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


module vmulblock #(parameter XLEN = 8) (
  input  logic [XLEN-1:0]     A, B,                           // multiplier operands
  input  logic [1:0]          Signed,                         // 00 u*u, 10 s*u (A signed), 11 s*s
  output logic [XLEN*2-1:0]   PP1E, PP2E, PP3E, PP4E          // partial products; their sum mod 2^(2*XLEN) is A*B
);

  // Number systems
  // Let A' = sum(i=0, XLEN-2, A[i]*2^i)
  // Unsigned: A = A' + A[XLEN-1]*2^(XLEN-1)
  // Signed:   A = A' - A[XLEN-1]*2^(XLEN-1)

  // Multiplication: A*B
  // Let P' = A' * B'
  //     PA = (B' * A[XLEN-1])
  //     PB = (A' * B[XLEN-1])
  //     PP = A[XLEN-1] * B[XLEN-1]
  // Signed * Signed     = P' + (-PB - PA)*2^(XLEN-1) + PP*2^(2XLEN-2)
  // Signed * Unsigned   = P' + ( PB - PA)*2^(XLEN-1) - PP*2^(2XLEN-2)
  // Unsigned * Unsigned = P' + ( PA + PB)*2^(XLEN-1) + PP*2^(2XLEN-2)

  logic [XLEN-1:0]    Aprime, Bprime;                       // lower bits of source A and B
  logic               MULH, MULHSU;                         // type of multiply
  logic [XLEN-2:0]    PA, PB;                               // product of msb and lsbs
  logic               PP;                                   // product of msbs

  //////////////////////////////
  // Compute partial products
  //////////////////////////////

  assign Aprime = {1'b0, A[XLEN-2:0]};
  assign Bprime = {1'b0, B[XLEN-2:0]};
  assign PP1E = Aprime * Bprime;
  assign PA = {(XLEN-1){A[XLEN-1]}} & B[XLEN-2:0];
  assign PB = {(XLEN-1){B[XLEN-1]}} & A[XLEN-2:0];
  assign PP = A[XLEN-1] & B[XLEN-1];

  // flavor of multiplication
  assign MULH   = (Signed == 2'b11);
  assign MULHSU = (Signed == 2'b10);

  // Select partial products, handling signed multiplication
  assign PP2E = {2'b00, (MULH | MULHSU) ? ~PA : PA, {(XLEN-1){1'b0}}};
  assign PP3E = {2'b00, (MULH) ? ~PB : PB, {(XLEN-1){1'b0}}};
  // PP4E holds the +/-PP term plus constants (bits 2*XLEN-1 and XLEN or XLEN-1) that complete the
  // two's complement negation of the inverted PA/PB terms, modulo 2^(2*XLEN)
  always_comb
    if (MULH)        PP4E = {1'b1, PP, {(XLEN-3){1'b0}}, 1'b1, {(XLEN){1'b0}}};
    else if (MULHSU) PP4E = {1'b1, ~PP, {(XLEN-2){1'b0}}, 1'b1, {(XLEN-1){1'b0}}};
    else             PP4E = {1'b0, PP, {(XLEN*2-2){1'b0}}};

endmodule
