///////////////////////////////////////////
// pointermask.sv
//
// Written: naichewa@gmail.com 8/6/2026
// Modified:
//
// Purpose: Pointer masking (Smmpm, Smnpm, Ssnpm) for explicit memory accesses.
// Applies the ignore transformation to the upper PMLEN bits of the address: sign-extension of bit
// XLEN-PMLEN-1 for virtual addresses, zero-extension for physical addresses.  PMLEN is 7 or 16;
// PMLEN 16 is only supported without Sv57 so that the masked bits never reach the TLB tag.
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

module pointermask import cvw::*; #(parameter cvw_t P) (
  input  logic [1:0]        MSECCFG_PMM, MENVCFG_PMM, SENVCFG_PMM, // PMM fields: 00 off, 10 PMLEN 7, 11 PMLEN 16
  input  logic [1:0]        EffectivePrivilegeModeW,               // privilege mode of the access, including MPRV
  input  logic              STATUS_MXR,                            // MXR disables pointer masking below M-mode
  input  logic [P.XLEN-1:0] SATP_REGW,                             // satp.MODE = Bare means addresses are physical
  input  logic [1:0]        MemRWM,                                // load or store
  input  logic [3:0]        CMOpM,                                 // cache management operation
  input  logic [P.XLEN-1:0] IEUAdrSpillM,                          // address of the access
  output logic [P.XLEN-1:0] IEUAdrSpillMaskedM                     // address after pointer masking
);

  logic [1:0] PMMM;        // PMM of the effective privilege mode
  logic       EnableM;     // mask this access
  logic       PMLen16M;    // PMLEN = 16 rather than 7
  logic       VirtualM;    // address is translated, so the masked bits sign-extend rather than zero-extend
  logic       AdrSignBitM; // value of the masked bits: sign bit of a virtual address, 0 for a physical address

  always_comb
    case (EffectivePrivilegeModeW)
      P.M_MODE: PMMM = MSECCFG_PMM;
      P.S_MODE: PMMM = MENVCFG_PMM;
      default:  PMMM = P.S_SUPPORTED ? SENVCFG_PMM : MENVCFG_PMM; // U-mode
    endcase

  // Mask loads, stores, atomics, and CMOs when PMM is nonzero and MXR is inactive (MXR has no effect in M-mode)
  assign EnableM     = |PMMM & (|MemRWM | |CMOpM) & (EffectivePrivilegeModeW == P.M_MODE | ~STATUS_MXR);
  assign PMLen16M    = P.PMLEN16_SUPPORTED & PMMM[0];
  assign VirtualM    = (EffectivePrivilegeModeW != P.M_MODE) & |SATP_REGW[P.XLEN-1:P.XLEN-P.SVMODE_BITS];
  assign AdrSignBitM = VirtualM & (PMLen16M ? IEUAdrSpillM[47] : IEUAdrSpillM[56]);

  assign IEUAdrSpillMaskedM = {EnableM            ? {7{AdrSignBitM}} : IEUAdrSpillM[63:57],
                               EnableM & PMLen16M ? {9{AdrSignBitM}} : IEUAdrSpillM[56:48],
                               IEUAdrSpillM[47:0]};
endmodule
