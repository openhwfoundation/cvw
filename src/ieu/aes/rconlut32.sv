///////////////////////////////////////////
// rconlut32.sv
//
// Written: ryan.swann@okstate.edu, james.stine@okstate.edu
// Created: 20 February 2024
//
// Purpose: rcon lookup for aes64ks1i instruction
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

module rconlut32(
  input  logic [3:0]  rd,
  output logic [31:0] rcon
);

  logic [7:0] rcon8;

  always_comb
    case(rd)
      4'h0 : rcon8 = 8'h01;
      4'h1 : rcon8 = 8'h02;
      4'h2 : rcon8 = 8'h04;
      4'h3 : rcon8 = 8'h08;
      4'h4 : rcon8 = 8'h10;
      4'h5 : rcon8 = 8'h20;
      4'h6 : rcon8 = 8'h40;
      4'h7 : rcon8 = 8'h80;
      4'h8 : rcon8 = 8'h1b;
      4'h9 : rcon8 = 8'h36;
      4'hA : rcon8 = 8'h00;
      default : rcon8 = 8'h00;
    endcase

  assign rcon = {24'b0, rcon8};
endmodule
