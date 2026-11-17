///////////////////////////////////////////
// pointermask.sv
//
// Written: naichewa@gmail.com 8/6/2026
// Modified:
//
// Purpose: Pointer Masking Module v1.0
// Module inside of MMU that determines whether pointer masking should be applied based on privilege level and instruction.
// Pointer Masking length (PMLen16Sel) currently limited to be mutually exclusive with SV57 so that used virtual address bits
// are never masked. Hypervisor guest physical addresses are 2 bits longer and therefore have
// additional configurations where addressable bits are masked, for future work.
// Virtual address validity checks are masked in vm64check.sv, physical address validity checks are masked in the mmu
// with PAOutOfRange, and the full ignore transformation is performed when hardware writes to xtval
// Documentation: Based on descriptions in RISC-V Privileged Specifications
// Chapter on Pointer Masking https://docs.riscv.org/reference/isa/v20260120/priv/zpm.html
// Complete Specifications V20260120 https://docs.riscv.org/reference/isa/_attachments/riscv-privileged.pdf
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
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

module pointermask import cvw::*;   #(parameter cvw_t P) (
    input logic [1:0]                MSECCFG_PMM, MENVCFG_PMM, SENVCFG_PMM,
    input logic [1:0]                EffectivePrivilegeModeW,
    input logic                      STATUS_MXR,
    input logic [1:0]                MemRWM,
    input logic [3:0]                CMOpM,
    input logic [P.XLEN-1:0]         SATP_REGW,
    input logic [P.XLEN-1:0]         IEUAdrSpillM, IEUAdrxTvalM,
    output logic                     PointerMaskApplicable, PMLen16Sel,
    output logic [P.XLEN-1:0]        IEUAdrSpillMMasked, IEUAdrxTvalMMasked
);

  logic MaskApplicableInstr;
  // Determine if instruction is mask-applicable (explicit memory access)
  assign MaskApplicableInstr = |(MemRWM) | |(CMOpM);

  // Determine if mask should be applied based on CSR configuration PMM bits and current privilege level
  always_comb
    case(EffectivePrivilegeModeW)
      2'b00:    begin
                  PointerMaskApplicable = ~STATUS_MXR & MaskApplicableInstr & ((|(MENVCFG_PMM) & !P.S_SUPPORTED) | |(SENVCFG_PMM));
                  PMLen16Sel = P.S_SUPPORTED ? SENVCFG_PMM[0] : MENVCFG_PMM[0];
                end
      2'b01:    begin
                  PointerMaskApplicable = ~STATUS_MXR & MaskApplicableInstr & (|(MENVCFG_PMM));
                  PMLen16Sel = MENVCFG_PMM[0];
                end
      2'b11:    begin
                  PointerMaskApplicable = MaskApplicableInstr & (|(MSECCFG_PMM));
                  PMLen16Sel = MSECCFG_PMM[0];
                end
      default:  begin
                  PointerMaskApplicable = 1'b0;
                  PMLen16Sel = 1'b0;
                end
    endcase
  logic SvActiveM;   // The address is physical (M mode or satp Bare), so masking zero-extends it
  logic Fill7SpillM;          // Value of masked bits for PMLEN 7: 0 if physical, else bit 56
  logic Fill7xTvalM;          // Value of masked bits for PMLEN 7: 0 if physical, else bit 56
  assign SvActiveM = ~|(SATP_REGW[P.XLEN-1:P.XLEN-P.SVMODE_BITS]) | EffectivePrivilegeModeW[1];
  assign Fill7SpillM = ~SvActiveM & IEUAdrSpillM[56];
  assign Fill7xTvalM = ~SvActiveM & IEUAdrxTvalM[56];
  if (P.PMLEN16_SUPPORTED) begin : pmlen16
    logic Mask16SpillM, Fill16SpillM, TopFillSpillM;
    logic Mask16xTvalM, Fill16xTvalM, TopFillxTvalM;
    assign Mask16SpillM  = PointerMaskApplicable & PMLen16Sel;
    assign Fill16SpillM  = ~SvActiveM & IEUAdrSpillM[47];
    assign TopFillSpillM = PMLen16Sel ? Fill16SpillM : Fill7SpillM;
    assign IEUAdrSpillMMasked[63:57] = PointerMaskApplicable ? {7{TopFillSpillM}} : IEUAdrSpillM[63:57];
    assign IEUAdrSpillMMasked[56:48] = Mask16SpillM ? {9{Fill16SpillM}} : IEUAdrSpillM[56:48];
    assign IEUAdrSpillMMasked[47:0]  = IEUAdrSpillM[47:0];

    assign Mask16xTvalM  = PointerMaskApplicable & PMLen16Sel;
    assign Fill16xTvalM  = ~SvActiveM & IEUAdrxTvalM[47];
    assign TopFillxTvalM = PMLen16Sel ? Fill16xTvalM : Fill7xTvalM;
    assign IEUAdrxTvalMMasked[63:57] = PointerMaskApplicable ? {7{TopFillxTvalM}} : IEUAdrxTvalM[63:57];
    assign IEUAdrxTvalMMasked[56:48] = Mask16xTvalM ? {9{Fill16xTvalM}} : IEUAdrxTvalM[56:48];
    assign IEUAdrxTvalMMasked[47:0]  = IEUAdrxTvalM[47:0];
  end else begin
    assign IEUAdrSpillMMasked[63:57] = PointerMaskApplicable ? {7{Fill7SpillM}} : IEUAdrSpillM[63:57];
    assign IEUAdrSpillMMasked[56:0]  = IEUAdrSpillM[56:0];

    assign IEUAdrxTvalMMasked[63:57] = PointerMaskApplicable ? {7{Fill7xTvalM}} : IEUAdrxTvalM[63:57];
    assign IEUAdrxTvalMMasked[56:0]  = IEUAdrxTvalM[56:0];
  end
endmodule
