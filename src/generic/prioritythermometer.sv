///////////////////////////////////////////
// prioritythermometer.sv
//
// Written:  Thomas Fleming tfleming@hmc.edu, Jessica Torrey jtorrey@hmc.edu 7 April 2021
// Modified: Kip Macsai-Goren kmacsaigoren@hmc.edu, David Harris David_Harris@hmc.edu
//
// Purpose: Thermometer code with 1s in all bits below the least significant 1 of the input.
//          Example:  msb           lsb
//                in  01011101010100000
//                out 00000000000011111
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

module prioritythermometer #(parameter N = 8) (
  input  logic  [N-1:0] a,
  output logic  [N-1:0] y
);

  // Carefully crafted so design compiler will synthesize into a fast tree structure
  //  Rather than linear.

  // create thermometer code mask
  genvar i;
  assign y[0] = ~a[0];
  for (i=1; i<N; i++) begin : therm
    assign y[i] = y[i-1] & ~a[i];
  end
endmodule
