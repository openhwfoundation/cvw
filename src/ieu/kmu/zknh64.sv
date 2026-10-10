///////////////////////////////////////////
// zknh64.sv
//
// Written:  Kelvin Tran kelvin.tran@okstate.edu, James Stine james.stine@okstate.edu 13 February 2024
// Modified: David Harris David_Harris@hmc.edu
//
// Purpose: RV64 Zknh unit for the SHA-256 and SHA-512 hash instructions.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module zknh64 (
  input  logic [63:0] A,
  input  logic [3:0]  ZKNHSelect,
  output logic [63:0] ZKNHResult
);

  logic [31:0]         sha256_32;
  logic [63:0]         sha256res, sha512res;

  sha256 sha256(A[31:0], ZKNHSelect[1:0], sha256_32);                    // 256-bit SHA support: sha256{sig0/sig1/sum0/sum1}
  assign sha256res = {{32{sha256_32[31]}}, sha256_32};                   // sign-extend 256-bit result from 32 to 64 bits
  sha512_64 sha512(A, ZKNHSelect[1:0], sha512res);                       // 512-bit SHA support: sha512{sig0/sig1/sum0/sum1}
  mux2 #(64) resultmux(sha256res, sha512res, ZKNHSelect[3], ZKNHResult); // SHA256 vs. SHA512 result mux
endmodule
