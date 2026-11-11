///////////////////////////////////////////
// valu.sv
//
// Written: Rose Thompson rose@rosethompson.net
// Created: 10 Sept 2026
// Modified: 10 Sept 2026
//
// Purpose: RISC-V Vector Arithmetic/Logic Unit
//
// Documentation: RISC-V System on Chip Design Volume 2
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
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

module valu import cvw::*; #(parameter cvw_t P)
  (
   input logic [P.ELEN-1:0] A, B,
   input logic [2:0] VALUSelect,
   input logic VSub,
   output logic [P.ELEN-1:0] VALUResult
   );

  logic [P.ELEN-1:0] AddResult, AndResult, OrResult;
  logic [P.ELEN-1:0] CondInvA;

  assign CondInvA = VSub ? ~A : A;
  assign AddResult = B + CondInvA + {{(P.ELEN-1){1'b0}}, VSub};
  assign AndResult = A & B;
  assign OrResult = A | B;

  always_comb
    case (VALUSelect)
      3'b000: VALUResult = AddResult;
      3'b011: VALUResult = OrResult;
      3'b101: VALUResult = AndResult;
      default: VALUResult = AddResult;
    endcase



endmodule
