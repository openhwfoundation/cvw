///////////////////////////////////////////
// bsr.sv
//
// Written: Jacob Pease jacobpease@protonmail.com,
//          James E. Stine james.stine@okstate.edu
// Created: August 4th, 2025
// Modified:
//
// Purpose: Boundary Scan Register with load on reset
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

module bsr #(parameter WIDTH=8) (
    input logic [WIDTH-1:0]  DataIn,
    input logic             ScanIn,
    input logic              ShiftDR,
    input logic              ClockDR,
    input logic              UpdateDR,
    input logic              Mode,
    output logic [WIDTH-1:0] Qout,
    output logic         ScanOut
);
   logic [WIDTH-1:0]         shiftreg;
   logic [WIDTH-1:0]         y;

   always @(posedge ClockDR)
     shiftreg <= ShiftDR ? {ScanIn, shiftreg[WIDTH-1:1]} : DataIn;

   always @(posedge UpdateDR)
     y <= shiftreg;

   assign Qout = Mode ? y : DataIn;
   assign ScanOut = shiftreg[0];
endmodule
