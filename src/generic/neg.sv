///////////////////////////////////////////
// neg.sv
//
// Written:  David Harris David_Harris@hmc.edu 28 September 2021
// Modified:
//
// Purpose: Two's complement negator.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module neg #(parameter WIDTH = 8) (
  input  logic [WIDTH-1:0] a,
  output logic [WIDTH-1:0] y);

  assign y = ~a + 1;
endmodule
