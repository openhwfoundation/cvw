///////////////////////////////////////////
// vm64check.sv
//
// Written:  David Harris David_Harris@hmc.edu 4 November 2022
// Modified: Ayesha Anwaar, Muhammad Zain
//
// Purpose: RV64 virtual address sign-extension check.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2022-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module vm64check import cvw::*; #(parameter cvw_t P, ITLB = 0) (
  input  logic [P.SVMODE_BITS-1:0]  SATP_MODE,
  input  logic [P.XLEN-1:0]         VAdr,
  input  logic                      PointerMaskApplicable,
  input  logic                      PMLen16Sel,
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

    // Without pointer masking, bits 63 down to the top bit of the virtual address must all equal it.  The result
    // matters only when the access is translated, so with satp.MODE = Bare it is never used.
    logic Unequal;
    assign Unequal =
        SV39Mode  ?                     ~((all0_46_38 & all0_55_47 & all0_63_56 ) | (all1_46_38 & all1_55_47 & all1_63_56 ) ) :  // SV39 Mode
        (SV48Mode ? (P.SV48_SUPPORTED & ~((all0_55_47 & all0_63_56) | (all1_55_47 & all1_63_56 ))) :                             // SV48 Mode
                    (P.SV57_SUPPORTED & ~((all0_63_56 | all1_63_56))));                                                             // SV57 Mode

    if (ITLB == 1 | !P.ZPM_SUPPORTED) begin : nopm // Instruction fetches are not pointer masked
      assign UpperBitsUnequal = Unequal;
    end else begin : pm
      // With pointer masking, the masked bits are ignored, and the bits above the top of the virtual address must
      // equal the new top bit instead: bit 56 with PMLEN 7 (Sv57 has nothing left to check), or bit 47 with PMLEN 16
      // (Sv48 has nothing left to check, and PMLEN 16 is never supported with Sv57).
      logic Unequal7, MaskedUnequal;
      assign Unequal7 =
          SV39Mode ? ~((all0_46_38 & all0_55_47 & ~VAdr[56]) | (all1_46_38 & all1_55_47 & VAdr[56])) :          // SV39 Mode
                     (SV48Mode & P.SV48_SUPPORTED & ~((all0_55_47 & ~VAdr[56]) | (all1_55_47 & VAdr[56])));       // SV48 Mode
      if (P.PMLEN16_SUPPORTED) begin : pmlen16
        logic Unequal16;
        assign Unequal16 = SV39Mode & ~((all0_46_38 & ~VAdr[47]) | (all1_46_38 & VAdr[47]));
        assign MaskedUnequal = PMLen16Sel ? Unequal16 : Unequal7;
      end else
        assign MaskedUnequal = Unequal7;
      assign UpperBitsUnequal = PointerMaskApplicable ? MaskedUnequal : Unequal;
    end
  end else begin
    assign SV39Mode = 1'b0;
    assign SV48Mode = 1'b0;
    assign UpperBitsUnequal = 1'b0;
  end
endmodule
