///////////////////////////////////////////
// vm64check.sv
//
// Written:  David Harris David_Harris@hmc.edu 4 November 2022
// Modified: Ayesha Anwaar ayesha.anwaar2005@gmail.com, Muhammad Zain zainzahid2050@gmail.com
//
// Purpose: Checks that the unused upper virtual address bits are a sign extension in RV64 virtual memory modes.
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
