///////////////////////////////////////////
// valu.sv
//
// Written: Rose Thompson rose@rosethompson.net
// Created: 10 Sept 2026
// Modified: 10 Sept 2026
//
// Purpose: RISC-V Vector Arithmetic/Logic Unit
//
// Documentation: RISC-V System on Chip Design Volume 2
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
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

module valu import cvw::*; #(parameter cvw_t P)
  (
   input logic [P.VPU_INT_BLEN-1:0] A, B,
   output logic [P.VPU_INT_BLEN-1:0] Sum
   );

  // *** simplest implementation for now, just add, SEW = e64

  genvar i;
  for(i = 0; i < P.VPU_INT_LANES; i++) begin
    assign Sum[P.ELEN*(i+1)-1:P.ELEN*i] = A[P.ELEN*(i+1)-1:P.ELEN*i] + B[P.ELEN*(i+1)-1:P.ELEN*i];
  end

endmodule
