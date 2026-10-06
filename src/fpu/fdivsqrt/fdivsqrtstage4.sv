///////////////////////////////////////////
// fdivsqrtstage4.sv
//
// Written: David_Harris@hmc.edu, me@KatherineParry.com, cturek@hmc.edu
// Modified:13 January 2022
//
// Purpose: radix-4 divsqrt recurrence stage
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

module fdivsqrtstage4 import cvw::*;  #(parameter cvw_t P) (
  input  logic [P.DIVb+3:0] D, DBar, D2, DBar2, // Q4.DIVb
  input  logic [P.DIVb:0]   U,UM,               // U1.DIVb
  input  logic [P.DIVb+3:0] WS, WC,             // Q4.DIVb
  input  logic [P.DIVb+1:0] C,                  // Q2.DIVb
  input  logic              SqrtE,
  output logic [P.DIVb+1:0] CNext,              // Q2.DIVb
  output logic              un,
  output logic [P.DIVb:0]   UNext, UMNext,      // U1.DIVb
  output logic [P.DIVb+3:0] WSNext, WCNext      // Q4.DIVb
);

  logic [P.DIVb+3:0]        Dsel;               // Q4.DIVb
  logic [3:0]               udigit;             // {+2, +1, -1, -2} or 0000 for 0
  logic [P.DIVb+3:0]        F;                  // Q4.DIVb
  logic [P.DIVb+3:0]        AddIn;              // Q4.DIVb
  logic [4:0]               Smsbs;              // U1.4
  logic [2:0]               Dmsbs;              // U0.3   drop leading 1 from D
  logic [7:0]               WCmsbs, WSmsbs;     // U4.4
  logic                     CarryIn;
  logic [P.DIVb+3:0]        WSA, WCA;           // Q4.DIVb
  logic j0, j1;                                 // step j = 0 or step j = 1

  // Digit Selection logic
  assign j0     = ~C[P.DIVb+1];             // first step of R digit selection: C = 00...0
  assign j1     = ~C[P.DIVb-1]; // second step of R digit selection: C = 1100...0; simplified from  C[P.DIVb] & ~C[P.DIVb-1] because j=0 case takes priority
  assign Smsbs  = U[P.DIVb:P.DIVb-4];       // U1.4 most significant bits of square root
  assign Dmsbs  = D[P.DIVb-1:P.DIVb-3];     // U0.3 most significant fractional bits of divisor after leading 1
  assign WCmsbs = WC[P.DIVb+3:P.DIVb-4];    // Q4.4 most significant bits of residual
  assign WSmsbs = WS[P.DIVb+3:P.DIVb-4];    // Q4.4 most significant bits of residual
  fdivsqrtuslc4cmp uslc4(.Dmsbs, .Smsbs, .WSmsbs, .WCmsbs, .SqrtE, .j0, .j1, .udigit);
  assign un = 1'b0; // unused for radix 4

  // F generation logic
  fdivsqrtfgen4 #(P) fgen4(.udigit, .C({2'b11, CNext}), .U({3'b000, U}), .UM({3'b000, UM}), .F);

  // Divisor multiple logic
  always_comb
    case (udigit)
      4'b1000: Dsel = DBar2;
      4'b0100: Dsel = DBar;
      4'b0000: Dsel = '0;
      4'b0010: Dsel = D;
      4'b0001: Dsel = D2;
      default: Dsel = 'x;
    endcase

  // Residual Update
  //  {WS, WC}}Next = (WS + WC - qD or F) << 2
  assign AddIn = SqrtE ? F : Dsel;
  assign CarryIn = ~SqrtE & (udigit[3] | udigit[2]); // +1 for 2's complement of -D and -2D
  csa #(P.DIVb+4) csa(WS, WC, AddIn, CarryIn, WSA, WCA);
  assign WSNext = WSA << 2;
  assign WCNext = WCA << 2;

  // Shift thermometer code C
  assign CNext = {2'b11, C[P.DIVb+1:2]};

  // On-the-fly converter to accumulate result
  fdivsqrtuotfc4 #(P) fdivsqrtuotfc4(.udigit, .C(CNext[P.DIVb:0]), .U, .UM, .UNext, .UMNext);
endmodule
