///////////////////////////////////////////
// riscvassertions.sv
//
// A component of the Wally configurable RISC-V project.
// Assertions generic to RISCV architecture
//
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
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

module riscvassertions import cvw::*; #(parameter cvw_t P);
  initial begin
    assert (P.PMP_ENTRIES == 0 | P.PMP_ENTRIES==16 | P.PMP_ENTRIES==64) else $fatal(1, "Illegal number of PMP entries: PMP_ENTRIES must be 0, 16, or 64");
    assert (P.F_SUPPORTED | !P.D_SUPPORTED) else $fatal(1, "Can't support double fp (D) without supporting float (F)");
    assert (P.D_SUPPORTED | !P.Q_SUPPORTED) else $fatal(1, "Can't support quad fp (Q) without supporting double (D)");
    assert (P.F_SUPPORTED | !P.ZFH_SUPPORTED) else $fatal(1, "Can't support half-precision fp (ZFH) without supporting float (F)");

    assert (P.I_SUPPORTED ^ P.E_SUPPORTED) else $fatal(1, "Exactly one of I and E must be supported");

    assert (P.S_SUPPORTED | P.VIRTMEM_SUPPORTED == 0) else $fatal(1, "Virtual memory requires S mode support");
    assert (P.ZICSR_SUPPORTED == 1 | (P.PMP_ENTRIES == 0 & P.VIRTMEM_SUPPORTED == 0)) else $fatal(1, "PMP_ENTRIES and VIRTMEM_SUPPORTED must be zero if ZICSR not supported.");
    assert (P.ZICSR_SUPPORTED == 1 | (P.S_SUPPORTED == 0 & P.U_SUPPORTED == 0)) else $fatal(1, "S and U modes not supported if ZICSR not supported");
    assert (P.U_SUPPORTED | (P.S_SUPPORTED == 0)) else $error ("S mode only supported if U also is supported");

    assert (P.SSTC_SUPPORTED == 0 | (P.S_SUPPORTED)) else $fatal(1, "SSTC requires S_SUPPORTED");
    assert ((P.M_SUPPORTED == 0) | (P.ZMMUL_SUPPORTED == 1)) else $fatal(1, "M requires ZMMUL");
    assert ((P.ZICNTR_SUPPORTED == 0) | (P.ZICSR_SUPPORTED == 1)) else $fatal(1, "ZICNTR_SUPPORTED requires ZICSR_SUPPORTED");
    assert ((P.ZIHPM_SUPPORTED == 0) | (P.ZICNTR_SUPPORTED == 1)) else $fatal(1, "ZIPHM_SUPPORTED requires ZICNTR_SUPPORTED");

    assert (P.XLEN == 32 | P.SV32_SUPPORTED == 0) else $fatal(1, "SV32_SUPPORTED requires XLEN = 32");
    assert (P.XLEN == 64 | P.SV39_SUPPORTED == 0) else $fatal(1, "SV39_SUPPORTED requires XLEN = 64");
    assert (P.SV39_SUPPORTED | P.SV48_SUPPORTED == 0) else $fatal(1, "SV48_SUPPORTED requires SV39 virtual memory");
    assert (P.SV48_SUPPORTED | P.SV57_SUPPORTED == 0) else $fatal(1, "SV57_SUPPORTED requires SV48 virtual memory");
    assert (P.VIRTMEM_SUPPORTED | P.SVINVAL_SUPPORTED == 0) else $fatal(1, "SVINVAL_SUPPORTED requires virtual memory");
    assert (P.VIRTMEM_SUPPORTED | P.SVADU_SUPPORTED == 0) else $fatal(1, "SVADU_SUPPORTED requires virtual memory");
    assert (P.SV39_SUPPORTED | P.SVPBMT_SUPPORTED == 0) else $fatal(1, "SVPBMT_SUPPORTED requires at least SV39_SUPPORTED virtual memory");
    assert (P.SV39_SUPPORTED | P.SVNAPOT_SUPPORTED == 0) else $fatal(1, "SVNAPOT_SUPPORTED requires at least SV39_SUPPORTED virtual memory");

    assert ((P.ZCA_SUPPORTED == 1) | (P.ZCD_SUPPORTED == 0 & P.ZCF_SUPPORTED == 0 & P.ZCB_SUPPORTED == 0)) else $fatal(1, "ZCB, ZCF, or ZCD requires ZCA");
    assert ((P.ZCF_SUPPORTED == 0) | ((P.F_SUPPORTED == 1) & (P.XLEN == 32))) else $fatal(1, "ZCF requires F and XLEN == 32");
    assert ((P.ZCD_SUPPORTED == 0) | (P.D_SUPPORTED == 1)) else $fatal(1, "ZCD requires D");
  end
endmodule
