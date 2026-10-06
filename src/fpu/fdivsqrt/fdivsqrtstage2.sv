///////////////////////////////////////////
// fdivsqrtstage2.sv
//
// Written: David_Harris@hmc.edu, me@KatherineParry.com, cturek@hmc.edu
// Modified:13 January 2022
//
// Purpose: radix-2 divsqrt recurrence stage
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////


module fdivsqrtstage2 import cvw::*;  #(parameter cvw_t P) (
  input  logic [P.DIVb+3:0] D, DBar,        // Q4.DIVb
  input  logic [P.DIVb:0]   U, UM,          // U1.DIVb
  input  logic [P.DIVb+3:0] WS, WC,         // Q4.DIVb
  input  logic [P.DIVb+1:0] C,              // Q2.DIVb
  input  logic              SqrtE,
  output logic              un,
  output logic [P.DIVb+1:0] CNext,          // Q2.DIVb
  output logic [P.DIVb:0]   UNext, UMNext,  // U1.DIVb
  output logic [P.DIVb+3:0] WSNext, WCNext  // Q4.DIVb
);

  logic [P.DIVb+3:0]        Dsel;     // Q4.DIVb
  logic                     up, uz;
  logic [P.DIVb+3:0]        F;        // Q4.DIVb
  logic [P.DIVb+3:0]        AddIn;    // Q4.DIVb
  logic [P.DIVb+3:0]        WSA, WCA; // Q4.DIVb

  // Quotient Selection logic
  // Given partial remainder, select digit of +1, 0, or -1 (up, uz, un)
  fdivsqrtuslc2 uslc2(.WS(WS[P.DIVb+3:P.DIVb]), .WC(WC[P.DIVb+3:P.DIVb]), .up, .uz, .un);

  // Sqrt F generation.  Extend C, U, UM to Q4.k
  fdivsqrtfgen2 #(P) fgen2(.up, .uz, .C({2'b11, CNext}), .U({3'b000, U}), .UM({3'b000, UM}), .F);

  // Divisor multiple
  always_comb
    if      (up) Dsel = DBar;
    else if (uz) Dsel = '0;
    else         Dsel = D; // un

  // Residual Update
  //  WSA, WCA = WS + WC - qD
  mux2 #(P.DIVb+4) addinmux(Dsel, F, SqrtE, AddIn);
  csa #(P.DIVb+4) csa(WS, WC, AddIn, up&~SqrtE, WSA, WCA);
  assign WSNext = WSA << 1;
  assign WCNext = WCA << 1;

  // Shift thermometer code C
  assign CNext = {1'b1, C[P.DIVb+1:1]};

  // Unified On-The-Fly Converter to accumulate result
  fdivsqrtuotfc2 #(P) uotfc2(.up, .un, .C(CNext), .U, .UM, .UNext, .UMNext);
endmodule
