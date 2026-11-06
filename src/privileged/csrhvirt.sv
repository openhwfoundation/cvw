///////////////////////////////////////////
// csrhvirt.sv
//
// Written: nchulani@hmc.edu 27 April 2026
// Purpose: Combinational H-extension CSR virtualization: VS address substitution,
//          virtual-instruction classification, and trap GVA generation
//          See RISC-V Privileged Mode Specification (Hypervisor Extension)
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
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

module csrhvirt import cvw::*;  #(parameter cvw_t P) (
  input  logic [11:0]       CSRAdrM_In,
  input  logic              CSRReadM, CSRWriteM,
  input  logic              TrapM, ExceptionM,
  input  logic              VirtModeW,
  input  logic [1:0]        PrivilegeModeW,
  input  logic [31:0]       MCOUNTEREN_REGW, HCOUNTEREN_REGW,
  input  logic [63:0]       HENVCFG_REGW,
  input  logic              VirtualCSRCAccessM,
  input  logic              TrapWritesVAToTvalM,
  input  logic              HLVHSVLegalM,
  input  logic              MENVCFG_STCE,
  output logic [11:0]       CSRAdrM,
  output logic              VirtualCSRAccessM,
  output logic              TrapGVAM
);

  localparam SSTATUS    = 12'h100;
  localparam SIE        = 12'h104;
  localparam STVEC      = 12'h105;
  localparam SCOUNTEREN = 12'h106;
  localparam SENVCFG    = 12'h10A;
  localparam SSCRATCH   = 12'h140;
  localparam SEPC       = 12'h141;
  localparam SCAUSE     = 12'h142;
  localparam STVAL      = 12'h143;
  localparam SIP        = 12'h144;
  localparam STIMECMP   = 12'h14D;
  localparam STIMECMPH  = 12'h15D;
  localparam SATP       = 12'h180;
  localparam HSTATUS    = 12'h600;
  localparam HEDELEG    = 12'h602;
  localparam HEDELEGH   = 12'h612;
  localparam HIDELEG    = 12'h603;
  localparam HIE        = 12'h604;
  localparam HTIMEDELTA = 12'h605;
  localparam HTIMEDELTAH = 12'h615;
  localparam HCOUNTEREN = 12'h606;
  localparam HGEIE      = 12'h607;
  localparam HENVCFG    = 12'h60A;
  localparam HENVCFGH   = 12'h61A;
  localparam HTVAL      = 12'h643;
  localparam HIP        = 12'h644;
  localparam HVIP       = 12'h645;
  localparam HTINST     = 12'h64A;
  localparam HGATP      = 12'h680;
  localparam HGEIP      = 12'hE12;
  localparam VSSTATUS   = 12'h200;
  localparam VSIE       = 12'h204;
  localparam VSTVEC     = 12'h205;
  localparam VSSCRATCH  = 12'h240;
  localparam VSEPC      = 12'h241;
  localparam VSCAUSE    = 12'h242;
  localparam VSTVAL     = 12'h243;
  localparam VSIP       = 12'h244;
  localparam VSATP      = 12'h280;
  localparam VSTIMECMP  = 12'h24D;
  localparam VSTIMECMPH = 12'h25D;

  logic HasVSCSR, HSQualifiedSCSRAccessM, HSQualifiedHCSRAccessM, HSQualifiedVSCSRAccessM;
  logic VirtualSCSRAccessM, VirtualHCSRAccessM, VirtualVSCSRAccessM, VirtualVSTimecmpAccessM;
  logic MapVSCSR;

  // H spec norm:H_vscsrs_sub substitutes only S CSRs with matching VS CSRs.
  // norm:H_scsrs_nomatch leaves S CSRs such as senvcfg/scounteren on their S addresses when V=1.
  /* verilator lint_off CASEINCOMPLETE */
  always_comb begin
    HasVSCSR = 1'b0;
    case (CSRAdrM_In)
      SSTATUS, SIE, STVEC, SSCRATCH, SEPC, SCAUSE, STVAL, SIP:
        HasVSCSR = 1'b1;
      SATP:
        HasVSCSR = P.VIRTMEM_SUPPORTED;
      STIMECMP:
        HasVSCSR = P.SSTC_SUPPORTED;
      STIMECMPH:
        HasVSCSR = P.SSTC_SUPPORTED & (P.XLEN == 32);
    endcase
  end

  // HS-qualified means the same CSR access would be legal in HS-mode with mstatus.TVM=0
  // (norm:H_cause_virtual_instruction). VU attempts to access HS-qualified S CSRs trap
  // virtually; VS attempts to access senvcfg/scounteren stay legal per norm:H_scsrs_nomatch.
  always_comb begin
    HSQualifiedSCSRAccessM = 1'b0;
    case (CSRAdrM_In)
      SSTATUS, SIE, STVEC, SCOUNTEREN, SENVCFG, SSCRATCH, SEPC, SCAUSE, STVAL, SIP:
        HSQualifiedSCSRAccessM = 1'b1;
      SATP:
        HSQualifiedSCSRAccessM = P.VIRTMEM_SUPPORTED;
      STIMECMP:
        HSQualifiedSCSRAccessM = (P.SSTC_SUPPORTED) & (MCOUNTEREN_REGW[1] & MENVCFG_STCE);
      STIMECMPH:
        HSQualifiedSCSRAccessM = P.SSTC_SUPPORTED & (P.XLEN == 32) & (MCOUNTEREN_REGW[1] & MENVCFG_STCE);
    endcase
  end

  // H/VS CSRs are not directly accessible when V=1, but accesses that would be allowed
  // from HS-mode are virtual-instruction exceptions (norm:H_virtinst_vu_vs_nonhigh_allowedhs_tvm0).
  always_comb begin
    HSQualifiedHCSRAccessM = 1'b0;
    case (CSRAdrM_In)
      HSTATUS, HEDELEG, HIDELEG, HIE, HTIMEDELTA, HCOUNTEREN, HGEIE, HENVCFG,
      HTVAL, HIP, HVIP, HTINST, HGATP:
        HSQualifiedHCSRAccessM = 1'b1;
      HEDELEGH, HTIMEDELTAH, HENVCFGH:
        HSQualifiedHCSRAccessM = (P.XLEN == 32);
      HGEIP:
        HSQualifiedHCSRAccessM = ~CSRWriteM;
    endcase
  end

  always_comb begin
    HSQualifiedVSCSRAccessM = 1'b0;
    case (CSRAdrM_In)
      VSSTATUS, VSIE, VSTVEC, VSSCRATCH, VSEPC, VSCAUSE, VSTVAL, VSIP, VSATP:
        HSQualifiedVSCSRAccessM = 1'b1;
      VSTIMECMP:
        HSQualifiedVSCSRAccessM = P.SSTC_SUPPORTED & (MCOUNTEREN_REGW[1] & MENVCFG_STCE);
      VSTIMECMPH:
        HSQualifiedVSCSRAccessM = (P.SSTC_SUPPORTED & (P.XLEN == 32)) & (MCOUNTEREN_REGW[1] & MENVCFG_STCE);
    endcase
  end
  /* verilator lint_on CASEINCOMPLETE */

  assign MapVSCSR = VirtModeW & (PrivilegeModeW == P.S_MODE) & HasVSCSR;
  mux2 #(12) csradrmux(CSRAdrM_In, {CSRAdrM_In[11:10], 2'b10, CSRAdrM_In[7:0]}, MapVSCSR, CSRAdrM);


  assign VirtualSCSRAccessM = VirtModeW & (PrivilegeModeW == P.U_MODE) & HSQualifiedSCSRAccessM;
  assign VirtualHCSRAccessM = VirtModeW & HSQualifiedHCSRAccessM;
  assign VirtualVSCSRAccessM = VirtModeW & HSQualifiedVSCSRAccessM; // Virtual modes accessing VS CSRs raise virtual exception
  // VS access to stimecmp (remapped to vstimecmp) raises a virtual-instruction exception
  // when hcounteren.TM or henvcfg.STCE blocks it but mcounteren.TM & menvcfg.STCE allow it
  // (norm:henvcfg-stce, norm:hcounteren_acc). If the M-level gates block it, it is illegal instead.
  assign VirtualVSTimecmpAccessM = VirtModeW & (PrivilegeModeW == P.S_MODE) & P.SSTC_SUPPORTED & // in VS mode
                                   ((CSRAdrM_In == STIMECMP) | ((P.XLEN == 32) & (CSRAdrM_In == STIMECMPH))) & // accessing vstimecmp
                                   ~(HCOUNTEREN_REGW[1] & HENVCFG_REGW[63]) &
                                   (MCOUNTEREN_REGW[1] & MENVCFG_STCE); // not illegal instruction fault
  assign VirtualCSRAccessM = CSRReadM & (VirtualSCSRAccessM | VirtualHCSRAccessM | VirtualVSCSRAccessM |
                                         VirtualVSTimecmpAccessM | VirtualCSRCAccessM);

  // GVA gets set when traps from virtualized execution write a VA to tval.
  // H spec hstatus.GVA note: HLV/HLVX/HSV address faults write guest virtual
  // addresses even though V=0 for the executing hypervisor instruction.
  assign TrapGVAM = TrapM & ExceptionM & (VirtModeW | HLVHSVLegalM) & TrapWritesVAToTvalM;
endmodule
