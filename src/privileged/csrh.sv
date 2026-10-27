///////////////////////////////////////////
// csrh.sv
//
// Written: nchulani@hmc.edu, vkrishna@hmc.edu, jgong@hmc.edu 11 November 2025
// Purpose: Hypervisor-Mode Control and Status Registers
//          See RISC-V Privileged Mode Specification (Hypervisor Extension)
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-25 Harvey Mudd College & Oklahoma State University
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

module csrh import cvw::*;  #(parameter cvw_t P) (
  input  logic              clk, reset,
  input  logic              CSRMWriteM,       // M-mode CSR write
  input  logic              CSRSWriteM,       // M/S-mode CSR write
  input  logic              CSRWriteM,        // CSR instruction writes
  input  logic [11:0]       CSRAdrM,
  input  logic [P.XLEN-1:0] CSRWriteValM,
  input  logic [1:0]        PrivilegeModeW,   // Current privilege mode (U, S, M)
  input  logic              VirtModeW,        // Virtualization mode (VS/VU)
  input  logic              FRegWriteM,       // VS FP writeback updates vsstatus.FS
  input  logic              WriteFRMM,        // VS CSR write to FRM updates vsstatus.FS
  input  logic              SetOrWriteFFLAGSM,// VS CSR write to FFLAGS updates vsstatus.FS
  input  logic              TrapGVAM,         // Trap writes guest virtual address to tval
  input  logic [63:0]       MTIME_CLINT,      // time source for VSTIP (vstimecmp)
  input  logic [P.XLEN-1:0] HGEIPIn,          // guest external interrupt sources
  input  logic              STATUS_TVM,       // mstatus.TVM gate for HGATP access in HS-mode
  input  logic              MCOUNTEREN_TM,    // mcounteren.TM gate for VS timer CSR access
  input  logic              MENVCFG_STCE,     // menvcfg.STCE constrains henvcfg.STCE
  input  logic              MENVCFG_PBMTE,    // menvcfg.PBMTE constrains henvcfg.PBMTE
  input  logic              MENVCFG_ADUE,     // menvcfg.ADUE constrains henvcfg.ADUE

  input  logic              TrapToM,          // Trap targets M-mode
  input  logic              TrapToHSM,        // Trap targets HS-mode
  input  logic              TrapToVSM,        // Trap targets VS-mode
  input  logic              sretM,            // SRET in M stage
  input  logic [31:0]       InstrM,           // Instruction for mtinst/htinst decode
  input  logic [P.XLEN-1:0] NextEPCM,         // EPC value for trap/return
  input  logic [5:0]        NextCauseM,       // Exception/interrupt cause
  input  logic [P.XLEN-1:0] NextTvalM,       // Value for {v,s,}tval on trap
  input  logic [P.XLEN-1:0] NextHtvalM,       // Value for htval on trap
  input  logic [31:0]       InstrOrigM,       // Original compressed or uncompressed instruction for mtinst/htinst
  input  logic [15:0]       HIE_REGW,         // hie alias view of the H bits stored in mie

  output logic [P.XLEN-1:0] CSRHReadValM,
  output logic              IllegalCSRHAccessM,
  output logic              HSTATUS_SPV,
  output logic              HSTATUS_SPVP,
  output logic              HSTATUS_VTSR, HSTATUS_VTW, HSTATUS_VTVM,
  output logic              HSTATUS_HU,
  output logic              HSTATUS_VSBE,
  output logic              VSSTATUS_SPP, VSSTATUS_SIE,
  output logic              VSSTATUS_SUM, VSSTATUS_MXR, VSSTATUS_UBE,
  output logic [1:0]        VSSTATUS_FS,
  output logic [63:0]       HEDELEG_REGW,
  output logic [15:0]       HIDELEG_REGW,
  output logic [31:0]       HCOUNTEREN_REGW,
  output logic [11:0]       HVIP_REGW,
  output logic [15:0]       HIP_MIP_REGW,    // mip alias view of HIP bits [15:0]
  output logic              WriteHIEM, WriteVSIEM,
  output logic [P.XLEN-1:0] HGEIE_REGW,
  output logic [63:0]       HTIMEDELTA_REGW,
  output logic [63:0]       HENVCFG_REGW,
  output logic [P.XLEN-1:0] VSTVEC_REGW,
  output logic [P.XLEN-1:0] VSEPC_REGW,
  output logic [P.XLEN-1:0] VSATP_REGW,
  output logic [P.XLEN-1:0] HGATP_REGW
);

  logic [P.XLEN-1:0] MTINST_REGW;
  logic [P.XLEN-1:0] MTVAL2_REGW;
  logic [P.XLEN-1:0] HSTATUS_REGW;
  logic [P.XLEN-1:0] VSSTATUS_REGW;
  logic              HSTATUS_GVA;
  logic [5:0]        HSTATUS_VGEIN;
  logic [1:0]        HSTATUS_VSXL, HSTATUS_HUPMM;
  logic              VSSTATUS_SD, VSSTATUS_SPELP, VSSTATUS_SDT;
  logic              VSSTATUS_SPIE;
  logic [1:0]        VSSTATUS_XS, VSSTATUS_UXL, VSSTATUS_VS;
  logic [11:0]       VSIE_REGW;
  logic [P.XLEN-1:0] HTVAL_REGW;
  logic [P.XLEN-1:0] VSTVAL_REGW;
  logic [11:0]       VSIP_REGW;
  logic [P.XLEN-1:0] HTINST_REGW;
  logic [P.XLEN-1:0] HGEIP_REGW;
  logic              HGEIP_VGEIN_BIT;
  logic [P.XLEN-1:0] VSSCRATCH_REGW;
  logic [P.XLEN-1:0] VSCAUSE_REGW;
  logic [63:0] VSTIMECMP_REGW;

  // Hypervisor CSR Addresses
  localparam MTINST     = 12'h34A;
  localparam MTVAL2     = 12'h34B;
  localparam HSTATUS    = 12'h600;
  localparam VSSTATUS   = 12'h200;
  localparam HEDELEG    = 12'h602;
  localparam HEDELEGH    = 12'h612;
  localparam HIDELEG    = 12'h603;
  localparam HIE        = 12'h604;
  localparam MIE        = 12'h304;
  localparam MIP        = 12'h344;
  localparam VSIE       = 12'h204;
  localparam HTIMEDELTA = 12'h605;
  localparam HTIMEDELTAH = 12'h615;
  localparam HCOUNTEREN = 12'h606;
  localparam HGEIE      = 12'h607;
  localparam HENVCFG    = 12'h60A;
  localparam HENVCFGH   = 12'h61A;
  localparam HTVAL      = 12'h643;
  localparam VSTVAL    = 12'h243;
  localparam HIP        = 12'h644;
  localparam VSIP        = 12'h244;
  localparam HVIP       = 12'h645;
  localparam HTINST     = 12'h64A;
  localparam HGATP      = 12'h680;
  localparam HGEIP      = 12'hE12;
  localparam VSTVEC     = 12'h205;
  localparam VSSCRATCH  = 12'h240;
  localparam VSEPC      = 12'h241;
  localparam VSCAUSE    = 12'h242;
  localparam VSATP      = 12'h280;
  localparam VSTIMECMP  = 12'h24D;
  localparam VSTIMECMPH = 12'h25D;

  // hedeleg bit 0 is writable only when IALIGN=32. Compressed support implies IALIGN=16,
  // so mirror the existing medeleg handling and clear bit 0 when Zca/compressed is enabled.
  // Bits 18 and 19 are writable per the H-spec delegation table.
  localparam [63:0] HEDELEG_MASK = P.ZCA_SUPPORTED ? 64'h0000_0000_000C_B1FE
                                                   : 64'h0000_0000_000C_B1FF;
  // HIDELEG: only VS-level interrupts (VSSIP/VSTIP/VSEIP) are writable.
  localparam [15:0] HIDELEG_MASK = 16'h0444;
  localparam [11:0] HVIP_MASK    = 12'h444; // Only VSSIP[2], VSTIP[6], VSEIP[10] are writable (spec 7.4.4)
  localparam int unsigned GEILEN = (P.GEILEN > (P.XLEN-1)) ? (P.XLEN-1) : P.GEILEN;
  // Write Enables for CSR instructions
  logic WriteMTINSTM;
  logic WriteMTVAL2M;
  logic WriteMIPM;
  logic WriteHSTATUSM, WriteVSSTATUSM;
  logic WriteHEDELEGM, WriteHEDELEGHM;
  logic WriteHIDELEGM;
  logic WriteHTIMEDELTAM, WriteHTIMEDELTAHM;
  logic WriteHCOUNTERENM;
  logic WriteHGEIEM;
  logic WriteHENVCFGM, WriteHENVCFGHM;
  logic WriteHTVALM, WriteVSTVALM;
  logic WriteVSIPM;
  logic WriteHVIPM;
  logic WriteHIPM;
  logic WriteHTINSTM;
  logic WriteHGATPM;
  logic WriteVSTVECM;
  logic WriteVSSCRATCHM;
  logic WriteVSEPCM;
  logic WriteVSCAUSEM;
  logic WriteVSATPM;
  logic WriteVSTIMECMPM, WriteVSTIMECMPHM;
  logic AllowVSTimecmpAccessM;
  logic SretFromHSM, SretFromVSM;
  logic [P.XLEN-1:0] NextMtinstM;
  logic [P.XLEN-1:0] NextHtinstM;
  logic [P.XLEN-1:0] NextMtval2M;

  // Next Value Muxes
  logic [P.XLEN-1:0] NextHTVALM;
  logic [P.XLEN-1:0] NextVSCAUSEM;
  logic [63:0]       NextHEDELEGM;
  logic [15:0]       NextHIDELEGM;
  logic [11:0]       NextHVIPM;
  logic [15:0]       HIP_PENDING;
  logic [63:0]       TimeVirt;
  logic              VSTIP_CMP_PENDING;
  logic              HIP_SGEIP_PENDING, HIP_VSEIP_PENDING, HIP_VSTIP_PENDING, HIP_VSSIP_PENDING;
  logic [P.XLEN-1:0] VSTVECWriteValM;
  logic [63:0]       NextHENVCFGM, HENVCFG_REGW_INT;
  logic [1:0]        LegalizedHENVCFG_CBIE;
  logic              LegalVSatpModeM;
  logic [P.XLEN-1:0] LegalizedVSatpWriteValM;
  logic [P.XLEN-1:0] HGATPReadVal;
  logic [P.XLEN-1:0] HGEIMaskM;
  logic [P.XLEN-1:0] NextHGEIEM;
  logic [5:0]        HSTATUSVGEINWriteValM;
  logic [5:0]        LegalizedHSTATUSVGEINWriteValM;
  localparam logic [5:0] GEILEN_LIMIT = GEILEN[5:0];

  // CBIE has WARL encoding; 2'b10 is reserved and is legalized to 2'b00.
  assign LegalizedHENVCFG_CBIE = (CSRWriteValM[5:4] == 2'b10) ? 2'b00 : CSRWriteValM[5:4];
  // Hypervisor spec norm:hstatus-vgein_op: VGEIN is WLRL with legal values 0..GEILEN,
  // and VGEIN=0 selects no guest external source. Legalize unsupported values to 0.
  assign HSTATUSVGEINWriteValM = (P.XLEN == 32) ? {1'b0, CSRWriteValM[16:12]} : CSRWriteValM[17:12];
  assign LegalizedHSTATUSVGEINWriteValM = (HSTATUSVGEINWriteValM <= GEILEN_LIMIT) ? HSTATUSVGEINWriteValM : 6'b0;

  // CSR Write Validation Intermediates
  logic LegalHAccessM;
  logic LegalVSAccessM;
  logic ReadOnlyCSRM;
  logic ValidHWriteM, ValidVSWriteM;
  logic VSCSRDirectM;
  logic LegalAccessM;

  // Direct VS-CSR access uses CSR address class 0x2** (CSR[9:8]=2'b10).
  // Per H spec, when V=1 guest software accesses virtualized S-state via S-CSR
  // encodings (e.g., sstatus substitutes to vsstatus); direct 0x2** VS CSR
  // encodings from VS are treated as illegal accesses.
  assign VSCSRDirectM = VirtModeW & (InstrM[29:28] == 2'b10);

  // H-CSRs are accessible in M-Mode or HS-Mode.
  // VS-CSRs are accessible in M-Mode or HS-Mode; in VS-Mode they are accessed via S-CSR remapping.
  // Access is ILLEGAL in U-Mode (U/VU), and H-CSRs are illegal in VS-Mode.
  assign LegalHAccessM = (PrivilegeModeW == P.M_MODE) |
                        ((PrivilegeModeW == P.S_MODE) & ~VirtModeW);
  assign LegalVSAccessM = (PrivilegeModeW == P.M_MODE) |
                          ((PrivilegeModeW == P.S_MODE) & (~VirtModeW | ~VSCSRDirectM));

  assign ReadOnlyCSRM = (CSRAdrM == HGEIP);

  assign ValidHWriteM  = CSRSWriteM & LegalHAccessM & ~ReadOnlyCSRM;
  assign ValidVSWriteM = CSRSWriteM & LegalVSAccessM;

  // SRET context meanings for H support:
  // SretFromHSM: SRET executed in HS context (returns using hstatus.SPV).
  // SretFromVSM: SRET executed in VS context.
  assign SretFromHSM = sretM & (PrivilegeModeW == P.S_MODE) & ~VirtModeW;
  assign SretFromVSM = sretM & (PrivilegeModeW == P.S_MODE) &  VirtModeW;

  // mtinst/htinst/mtval2 are derived from the trapped instruction (InstrM); not yet implemented.
  // We write 0 on traps for now, which is spec compliant (indicating transformation not supported).
  assign NextMtinstM = TrapToM   ? '0 : CSRWriteValM;
  assign NextHtinstM = TrapToHSM ? '0 : CSRWriteValM;
  assign NextMtval2M = TrapToM   ? '0 : CSRWriteValM;

  // Write enables for each CSR (from CSR instruction)
  assign WriteMIPM        = CSRMWriteM & (CSRAdrM == MIP);
  assign WriteMTINSTM     = CSRMWriteM & (CSRAdrM == MTINST);
  assign WriteMTVAL2M     = CSRMWriteM & (CSRAdrM == MTVAL2);
  assign WriteHSTATUSM    = ValidHWriteM & (CSRAdrM == HSTATUS);
  assign WriteVSSTATUSM   = ValidVSWriteM & (CSRAdrM == VSSTATUS);
  assign WriteHEDELEGM    = ValidHWriteM & (CSRAdrM == HEDELEG);
  assign WriteHEDELEGHM   = (P.XLEN == 32) & (ValidHWriteM & (CSRAdrM == HEDELEGH));
  assign WriteHIDELEGM    = ValidHWriteM & (CSRAdrM == HIDELEG);
  assign WriteHIEM        = ValidHWriteM & (CSRAdrM == HIE);
  assign WriteVSIEM       = ValidVSWriteM & (CSRAdrM == VSIE);
  assign WriteHTIMEDELTAM = ValidHWriteM & (CSRAdrM == HTIMEDELTA);
  assign WriteHTIMEDELTAHM = (P.XLEN == 32) & (ValidHWriteM & (CSRAdrM == HTIMEDELTAH));
  assign WriteHCOUNTERENM = ValidHWriteM & (CSRAdrM == HCOUNTEREN);
  assign WriteHGEIEM      = ValidHWriteM & (CSRAdrM == HGEIE);
  assign WriteHENVCFGM    = ValidHWriteM & (CSRAdrM == HENVCFG);
  assign WriteHENVCFGHM   = (P.XLEN == 32) & (ValidHWriteM & (CSRAdrM == HENVCFGH));
  assign WriteHTVALM      = ValidHWriteM & (CSRAdrM == HTVAL);
  assign WriteVSTVALM     = ValidVSWriteM & (CSRAdrM == VSTVAL);
  assign WriteVSIPM       = ValidVSWriteM & (CSRAdrM == VSIP) & HIDELEG_REGW[2];
  assign WriteHVIPM       = ValidHWriteM & (CSRAdrM == HVIP);
  assign WriteHIPM        = ValidHWriteM & (CSRAdrM == HIP);
  assign WriteHTINSTM     = ValidHWriteM & (CSRAdrM == HTINST);
  assign WriteHGATPM      = P.VIRTMEM_SUPPORTED & ValidHWriteM & (CSRAdrM == HGATP) &
                            ((PrivilegeModeW == P.M_MODE) | ~STATUS_TVM);
  assign WriteVSTVECM     = ValidVSWriteM & (CSRAdrM == VSTVEC);
  assign WriteVSSCRATCHM  = ValidVSWriteM & (CSRAdrM == VSSCRATCH);
  assign WriteVSEPCM      = ValidVSWriteM & (CSRAdrM == VSEPC);
  assign WriteVSCAUSEM    = ValidVSWriteM & (CSRAdrM == VSCAUSE);

  // For unsupported MODE writes, choose satp-like behavior (ignore write).
  // This is spec-compliant for V=0 and required for satp writes when V=1.
  assign WriteVSATPM = P.VIRTMEM_SUPPORTED & ValidVSWriteM & (CSRAdrM == VSATP) &
                       LegalVSatpModeM;

  // vstimecmp is accessible from M-mode, from HS when MENVCFG_STCE & MCOUNTEREN_TM,
  // from VS when also HENVCFG_STCE & HCOUNTEREN_TM.
  assign AllowVSTimecmpAccessM = (PrivilegeModeW == P.M_MODE) |
    (PrivilegeModeW == P.S_MODE) & MENVCFG_STCE & MCOUNTEREN_TM &
    (~VirtModeW | HENVCFG_REGW[63] & HCOUNTEREN_REGW[1]);
  assign WriteVSTIMECMPM  = P.SSTC_SUPPORTED & ValidVSWriteM & (CSRAdrM == VSTIMECMP) & AllowVSTimecmpAccessM;
  assign WriteVSTIMECMPHM = P.SSTC_SUPPORTED & (P.XLEN == 32) & (ValidVSWriteM & (CSRAdrM == VSTIMECMPH)) & AllowVSTimecmpAccessM;

  if (P.XLEN == 64) begin : legal_vsatp_mode_64
    assign LegalVSatpModeM = (CSRWriteValM[63:60] == 4'h0) |
                             (P.SV39_SUPPORTED & (CSRWriteValM[63:60] == P.SV39)) |
                             (P.SV48_SUPPORTED & (CSRWriteValM[63:60] == P.SV48)) |
                             (P.SV57_SUPPORTED & (CSRWriteValM[63:60] == P.SV57));
    assign LegalizedVSatpWriteValM = CSRWriteValM;
  end else begin : legal_vsatp_mode_32
    assign LegalVSatpModeM = (CSRWriteValM[31] == 1'b0) | (P.SV32_SUPPORTED & CSRWriteValM[31]);
    assign LegalizedVSatpWriteValM = CSRWriteValM;
  end


  // MTINST
  // On traps to M, mtinst is written with trap information; writing zero is always compliant.
  flopenr #(P.XLEN) MTINSTreg(clk, reset, (WriteMTINSTM | TrapToM), NextMtinstM, MTINST_REGW);

  // MTVAL2
  // On traps to M, mtval2 is written with trap information; writing zero is always compliant.
  // TODO: Consider using paddr; mtval2 is written with either zero or the guest physical
  // address that faulted, shifted right by 2 bits
  flopenr #(P.XLEN) MTVAL2reg(clk, reset, (WriteMTVAL2M | TrapToM), NextMtval2M, MTVAL2_REGW);

  // HSTATUS
  // HS-visible virtualization control; SPV tracks prior V on HS traps and clears on HS sret.
  always_ff @(posedge clk)
    if (reset) begin
      HSTATUS_SPV   <= 1'b0;
      HSTATUS_SPVP  <= 1'b0;
      HSTATUS_GVA   <= 1'b0;
      HSTATUS_VSBE  <= 1'b0;
      HSTATUS_HU    <= 1'b0;
      HSTATUS_VGEIN <= 6'b0;
      HSTATUS_VTVM  <= 1'b0;
      HSTATUS_VTW   <= 1'b0;
      HSTATUS_VTSR  <= 1'b0;
    end else if (TrapToHSM) begin
      HSTATUS_SPV <= VirtModeW;
      if (VirtModeW)
        HSTATUS_SPVP <= PrivilegeModeW[0];
      HSTATUS_GVA <= TrapGVAM;
    end else if (SretFromHSM) begin
      // SRET in HS-mode (V=0) must clear hstatus.SPV.
      HSTATUS_SPV <= 1'b0;
    end else if (WriteHSTATUSM) begin
      HSTATUS_VSBE  <= P.BIGENDIAN_SUPPORTED & CSRWriteValM[5];
      HSTATUS_GVA   <= CSRWriteValM[6];
      HSTATUS_SPV   <= CSRWriteValM[7];
      HSTATUS_SPVP  <= CSRWriteValM[8];
      HSTATUS_HU    <= P.U_SUPPORTED & CSRWriteValM[9];
      HSTATUS_VGEIN <= LegalizedHSTATUSVGEINWriteValM;
      HSTATUS_VTVM  <= CSRWriteValM[20];
      HSTATUS_VTW   <= CSRWriteValM[21];
      HSTATUS_VTSR  <= CSRWriteValM[22];
    end

  assign HSTATUS_VSXL = (P.XLEN == 64) ? 2'b10 : 2'b00;
  assign HSTATUS_HUPMM = 2'b00;

  if (P.XLEN == 64) begin : hstatus64
    assign HSTATUS_REGW = {14'b0, HSTATUS_HUPMM, 14'b0, HSTATUS_VSXL, 9'b0,
                           HSTATUS_VTSR, HSTATUS_VTW, HSTATUS_VTVM, 2'b0,
                           HSTATUS_VGEIN, 2'b0, HSTATUS_HU, HSTATUS_SPVP,
                           HSTATUS_SPV, HSTATUS_GVA, HSTATUS_VSBE, 5'b0};
  end else begin : hstatus32
    assign HSTATUS_REGW = {9'b0, HSTATUS_VTSR, HSTATUS_VTW, HSTATUS_VTVM, 2'b0,
                           HSTATUS_VGEIN, 2'b0, HSTATUS_HU, HSTATUS_SPVP,
                           HSTATUS_SPV, HSTATUS_GVA, HSTATUS_VSBE, 5'b0};
  end

  // VSSTATUS
  // Guest-visible SSTATUS state, updated on VS traps/returns or CSR writes.
  assign VSSTATUS_XS  = 2'b00;  // Custom extensions not supported
  assign VSSTATUS_VS  = 2'b00;  // Vector not supported
  assign VSSTATUS_SPELP = 1'b0; // Landing pads not supported
  assign VSSTATUS_SDT = 1'b0;   // Double trap not supported
  assign VSSTATUS_SD  = (VSSTATUS_FS == 2'b11) | (VSSTATUS_XS == 2'b11) | (VSSTATUS_VS == 2'b11);
  assign VSSTATUS_UXL = HSTATUS_VSXL;

  if (P.XLEN == 64) begin : vsstatus64
    assign VSSTATUS_REGW = {VSSTATUS_SD, 29'b0, VSSTATUS_UXL, 7'b0,
                            VSSTATUS_SDT, VSSTATUS_SPELP, 3'b0,
                            VSSTATUS_MXR, VSSTATUS_SUM, 1'b0,
                            VSSTATUS_XS, VSSTATUS_FS, 2'b0, VSSTATUS_VS,
                            VSSTATUS_SPP, 1'b0, VSSTATUS_UBE, VSSTATUS_SPIE,
                            3'b0, VSSTATUS_SIE, 1'b0};
  end else begin : vsstatus32
    assign VSSTATUS_REGW = {VSSTATUS_SD, 6'b0, VSSTATUS_SDT, VSSTATUS_SPELP, 3'b0,
                            VSSTATUS_MXR, VSSTATUS_SUM, 1'b0,
                            VSSTATUS_XS, VSSTATUS_FS, 2'b0, VSSTATUS_VS,
                            VSSTATUS_SPP, 1'b0, VSSTATUS_UBE, VSSTATUS_SPIE,
                            3'b0, VSSTATUS_SIE, 1'b0};
  end

  // VSSTATUS update mirrors SSTATUS ordering in csrsr for easier sharing.
  always_ff @(posedge clk)
    if (reset) begin
      VSSTATUS_MXR     <= 1'b0;
      VSSTATUS_SUM     <= 1'b0;
      VSSTATUS_FS      <= 2'b00;
      VSSTATUS_SPP     <= 1'b0;
      VSSTATUS_SPIE    <= 1'b0;
      VSSTATUS_SIE     <= 1'b0;
      VSSTATUS_UBE     <= 1'b0;
    end else if (TrapToVSM) begin
      VSSTATUS_SPIE <= VSSTATUS_SIE;
      VSSTATUS_SIE  <= 1'b0;
      VSSTATUS_SPP  <= PrivilegeModeW[0];
    end else if (SretFromVSM) begin
      VSSTATUS_SIE  <= VSSTATUS_SPIE;
      VSSTATUS_SPIE <= 1'b1;
      VSSTATUS_SPP  <= 1'b0;
    end else if (WriteVSSTATUSM) begin
      VSSTATUS_MXR     <= CSRWriteValM[19];
      VSSTATUS_SUM     <= P.VIRTMEM_SUPPORTED & CSRWriteValM[18];
      VSSTATUS_FS      <= P.F_SUPPORTED ? CSRWriteValM[14:13] : 2'b00;
      VSSTATUS_SPP     <= CSRWriteValM[8];
      VSSTATUS_SPIE    <= CSRWriteValM[5];
      VSSTATUS_SIE     <= CSRWriteValM[1];
      VSSTATUS_UBE     <= P.U_SUPPORTED & P.BIGENDIAN_SUPPORTED & CSRWriteValM[6];
    end else if (VirtModeW & (FRegWriteM | WriteFRMM | SetOrWriteFFLAGSM)) begin
      VSSTATUS_FS  <= 2'b11;
    end

  // Exception and Interrupt Delegation Registers
  // Mask off read-only zero bits (see ISA 15.2.2)
  if (P.XLEN == 64) begin : hedeleg_update_64
    always_comb begin
      NextHEDELEGM = HEDELEG_REGW;
      if (WriteHEDELEGM) NextHEDELEGM = CSRWriteValM & HEDELEG_MASK;
    end
  end else begin : hedeleg_update_32
    always_comb begin
      NextHEDELEGM = HEDELEG_REGW;
      if (WriteHEDELEGM)  NextHEDELEGM[31:0]  = CSRWriteValM[31:0] & HEDELEG_MASK[31:0];
      if (WriteHEDELEGHM) NextHEDELEGM[63:32] = CSRWriteValM[31:0] & HEDELEG_MASK[63:32];
    end
  end
  flopenr #(64) HEDELEGreg(clk, reset, (WriteHEDELEGM | WriteHEDELEGHM), NextHEDELEGM, HEDELEG_REGW);

  assign NextHIDELEGM = WriteHIDELEGM ? (CSRWriteValM[15:0] & HIDELEG_MASK) : HIDELEG_REGW;
  flopenr #(16) HIDELEGreg(clk, reset, WriteHIDELEGM, NextHIDELEGM, HIDELEG_REGW);

  // Interrupt Pending
  // VSIP/VSIE are aliases of HIP/HIE when delegated; otherwise read-only zero.
  // VSTIP can be driven by timer compare when Sstc is implemented and STCE is enabled.
  assign TimeVirt = MTIME_CLINT + HTIMEDELTA_REGW;
  assign VSTIP_CMP_PENDING = P.SSTC_SUPPORTED & HENVCFG_REGW[63] & (TimeVirt >= VSTIMECMP_REGW);

  if (GEILEN == 0) begin : hgeip_vgein_geilen0
    assign HGEIP_VGEIN_BIT = 1'b0;
  end else begin : hgeip_vgein_geilen_nz
    if (P.XLEN == 64) begin : hgeip_vgein_sel64
      always_comb begin
        HGEIP_VGEIN_BIT = HGEIP_REGW[HSTATUS_VGEIN];
      end
    end else begin : hgeip_vgein_sel32
      always_comb begin
        HGEIP_VGEIN_BIT = 1'b0;
        if (HSTATUS_VGEIN < 6'd32)
          HGEIP_VGEIN_BIT = HGEIP_REGW[HSTATUS_VGEIN[4:0]];
      end
    end
  end

  assign HIP_SGEIP_PENDING = |(HGEIP_REGW & HGEIE_REGW);
  // TODO: OR in any platform-specific VS external interrupt signal when that source is integrated.
  assign HIP_VSEIP_PENDING = HVIP_REGW[10] | HGEIP_VGEIN_BIT;
  assign HIP_VSTIP_PENDING = HVIP_REGW[6]  | VSTIP_CMP_PENDING;
  assign HIP_VSSIP_PENDING = HVIP_REGW[2];
  assign HIP_PENDING = {3'b0, HIP_SGEIP_PENDING, 1'b0, HIP_VSEIP_PENDING, 3'b0,
                        HIP_VSTIP_PENDING, 3'b0, HIP_VSSIP_PENDING, 2'b0};
  assign HIP_MIP_REGW = HIP_PENDING;

  assign VSIE_REGW = (HIE_REGW[11:0] & HIDELEG_REGW[11:0] & HIDELEG_MASK[11:0]) >> 1;

  // hvip holds the writable virtual interrupt sources.
  // hip.VSSIP aliases hvip.VSSIP, and vsip.SSIP aliases hip.VSSIP only when hideleg[2] is set.
  always_comb begin
    NextHVIPM = HVIP_REGW;
    if (WriteHVIPM)
      NextHVIPM = (HVIP_REGW & ~HVIP_MASK) | (CSRWriteValM[11:0] & HVIP_MASK);
    if (WriteHIPM)
      NextHVIPM[2] = CSRWriteValM[2];
    if (WriteVSIPM)
      NextHVIPM[2] = CSRWriteValM[1];
    if (WriteMIPM)
      NextHVIPM[2] = CSRWriteValM[2];
  end
  flopenr #(12) HVIPreg(clk, reset, (WriteHVIPM | WriteHIPM | WriteVSIPM | WriteMIPM), NextHVIPM, HVIP_REGW);
  assign VSIP_REGW = (HIP_PENDING[11:0] & HIDELEG_REGW[11:0]) >> 1;

  // hgeie bits GEILEN:1 are writable; all others are read-only zero.
  assign HGEIMaskM = {{(P.XLEN-GEILEN-1){1'b0}}, {GEILEN{1'b1}}, 1'b0};
  assign HGEIP_REGW = HGEIPIn & HGEIMaskM;
  assign NextHGEIEM = CSRWriteValM & HGEIMaskM;
  flopenr #(P.XLEN) HGEIEreg(clk, reset, WriteHGEIEM, NextHGEIEM, HGEIE_REGW);

  // HTVAL: Written by CSR instructions and by hardware on traps
  assign NextHTVALM = TrapToHSM ? NextHtvalM : CSRWriteValM;
  flopenr #(P.XLEN) HTVALreg(clk, reset, (WriteHTVALM | TrapToHSM), NextHTVALM, HTVAL_REGW);

  // HTINST: Written by CSR instructions and by hardware on traps
  // If TrapToHSM, write 0 (placeholder). Else write CSR val.
  flopenr #(P.XLEN) HTINSTreg(clk, reset, (WriteHTINSTM | TrapToHSM), NextHtinstM, HTINST_REGW);

  // VS CSRs: Guest-visible S-mode state
  // Match stvec/mtvec legalization: vectored mode requires the tighter BASE alignment.
  assign VSTVECWriteValM = CSRWriteValM[0] ? {CSRWriteValM[P.XLEN-1:6], 6'b000001}
                                           : {CSRWriteValM[P.XLEN-1:2], 2'b00};
  flopenr #(P.XLEN) VSTVECreg(clk, reset, WriteVSTVECM, VSTVECWriteValM, VSTVEC_REGW);
  flopenr #(P.XLEN) VSSCRATCHreg(clk, reset, WriteVSSCRATCHM, CSRWriteValM, VSSCRATCH_REGW);
  flopenr #(P.XLEN) VSEPCreg(clk, reset, (TrapToVSM | WriteVSEPCM), TrapToVSM ? NextEPCM : CSRWriteValM, VSEPC_REGW);
  // VSCAUSE is WLRL; allow CSR writes to set full VSXLEN value, but let traps override.
  assign NextVSCAUSEM = TrapToVSM ? {NextCauseM[5], {(P.XLEN-6){1'b0}}, NextCauseM[4:0]}
                                : CSRWriteValM;
  flopenr #(P.XLEN) VSCAUSEreg(clk, reset, (TrapToVSM | WriteVSCAUSEM), NextVSCAUSEM, VSCAUSE_REGW);
  flopenr #(P.XLEN) VSTVALreg(clk, reset, (TrapToVSM | WriteVSTVALM), TrapToVSM ? NextTvalM : CSRWriteValM, VSTVAL_REGW);
  if (P.VIRTMEM_SUPPORTED)
    flopenr #(P.XLEN) VSATPreg(clk, reset, WriteVSATPM, LegalizedVSatpWriteValM, VSATP_REGW);
  else
    assign VSATP_REGW = '0;

  if (P.SSTC_SUPPORTED) begin : vstc
    if (P.XLEN == 64) begin : vstc64
      flopenr #(P.XLEN) VSTIMECMPreg(clk, reset, WriteVSTIMECMPM, CSRWriteValM, VSTIMECMP_REGW);
    end else begin : vstc32
      flopenr #(P.XLEN) VSTIMECMPreg(clk, reset, WriteVSTIMECMPM, CSRWriteValM, VSTIMECMP_REGW[31:0]);
      flopenr #(P.XLEN) VSTIMECMPHreg(clk, reset, WriteVSTIMECMPHM, CSRWriteValM, VSTIMECMP_REGW[63:32]);
    end
  end else assign VSTIMECMP_REGW = '0;

  // Address Translation
  if (P.VIRTMEM_SUPPORTED) begin : hgatp
    if (P.XLEN == 64) begin : hgatp64
      logic LegalHgatpModeM;
      logic [P.XLEN-1:0] LegalizedHgatpWriteValM;

      assign LegalHgatpModeM = (CSRWriteValM[63:60] == 4'h0) |
                               (P.SV39_SUPPORTED & (CSRWriteValM[63:60] == 4'h8)) |
                               (P.SV48_SUPPORTED & (CSRWriteValM[63:60] == 4'h9)) |
                               (P.SV57_SUPPORTED & (CSRWriteValM[63:60] == 4'hA));

      // hgatp unsupported MODE writes are WARL, not ignored.
      always_comb begin
        LegalizedHgatpWriteValM = CSRWriteValM;
        LegalizedHgatpWriteValM[59:58] = 2'b00;
        LegalizedHgatpWriteValM[1:0]   = 2'b00;
        if (~LegalHgatpModeM)
          LegalizedHgatpWriteValM[63:60] = 4'h0;
      end

      assign HGATPReadVal = {HGATP_REGW[63:60], 2'b00, HGATP_REGW[57:2], 2'b00};
      flopenr #(P.XLEN) HGATPreg(clk, reset, WriteHGATPM, LegalizedHgatpWriteValM, HGATP_REGW);
    end else begin : hgatp32
      logic [P.XLEN-1:0] LegalizedHgatpWriteValM;

      always_comb begin
        LegalizedHgatpWriteValM = CSRWriteValM;
        LegalizedHgatpWriteValM[30:29] = 2'b00;
        LegalizedHgatpWriteValM[1:0]   = 2'b00;
      end

      assign HGATPReadVal = {HGATP_REGW[31], 2'b00, HGATP_REGW[28:2], 2'b00};
      flopenr #(P.XLEN) HGATPreg(clk, reset, WriteHGATPM, LegalizedHgatpWriteValM, HGATP_REGW);
    end
  end else begin : no_hgatp
    assign HGATPReadVal = '0;
    assign HGATP_REGW = '0;
  end

  // Configuration & Timers
  flopenr #(32) HCOUNTERENreg(clk, reset, WriteHCOUNTERENM, CSRWriteValM[31:0], HCOUNTEREN_REGW);

  // HENVCFG: Conditional bit masking based on supported features (similar to MENVCFG in csrm.sv)
  if (P.XLEN == 64) begin : henvcfg_update_64
    always_comb begin
      NextHENVCFGM = HENVCFG_REGW_INT;
      if (WriteHENVCFGM) begin
        // Mask WPRI/unsupported fields to 0 per spec.
        NextHENVCFGM[31:0] = {
          16'b0,                                  // 31:16 WPRI
          8'b0,                                   // 15:8  WPRI
          CSRWriteValM[7]  & P.ZICBOZ_SUPPORTED,  // CBZE
          CSRWriteValM[6]  & P.ZICBOM_SUPPORTED,  // CBCFE
          LegalizedHENVCFG_CBIE & {2{P.ZICBOM_SUPPORTED}}, // CBIE (WARL, 10b reserved)
          1'b0,                                   // SSE (Zicfiss) unsupported
          1'b0,                                   // LPE (Zicfilp) unsupported
          1'b0,                                   // WPRI
          CSRWriteValM[0]                         // FIOM
        };
        NextHENVCFGM[63:32] = {
          CSRWriteValM[63] & P.SSTC_SUPPORTED & MENVCFG_STCE,      // STCE
          CSRWriteValM[62] & P.SVPBMT_SUPPORTED & MENVCFG_PBMTE,   // PBMTE
          CSRWriteValM[61] & P.SVADU_SUPPORTED & MENVCFG_ADUE,     // ADUE
          1'b0,                                   // WPRI
          1'b0,                                   // DTE (Ssdbltrp) unsupported
          1'b0,                                   // WPRI
          10'b0,                                  // 57:48 WPRI
          14'b0,                                  // 47:34 WPRI
          2'b0                                    // PMM (Ssnpm) unsupported
        };
      end
    end
  end else begin : henvcfg_update_32
    always_comb begin
      NextHENVCFGM = HENVCFG_REGW_INT;
      if (WriteHENVCFGM) begin
        // Mask WPRI/unsupported fields to 0 per spec.
        NextHENVCFGM[31:0] = {
          16'b0,                                  // 31:16 WPRI
          8'b0,                                   // 15:8  WPRI
          CSRWriteValM[7]  & P.ZICBOZ_SUPPORTED,  // CBZE
          CSRWriteValM[6]  & P.ZICBOM_SUPPORTED,  // CBCFE
          LegalizedHENVCFG_CBIE & {2{P.ZICBOM_SUPPORTED}}, // CBIE (WARL, 10b reserved)
          1'b0,                                   // SSE (Zicfiss) unsupported
          1'b0,                                   // LPE (Zicfilp) unsupported
          1'b0,                                   // WPRI
          CSRWriteValM[0]                         // FIOM
        };
      end
      if (WriteHENVCFGHM) begin
        // Mask WPRI/unsupported fields to 0 per spec.
        NextHENVCFGM[63:32] = {
          CSRWriteValM[31] & P.SSTC_SUPPORTED & MENVCFG_STCE,      // STCE
          CSRWriteValM[30] & P.SVPBMT_SUPPORTED & MENVCFG_PBMTE,   // PBMTE
          CSRWriteValM[29] & P.SVADU_SUPPORTED & MENVCFG_ADUE,     // ADUE
          1'b0,                                   // WPRI
          1'b0,                                   // DTE (Ssdbltrp) unsupported
          1'b0,                                   // WPRI
          10'b0,                                  // 57:48 WPRI
          14'b0,                                  // 47:34 WPRI
          2'b0                                    // PMM (Ssnpm) unsupported
        };
      end
    end
  end

  flopenr #(64) HENVCFGreg(clk, reset, (WriteHENVCFGM | WriteHENVCFGHM), NextHENVCFGM, HENVCFG_REGW_INT);
  // menvcfg can dynamically force STCE/PBMTE/ADUE to read as zero in henvcfg.
  assign HENVCFG_REGW = {HENVCFG_REGW_INT[63] & MENVCFG_STCE,
                         HENVCFG_REGW_INT[62] & MENVCFG_PBMTE,
                         HENVCFG_REGW_INT[61] & MENVCFG_ADUE,
                         HENVCFG_REGW_INT[60:0]};
  if (P.XLEN == 64) begin : htimedelta_regs_64
    flopenr #(P.XLEN) HTIMEDELTAreg(clk, reset, WriteHTIMEDELTAM, CSRWriteValM, HTIMEDELTA_REGW);
  end else begin : htimedelta_regs_32
    flopenr #(P.XLEN) HTIMEDELTAreg(clk, reset, WriteHTIMEDELTAM, CSRWriteValM, HTIMEDELTA_REGW[31:0]);
    flopenr #(P.XLEN) HTIMEDELTAHreg(clk, reset, WriteHTIMEDELTAHM, CSRWriteValM, HTIMEDELTA_REGW[63:32]);
  end
  // CSR Read and Illegal Access Logic
  always_comb begin : csrrh
    CSRHReadValM = '0;
    LegalAccessM = 1'b0;

    case (CSRAdrM)
      MTINST:     begin LegalAccessM = (PrivilegeModeW == P.M_MODE); CSRHReadValM = MTINST_REGW; end
      MTVAL2:     begin LegalAccessM = (PrivilegeModeW == P.M_MODE); CSRHReadValM = MTVAL2_REGW; end
      HSTATUS:    begin LegalAccessM = LegalHAccessM; CSRHReadValM = HSTATUS_REGW; end
      HEDELEG:    begin LegalAccessM = LegalHAccessM; CSRHReadValM = HEDELEG_REGW[P.XLEN-1:0]; end
      HEDELEGH:   begin LegalAccessM = LegalHAccessM & (P.XLEN == 32); CSRHReadValM = {{(P.XLEN-32){1'b0}}, HEDELEG_REGW[63:32]}; end
      HIDELEG:    begin LegalAccessM = LegalHAccessM; CSRHReadValM = {{(P.XLEN-16){1'b0}}, HIDELEG_REGW}; end
      HIE:        begin LegalAccessM = LegalHAccessM; CSRHReadValM = {{(P.XLEN-16){1'b0}}, HIE_REGW}; end
      HTIMEDELTA: begin LegalAccessM = LegalHAccessM; CSRHReadValM = HTIMEDELTA_REGW[P.XLEN-1:0]; end
      HTIMEDELTAH:begin LegalAccessM = LegalHAccessM & (P.XLEN == 32); CSRHReadValM = {{(P.XLEN-32){1'b0}}, HTIMEDELTA_REGW[63:32]}; end
      HCOUNTEREN: begin LegalAccessM = LegalHAccessM; CSRHReadValM = {{(P.XLEN-32){1'b0}}, HCOUNTEREN_REGW}; end
      HGEIE:      begin LegalAccessM = LegalHAccessM; CSRHReadValM = HGEIE_REGW; end
      HENVCFG:    begin LegalAccessM = LegalHAccessM; CSRHReadValM = HENVCFG_REGW[P.XLEN-1:0]; end
      HENVCFGH:   begin LegalAccessM = LegalHAccessM & (P.XLEN == 32); CSRHReadValM = {{(P.XLEN-32){1'b0}}, HENVCFG_REGW[63:32]}; end
      HTVAL:      begin LegalAccessM = LegalHAccessM; CSRHReadValM = HTVAL_REGW; end
      HIP:        begin LegalAccessM = LegalHAccessM; CSRHReadValM = {{(P.XLEN-16){1'b0}}, HIP_PENDING}; end
      HVIP:       begin LegalAccessM = LegalHAccessM; CSRHReadValM = {{(P.XLEN-12){1'b0}}, HVIP_REGW}; end
      HTINST:     begin LegalAccessM = LegalHAccessM; CSRHReadValM = HTINST_REGW; end
      HGATP:      begin LegalAccessM = LegalHAccessM & ((PrivilegeModeW == P.M_MODE) | ~STATUS_TVM); CSRHReadValM = HGATPReadVal; end
      HGEIP:      begin LegalAccessM = LegalHAccessM; CSRHReadValM = HGEIP_REGW; end

      VSSTATUS:   begin LegalAccessM = LegalVSAccessM; CSRHReadValM = VSSTATUS_REGW; end
      VSIE:       begin LegalAccessM = LegalVSAccessM; CSRHReadValM = {{(P.XLEN-12){1'b0}}, VSIE_REGW}; end
      VSTVEC:     begin LegalAccessM = LegalVSAccessM; CSRHReadValM = VSTVEC_REGW; end
      VSSCRATCH:  begin LegalAccessM = LegalVSAccessM; CSRHReadValM = VSSCRATCH_REGW; end
      VSEPC:      begin LegalAccessM = LegalVSAccessM; CSRHReadValM = VSEPC_REGW; end
      VSCAUSE:    begin LegalAccessM = LegalVSAccessM; CSRHReadValM = VSCAUSE_REGW; end
      VSTVAL:     begin LegalAccessM = LegalVSAccessM; CSRHReadValM = VSTVAL_REGW; end
      VSIP:       begin LegalAccessM = LegalVSAccessM; CSRHReadValM = {{(P.XLEN-12){1'b0}}, VSIP_REGW}; end
      VSATP:      begin LegalAccessM = LegalVSAccessM; CSRHReadValM = VSATP_REGW; end
      VSTIMECMP:  begin LegalAccessM = LegalVSAccessM & P.SSTC_SUPPORTED & AllowVSTimecmpAccessM; CSRHReadValM = VSTIMECMP_REGW[P.XLEN-1:0]; end
      VSTIMECMPH: begin LegalAccessM = LegalVSAccessM & P.SSTC_SUPPORTED & (P.XLEN == 32) & AllowVSTimecmpAccessM; CSRHReadValM = {{(P.XLEN-32){1'b0}}, VSTIMECMP_REGW[63:32]}; end

      default:    begin LegalAccessM = 1'b0; CSRHReadValM = '0; end
    endcase
    if (~LegalAccessM) CSRHReadValM = '0;
    IllegalCSRHAccessM = ~LegalAccessM;
    if (CSRWriteM && ReadOnlyCSRM)
      IllegalCSRHAccessM = 1'b1;
  end

endmodule
