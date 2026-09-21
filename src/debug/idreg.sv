///////////////////////////////////////////
// idreg.sv
//
// Written: Jacob Pease jacobpease@protonmail.com,
//          James E. Stine james.stine@okstate.edu
// Created: August 4th, 2025
// Modified:
//
// Purpose: Internal Data Register
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

module idreg #(parameter WIDTH = 8) (
    input logic             tck, tdi, resetn,
    input logic [WIDTH-1:0] val,
    input logic             ShiftDR, ClockDR,
    output logic            tdo
);
   logic [WIDTH-1:0]        y;

   always @(posedge tck, negedge resetn) begin
      if (~resetn) begin
         y <= val;
      end else if (ClockDR) begin
         y <= ShiftDR ? {tdi, y[WIDTH-1:1]} : val;
      end
   end

   assign tdo = y[0];
endmodule
