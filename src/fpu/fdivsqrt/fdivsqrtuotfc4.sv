///////////////////////////////////////////
// fdivsqrtuotfc4.sv
//
// Written:  Katherine Parry me@KatherineParry.com, Cedar Turek cturek@hmc.edu 15 July 2022
// Modified: David Harris
//
// Purpose: Radix-4 on-the-fly quotient/root converter.
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

module fdivsqrtuotfc4 import cvw::*;  #(parameter cvw_t P) (
  input  logic [3:0]      udigit,
  input  logic [P.DIVb:0] U, UM,          // U1.DIVb  UM is actually U - 1 ulp and starts negative, but this representation still produces the right answer
  input  logic [P.DIVb:0] C,              // Q1.DIVb
  output logic [P.DIVb:0] UNext, UMNext   // U1.DIVb
);
  //  The on-the-fly converter transfers the square root
  //  bits to the quotient as they come.
  //  Use this otfc for division and square root.

  // C is a thermometer code; K is its lowest 1, the lsb of the current radix-4 digit.
  // OR-ing K, 2K, or 3K into U or UM writes a digit value of 1, 2, or 3.
  logic [P.DIVb:0] K1, K2, K3;            // U1.DIVb
  assign K1 = (C & ~(C << 1));          // K
  assign K2 = ((C << 1) & ~(C << 2));   // 2K
  assign K3 = (C & ~(C << 2));          // 3K

  always_comb begin
    if (udigit[3]) begin            // +2
      UNext  = U | K2;
      UMNext = U | K1;
    end else if (udigit[2]) begin   // +1
      UNext  = U | K1;
      UMNext = U;
    end else if (udigit[1]) begin   // -1
      UNext  = UM | K3;
      UMNext = UM | K2;
    end else if (udigit[0]) begin   // -2
      UNext  = UM | K2;
      UMNext = UM | K1;
    end else begin                  // 0
      UNext  = U;
      UMNext = UM | K3;
    end
  end

endmodule
