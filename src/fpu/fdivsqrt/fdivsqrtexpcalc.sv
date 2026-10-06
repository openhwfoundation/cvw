///////////////////////////////////////////
// fdivsqrtexpcalc.sv
//
// Written: David_Harris@hmc.edu, me@KatherineParry.com, cturek@hmc.edu
// Modified:13 January 2022
//
// Purpose: Exponent calculation for divide and square root
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

module fdivsqrtexpcalc import cvw::*;  #(parameter cvw_t P) (
  input  logic [P.NE-2:0]      Bias,      // Bias of exponent
  input  logic [P.NE-1:0]      Xe, Ye,    // input exponents
  input  logic                 Sqrt,
  input  logic [P.DIVBLEN-1:0] ell, m,    // number of leading 0s in Xe and Ye
  output logic [P.NE+1:0]      Ue         // result exponent
  );

  logic [P.NE+1:0] SXExp;
  logic [P.NE+1:0] SExp;
  logic [P.NE+1:0] DExp;

  // Square root exponent = (Xe - l - bias) / 2 + bias; l accounts for subnorms
  assign SXExp = {2'b0, Xe} - {{(P.NE+1-P.DIVBLEN){1'b0}}, ell} - (P.NE+2)'(P.BIAS);
  assign SExp  = {SXExp[P.NE+1], SXExp[P.NE+1:1]} + {2'b0, Bias};

  // division exponent = (Xe-l) - (Ye-m) + bias; l and m account for subnorms
  assign DExp  = ({2'b0, Xe} - {{(P.NE+1-P.DIVBLEN){1'b0}}, ell} - {2'b0, Ye} + {{(P.NE+1-P.DIVBLEN){1'b0}}, m} + {3'b0, Bias});

  // Select square root or division exponent
  assign Ue = Sqrt ? SExp : DExp;
endmodule
