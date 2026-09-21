///////////////////////////////////////////
// fpgaTop.sv
//
// Written: rose@rosethompson.net November 17, 2021
// Modified:
//
// Purpose: This is a top level for the fpga's implementation of wally.
//          Instantiates wallysoc, ddr4, abh lite to axi converters, pll, etc
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software
// is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
// OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
///////////////////////////////////////////

`include "config.vh"

import cvw::*;

module fpgaTop #(parameter logic RVVI_SYNTH_SUPPORTED = 0)
  (input logic           default_100mhz_clk,
   input logic           resetn,
   input logic           south_reset,

   // GPIO signals
   input logic [3:0]   GPI,
   output logic [4:0]  GPO,

   // UART Signals
   input logic         UARTSin,
   output logic        UARTSout,

   // SDC Signals connecting to an SPI peripheral
   input logic         SDCIn,
   output logic        SDCCLK,
   output logic        SDCCmd,
   output logic        SDCCS,
   input logic         SDCCD,
   input logic         SDCWP,
 /*
     * Ethernet: 100BASE-T MII
     */
    output logic       phy_ref_clk,
    input logic        phy_rx_clk,
    input logic  [3:0] phy_rxd,
    input logic        phy_rx_dv,
    input logic        phy_rx_er,
    input logic        phy_tx_clk,
    output logic [3:0] phy_txd,
    output logic       phy_tx_en,
    input logic        phy_col, // nc
    input logic        phy_crs, // nc
    output logic       phy_reset_n,

   inout logic [15:0]    ddr3_dq,
   inout logic [1:0]     ddr3_dqs_n,
   inout logic [1:0]     ddr3_dqs_p,
   output logic [13:0]   ddr3_addr,
   output logic [2:0]    ddr3_ba,
   output logic          ddr3_ras_n,
   output logic          ddr3_cas_n,
   output logic          ddr3_we_n,
   output logic          ddr3_reset_n,
   output logic [0:0]    ddr3_ck_p,
   output logic [0:0]    ddr3_ck_n,
   output logic [0:0]    ddr3_cke,
   output logic [0:0]    ddr3_cs_n,
   output logic [1:0]    ddr3_dm,
   output logic [0:0]    ddr3_odt,

   input logic         tck,
   input logic         tms,
   input logic         tdi,
   output logic        tdo
   );

  // MMCM Signals
  logic          CPUCLK;
  logic          c0_ddr4_ui_clk_sync_rst;
  logic          bus_struct_reset;
  logic          peripheral_reset;
  logic          interconnect_aresetn;
  logic          peripheral_aresetn;
  logic          mb_reset;

  // AHB Signals from Wally
  logic            HCLKOpen;
  logic            HRESETnOpen;
  logic [63:0]     HRDATAEXT;
  logic            HREADYEXT;
  logic            HRESPEXT;
  logic            HSELEXT;
  logic [55:0]     HADDR;
  logic [63:0]     HWDATA;
  logic [64/8-1:0] HWSTRB;
  logic            HWRITE;
  logic [2:0]      HSIZE;
  logic [2:0]      HBURST;
  logic [1:0]      HTRANS;
  logic            HREADY;
  logic [3:0]      HPROT;
  logic            HMASTLOCK;

  // GPIO Signals
  logic [31:0]    GPIOIN, GPIOOUT, GPIOEN;

  // AHB to AXI Bridge Signals
  logic [3:0]      m_axi_awid;
  logic [7:0]      m_axi_awlen;
  logic [2:0]      m_axi_awsize;
  logic [1:0]      m_axi_awburst;
  logic [3:0]      m_axi_awcache;
  logic [31:0]     m_axi_awaddr;
  logic [2:0]      m_axi_awprot;
  logic            m_axi_awvalid;
  logic            m_axi_awready;
  logic            m_axi_awlock;
  logic [63:0]     m_axi_wdata;
  logic [7:0]      m_axi_wstrb;
  logic            m_axi_wlast;
  logic            m_axi_wvalid;
  logic            m_axi_wready;
  logic [3:0]      m_axi_bid;
  logic [1:0]      m_axi_bresp;
  logic            m_axi_bvalid;
  logic            m_axi_bready;
  logic [3:0]      m_axi_arid;
  logic [7:0]      m_axi_arlen;
  logic [2:0]      m_axi_arsize;
  logic [1:0]      m_axi_arburst;
  logic [2:0]      m_axi_arprot;
  logic [3:0]      m_axi_arcache;
  logic            m_axi_arvalid;
  logic [31:0]     m_axi_araddr;
  logic            m_axi_arlock;
  logic            m_axi_arready;
  logic [3:0]      m_axi_rid;
  logic [63:0]     m_axi_rdata;
  logic [1:0]      m_axi_rresp;
  logic            m_axi_rvalid;
  logic            m_axi_rlast;
  logic            m_axi_rready;

  // AXI Signals going out of Clock Converter
  logic [3:0]      BUS_axi_arregion;
  logic [3:0]      BUS_axi_arqos;
  logic [3:0]      BUS_axi_awregion;
  logic [3:0]      BUS_axi_awqos;
  logic [3:0]      BUS_axi_awid;
  logic [7:0]      BUS_axi_awlen;
  logic [2:0]      BUS_axi_awsize;
  logic [1:0]      BUS_axi_awburst;
  logic [3:0]      BUS_axi_awcache;
  logic [31:0]     BUS_axi_awaddr;
  logic [2:0]      BUS_axi_awprot;
  logic            BUS_axi_awvalid;
  logic            BUS_axi_awready;
  logic            BUS_axi_awlock;
  logic [63:0]     BUS_axi_wdata;
  logic [7:0]      BUS_axi_wstrb;
  logic            BUS_axi_wlast;
  logic            BUS_axi_wvalid;
  logic            BUS_axi_wready;
  logic [3:0]      BUS_axi_bid;
  logic [1:0]      BUS_axi_bresp;
  logic            BUS_axi_bvalid;
  logic            BUS_axi_bready;
  logic [3:0]      BUS_axi_arid;
  logic [7:0]      BUS_axi_arlen;
  logic [2:0]      BUS_axi_arsize;
  logic [1:0]      BUS_axi_arburst;
  logic [2:0]      BUS_axi_arprot;
  logic [3:0]      BUS_axi_arcache;
  logic            BUS_axi_arvalid;
  logic [31:0]     BUS_axi_araddr;
  logic            BUS_axi_arlock;
  logic            BUS_axi_arready;
  logic [3:0]      BUS_axi_rid;
  logic [63:0]     BUS_axi_rdata;
  logic [1:0]      BUS_axi_rresp;
  logic            BUS_axi_rvalid;
  logic            BUS_axi_rlast;
  logic            BUS_axi_rready;

  logic            BUSCLK;
  logic            sdio_reset_open;

  logic            c0_init_calib_complete;
  logic            dbg_clk;
  logic [511 : 0]  dbg_bus;
  logic            ui_clk_sync_rst;

  logic            CLK208;
  logic            clk167;
  logic            clk200;

  logic            app_sr_active;
  logic            app_ref_ack;
  logic            app_zq_ack;
  logic            mmcm_locked;
  logic [11:0]     device_temp;
  logic            mmcm1_locked;

(* mark_debug = "true" *)  logic              RVVIStall;

  assign GPIOIN = {25'b0, SDCCD, SDCWP, 1'b0, GPI};
  assign GPO = GPIOOUT[4:0];
  assign ahblite_resetn = peripheral_aresetn;
  assign cpu_reset = bus_struct_reset;
  assign calib = c0_init_calib_complete;

  logic [3:0] SDCCSin;
  assign SDCCS = SDCCSin[0];

  // mmcm

  // the ddr3 mig7 requires 2 input clocks
  // 1. sys clock which is 167 MHz = ddr3 clock / 4
  // 2. a second clock which is 200 MHz
  // Wally requires a slower clock.  At this point I don't know what speed the atrix 7 will run so I'm initially targeting 25Mhz.
  // the mig will output a clock at 1/4 the sys clock or 41Mhz which might work with wally so we may be able to simplify the logic a lot.
  mmcm mmcm(.clk_out1(clk167),
                     .clk_out2(clk200),
                     .clk_out3(CPUCLK),
                     .clk_out4(phy_ref_clk),
                     .reset(1'b0),
                     .locked(mmcm1_locked),
                     .clk_in1(default_100mhz_clk));



  // reset controller XILINX IP
  sysrst sysrst
    (.slowest_sync_clk(CPUCLK),
     .ext_reset_in(1'b0),
     .aux_reset_in(south_reset),
     .mb_debug_sys_rst(1'b0),
     .dcm_locked(c0_init_calib_complete),
     .mb_reset(mb_reset),  //open
     .bus_struct_reset(bus_struct_reset),
     .peripheral_reset(peripheral_reset), //open
     .interconnect_aresetn(interconnect_aresetn), //open
     .peripheral_aresetn(peripheral_aresetn));

  `include "parameter-defs.vh"

  // Wally
  wallypipelinedsoc  #(P)
  wallypipelinedsoc(.clk(CPUCLK), .reset_ext(bus_struct_reset), .reset(),
                    .HRDATAEXT, .HREADYEXT, .HRESPEXT, .HSELEXT,
                    .HCLK(HCLKOpen), .HRESETn(HRESETnOpen),
                    .HADDR, .HWDATA, .HWSTRB, .HWRITE, .HSIZE, .HBURST, .HPROT,
                    .HTRANS, .HMASTLOCK, .HREADY, .TIMECLK(1'b0),
                    .GPIOIN, .GPIOOUT, .GPIOEN,
                    .UARTSin, .UARTSout, .SDCIn, .SDCCmd, .SDCCS(SDCCSin), .SDCCLK, .ExternalStall(RVVIStall),
                    .tck, .tms, .tdi, .tdo);


  // ahb lite to axi bridge
  ahbaxibridge ahbaxibridge
    (.s_ahb_hclk(CPUCLK),
     .s_ahb_hresetn(peripheral_aresetn),
     .s_ahb_hsel(HSELEXT),
     .s_ahb_haddr(HADDR[31:0]),
     .s_ahb_hprot(HPROT),
     .s_ahb_htrans(HTRANS),
     .s_ahb_hsize(HSIZE),
     .s_ahb_hwrite(HWRITE),
     .s_ahb_hburst(HBURST),
     .s_ahb_hwdata(HWDATA),
     .s_ahb_hready_out(HREADYEXT),
     .s_ahb_hready_in(HREADY),
     .s_ahb_hrdata(HRDATAEXT),
     .s_ahb_hresp(HRESPEXT),
     .m_axi_awid(m_axi_awid),
     .m_axi_awlen(m_axi_awlen),
     .m_axi_awsize(m_axi_awsize),
     .m_axi_awburst(m_axi_awburst),
     .m_axi_awcache(m_axi_awcache),
     .m_axi_awaddr(m_axi_awaddr),
     .m_axi_awprot(m_axi_awprot),
     .m_axi_awvalid(m_axi_awvalid),
     .m_axi_awready(m_axi_awready),
     .m_axi_awlock(m_axi_awlock),
     .m_axi_wdata(m_axi_wdata),
     .m_axi_wstrb(m_axi_wstrb),
     .m_axi_wlast(m_axi_wlast),
     .m_axi_wvalid(m_axi_wvalid),
     .m_axi_wready(m_axi_wready),
     .m_axi_bid(m_axi_bid),
     .m_axi_bresp(m_axi_bresp),
     .m_axi_bvalid(m_axi_bvalid),
     .m_axi_bready(m_axi_bready),
     .m_axi_arid(m_axi_arid),
     .m_axi_arlen(m_axi_arlen),
     .m_axi_arsize(m_axi_arsize),
     .m_axi_arburst(m_axi_arburst),
     .m_axi_arprot(m_axi_arprot),
     .m_axi_arcache(m_axi_arcache),
     .m_axi_arvalid(m_axi_arvalid),
     .m_axi_araddr(m_axi_araddr),
     .m_axi_arlock(m_axi_arlock),
     .m_axi_arready(m_axi_arready),
     .m_axi_rid(m_axi_rid),
     .m_axi_rdata(m_axi_rdata),
     .m_axi_rresp(m_axi_rresp),
     .m_axi_rvalid(m_axi_rvalid),
     .m_axi_rlast(m_axi_rlast),
     .m_axi_rready(m_axi_rready));

  // AXI Clock Converter
  clkconverter clkconverter
    (.s_axi_aclk(CPUCLK),
     .s_axi_aresetn(peripheral_aresetn),
     .s_axi_awid(m_axi_awid),
     .s_axi_awlen(m_axi_awlen),
     .s_axi_awsize(m_axi_awsize),
     .s_axi_awburst(m_axi_awburst),
     .s_axi_awcache(m_axi_awcache),
     .s_axi_awaddr(m_axi_awaddr[30:0] ),
     .s_axi_awprot(m_axi_awprot),
     .s_axi_awregion(4'b0), // this could be a bug. bridge does not have these outputs
     .s_axi_awqos(4'b0),    // this could be a bug. bridge does not have these outputs
     .s_axi_awvalid(m_axi_awvalid),
     .s_axi_awready(m_axi_awready),
     .s_axi_awlock(m_axi_awlock),
     .s_axi_wdata(m_axi_wdata),
     .s_axi_wstrb(m_axi_wstrb),
     .s_axi_wlast(m_axi_wlast),
     .s_axi_wvalid(m_axi_wvalid),
     .s_axi_wready(m_axi_wready),
     .s_axi_bid(m_axi_bid),
     .s_axi_bresp(m_axi_bresp),
     .s_axi_bvalid(m_axi_bvalid),
     .s_axi_bready(m_axi_bready),
     .s_axi_arid(m_axi_arid),
     .s_axi_arlen(m_axi_arlen),
     .s_axi_arsize(m_axi_arsize),
     .s_axi_arburst(m_axi_arburst),
     .s_axi_arprot(m_axi_arprot),
     .s_axi_arregion(4'b0), // this could be a bug. bridge does not have these outputs
     .s_axi_arqos(4'b0),    // this could be a bug. bridge does not have these outputs
     .s_axi_arcache(m_axi_arcache),
     .s_axi_arvalid(m_axi_arvalid),
     .s_axi_araddr(m_axi_araddr[30:0]),
     .s_axi_arlock(m_axi_arlock),
     .s_axi_arready(m_axi_arready),
     .s_axi_rid(m_axi_rid),
     .s_axi_rdata(m_axi_rdata),
     .s_axi_rresp(m_axi_rresp),
     .s_axi_rvalid(m_axi_rvalid),
     .s_axi_rlast(m_axi_rlast),
     .s_axi_rready(m_axi_rready),

     .m_axi_aclk(BUSCLK),
     .m_axi_aresetn(resetn),
     .m_axi_awid(BUS_axi_awid),
     .m_axi_awlen(BUS_axi_awlen),
     .m_axi_awsize(BUS_axi_awsize),
     .m_axi_awburst(BUS_axi_awburst),
     .m_axi_awcache(BUS_axi_awcache),
     .m_axi_awaddr(BUS_axi_awaddr),
     .m_axi_awprot(BUS_axi_awprot),
     .m_axi_awregion(BUS_axi_awregion),
     .m_axi_awqos(BUS_axi_awqos),
     .m_axi_awvalid(BUS_axi_awvalid),
     .m_axi_awready(BUS_axi_awready),
     .m_axi_awlock(BUS_axi_awlock),
     .m_axi_wdata(BUS_axi_wdata),
     .m_axi_wstrb(BUS_axi_wstrb),
     .m_axi_wlast(BUS_axi_wlast),
     .m_axi_wvalid(BUS_axi_wvalid),
     .m_axi_wready(BUS_axi_wready),
     .m_axi_bid(BUS_axi_bid),
     .m_axi_bresp(BUS_axi_bresp),
     .m_axi_bvalid(BUS_axi_bvalid),
     .m_axi_bready(BUS_axi_bready),
     .m_axi_arid(BUS_axi_arid),
     .m_axi_arlen(BUS_axi_arlen),
     .m_axi_arsize(BUS_axi_arsize),
     .m_axi_arburst(BUS_axi_arburst),
     .m_axi_arprot(BUS_axi_arprot),
     .m_axi_arregion(BUS_axi_arregion),
     .m_axi_arqos(BUS_axi_arqos),
     .m_axi_arcache(BUS_axi_arcache),
     .m_axi_arvalid(BUS_axi_arvalid),
     .m_axi_araddr(BUS_axi_araddr),
     .m_axi_arlock(BUS_axi_arlock),
     .m_axi_arready(BUS_axi_arready),
     .m_axi_rid(BUS_axi_rid),
     .m_axi_rdata(BUS_axi_rdata),
     .m_axi_rresp(BUS_axi_rresp),
     .m_axi_rvalid(BUS_axi_rvalid),
     .m_axi_rlast(BUS_axi_rlast),
     .m_axi_rready(BUS_axi_rready));

  // DDR3 Controller
  ddr3 ddr3
    (
     // ddr3 I/O
     .ddr3_dq(ddr3_dq),
     .ddr3_dqs_n(ddr3_dqs_n),
     .ddr3_dqs_p(ddr3_dqs_p),
     .ddr3_addr(ddr3_addr),
     .ddr3_ba(ddr3_ba),
     .ddr3_ras_n(ddr3_ras_n),
     .ddr3_cas_n(ddr3_cas_n),
     .ddr3_we_n(ddr3_we_n),
     .ddr3_reset_n(ddr3_reset_n),
     .ddr3_ck_p(ddr3_ck_p),
     .ddr3_ck_n(ddr3_ck_n),
     .ddr3_cke(ddr3_cke),
     .ddr3_cs_n(ddr3_cs_n),
     .ddr3_dm(ddr3_dm),
     .ddr3_odt(ddr3_odt),

     .sys_clk_i(clk167),
     .clk_ref_i(clk200),

     .ui_clk(BUSCLK),
     .ui_clk_sync_rst(ui_clk_sync_rst),
     .aresetn(resetn),
     .sys_rst(resetn),    // omg. this is active low?!?!??
     .mmcm_locked(mmcm_locked),

     .app_sr_req(1'b0),  // reserved command
     .app_ref_req(1'b0), // refresh command
     .app_zq_req(1'b0),  // recalibrate command
     .app_sr_active(app_sr_active), // reserved response
     .app_ref_ack(app_ref_ack),     // refresh ack
     .app_zq_ack(app_zq_ack),       // recalibrate ack

     // axi
     .s_axi_awid(BUS_axi_awid),
     .s_axi_awaddr(BUS_axi_awaddr[27:0]),
     .s_axi_awlen(BUS_axi_awlen),
     .s_axi_awsize(BUS_axi_awsize),
     .s_axi_awburst(BUS_axi_awburst),
     .s_axi_awlock(BUS_axi_awlock),
     .s_axi_awcache(BUS_axi_awcache),
     .s_axi_awprot(BUS_axi_awprot),
     .s_axi_awqos(BUS_axi_awqos),
     .s_axi_awvalid(BUS_axi_awvalid),
     .s_axi_awready(BUS_axi_awready),
     .s_axi_wdata(BUS_axi_wdata),
     .s_axi_wstrb(BUS_axi_wstrb),
     .s_axi_wlast(BUS_axi_wlast),
     .s_axi_wvalid(BUS_axi_wvalid),
     .s_axi_wready(BUS_axi_wready),
     .s_axi_bready(BUS_axi_bready),
     .s_axi_bid(BUS_axi_bid),
     .s_axi_bresp(BUS_axi_bresp),
     .s_axi_bvalid(BUS_axi_bvalid),
     .s_axi_arid(BUS_axi_arid),
     .s_axi_araddr(BUS_axi_araddr[27:0]),
     .s_axi_arlen(BUS_axi_arlen),
     .s_axi_arsize(BUS_axi_arsize),
     .s_axi_arburst(BUS_axi_arburst),
     .s_axi_arlock(BUS_axi_arlock),
     .s_axi_arcache(BUS_axi_arcache),
     .s_axi_arprot(BUS_axi_arprot),
     .s_axi_arqos(BUS_axi_arqos),
     .s_axi_arvalid(BUS_axi_arvalid),
     .s_axi_arready(BUS_axi_arready),
     .s_axi_rready(BUS_axi_rready),
     .s_axi_rlast(BUS_axi_rlast),
     .s_axi_rvalid(BUS_axi_rvalid),
     .s_axi_rresp(BUS_axi_rresp),
     .s_axi_rid(BUS_axi_rid),
     .s_axi_rdata(BUS_axi_rdata),

     .init_calib_complete(c0_init_calib_complete),
     .device_temp(device_temp));

  (* mark_debug = "true" *)  logic IlaTrigger;


  if(RVVI_SYNTH_SUPPORTED) begin : rvvi_synth
    localparam MAX_CSRS = 3;
    localparam TOTAL_CSRS = 36;
    localparam [31:0] RVVI_INIT_TIME_OUT = 32'd100000000;
    localparam [31:0] RVVI_PACKET_DELAY = 32'd400;

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

    logic                                             valid;
    logic [72+(5*P.XLEN) + MAX_CSRS*(P.XLEN+16)-1:0] rvvi;

    assign StallE         = fpgaTop.wallypipelinedsoc.core.StallE;
    assign StallM         = fpgaTop.wallypipelinedsoc.core.StallM;
    assign StallW         = fpgaTop.wallypipelinedsoc.core.StallW;
    assign FlushE         = fpgaTop.wallypipelinedsoc.core.FlushE;
    assign FlushM         = fpgaTop.wallypipelinedsoc.core.FlushM;
    assign FlushW         = fpgaTop.wallypipelinedsoc.core.FlushW;
    assign InstrValidM    = fpgaTop.wallypipelinedsoc.core.ieu.InstrValidM;
    assign InstrRawD      = fpgaTop.wallypipelinedsoc.core.ifu.InstrRawD;
    assign PCM            = fpgaTop.wallypipelinedsoc.core.ifu.PCM;
    assign Mcycle         = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.counters.counters.HPMCOUNTER_REGW[0];
    assign Minstret       = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.counters.counters.HPMCOUNTER_REGW[2];
    assign TrapM          = fpgaTop.wallypipelinedsoc.core.TrapM;
    assign PrivilegeModeW = fpgaTop.wallypipelinedsoc.core.priv.priv.privmode.PrivilegeModeW;
    assign GPRAddr        = fpgaTop.wallypipelinedsoc.core.ieu.dp.regf.a3;
    assign GPRWen         = fpgaTop.wallypipelinedsoc.core.ieu.dp.regf.we3;
    assign GPRValue       = fpgaTop.wallypipelinedsoc.core.ieu.dp.regf.wd3;
    assign FPRAddr        = fpgaTop.wallypipelinedsoc.core.fpu.fpu.fregfile.a4;
    assign FPRWen         = fpgaTop.wallypipelinedsoc.core.fpu.fpu.fregfile.we4;
    assign FPRValue       = fpgaTop.wallypipelinedsoc.core.fpu.fpu.fregfile.wd4;

    assign CSRArray[0] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MSTATUS_REGW; // 12'h300
    assign CSRArray[1] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MSTATUSH_REGW; // 12'h310
    assign CSRArray[2] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MTVEC_REGW; // 12'h305
    assign CSRArray[3] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MEPC_REGW; // 12'h341
    assign CSRArray[4] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MCOUNTEREN_REGW; // 12'h306
    assign CSRArray[5] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MCOUNTINHIBIT_REGW; // 12'h320
    assign CSRArray[6] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MEDELEG_REGW; // 12'h302
    assign CSRArray[7] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MIDELEG_REGW; // 12'h303
    assign CSRArray[8] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MIP_REGW; // 12'h344
    assign CSRArray[9] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MIE_REGW; // 12'h304
    assign CSRArray[10] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MISA_REGW; // 12'h301
    assign CSRArray[11] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MENVCFG_REGW; // 12'h30A
    assign CSRArray[12] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MHARTID_REGW; // 12'hF14
    assign CSRArray[13] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MSCRATCH_REGW; // 12'h340
    assign CSRArray[14] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MCAUSE_REGW; // 12'h342
    assign CSRArray[15] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MTVAL_REGW; // 12'h343
    assign CSRArray[16] = 0; // 12'hF11
    assign CSRArray[17] = 0; // 12'hF12
    assign CSRArray[18] = {{P.XLEN-12{1'b0}}, 12'h100}; //P.XLEN'h100; // 12'hF13
    assign CSRArray[19] = 0; // 12'hF15
    assign CSRArray[20] = 0; // 12'h34A
    // supervisor CSRs
    assign CSRArray[21] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.SSTATUS_REGW; // 12'h100
    assign CSRArray[22] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MIE_REGW & 12'h222; // 12'h104
    assign CSRArray[23] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.STVEC_REGW; // 12'h105
    assign CSRArray[24] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.SEPC_REGW; // 12'h141
    assign CSRArray[25] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.SCOUNTEREN_REGW; // 12'h106
    assign CSRArray[26] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.SENVCFG_REGW; // 12'h10A
    assign CSRArray[27] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.SATP_REGW; // 12'h180
    assign CSRArray[28] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.SSCRATCH_REGW; // 12'h140
    assign CSRArray[29] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.STVAL_REGW; // 12'h143
    assign CSRArray[30] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.SCAUSE_REGW; // 12'h142
    assign CSRArray[31] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MIP_REGW & 12'h222 & fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MIDELEG_REGW; // 12'h144
    assign CSRArray[32] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.STIMECMP_REGW; // 12'h14D
    // user CSRs
    assign CSRArray[33] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csru.csru.FFLAGS_REGW; // 12'h001
    assign CSRArray[34] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csru.csru.FRM_REGW; // 12'h002
    assign CSRArray[35] = {fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csru.csru.FRM_REGW, fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csru.csru.FFLAGS_REGW}; // 12'h003

    rvvisynth #(P, MAX_CSRS) rvvisynth(.clk(CPUCLK), .reset(bus_struct_reset), .StallE, .StallM, .StallW, .FlushE, .FlushM, .FlushW,
      .PCM, .InstrValidM, .InstrRawD, .Mcycle, .Minstret, .TrapM,
      .PrivilegeModeW, .GPRWen, .FPRWen, .GPRAddr, .FPRAddr, .GPRValue, .FPRValue, .CSRArray,
      .valid, .rvvi);

    // axi 4 write data channel
    logic [31:0]                                      RvviAxiWdata;
    logic [3:0]                                       RvviAxiWstrb;
    logic                                             RvviAxiWlast;
    logic                                             RvviAxiWvalid;
    logic                                             RvviAxiWready;

    logic [31:0] RvviAxiRdata;
    logic [3:0]                                       RvviAxiRstrb;
    logic RvviAxiRlast;
    logic RvviAxiRvalid;

    logic                                             tx_error_underflow, tx_fifo_overflow, tx_fifo_bad_frame, tx_fifo_good_frame, rx_error_bad_frame;
    logic                                             rx_error_bad_fcs, rx_fifo_overflow, rx_fifo_bad_frame, rx_fifo_good_frame;

    packetizer #(P, MAX_CSRS, RVVI_INIT_TIME_OUT, RVVI_PACKET_DELAY) packetizer(.rvvi, .valid, .m_axi_aclk(CPUCLK), .m_axi_aresetn(~bus_struct_reset), .RVVIStall,
      .RvviAxiWdata, .RvviAxiWstrb, .RvviAxiWlast, .RvviAxiWvalid, .RvviAxiWready);

    eth_mac_mii_fifo #(.TARGET("XILINX"), .CLOCK_INPUT_STYLE("BUFG"), .AXIS_DATA_WIDTH(32), .TX_FIFO_DEPTH(1024)) ethernet(.rst(bus_struct_reset), .logic_clk(CPUCLK), .logic_rst(bus_struct_reset),
      .tx_axis_tdata(RvviAxiWdata), .tx_axis_tkeep(RvviAxiWstrb), .tx_axis_tvalid(RvviAxiWvalid), .tx_axis_tready(RvviAxiWready),
      .tx_axis_tlast(RvviAxiWlast), .tx_axis_tuser('0), .rx_axis_tdata(RvviAxiRdata),
      .rx_axis_tkeep(RvviAxiRstrb), .rx_axis_tvalid(RvviAxiRvalid), .rx_axis_tready(1'b1),
      .rx_axis_tlast(RvviAxiRlast), .rx_axis_tuser(),

      .mii_rx_clk(phy_rx_clk),
      .mii_rxd(phy_rxd),
      .mii_rx_dv(phy_rx_dv),
      .mii_rx_er(phy_rx_er),
      .mii_tx_clk(phy_tx_clk),
      .mii_txd(phy_txd),
      .mii_tx_en(phy_tx_en),
      .mii_tx_er(),

      // status
      .tx_error_underflow, .tx_fifo_overflow, .tx_fifo_bad_frame, .tx_fifo_good_frame, .rx_error_bad_frame,
      .rx_error_bad_fcs, .rx_fifo_overflow, .rx_fifo_bad_frame, .rx_fifo_good_frame,
      .cfg_ifg(8'd12), .cfg_tx_enable(1'b1), .cfg_rx_enable(1'b1)
      );

    triggergen triggergen(.clk(CPUCLK), .reset(bus_struct_reset), .RvviAxiRdata,
      .RvviAxiRstrb, .RvviAxiRlast, .RvviAxiRvalid, .IlaTrigger);
  end else begin // if (P.RVVI_SYNTH_SUPPORTED)
    assign IlaTrigger = '0;
    assign RVVIStall = '0;
  end

  //assign phy_reset_n = ~bus_struct_reset;
   assign phy_reset_n = ~1'b0;

endmodule
