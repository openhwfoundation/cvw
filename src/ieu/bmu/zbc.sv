///////////////////////////////////////////
// zbc.sv
//
// Written: Kevin Kim <kekim@hmc.edu> and Kip Macsai-Goren <kmacsaigoren@hmc.edu>
// Created: 2 February 2023
// Modified: 3 March 2023
//
// Purpose: RISC-V ZBC top-level unit
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
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
