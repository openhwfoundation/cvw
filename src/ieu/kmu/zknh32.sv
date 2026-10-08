///////////////////////////////////////////
// zknh32.sv
//
// Written: kelvin.tran@okstate.edu, james.stine@okstate.edu
// Created: 13 February 2024
// Modified: 12 March 2024
//
// Purpose: RISC-V ZKNH 32-Bit top level unit: RV32 NIST Hash
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
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
