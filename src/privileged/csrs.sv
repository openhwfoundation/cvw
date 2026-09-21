///////////////////////////////////////////
// csrs.sv
//
// Written: David_Harris@hmc.edu 9 January 2021
// Modified:
//          dottolia@hmc.edu 3 May 2021 - fix bug with stvec getting wrong value
//
// Purpose: Supervisor-Mode Control and Status Registers
//          See RISC-V Privileged Mode Specification 20190608
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

module csrs import cvw::*;  #(parameter cvw_t P) (
  input  logic              clk, reset,
  input  logic              CSRSWriteM, STrapM,
  input  logic [11:0]       CSRAdrM,
  input  logic [P.XLEN-1:0] NextEPCM, NextMtvalM, SSTATUS_REGW,
  input  logic [5:0]        NextCauseM,
  input  logic              STATUS_TVM,
  input  logic [P.XLEN-1:0] CSRWriteValM,
  input  logic [1:0]        PrivilegeModeW,
  output logic [P.XLEN-1:0] CSRSReadValM, STVEC_REGW,
  output logic [P.XLEN-1:0] SEPC_REGW,
  output logic [31:0]       SCOUNTEREN_REGW,
  output logic [P.XLEN-1:0] SATP_REGW,
  input  logic [11:0]       MIP_REGW, MIE_REGW, MIDELEG_REGW,
  input  logic [63:0]       MTIME_CLINT,
  input  logic              STCE,
  output logic              WriteSSTATUSM,
  output logic              IllegalCSRSAccessM,
  output logic              STimerInt,
  output logic [P.XLEN-1:0] SENVCFG_REGW

);

  // Supervisor CSRs
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
  // Constants

  logic                    WriteSTVECM;
  logic                    WriteSSCRATCHM, WriteSEPCM;
  logic                    WriteSCAUSEM, WriteSTVALM, WriteSATPM, WriteSCOUNTERENM;
  logic                    WriteSTIMECMPM, WriteSTIMECMPHM;
  logic                    WriteSENVCFGM;

  logic [P.XLEN-1:0]       SSCRATCH_REGW, STVAL_REGW, SCAUSE_REGW;
  logic [P.XLEN-1:0]       SENVCFG_WriteValM;
  logic [P.XLEN-1:0]               TVECWriteValM;

  logic [63:0]             STIMECMP_REGW;

  // write enables
  assign WriteSSTATUSM    = CSRSWriteM & (CSRAdrM == SSTATUS);
  assign WriteSTVECM      = CSRSWriteM & (CSRAdrM == STVEC);
  assign WriteSSCRATCHM   = CSRSWriteM & (CSRAdrM == SSCRATCH);
  assign WriteSEPCM       = STrapM | (CSRSWriteM & (CSRAdrM == SEPC));
  assign WriteSCAUSEM     = STrapM | (CSRSWriteM & (CSRAdrM == SCAUSE));
  assign WriteSTVALM      = STrapM | (CSRSWriteM & (CSRAdrM == STVAL));
  if(P.XLEN == 64) begin
    logic LegalSatpModeM;
    assign LegalSatpModeM = CSRWriteValM[63:60] == 0 |
                           (P.SV39_SUPPORTED & CSRWriteValM[63:60] == P.SV39) |
                           (P.SV48_SUPPORTED & CSRWriteValM[63:60] == P.SV48) |
                           (P.SV57_SUPPORTED & CSRWriteValM[63:60] == P.SV57); // Only change Satp if the mode is supported
    assign WriteSATPM     = CSRSWriteM & (CSRAdrM == SATP) & (PrivilegeModeW == P.M_MODE | ~STATUS_TVM) & LegalSatpModeM & P.SV39_SUPPORTED;
  end else  // RV32
    assign WriteSATPM     = CSRSWriteM & (CSRAdrM == SATP) & (PrivilegeModeW == P.M_MODE | ~STATUS_TVM) & P.SV32_SUPPORTED;
  assign WriteSCOUNTERENM = CSRSWriteM & (CSRAdrM == SCOUNTEREN);
  assign WriteSENVCFGM    = CSRSWriteM & (CSRAdrM == SENVCFG);
  assign WriteSTIMECMPM   = CSRSWriteM & (CSRAdrM == STIMECMP) & STCE;
  assign WriteSTIMECMPHM  = CSRSWriteM & (CSRAdrM == STIMECMPH) & STCE & (P.XLEN == 32);

  // CSRs
  assign TVECWriteValM = CSRWriteValM[0] ? {CSRWriteValM[P.XLEN-1:6], 6'b000001} : {CSRWriteValM[P.XLEN-1:2], 2'b00}; // could share this with MTVEC, but reduces to 4-bit AND to mask bits [5:2]
  flopenr #(P.XLEN) STVECreg(clk, reset, WriteSTVECM, TVECWriteValM, STVEC_REGW);
  flopenr #(P.XLEN) SSCRATCHreg(clk, reset, WriteSSCRATCHM, CSRWriteValM, SSCRATCH_REGW);
  flopenr #(P.XLEN) SEPCreg(clk, reset, WriteSEPCM, NextEPCM, SEPC_REGW);
  flopenr #(P.XLEN) SCAUSEreg(clk, reset, WriteSCAUSEM, {NextCauseM[5], {(P.XLEN-6){1'b0}}, NextCauseM[4:0]}, SCAUSE_REGW);
  flopenr #(P.XLEN) STVALreg(clk, reset, WriteSTVALM, NextMtvalM, STVAL_REGW);
  if (P.VIRTMEM_SUPPORTED)
    flopenr #(P.XLEN) SATPreg(clk, reset, WriteSATPM, CSRWriteValM, SATP_REGW);
  else
    assign SATP_REGW = '0; // hardwire to zero if virtual memory not supported
  flopenr #(32)   SCOUNTERENreg(clk, reset, WriteSCOUNTERENM, CSRWriteValM[31:0], SCOUNTEREN_REGW);
  if (P.SSTC_SUPPORTED) begin : sstc
    if (P.XLEN == 64) begin : sstc64
      flopenr #(P.XLEN) STIMECMPreg(clk, reset, WriteSTIMECMPM, CSRWriteValM, STIMECMP_REGW);
    end else begin : sstc32
      flopenr #(P.XLEN) STIMECMPreg(clk, reset, WriteSTIMECMPM, CSRWriteValM, STIMECMP_REGW[31:0]);
      flopenr #(P.XLEN) STIMECMPHreg(clk, reset, WriteSTIMECMPHM, CSRWriteValM, STIMECMP_REGW[63:32]);
    end
  end else assign STIMECMP_REGW = '0;

  // Supervisor timer interrupt logic
  // Spec is a bit peculiar - Machine timer interrupts are produced in CLINT, while Supervisor timer interrupts are in CSRs
  if (P.SSTC_SUPPORTED)
   assign STimerInt  = ({1'b0, MTIME_CLINT} >= {1'b0, STIMECMP_REGW}); // unsigned comparison
  else
    assign STimerInt = 1'b0;

  logic [1:0] LegalizedCBIE;
  assign LegalizedCBIE = CSRWriteValM[5:4] == 2'b10 ? SENVCFG_REGW[5:4] : CSRWriteValM[5:4]; // Assume WARL for reserved CBIE = 10, keeps old value
  assign SENVCFG_WriteValM = {
    {(P.XLEN-8){1'b0}},
    CSRWriteValM[7]   & P.ZICBOZ_SUPPORTED,
    CSRWriteValM[6]   & P.ZICBOM_SUPPORTED,
    LegalizedCBIE     & {2{P.ZICBOM_SUPPORTED}},
    3'b0,
    CSRWriteValM[0]   & P.VIRTMEM_SUPPORTED
  };

  flopenr #(P.XLEN) SENVCFGreg(clk, reset, WriteSENVCFGM, SENVCFG_WriteValM, SENVCFG_REGW);

  // CSR Reads
  always_comb begin : csrr
    CSRSReadValM = '0;
    IllegalCSRSAccessM = 1'b0;
    case (CSRAdrM)
      SSTATUS:   CSRSReadValM = SSTATUS_REGW;
      STVEC:     CSRSReadValM = STVEC_REGW;
      SIP:       CSRSReadValM = {{(P.XLEN-12){1'b0}}, MIP_REGW & 12'h222 & MIDELEG_REGW}; // only read supervisor fields
      SIE:       CSRSReadValM = {{(P.XLEN-12){1'b0}}, MIE_REGW & 12'h222 & MIDELEG_REGW}; // only read supervisor fields
      SSCRATCH:  CSRSReadValM = SSCRATCH_REGW;
      SEPC:      CSRSReadValM = SEPC_REGW;
      SCAUSE:    CSRSReadValM = SCAUSE_REGW;
      STVAL:     CSRSReadValM = STVAL_REGW;
      SATP:      if (P.VIRTMEM_SUPPORTED & (PrivilegeModeW == P.M_MODE | ~STATUS_TVM)) CSRSReadValM = SATP_REGW;
                 else IllegalCSRSAccessM = 1'b1;
      SCOUNTEREN:CSRSReadValM = {{(P.XLEN-32){1'b0}}, SCOUNTEREN_REGW};
      SENVCFG:   CSRSReadValM = SENVCFG_REGW;
      STIMECMP:  if (STCE) CSRSReadValM = STIMECMP_REGW[P.XLEN-1:0];
                 else IllegalCSRSAccessM = 1'b1;
      STIMECMPH: if (STCE & P.XLEN == 32) CSRSReadValM = {{(P.XLEN-32){1'b0}}, STIMECMP_REGW[63:32]};
                 else IllegalCSRSAccessM = 1'b1; // not supported for RV64
      default:   IllegalCSRSAccessM = 1'b1;
    endcase
  end
endmodule
