///////////////////////////////////////////
// zknh32.sv
//
// Written:  Kelvin Tran kelvin.tran@okstate.edu, James Stine james.stine@okstate.edu 13 February 2024
// Modified:
//
// Purpose: RV32 Zknh unit for the SHA-256 and SHA-512 hash instructions.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module zknh32 (
  input  logic [31:0] A, B,
  input  logic [3:0]  ZKNHSelect,
  output logic [31:0] ZKNHResult
);

  logic [31:0]        sha256res, sha512res;

  sha256 sha256(A, ZKNHSelect[1:0], sha256res);                          // 256-bit SHA support: sha256{sig0/sig1/sum0/sum1}
  sha512_32 sha512(A, B, ZKNHSelect[2:0], sha512res);                    // 512-bit SHA support: sha512{sig0h/sig0l/sig1h/sig1l/sum0r/sum1r}
  mux2 #(32) resultmux(sha256res, sha512res, ZKNHSelect[3], ZKNHResult); // SHA256 vs. SHA512 result mux
endmodule
