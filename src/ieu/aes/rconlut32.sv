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
