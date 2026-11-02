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

module vm64check import cvw::*;  #(parameter cvw_t P, ITLB = 0) (
  input  logic [P.SVMODE_BITS-1:0]  SATP_MODE,
  input  logic [P.XLEN-1:0]         VAdr,
  input  logic [1:0]                MSECCFG_PMM, MENVCFG_PMM, SENVCFG_PMM,
  input  logic [1:0]                EffectivePrivilegeModeW,
  input  logic                      STATUS_MXR,
  input  logic [1:0]                MemRWM,
  input  logic [3:0]                CMOpM,
  output logic                      SV39Mode,
  output logic                      SV48Mode,
  output logic                      UpperBitsUnequal,
  output logic                      PointerMaskApplicable, PMLength
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

    if (ITLB == 1) begin : itlb // Instruction tlb isn't subject to pointer masking
      assign PointerMaskApplicable = 1'b0;
      assign PMLength = 1'b0;
      assign UpperBitsUnequal =
          SV39Mode  ?                     ~((all0_46_38 & all0_55_47 & all0_63_56 ) | (all1_46_38 & all1_55_47 & all1_63_56 ) ) :  // SV39 Mode
          (SV48Mode ? (P.SV48_SUPPORTED & ~((all0_55_47 & all0_63_56) | (all1_55_47 & all1_63_56 ))) :                             // SV48 Mode
                      (P.SV57_SUPPORTED & ~((all0_63_56 | all1_63_56))));
    end else begin : dtlb // Data TLB pointer masking can turn off validity checks
      pointermask #(P) pointermask(.MSECCFG_PMM, .MENVCFG_PMM, .SENVCFG_PMM, .EffectivePrivilegeModeW,
                                   .STATUS_MXR, .MemRWM, .CMOpM, .PointerMaskApplicable, .PMLength);
      always_comb
        case(SATP_MODE)
          P.SV39: if (PointerMaskApplicable) UpperBitsUnequal = PMLength ? ~((all0_46_38 & ~VAdr[47]) | (all1_46_38 & VAdr[47])): ~((all0_46_38 & all0_55_47 & ~VAdr[56]) | (all1_46_38 & all1_55_47 & VAdr[56]));
                  else UpperBitsUnequal = ~((all0_46_38 & all0_55_47 & all0_63_56 ) | (all1_46_38 & all1_55_47 & all1_63_56));
          P.SV48: if (PointerMaskApplicable) UpperBitsUnequal = PMLength ? 1'b0 : P.SV48_SUPPORTED & ~((all0_55_47 & ~VAdr[56]) | (all1_55_47 & VAdr[56]));
                  else UpperBitsUnequal = (P.SV48_SUPPORTED & ~((all0_55_47 & all0_63_56) | (all1_55_47 & all1_63_56 )));
          P.SV57: if (PointerMaskApplicable) UpperBitsUnequal = 1'b0;
                  else UpperBitsUnequal = (P.SV57_SUPPORTED & ~((all0_63_56 | all1_63_56)));
          default: UpperBitsUnequal = 1'b1;
        endcase
      end
    end else begin
      assign SV39Mode = 1'b0;
      assign SV48Mode = 1'b0;
      assign UpperBitsUnequal = 1'b0;
      assign PointerMaskApplicable = 1'b0;
      assign PMLength = 1'b0;
  end
endmodule
