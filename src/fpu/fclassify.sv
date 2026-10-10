///////////////////////////////////////////
// fclassivy.sv
//
// Written: me@KatherineParry.com
// Modified: 7/5/2022
//
// Purpose: Floating-point classify unit
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module fclassify import cvw::*;  #(parameter cvw_t P) (
  input  logic                Xs,         // sign bit
  input  logic                XNaN,       // is NaN
  input  logic                XSNaN,      // is signaling NaN
  input  logic                XSubnorm,   // is Subnormal
  input  logic                XZero,      // is zero
  input  logic                XInf,       // is infinity
  output logic [P.XLEN-1:0]   ClassRes    // classify result
);

  logic PInf, PZero, PNorm, PSubnorm;     // is the input a positive infinity/zero/normal/subnormal
  logic NInf, NZero, NNorm, NSubnorm;     // is the input a negative infinity/zero/normal/subnormal
  logic XNorm;                            // is the input normal

  // determine the sub categories
  assign XNorm= ~(XNaN | XInf| XSubnorm| XZero);
  assign PInf = ~Xs&XInf;
  assign NInf = Xs&XInf;
  assign PNorm = ~Xs&XNorm;
  assign NNorm = Xs&XNorm;
  assign PSubnorm = ~Xs&XSubnorm;
  assign NSubnorm = Xs&XSubnorm;
  assign PZero = ~Xs&XZero;
  assign NZero = Xs&XZero;

  // determine sub category and combine into the result
  //  bit 0 - -Inf
  //  bit 1 - -Norm
  //  bit 2 - -Subnorm
  //  bit 3 - -Zero
  //  bit 4 - +Zero
  //  bit 5 - +Subnorm
  //  bit 6 - +Norm
  //  bit 7 - +Inf
  //  bit 8 - signaling NaN
  //  bit 9 - quiet NaN
  assign ClassRes = {{P.XLEN-10{1'b0}}, XNaN&~XSNaN, XSNaN, PInf, PNorm, PSubnorm, PZero, NZero, NSubnorm, NNorm, NInf};

endmodule
