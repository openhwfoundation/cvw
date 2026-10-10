///////////////////////////////////////////
// resultsign.sv
//
// Written:  Katherine Parry me@KatherineParry.com 13 June 2022
// Modified:
//
// Purpose: Compute the FMA result sign, including the sign of exact zero results.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2022-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module resultsign(
  input  logic [2:0]  Frm,        // rounding mode
  input  logic        FmaOp,      // is the operation an Fma
  input  logic        Mult,       // is the fma operation multiply
  input  logic        ZInf,       // is Z infinity
  input  logic        InfIn,      // are any of the inputs infinity
  input  logic        FmaSZero,   // is the fma sum zero
  input  logic        Ms,         // normalized result sign
  input  logic        FmaPs,      // product's sign
  input  logic        FmaAs,      // aligned addend's sign
  input  logic        Guard,      // guard bit for rounding
  input  logic        Round,      // round bit for rounding
  input  logic        Sticky,     // sticky bit for rounding
  output logic        Rs          // result sign
);

  logic Zeros;    // zero result sign
  logic Infs;     // infinity result sign

  // determine the sign for a result of 0
  //  The IEEE754-2019 standard specifies:
  //      - the sign of an exact zero sum (with operands of different signs) should be positive unless rounding toward negative infinity
  //      - when the exact result of an FMA operation is non-zero, but is zero due to rounding, use the sign of the exact result
  //      - if x = +0 or -0 then x+x=x and x-(-x)=x
  //      - the sign of a product is the exclisive or or the opperand's signs
  //  Zero sign will only be selected if:
  //      - P=Z and a cancellation occurs - exact zero
  //      - Z is zero and P is zero - exact zero
  //      - P is killed and Z is zero - Psgn
  //      - Z is killed and P is zero - impossible
  //  Zero sign calculation:
  //      - if a multiply operation is done, then use the products sign(Ps)
  //      - if the zero sum is not exactly zero i.e. Round|Sticky use the sign of the exact result (which is the product's sign)
  //      - if an effective addition occurs (P+A or -P+-A or P--A) then use the product's sign
  assign Zeros = (FmaPs^FmaAs)&~(Round|Guard|Sticky)&~Mult ? Frm[1:0] == 2'b10 : FmaPs;

  // determine the sign of an infinity result
  //  is the result negative
  //      if p - z is the Sum negative
  //      if -p + z is the Sum positive
  //      if -p - z then the Sum is negative
  assign Infs = ZInf ? FmaAs : FmaPs;

  // select the result sign
  always_comb
    if(InfIn&FmaOp)         Rs = Infs;
    else if(FmaSZero&FmaOp) Rs = Zeros;
    else                    Rs = Ms;

endmodule
