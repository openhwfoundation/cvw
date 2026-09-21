///////////////////////////////////////////
// csrm.sv
//
// Written: David_Harris@hmc.edu 9 January 2021
// Modified:
//          dottolia@hmc.edu 7 April 2021
//
// Purpose: Machine-Mode Control and Status Registers
//          See RISC-V Privileged Mode Specification 20190608
// Note: the CSRs do not support the following optional features
//   - Disabling portions of the instruction set with bits of the MISA register
//   - Changing from RV64 to RV32 by writing the SXL/UXL bits of the STATUS register
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

module csrm  import cvw::*;  #(parameter cvw_t P) (
  input  logic                     clk, reset,
  input  logic                     UngatedCSRMWriteM, CSRMWriteM, MTrapM,
  input  logic [11:0]              CSRAdrM,
  input  logic [P.XLEN-1:0]        NextEPCM, NextMtvalM, MSTATUS_REGW, MSTATUSH_REGW,
  input  logic [5:0]               NextCauseM,
  input  logic [P.XLEN-1:0]        CSRWriteValM,
  input  logic [11:0]              MIP_REGW, MIE_REGW,
  output logic [P.XLEN-1:0]        CSRMReadValM, MTVEC_REGW,
  output logic [P.XLEN-1:0]        MEPC_REGW,
  output logic [31:0]              MCOUNTEREN_REGW, MCOUNTINHIBIT_REGW,
  output logic [15:0]              MEDELEG_REGW,
  output logic [11:0]              MIDELEG_REGW,
  /* verilator lint_off UNDRIVEN */ // PMP registers are only used when PMP_ENTRIES > 0
  output var logic [P.PA_BITS-3:0] PMPADDR_ARRAY_REGW[P.PMP_ENTRIES-1:0],
  output var logic [7:0]           PMPCFG_ARRAY_REGW[P.PMP_ENTRIES-1:0],
  /* verilator lint_on UNDRIVEN */
  output logic                     WriteMSTATUSM, WriteMSTATUSHM,
  output logic                     IllegalCSRMAccessM, IllegalCSRMWriteReadonlyM,
  output logic [63:0]              MENVCFG_REGW
);

  logic [P.PA_BITS-3:0]            PMPADDR_ARRAY_PREGRAIN_REGW[P.PMP_ENTRIES-1:0];
  logic [P.XLEN-1:0]               MISA_REGW, MHARTID_REGW;
  logic [P.XLEN-1:0]               MSCRATCH_REGW, MTVAL_REGW, MCAUSE_REGW;
  logic [P.XLEN-1:0]               MENVCFGH_REGW;
  logic [P.XLEN-1:0]               TVECWriteValM;
  logic                            WriteMTVECM, WriteMEDELEGM, WriteMIDELEGM;
  logic                            WriteMSCRATCHM, WriteMEPCM, WriteMCAUSEM, WriteMTVALM;
  logic                            WriteMCOUNTERENM, WriteMCOUNTINHIBITM;

  // Machine CSRs
  localparam MVENDORID     = 12'hF11;
  localparam MARCHID       = 12'hF12; // github.com/riscv/riscv-isa-manual/blob/main/marchid.md
  localparam MIMPID        = 12'hF13;
  localparam MHARTID       = 12'hF14;
  localparam MCONFIGPTR    = 12'hF15;
  localparam MSTATUS       = 12'h300;
  localparam MISA_ADR      = 12'h301;
  localparam MEDELEG       = 12'h302;
  localparam MIDELEG       = 12'h303;
  localparam MIE           = 12'h304;
  localparam MTVEC         = 12'h305;
  localparam MCOUNTEREN    = 12'h306;
  localparam MENVCFG       = 12'h30A;
  localparam MSTATUSH      = 12'h310;
  localparam MENVCFGH      = 12'h31A;
  localparam MCOUNTINHIBIT = 12'h320;
  localparam MSCRATCH      = 12'h340;
  localparam MEPC          = 12'h341;
  localparam MCAUSE        = 12'h342;
  localparam MTVAL         = 12'h343;
  localparam MIP           = 12'h344;
  localparam PMPCFG0       = 12'h3A0;
  // .. up to 15 more at consecutive addresses
  localparam PMPADDR0      = 12'h3B0;
  // ... up to 63 more at consecutive addresses
  /* verilator lint_off UNUSEDPARAM */
  localparam TSELECT       = 12'h7A0;
  localparam TDATA1        = 12'h7A1;
  localparam TDATA2        = 12'h7A2;
  localparam TDATA3        = 12'h7A3;
  localparam DCSR          = 12'h7B0;
  localparam DPC           = 12'h7B1;
  localparam DSCRATCH0     = 12'h7B2;
  localparam DSCRATCH1     = 12'h7B3;
  /* verilator lint_off UNUSEDPARAM */
  // Constants
  localparam ZERO = {(P.XLEN){1'b0}};
  // when compressed instructions are supported, there can't be misaligned instructions
  localparam MEDELEG_MASK  = P.ZCA_SUPPORTED ? 16'hB3FE : 16'hB3FF;
  localparam MIDELEG_MASK  = 12'h222; // we choose to not make machine interrupts delegable
  localparam Gm1 = P.PMP_G > 0 ? P.PMP_G - 1 : 0; // max(G-1, 0)

 // There are PMP_ENTRIES = 0, 16, or 64 PMPADDR registers, each of which has its own flop
  genvar i;
  if (P.PMP_ENTRIES > 0) begin : pmp
    logic [P.PMP_ENTRIES-1:0] WritePMPCFGM;
    logic [P.PMP_ENTRIES-1:0] WritePMPADDRM;
    logic [7:0]               CSRPMPWriteValM[P.PMP_ENTRIES-1:0];
    logic [7:0]               CSRPMPLegalizedWriteValM[P.PMP_ENTRIES-1:0];
    logic [1:0]               CSRPMPWRLegalizedWriteValM[P.PMP_ENTRIES-1:0];
    logic [1:0]               CSRPMPALegalizedWriteValM[P.PMP_ENTRIES-1:0];
    logic [P.PMP_ENTRIES-1:0] ADDRLocked, CFGLocked;
    for(i=0; i<P.PMP_ENTRIES; i++) begin : pmp
      // when the lock bit is set, don't allow writes to the PMPCFG or PMPADDR
      // also, when the lock bit of the next entry is set and the next entry is TOR, don't allow writes to this entry PMPADDR
      assign CFGLocked[i] = PMPCFG_ARRAY_REGW[i][7];
      if (i == P.PMP_ENTRIES-1)
        assign ADDRLocked[i] = PMPCFG_ARRAY_REGW[i][7];
      else
        assign ADDRLocked[i] = PMPCFG_ARRAY_REGW[i][7] | (PMPCFG_ARRAY_REGW[i+1][7] & PMPCFG_ARRAY_REGW[i+1][4:3] == 2'b01);

      assign WritePMPADDRM[i] = (CSRMWriteM & (CSRAdrM == (PMPADDR0+i))) & ~ADDRLocked[i];
      // PMPADDR_ARRAY_PREGRAIN_REGW flip-flops hold all the bits even though all but G-1 lsbs can be controlled by PMP mode and granularity
      flopenr #(P.PA_BITS-2) PMPADDRreg(clk, reset, WritePMPADDRM[i], CSRWriteValM[P.PA_BITS-3:0], PMPADDR_ARRAY_PREGRAIN_REGW[i]);
      if (P.XLEN==64) begin
        assign WritePMPCFGM[i] = (CSRMWriteM & (CSRAdrM == (PMPCFG0+2*(i/8)))) & ~CFGLocked[i];
        assign CSRPMPWriteValM[i] = CSRWriteValM[(i%8)*8+7:(i%8)*8];
      end else begin
        assign WritePMPCFGM[i]  = (CSRMWriteM & (CSRAdrM == (PMPCFG0+i/4))) & ~CFGLocked[i];
        assign CSRPMPWriteValM[i] = CSRWriteValM[(i%4)*8+7:(i%4)*8];
      end

      assign CSRPMPALegalizedWriteValM[i] = ((P.PMP_G > 0) & (CSRPMPWriteValM[i][4:3] == 2'b10)) ? PMPCFG_ARRAY_REGW[i][4:3] : CSRPMPWriteValM[i][4:3]; // WARL A field keeps its old value when attempting to write unselectable NA4 mode
      assign CSRPMPWRLegalizedWriteValM[i] = {(CSRPMPWriteValM[i][1] & CSRPMPWriteValM[i][0]), CSRPMPWriteValM[i][0]}; // legalize WR fields (reserved 10 written as 00)
      assign CSRPMPLegalizedWriteValM[i] = {CSRPMPWriteValM[i][7], 2'b00, CSRPMPALegalizedWriteValM[i], CSRPMPWriteValM[i][2], CSRPMPWRLegalizedWriteValM[i]};
      flopenr #(8) PMPCFGreg(clk, reset, WritePMPCFGM[i], CSRPMPLegalizedWriteValM[i], PMPCFG_ARRAY_REGW[i]);
    end
  end

  localparam MISA_26 = $unsigned(P.MISA) & 32'h03ffffff;

  // MISA is hardwired.  Spec says it could be written to disable features, but this is not supported by Wally
  assign MISA_REGW = {(P.XLEN == 32 ? 2'b01 : 2'b10), {(P.XLEN-28){1'b0}}, MISA_26[25:0]};

  // MHARTID is hardwired. It only exists as a signal so that the testbench can easily see it.
  assign MHARTID_REGW = '0;

  // Write machine Mode CSRs
  assign WriteMSTATUSM       = CSRMWriteM & (CSRAdrM == MSTATUS);
  assign WriteMSTATUSHM      = CSRMWriteM & (CSRAdrM == MSTATUSH) & (P.XLEN==32);
  assign WriteMTVECM         = CSRMWriteM & (CSRAdrM == MTVEC);
  assign WriteMEDELEGM       = CSRMWriteM & (CSRAdrM == MEDELEG);
  assign WriteMIDELEGM       = CSRMWriteM & (CSRAdrM == MIDELEG);
  assign WriteMSCRATCHM      = CSRMWriteM & (CSRAdrM == MSCRATCH);
  assign WriteMEPCM          = MTrapM | (CSRMWriteM & (CSRAdrM == MEPC));
  assign WriteMCAUSEM        = MTrapM | (CSRMWriteM & (CSRAdrM == MCAUSE));
  assign WriteMTVALM         = MTrapM | (CSRMWriteM & (CSRAdrM == MTVAL));
  assign WriteMCOUNTERENM    = CSRMWriteM & (CSRAdrM == MCOUNTEREN);
  assign WriteMCOUNTINHIBITM = CSRMWriteM & (CSRAdrM == MCOUNTINHIBIT);

  assign IllegalCSRMWriteReadonlyM = UngatedCSRMWriteM & (CSRAdrM == MVENDORID | CSRAdrM == MARCHID | CSRAdrM == MIMPID | CSRAdrM == MHARTID | CSRAdrM == MCONFIGPTR);

  // CSRs
  assign TVECWriteValM = CSRWriteValM[0] ? {CSRWriteValM[P.XLEN-1:6], 6'b000001} : {CSRWriteValM[P.XLEN-1:2], 2'b00};
  flopenr #(P.XLEN) MTVECreg(clk, reset, WriteMTVECM, TVECWriteValM, MTVEC_REGW);
  if (P.S_SUPPORTED) begin : deleg // DELEG registers should exist
    flopenr #(16) MEDELEGreg(clk, reset, WriteMEDELEGM, CSRWriteValM[15:0] & MEDELEG_MASK, MEDELEG_REGW);
    flopenr #(12) MIDELEGreg(clk, reset, WriteMIDELEGM, CSRWriteValM[11:0] & MIDELEG_MASK, MIDELEG_REGW);
  end else assign {MEDELEG_REGW, MIDELEG_REGW} = '0;

  flopenr #(P.XLEN) MSCRATCHreg(clk, reset, WriteMSCRATCHM, CSRWriteValM, MSCRATCH_REGW);
  flopenr #(P.XLEN) MEPCreg(clk, reset, WriteMEPCM, NextEPCM, MEPC_REGW);
  flopenr #(P.XLEN) MCAUSEreg(clk, reset, WriteMCAUSEM, {NextCauseM[5], {(P.XLEN-6){1'b0}}, NextCauseM[4:0]}, MCAUSE_REGW);
  flopenr #(P.XLEN) MTVALreg(clk, reset, WriteMTVALM, NextMtvalM, MTVAL_REGW);
  flopenr #(32)   MCOUNTINHIBITreg(clk, reset, WriteMCOUNTINHIBITM, {CSRWriteValM[31:2], 1'b0, CSRWriteValM[0]}, MCOUNTINHIBIT_REGW);
  if (P.U_SUPPORTED) begin : mcounteren // MCOUNTEREN only exists when user mode is supported
    flopenr #(32)   MCOUNTERENreg(clk, reset, WriteMCOUNTERENM, CSRWriteValM[31:0], MCOUNTEREN_REGW);
  end else assign MCOUNTEREN_REGW = '0;

  // MENVCFG register
  if (P.U_SUPPORTED) begin // menvcfg only exists if there is a lower privilege to control
    logic WriteMENVCFGM;
    logic [63:0] MENVCFG_PreWriteValM, MENVCFG_WriteValM;
    logic [1:0] LegalizedCBIE;
    assign WriteMENVCFGM = CSRMWriteM & (CSRAdrM == MENVCFG);
    assign LegalizedCBIE = MENVCFG_PreWriteValM[5:4] == 2'b10 ? MENVCFG_REGW[5:4] : MENVCFG_PreWriteValM[5:4]; // Assume WARL for reserved CBIE = 10, keeps old value
    // MENVCFG is always 64 bits even for RV32
    assign MENVCFG_WriteValM = {
      MENVCFG_PreWriteValM[63]  & P.SSTC_SUPPORTED,
      MENVCFG_PreWriteValM[62]  & P.SVPBMT_SUPPORTED,
      MENVCFG_PreWriteValM[61]  & P.SVADU_SUPPORTED,
      53'b0,
      MENVCFG_PreWriteValM[7]   & P.ZICBOZ_SUPPORTED,
      MENVCFG_PreWriteValM[6]   & P.ZICBOM_SUPPORTED,
      LegalizedCBIE             & {2{P.ZICBOM_SUPPORTED}},
      3'b0,
      MENVCFG_PreWriteValM[0]   & P.S_SUPPORTED & P.VIRTMEM_SUPPORTED
    };
    if (P.XLEN == 64) begin
      assign MENVCFG_PreWriteValM = CSRWriteValM;
      flopenr #(P.XLEN) MENVCFGreg(clk, reset, WriteMENVCFGM, MENVCFG_WriteValM, MENVCFG_REGW);
      assign MENVCFGH_REGW = '0;
    end else begin // RV32 has high and low halves
      logic WriteMENVCFGHM;
      assign MENVCFG_PreWriteValM = {CSRWriteValM, CSRWriteValM};
      assign WriteMENVCFGHM = CSRMWriteM & (CSRAdrM == MENVCFGH) & (P.XLEN==32);
      flopenr #(P.XLEN) MENVCFGreg(clk, reset, WriteMENVCFGM, MENVCFG_WriteValM[31:0], MENVCFG_REGW[31:0]);
      flopenr #(P.XLEN) MENVCFGHreg(clk, reset, WriteMENVCFGHM, MENVCFG_WriteValM[63:32], MENVCFG_REGW[63:32]);
      assign MENVCFGH_REGW = MENVCFG_REGW[63:32];
    end
  end else begin
    assign MENVCFG_REGW = '0;
    assign MENVCFGH_REGW = '0;
  end

  // Grain alignment for PMPADDR read values.
  for(i=0; i<P.PMP_ENTRIES; i++)
    always_comb begin
      logic [P.XLEN-1:0] pmpaddr;
      pmpaddr = {{(P.XLEN-(P.PA_BITS-2)){1'b0}}, PMPADDR_ARRAY_PREGRAIN_REGW[i]}; // raw value in PMP registers
      if (PMPCFG_ARRAY_REGW[i][4]) PMPADDR_ARRAY_REGW[i] = {pmpaddr[P.PA_BITS-3:Gm1],     {Gm1    {1'b1}}}; // in NAPOT/NA4, bottom G-1 bits read as all 1s (but no bits affected for NA4)
      else                         PMPADDR_ARRAY_REGW[i] = {pmpaddr[P.PA_BITS-3:P.PMP_G], {P.PMP_G{1'b0}}}; // in TOR/OFF, bottom G bits read as 0s
    end

  // Read machine mode CSRs
  // verilator lint_off WIDTH
  logic [5:0] entry;
  always_comb begin
    entry = '0;
    CSRMReadValM = '0;
    IllegalCSRMAccessM = !(P.S_SUPPORTED) & (CSRAdrM == MEDELEG | CSRAdrM == MIDELEG); // trap on DELEG register access when no S or N-mode
    if ($unsigned(CSRAdrM) >= PMPADDR0 & $unsigned(CSRAdrM) < PMPADDR0 + P.PMP_ENTRIES)
      CSRMReadValM = {{(P.XLEN-(P.PA_BITS-2)){1'b0}}, PMPADDR_ARRAY_REGW[CSRAdrM - PMPADDR0]}; // read PMPADDR entry with lsbs aligned to grain based on NAPOT vs. TOR
    else if ($unsigned(CSRAdrM) >= PMPCFG0 & $unsigned(CSRAdrM) < PMPCFG0 + P.PMP_ENTRIES/4 & (P.XLEN==32 | CSRAdrM[0] == 0)) begin
      // only odd-numbered PMPCFG entries exist in RV64
      if (P.XLEN==64) begin
        entry = ({CSRAdrM[11:1], 1'b0} - PMPCFG0)*4; // disregard odd entries in RV64
        CSRMReadValM = {PMPCFG_ARRAY_REGW[entry+7],PMPCFG_ARRAY_REGW[entry+6],PMPCFG_ARRAY_REGW[entry+5],PMPCFG_ARRAY_REGW[entry+4],
                        PMPCFG_ARRAY_REGW[entry+3],PMPCFG_ARRAY_REGW[entry+2],PMPCFG_ARRAY_REGW[entry+1],PMPCFG_ARRAY_REGW[entry]};
      end else begin
        entry = (CSRAdrM - PMPCFG0)*4;
        CSRMReadValM = {PMPCFG_ARRAY_REGW[entry+3],PMPCFG_ARRAY_REGW[entry+2],PMPCFG_ARRAY_REGW[entry+1],PMPCFG_ARRAY_REGW[entry]};
      end
    end
    else case (CSRAdrM)
      MISA_ADR:      CSRMReadValM = MISA_REGW;
      MVENDORID:     CSRMReadValM = {{(P.XLEN-32){1'b0}}, 32'h0000_0602}; // OpenHW JEDEC
      MARCHID:       CSRMReadValM = {{(P.XLEN-32){1'b0}}, 32'h24}; // 36 for CV-Wally
      MIMPID:        CSRMReadValM = {{P.XLEN-12{1'b0}}, 12'h100}; // pipelined implementation
      MHARTID:       CSRMReadValM = MHARTID_REGW; // hardwired to 0
      MCONFIGPTR:    CSRMReadValM = '0; // hardwired to 0
      MSTATUS:       CSRMReadValM = MSTATUS_REGW;
      MSTATUSH:      if (P.XLEN==32) CSRMReadValM = MSTATUSH_REGW;
                     else IllegalCSRMAccessM = 1'b1;
      MTVEC:         CSRMReadValM = MTVEC_REGW;
      MEDELEG:       CSRMReadValM = {{(P.XLEN-16){1'b0}}, MEDELEG_REGW};
      MIDELEG:       CSRMReadValM = {{(P.XLEN-12){1'b0}}, MIDELEG_REGW};
      MIP:           CSRMReadValM = {{(P.XLEN-12){1'b0}}, MIP_REGW};
      MIE:           CSRMReadValM = {{(P.XLEN-12){1'b0}}, MIE_REGW};
      MSCRATCH:      CSRMReadValM = MSCRATCH_REGW;
      MEPC:          CSRMReadValM = MEPC_REGW;
      MCAUSE:        CSRMReadValM = MCAUSE_REGW;
      MTVAL:         CSRMReadValM = MTVAL_REGW;
      MCOUNTEREN:    CSRMReadValM = {{(P.XLEN-32){1'b0}}, MCOUNTEREN_REGW};
      MENVCFG:       if (P.U_SUPPORTED) CSRMReadValM = MENVCFG_REGW[P.XLEN-1:0];
                     else IllegalCSRMAccessM = 1'b1;
      MENVCFGH:      if (P.U_SUPPORTED & P.XLEN==32) CSRMReadValM = MENVCFGH_REGW;
                     else IllegalCSRMAccessM = 1'b1;
      MCOUNTINHIBIT: CSRMReadValM = {{(P.XLEN-32){1'b0}}, MCOUNTINHIBIT_REGW};
      default:       IllegalCSRMAccessM = 1'b1;
    endcase
  end
  // verilator lint_on WIDTH
endmodule
