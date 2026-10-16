///////////////////////////////////////////
// negateintres.sv
//
// Written: me@KatherineParry.com
// Modified: 7/5/2022
//
// Purpose: Negate integer result
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

module negateintres import cvw::*;  #(parameter cvw_t P) (
  input  logic                     Signed,         // is the integer input signed
  input  logic                     Int64,          // is the integer input 64-bits
  input  logic                     Plus1,          // should one be added for rounding?
  input  logic                     Xs,             // X sign
  input  logic [P.NORMSHIFTSZ-1:0] Shifted,        // output from normalization shifter
  output logic [1:0]               CvtNegResMsbs,  // most signigficant bits of possibly negated result
  output logic [P.XLEN+1:0]        CvtNegRes       // possibly negated integer result
);

  logic [P.XLEN+1:0]               CvtPreRes;      // integer result with rounding
  logic [2:0]                      CvtNegResMsbs3; // first three msbs of possibly negated result

  // round and negate the positive res if needed
  assign CvtPreRes = {2'b0, Shifted[P.NORMSHIFTSZ-1:P.NORMSHIFTSZ-P.XLEN]}+{{P.XLEN+1{1'b0}}, Plus1};
  mux2 #(P.XLEN+2) resmux(CvtPreRes, -CvtPreRes, Xs, CvtNegRes);

  // select 2 most significant bits
  mux2 #(3) msb3mux(CvtNegRes[33:31], CvtNegRes[P.XLEN+1:P.XLEN-1], Int64, CvtNegResMsbs3);
  mux2 #(2) msb2mux(CvtNegResMsbs3[2:1], CvtNegResMsbs3[1:0], Signed, CvtNegResMsbs);
endmodule
