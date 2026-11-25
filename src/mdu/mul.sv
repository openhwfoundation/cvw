///////////////////////////////////////////
// mul.sv
//
// Written:  David Harris David_Harris@hmc.edu 16 February 2021
// Modified: Shreya Sanghai
//
// Purpose: Integer multiplier.
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

module mul #(parameter XLEN) (
  input  logic [XLEN-1:0]     SrcAM, SrcBM,                   // sources A and B, registered into the Memory stage by the IEU
  input  logic [2:0]          Funct3M,                        // type of multiply
  output logic [XLEN*2-1:0]   ProdM                           // double-width product
);

  // Extend each source to XLEN+1 bits, sign-extending the signed ones (both for mulh, A for mulhsu) and
  // zero-extending the unsigned ones (both for mulhu, B for mulhsu).  Then one signed (XLEN+1)x(XLEN+1)
  // multiply gives every flavor.  mul uses only the low half of the product, where the extension does not matter.
  // The whole multiply is in the Memory stage, so it needs no pipeline registers of its own: the IEU already
  // registers both sources into the Memory stage (SrcAM for the privileged unit and FPU, WriteDataM for the LSU).

  logic               SignedAM, SignedBM;                   // source is signed
  logic [XLEN:0]      AM, BM;                               // extended sources
  logic [XLEN*2+1:0]  PM;                                   // full product

  assign SignedAM = ~Funct3M[1] | ~Funct3M[0];              // mul, mulh, mulhsu
  assign SignedBM = ~Funct3M[1];                            // mul, mulh
  assign AM = {SignedAM & SrcAM[XLEN-1], SrcAM};
  assign BM = {SignedBM & SrcBM[XLEN-1], SrcBM};
  assign PM = $signed(AM) * $signed(BM);
  assign ProdM = PM[XLEN*2-1:0];
endmodule
