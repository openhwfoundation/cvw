///////////////////////////////////////////
// inst_reg.sv
//
// Written: Jacob Pease jacobpease@protonmail.com,
//          James E. Stine james.stine@okstate.edu
// Created: August 22th, 2025
// Modified:
//
// Purpose: Instruction Register (IR)
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-25 Harvey Mudd College & Oklahoma State University
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

module inst_reg #(parameter ADRWIDTH=5) (
   input logic tck,
    input logic                 tdi,
    input logic                 resetn, ShiftIR, CaptureIR, ClockIR, UpdateIR,
    output logic                tdo,
    output logic [ADRWIDTH-1:0] instreg
);
   logic [ADRWIDTH-1:0]    shiftreg;

   always @(posedge tck)
     if (CaptureIR) begin
       shiftreg <= {{(ADRWIDTH - 1){1'b0}},1'b1};
     end else if (ShiftIR) begin
        shiftreg <= {tdi, shiftreg[ADRWIDTH-1:1]};
     end

  always @(posedge tck)
     if (~resetn) instreg <= {{(ADRWIDTH - 1){1'b0}},1'b1};
     else if (UpdateIR) instreg <= shiftreg;

   assign tdo = shiftreg[0];

endmodule
