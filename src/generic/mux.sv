///////////////////////////////////////////
// mux.sv
//
// Written:  David Harris David_Harris@hmc.edu 9 January 2021
// Modified: James Stine
//
// Purpose: 2- through 7-input multiplexers.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

/* verilator lint_off DECLFILENAME */

module mux2 #(parameter WIDTH = 8) (
  input  logic [WIDTH-1:0] d0, d1, // Data inputs
  input  logic             s,      // Select
  output logic [WIDTH-1:0] y);     // Output

  assign y = s ? d1 : d0;
endmodule

module mux3 #(parameter WIDTH = 8) (
  input  logic [WIDTH-1:0] d0, d1, d2, // Data inputs
  input  logic [1:0]       s,          // Select
  output logic [WIDTH-1:0] y);         // Output

  assign y = s[1] ? d2 : (s[0] ? d1 : d0); // exclusion-tag: mux3
endmodule

module mux4 #(parameter WIDTH = 8) (
  input  logic [WIDTH-1:0] d0, d1, d2, d3, // Data inputs
  input  logic [1:0]       s,              // Select
  output logic [WIDTH-1:0] y);             // Output

  assign y = s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0);
endmodule

module mux5 #(parameter WIDTH = 8) (
  input  logic [WIDTH-1:0] d0, d1, d2, d3, d4, // Data inputs
  input  logic [2:0]       s,                  // Select
  output logic [WIDTH-1:0] y);                 // Output

  assign y = s[2] ? d4 : (s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0));
endmodule

/* verilator lint_on DECLFILENAME */
