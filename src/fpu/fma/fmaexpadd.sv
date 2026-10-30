///////////////////////////////////////////
// fmaexpadd.sv
//
// Written:  Katherine Parry me@KatherineParry.com, David Harris David_Harris@hmc.edu 23 June 2021
// Modified:
//
// Purpose: FMA product exponent.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module fmaexpadd import cvw::*; #(parameter cvw_t P) (
  input  logic [P.NE-1:0]      Xe, Ye,         // X and Y exponents
  input  logic                 XZero, YZero,   // X, Y are zero
  output logic [P.NE+1:0]      Pe              // Product exponent
);

  logic                        PZero;          // is the product zero?

  // kill the exponent if the product is zero - either X or Y is 0
  assign PZero = XZero | YZero;
  assign Pe    = PZero ? '0 : ({2'b0, Xe} + {2'b0, Ye} - {2'b0, (P.NE)'(P.BIAS)});

endmodule
