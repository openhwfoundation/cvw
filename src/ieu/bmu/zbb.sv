///////////////////////////////////////////
// zbb.sv
//
// Written: Kevin Kim <kekim@hmc.edu> and Kip Macsai-Goren <kmacsaigoren@hmc.edu>
// Created: 2 February 2023
// Modified: March 6 2023
//
// Purpose: RISC-V ZBB top level unit
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

module zbb #(parameter WIDTH=32) (
  input  logic [WIDTH-1:0] A, RevA, B,   // Operands
  input  logic             W64,          // Indicates word operation
  input  logic             LT,           // lt flag
  input  logic             LTU,          // ltu flag
  input  logic             BUnsigned,      // max/min (signed) flag
  input  logic [2:0]       ZBBSelect,    // ZBB Result select signal
  output logic [WIDTH-1:0] ZBBResult);   // ZBB result

  logic LessThan;                        // lt given signed/unsigned
  logic [WIDTH-1:0] CntResult;           // count result
  logic [WIDTH-1:0] MinMaxResult;        // min, max result
  logic [WIDTH-1:0] ByteResult;          // byte results
  logic [WIDTH-1:0] ExtResult;           // sign/zero extend results

  mux2 #(1) ltmux(LT, LTU, BUnsigned , LessThan);
  cnt #(WIDTH) cnt(.A, .RevA, .B(B[1:0]), .W64, .CntResult);
  byteop #(WIDTH) bu(.A, .ByteSelect(B[0]), .ByteResult);
  ext #(WIDTH) ext(.A(A[15:0]), .ExtSelect({~B[2], {B[2] & B[0]}}), .ExtResult);

  // ZBBSelect[2] differentiates between min(u) vs max(u) instruction
  mux2 #(WIDTH) minmaxmux(B, A, ZBBSelect[2]^LessThan, MinMaxResult);

  // ZBB Result select mux
  mux4 #(WIDTH) zbbresultmux(CntResult, ExtResult, ByteResult, MinMaxResult, ZBBSelect[1:0], ZBBResult);
endmodule
