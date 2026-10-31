///////////////////////////////////////////
// vlane.sv
//
// Written: eoinoconnell04@gmail.com
// Created: 30 October 2026
// Modified: 30 October 2026
//
// Purpose: vector integer execution unit lane. Currently just the valu adder.
//
// Documentation: RISC-V System on Chip Design Volume 2
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University & Skyworks Solutions Inc.
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

module vlane import cvw::*;  #(parameter cvw_t P) (
  input  logic [P.VPU_INT_BLEN-1:0] SrcA, SrcB,    // lane operands
  input  logic [5:0] Funct6E,
  input  logic [2:0] Funct3E,
  output logic [P.VPU_INT_BLEN-1:0] LaneResult     // lane result
);

  logic [P.VPU_INT_BLEN-1:0] SumE, ProductE;
  logic mul;  // whether the instruction is multiply

  assign mul = (Funct6E == 6'b100101) & (Funct3E[1:0] == 2'b10);

  valu #(P) valu(.A(SrcA), .B(SrcB), .Sum(SumE));

  vmul #(P) vmul(.A(SrcA), .B(SrcB), .Product(ProductE));

  mux2 #(P.VPU_INT_BLEN) resultmux(SumE, ProductE, mul, LaneResult);

endmodule
