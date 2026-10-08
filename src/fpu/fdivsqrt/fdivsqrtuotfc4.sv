///////////////////////////////////////////
// fdivsqrtuotfc4.sv
//
// Written: me@KatherineParry.com, cturek@hmc.edu
// Modified:7/14/2022
//
// Purpose: Radix 4 unified on-the-fly converter
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

module fdivsqrtuotfc4 import cvw::*;  #(parameter cvw_t P) (
  input  logic [3:0]     udigit,
  input  logic [P.DIVb:0] U, UM,          // U1.DIVb  UM is actually U - 1 ulp and starts negative, but this representation still produces the right answer
  input  logic [P.DIVb:0] C,              // Q1.DIVb
  output logic [P.DIVb:0] UNext, UMNext   // U1.DIVb
);
  //  The on-the-fly converter transfers the square root
  //  bits to the quotient as they come.
  //  Use this otfc for division and square root.

  logic [P.DIVb:0] K1, K2, K3;            // U1.DIVb
  assign K1 = (C&~(C << 1));        // K
  assign K2 = ((C << 1)&~(C << 2)); // 2K
  assign K3 = (C & ~(C << 2));      // 3K

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
