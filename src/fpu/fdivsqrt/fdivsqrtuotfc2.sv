///////////////////////////////////////////
// fdivsqrtuotfc2.sv
//
// Written:  Katherine Parry me@KatherineParry.com, Cedar Turek cturek@hmc.edu 15 July 2022
// Modified: David Harris
//
// Purpose: Radix-2 on-the-fly quotient/root converter.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2022-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////
// Unified OTFC, Radix 2 //
///////////////////////////////
module fdivsqrtuotfc2 import cvw::*; #(parameter cvw_t P) (
  input  logic              up, un,           // Result digit is +1 or -1
  input  logic [P.DIVb+1:0] C,                // Digit position marker (Q2.DIVb)
  input  logic [P.DIVb:0]   U, UM,            // Partial result and partial result minus 1 ulp (U1.DIVb); UM starts negative, but still gives the right answer
  output logic [P.DIVb:0]   UNext, UMNext     // Next partial result and next partial result minus 1 ulp (U1.DIVb)
);
  //  The on-the-fly converter transfers the divsqrt
  //  bits to the quotient as they come.
  logic [P.DIVb:0] K;                         // U1.DIVb one-hot

  assign K = (C[P.DIVb:0] & ~(C[P.DIVb:0] << 1)); // Thermometer to one hot encoding

  always_comb begin
    if (up) begin
      UNext  = U | K;
      UMNext = U;
    end else if (un) begin
      UNext  = UM | K;
      UMNext = UM;
    end else begin // If up and un are not true, then uz is
      UNext  = U;
      UMNext = UM | K;
    end
  end
endmodule
