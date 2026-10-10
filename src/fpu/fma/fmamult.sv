///////////////////////////////////////////
// fmamult.sv
//
// Written:  Katherine Parry me@KatherineParry.com, David Harris David_Harris@hmc.edu 23 June 2021
// Modified:
//
// Purpose: Multiply the FMA input significands.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module fmamult import cvw::*;  #(parameter cvw_t P) (
  input  logic [P.NF:0]     Xm, Ym, // x and y significand
  output logic [2*P.NF+1:0] Pm      // product's significand
);

  assign Pm = Xm * Ym;
endmodule
