///////////////////////////////////////////
// pointermask.sv
//
// Written: naichewa@gmail.com 8/6/2026
// Modified:
//
// Purpose: Pointer Masking Module v1.0
// LSU module that optionally pointer masks explicit memory accesses according to
// RISC-V specs. 16 bit mask lengths are only supported when Sv57 is unsupported and sets physical
// address bits to 48 so that used address bits are not masked.
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
  logic SvInactiveM;   // The address is physical (M mode or satp Bare), so masking zero-extends it
  logic Fill7SpillM;          // Value of masked bits for PMLEN 7: 0 if physical, else bit 56
  assign SvInactiveM = ~|(SATP_REGW[P.XLEN-1:P.XLEN-P.SVMODE_BITS]) | EffectivePrivilegeModeW[1];
  assign Fill7SpillM = ~SvInactiveM & IEUAdrSpillM[56];
  if (P.PMLEN16_SUPPORTED) begin : pmlen16
    logic Mask16SpillM, Fill16SpillM, TopFillSpillM;
    assign Mask16SpillM  = PointerMaskApplicable & PMLen16Sel;
    assign Fill16SpillM  = ~SvInactiveM & IEUAdrSpillM[47];
    assign TopFillSpillM = PMLen16Sel ? Fill16SpillM : Fill7SpillM;
    assign IEUAdrSpillMMasked[63:57] = PointerMaskApplicable ? {7{TopFillSpillM}} : IEUAdrSpillM[63:57];
    assign IEUAdrSpillMMasked[56:48] = Mask16SpillM ? {9{Fill16SpillM}} : IEUAdrSpillM[56:48];
    assign IEUAdrSpillMMasked[47:0]  = IEUAdrSpillM[47:0];
  end else begin
    assign IEUAdrSpillMMasked[63:57] = PointerMaskApplicable ? {7{Fill7SpillM}} : IEUAdrSpillM[63:57];
    assign IEUAdrSpillMMasked[56:0]  = IEUAdrSpillM[56:0];
  end
  assign IEUAdrxTvalMMasked = {IEUAdrSpillMMasked[P.XLEN-1:48], IEUAdrxTvalM[47:0]};
endmodule
