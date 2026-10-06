///////////////////////////////////////////
// loggers.sv
//
// Written: Rose Thompson rose@rosethompson.net
// Modified: 24 July 2024
//
// Purpose: Wraps all the synthesizable rvvi hardware into a single module for the testbench.
//
// A component of the Wally configurable RISC-V project.
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

module rvvitbwrapper import cvw::*; #(parameter cvw_t P,
                                parameter MAX_CSRS = 5,
                                parameter logic [31:0] RVVI_INIT_TIME_OUT = 32'd4,
                                parameter logic [31:0] RVVI_PACKET_DELAY = 32'd2)(
  input  logic clk,
  input  logic reset,
  output logic RVVIStall,
  input  logic mii_tx_clk,
  output logic [3:0] mii_txd,
  output logic mii_tx_en, mii_tx_er,
  input  logic mii_rx_clk,
  input  logic [3:0] mii_rxd,
  input  logic mii_rx_dv,
  input  logic mii_rx_er
);

  logic        valid;
  logic [72+(5*P.XLEN) + MAX_CSRS*(P.XLEN+16)-1:0] rvvi;

  localparam TOTAL_CSRS = 65;

  // pipeline controls
  logic                                             StallE, StallM, StallW, FlushE, FlushM, FlushW;
  // required
  logic [P.XLEN-1:0]                                PCM;
  logic                                             InstrValidM;
  logic [31:0]                                      InstrRawD;
  logic [63:0]                                      Mcycle, Minstret;
  logic                                             TrapM;
  logic [1:0]                                       PrivilegeModeW;
  // registers gpr and fpr
  logic                                             GPRWen, FPRWen;
  logic [4:0]                                       GPRAddr, FPRAddr;
  logic [P.XLEN-1:0]                                GPRValue, FPRValue;
  logic [P.XLEN-1:0]                                CSRArray [TOTAL_CSRS-1:0];

  // axi 4 write data channel
  logic [31:0]                                      RvviAxiWdata;
  logic [3:0]                                       RvviAxiWstrb;
  logic                                             RvviAxiWlast;
  logic                                             RvviAxiWvalid;
  logic                                             RvviAxiWready;

  logic                                             tx_error_underflow, tx_fifo_overflow, tx_fifo_bad_frame, tx_fifo_good_frame, rx_error_bad_frame;
  logic                                             rx_error_bad_fcs, rx_fifo_overflow, rx_fifo_bad_frame, rx_fifo_good_frame;

  logic                                             MiiTxEnDelay;
  logic                                             EthernetTXCounterEn;
  logic [31:0]                                      EthernetTXCount;

  assign StallE         = dut.core.StallE;
  assign StallM         = dut.core.StallM;
  assign StallW         = dut.core.StallW;
  assign FlushE         = dut.core.FlushE;
  assign FlushM         = dut.core.FlushM;
  assign FlushW         = dut.core.FlushW;
  assign InstrValidM    = dut.core.ieu.InstrValidM;
  assign InstrRawD      = dut.core.ifu.InstrRawD;
  assign PCM            = dut.core.ifu.PCM;
  assign Mcycle         = dut.core.priv.priv.csr.counters.HPMCOUNTER_REGW[0];
  assign Minstret       = dut.core.priv.priv.csr.counters.HPMCOUNTER_REGW[2];
  assign TrapM          = dut.core.TrapM;
  assign PrivilegeModeW = dut.core.priv.priv.privmode.PrivilegeModeW;
  assign GPRAddr        = dut.core.ieu.dp.regf.a3;
  assign GPRWen         = dut.core.ieu.dp.regf.we3;
  assign GPRValue       = dut.core.ieu.dp.regf.wd3;
  assign FPRAddr        = dut.core.fpu.fpu.fregfile.a4;
  assign FPRWen         = dut.core.fpu.fpu.fregfile.we4;
  assign FPRValue       = dut.core.fpu.fpu.fregfile.wd4;

  assign CSRArray[0] = dut.core.priv.priv.csr.csrm.MSTATUS_REGW; // 12'h300
  assign CSRArray[1] = dut.core.priv.priv.csr.csrm.MSTATUSH_REGW; // 12'h310
  assign CSRArray[2] = dut.core.priv.priv.csr.csrm.MTVEC_REGW; // 12'h305
  assign CSRArray[3] = dut.core.priv.priv.csr.csrm.MEPC_REGW; // 12'h341
  assign CSRArray[4] = dut.core.priv.priv.csr.csrm.MCOUNTEREN_REGW; // 12'h306
  assign CSRArray[5] = dut.core.priv.priv.csr.csrm.MCOUNTINHIBIT_REGW; // 12'h320
  assign CSRArray[6] = dut.core.priv.priv.csr.csrm.MEDELEG_REGW; // 12'h302
  assign CSRArray[7] = {{(P.XLEN-16){1'b0}}, dut.core.priv.priv.csr.csrm.MIDELEG_REGW}; // 12'h303
  assign CSRArray[8] = {{(P.XLEN-16){1'b0}}, dut.core.priv.priv.csr.csrm.MIP_REGW}; // 12'h344
  assign CSRArray[9] = {{(P.XLEN-16){1'b0}}, dut.core.priv.priv.csr.csrm.MIE_REGW}; // 12'h304
  assign CSRArray[10] = dut.core.priv.priv.csr.csrm.MISA_REGW; // 12'h301
  assign CSRArray[11] = dut.core.priv.priv.csr.csrm.MENVCFG_REGW; // 12'h30A
  assign CSRArray[12] = dut.core.priv.priv.csr.csrm.MHARTID_REGW; // 12'hF14
  assign CSRArray[13] = dut.core.priv.priv.csr.csrm.MSCRATCH_REGW; // 12'h340
  assign CSRArray[14] = dut.core.priv.priv.csr.csrm.MCAUSE_REGW; // 12'h342
  assign CSRArray[15] = dut.core.priv.priv.csr.csrm.MTVAL_REGW; // 12'h343
  assign CSRArray[16] = 0; // 12'hF11
  assign CSRArray[17] = 0; // 12'hF12
  assign CSRArray[18] = {{P.XLEN-12{1'b0}}, 12'h100}; //P.XLEN'h100; // 12'hF13
  assign CSRArray[19] = 0; // 12'hF15
  if (P.H_SUPPORTED) begin : mtinst_csr
    assign CSRArray[20] = dut.core.priv.priv.csr.csrh.csrh.MTINST_REGW; // 12'h34A
  end else begin : no_mtinst_csr
    assign CSRArray[20] = '0; // 12'h34A
  end
  // supervisor CSRs
  assign CSRArray[21] = dut.core.priv.priv.csr.csrs.csrs.SSTATUS_REGW; // 12'h100
  assign CSRArray[22] = {{(P.XLEN-16){1'b0}}, dut.core.priv.priv.csr.csrm.MIE_REGW & 16'h0222 & dut.core.priv.priv.csr.csrm.MIDELEG_REGW}; // 12'h104
  assign CSRArray[23] = dut.core.priv.priv.csr.csrs.csrs.STVEC_REGW; // 12'h105
  assign CSRArray[24] = dut.core.priv.priv.csr.csrs.csrs.SEPC_REGW; // 12'h141
  assign CSRArray[25] = dut.core.priv.priv.csr.csrs.csrs.SCOUNTEREN_REGW; // 12'h106
  assign CSRArray[26] = dut.core.priv.priv.csr.csrs.csrs.SENVCFG_REGW; // 12'h10A
  assign CSRArray[27] = dut.core.priv.priv.csr.csrs.csrs.SATP_REGW; // 12'h180
  assign CSRArray[28] = dut.core.priv.priv.csr.csrs.csrs.SSCRATCH_REGW; // 12'h140
  assign CSRArray[29] = dut.core.priv.priv.csr.csrs.csrs.STVAL_REGW; // 12'h143
  assign CSRArray[30] = dut.core.priv.priv.csr.csrs.csrs.SCAUSE_REGW; // 12'h142
  assign CSRArray[31] = {{(P.XLEN-16){1'b0}}, dut.core.priv.priv.csr.csrm.MIP_REGW & 16'h0222 & dut.core.priv.priv.csr.csrm.MIDELEG_REGW}; // 12'h144
  assign CSRArray[32] = dut.core.priv.priv.csr.csrs.csrs.STIMECMP_REGW; // 12'h14D
  // user CSRs
  assign CSRArray[33] = dut.core.priv.priv.csr.csru.csru.FFLAGS_REGW; // 12'h001
  assign CSRArray[34] = dut.core.priv.priv.csr.csru.csru.FRM_REGW; // 12'h002
  assign CSRArray[35] = {dut.core.priv.priv.csr.csru.csru.FRM_REGW, dut.core.priv.priv.csr.csru.csru.FFLAGS_REGW}; // 12'h003

  if (P.H_SUPPORTED) begin : hypervisor_csrs
    assign CSRArray[36] = dut.core.priv.priv.csr.csrh.csrh.MTVAL2_REGW; // 12'h34B
    assign CSRArray[37] = dut.core.priv.priv.csr.csrh.csrh.HSTATUS_REGW; // 12'h600
    assign CSRArray[38] = dut.core.priv.priv.csr.csrh.csrh.VSSTATUS_REGW; // 12'h200
    assign CSRArray[39] = dut.core.priv.priv.csr.csrh.csrh.HEDELEG_REGW; // 12'h602
    assign CSRArray[40] = (P.XLEN == 32) ? dut.core.priv.priv.csr.csrh.csrh.HEDELEG_REGW[63:32] : '0; // 12'h612
    assign CSRArray[41] = {{(P.XLEN-16){1'b0}}, dut.core.priv.priv.csr.csrh.csrh.HIDELEG_REGW}; // 12'h603
    assign CSRArray[42] = {{(P.XLEN-16){1'b0}}, dut.core.priv.priv.csr.csrh.csrh.HIE_REGW}; // 12'h604
    assign CSRArray[43] = dut.core.priv.priv.csr.csrh.csrh.VSIE_REGW; // 12'h204
    assign CSRArray[44] = dut.core.priv.priv.csr.csrh.csrh.HTIMEDELTA_REGW[P.XLEN-1:0]; // 12'h605
    assign CSRArray[45] = (P.XLEN == 32) ? dut.core.priv.priv.csr.csrh.csrh.HTIMEDELTA_REGW[63:32] : '0; // 12'h615
    assign CSRArray[46] = dut.core.priv.priv.csr.csrh.csrh.HCOUNTEREN_REGW; // 12'h606
    assign CSRArray[47] = dut.core.priv.priv.csr.csrh.csrh.HGEIE_REGW; // 12'h607
    assign CSRArray[48] = dut.core.priv.priv.csr.csrh.csrh.HENVCFG_REGW[P.XLEN-1:0]; // 12'h60A
    assign CSRArray[49] = (P.XLEN == 32) ? dut.core.priv.priv.csr.csrh.csrh.HENVCFG_REGW[63:32] : '0; // 12'h61A
    assign CSRArray[50] = dut.core.priv.priv.csr.csrh.csrh.HTVAL_REGW; // 12'h643
    assign CSRArray[51] = {{(P.XLEN-16){1'b0}}, dut.core.priv.priv.csr.csrh.csrh.HIP_PENDING}; // 12'h644
    assign CSRArray[52] = dut.core.priv.priv.csr.csrh.csrh.HVIP_REGW; // 12'h645
    assign CSRArray[53] = dut.core.priv.priv.csr.csrh.csrh.HTINST_REGW; // 12'h64A
    assign CSRArray[54] = dut.core.priv.priv.csr.csrh.csrh.HGATPReadVal; // 12'h680
    assign CSRArray[55] = dut.core.priv.priv.csr.csrh.csrh.HGEIP_REGW; // 12'hE12
    assign CSRArray[56] = dut.core.priv.priv.csr.csrh.csrh.VSTVEC_REGW; // 12'h205
    assign CSRArray[57] = dut.core.priv.priv.csr.csrh.csrh.VSSCRATCH_REGW; // 12'h240
    assign CSRArray[58] = dut.core.priv.priv.csr.csrh.csrh.VSEPC_REGW; // 12'h241
    assign CSRArray[59] = dut.core.priv.priv.csr.csrh.csrh.VSCAUSE_REGW; // 12'h242
    assign CSRArray[60] = dut.core.priv.priv.csr.csrh.csrh.VSTVAL_REGW; // 12'h243
    assign CSRArray[61] = dut.core.priv.priv.csr.csrh.csrh.VSIP_REGW; // 12'h244
    assign CSRArray[62] = dut.core.priv.priv.csr.csrh.csrh.VSATP_REGW; // 12'h280
    assign CSRArray[63] = dut.core.priv.priv.csr.csrh.csrh.VSTIMECMP_REGW[P.XLEN-1:0]; // 12'h24D
    assign CSRArray[64] = (P.XLEN == 32) ? dut.core.priv.priv.csr.csrh.csrh.VSTIMECMP_REGW[63:32] : '0; // 12'h25D
  end else begin : no_hypervisor_csrs
    for (genvar csrIdx = 36; csrIdx < 65; csrIdx++) begin
      assign CSRArray[csrIdx] = '0;
    end
  end

  rvvisynth #(P, MAX_CSRS, TOTAL_CSRS) rvvisynth(.clk, .reset, .StallE, .StallM, .StallW, .FlushE, .FlushM, .FlushW,
                                                 .PCM, .InstrValidM, .InstrRawD, .Mcycle, .Minstret, .TrapM,
                                                 .PrivilegeModeW, .GPRWen, .FPRWen, .GPRAddr, .FPRAddr, .GPRValue, .FPRValue, .CSRArray,
                                                 .valid, .rvvi);

  packetizer #(P, MAX_CSRS, RVVI_INIT_TIME_OUT, RVVI_PACKET_DELAY) packetizer(.rvvi, .valid, .m_axi_aclk(clk), .m_axi_aresetn(~reset), .RVVIStall,
    .RvviAxiWdata, .RvviAxiWstrb, .RvviAxiWlast, .RvviAxiWvalid, .RvviAxiWready);

  eth_mac_mii_fifo #("GENERIC", "BUFG", 32) ethernet(.rst(reset), .logic_clk(clk), .logic_rst(reset),
    .tx_axis_tdata(RvviAxiWdata), .tx_axis_tkeep(RvviAxiWstrb), .tx_axis_tvalid(RvviAxiWvalid), .tx_axis_tready(RvviAxiWready),
    .tx_axis_tlast(RvviAxiWlast), .tx_axis_tuser('0), .rx_axis_tdata(), .rx_axis_tkeep(), .rx_axis_tvalid(), .rx_axis_tready(1'b1),
    .rx_axis_tlast(), .rx_axis_tuser(),

    .mii_rx_clk(clk),
    .mii_rxd('0),
    .mii_rx_dv('0),
    .mii_rx_er('0),
    .mii_tx_clk(clk),
    .mii_txd,
    .mii_tx_en,
    .mii_tx_er,

    // status
    .tx_error_underflow, .tx_fifo_overflow, .tx_fifo_bad_frame, .tx_fifo_good_frame, .rx_error_bad_frame,
    .rx_error_bad_fcs, .rx_fifo_overflow, .rx_fifo_bad_frame, .rx_fifo_good_frame,
    .cfg_ifg(8'd12), .cfg_tx_enable(1'b1), .cfg_rx_enable(1'b1));

  flopr #(1) txedgereg(clk, reset, mii_tx_en, MiiTxEnDelay);
  assign EthernetTXCounterEn = ~mii_tx_en & MiiTxEnDelay;
  counter #(32) ethernexttxcounter(clk, reset, EthernetTXCounterEn, EthernetTXCount);

endmodule
