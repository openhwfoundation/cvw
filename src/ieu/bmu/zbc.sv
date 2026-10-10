///////////////////////////////////////////
// zbc.sv
//
// Written:  Kevin Kim kekim@hmc.edu, Kip Macsai-Goren kmacsaigoren@hmc.edu 2 February 2023
// Modified: David Harris David_Harris@hmc.edu
//
// Purpose: Zbc and Zbkc carry-less multiply unit for clmul, clmulh, and clmulr.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2023-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module zbc import cvw::*; #(parameter cvw_t P) (
  input  logic [P.XLEN-1:0] A, RevA, B,       // Operands
  input  logic [1:0]        Funct3,           // Indicates operation to perform
  output logic [P.XLEN-1:0] ZBCResult);       // ZBC result

  logic [P.XLEN-1:0] ClmulResult, RevClmulResult;
  logic [P.XLEN-1:0] RevB;
  logic [P.XLEN-1:0] X, Y;

  bitreverse #(P.XLEN) brB(B, RevB);

  // choose X = A for clmul, Rev(A) << 1 for clmulh, Rev(A) for clmulr
  // unshifted Rev(A) source is only needed for clmulr in ZBC, not in ZBKC
  if (P.ZBC_SUPPORTED)
    mux3 #(P.XLEN) xmux({RevA[P.XLEN-2:0], {1'b0}}, RevA, A, ~Funct3[1:0], X);
  else
    mux2 #(P.XLEN) xmux(A, {RevA[P.XLEN-2:0], {1'b0}}, Funct3[1], X);

  // choose X = B for clmul, Rev(B) for clmulH
  mux2 #(P.XLEN) ymux(B, RevB, Funct3[1], Y);

  // carry free multiplier
  clmul #(P.XLEN) clm(.X, .Y, .ClmulResult);

  // choose result = rev(X @ Y) for clmulh/clmulr
  bitreverse #(P.XLEN) brClmulResult(ClmulResult, RevClmulResult);
  mux2 #(P.XLEN) zbcresultmux(ClmulResult, RevClmulResult, Funct3[1], ZBCResult);
endmodule
