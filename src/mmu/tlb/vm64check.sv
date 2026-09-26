///////////////////////////////////////////
// vm64check.sv
//
// Written: David_Harris@hmc.edu 4 November 2022
// Modified:
//
// Purpose: Check for good upper address bits in RV64 mode
//
// Documentation: RISC-V System on Chip Design
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

module vm64check import cvw::*;  #(parameter cvw_t P) (
  input  logic [P.SVMODE_BITS-1:0]  SATP_MODE,
  input  logic [P.XLEN-1:0]         VAdr,
  output logic                      SV39Mode,
  output logic                      SV48Mode,
  output logic                      UpperBitsUnequal
);

  if (P.XLEN == 64) begin
    assign SV39Mode = (SATP_MODE == P.SV39);
    assign SV48Mode = (SATP_MODE == P.SV48);

    // page fault if upper bits aren't all the same
    logic all0_46_38, all1_46_38;
    logic all0_55_47, all1_55_47;
    logic all0_63_56, all1_63_56;

    assign all0_46_38 = ~|VAdr[46:38];
    assign all1_46_38 =  &VAdr[46:38];

    assign all0_55_47 = ~|VAdr[55:47];
    assign all1_55_47 =  &VAdr[55:47];

    assign all0_63_56 = ~|VAdr[63:56];
    assign all1_63_56 =  &VAdr[63:56];

    assign UpperBitsUnequal =
      SV39Mode  ?                     ~((all0_46_38 & all0_55_47 & all0_63_56 ) | (all1_46_38 & all1_55_47 & all1_63_56 ) ) :  // SV39 Mode
      (SV48Mode ? (P.SV48_SUPPORTED & ~((all0_55_47 & all0_63_56) | (all1_55_47 & all1_63_56 ))) :                             // SV48 Mode
                  (P.SV57_SUPPORTED & ~((all0_63_56 | all1_63_56))));                                                          // SV57 Mode
    end else begin
      assign SV39Mode = 1'b0;
      assign SV48Mode = 1'b0;
      assign UpperBitsUnequal = 1'b0;
  end
endmodule
