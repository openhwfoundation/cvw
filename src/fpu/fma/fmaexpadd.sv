///////////////////////////////////////////
// fmaexpadd.sv
//
// Written:  6/23/2021 me@KatherineParry.com, David_Harris@hmc.edu
// Modified:
//
// Purpose: FMA exponent addition
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

module fmaexpadd import cvw::*;  #(parameter cvw_t P) (
  input  logic [P.NE-1:0]      Xe, Ye,         // input's exponents
  input  logic                 XZero, YZero,   // are the inputs zero
  output logic [P.NE+1:0]      Pe              // product's exponent B^(1023)NE+2
);

  logic                        PZero;          // is the product zero?

  // kill the exponent if the product is zero - either X or Y is 0
  assign PZero = XZero | YZero;
  assign Pe    = PZero ? '0 : ({2'b0, Xe} + {2'b0, Ye} - {2'b0, (P.NE)'(P.BIAS)});

endmodule
