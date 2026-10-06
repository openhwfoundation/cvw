///////////////////////////////////////////
// fdivsqrtuotfc2.sv
//
// Written: me@KatherineParry.com, cturek@hmc.edu
// Modified:7/14/2022
//
// Purpose: Radix 2 unified on-the-fly converter
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

///////////////////////////////
// Unified OTFC, Radix 2 //
///////////////////////////////
module fdivsqrtuotfc2 import cvw::*;  #(parameter cvw_t P) (
  input  logic             up, un,
  input  logic [P.DIVb+1:0] C,                // Q2.DIVb
  input  logic [P.DIVb:0]   U, UM,            // U1.DIVb  UM is actually U - 1 ulp and starts negative, but this representation still produces the right answer
  output logic [P.DIVb:0]   UNext, UMNext     // U1.DIVb
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
