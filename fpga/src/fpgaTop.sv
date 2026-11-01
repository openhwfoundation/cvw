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

module fpgaTop
  (input           default_250mhz_clk1_0_n,
   input           default_250mhz_clk1_0_p,
   input           reset,
   input           south_rst,

   input [2:0]     GPI,
   output [4:0]    GPO,

   input           UARTSin,
   output          UARTSout,

   // SDC Signals connecting to an SPI peripheral
   input         SDCIn,
   output        SDCCLK,
   output        SDCCmd,
   output        SDCCS,
   input         SDCCD,
   input         SDCWP,

   output          cpu_reset,
   output          ahblite_resetn,

   output [16 : 0] c0_ddr4_adr,
   output [1 : 0]  c0_ddr4_ba,
   output [0 : 0]  c0_ddr4_cke,
   output [0 : 0]  c0_ddr4_cs_n,
   inout [7 : 0]   c0_ddr4_dm_dbi_n,
   inout [63 : 0]  c0_ddr4_dq,
   inout [7 : 0]   c0_ddr4_dqs_c,
   inout [7 : 0]   c0_ddr4_dqs_t,
   output [0 : 0]  c0_ddr4_odt,
   output [0 : 0]  c0_ddr4_bg,
   output          c0_ddr4_reset_n,
   output          c0_ddr4_act_n,
   output [0 : 0]  c0_ddr4_ck_c,
   output [0 : 0]  c0_ddr4_ck_t
   );

  logic       CPUCLK;
  logic       c0_ddr4_ui_clk_sync_rst;
  logic       bus_struct_reset;
  logic       peripheral_reset;
  logic       interconnect_aresetn;
  logic       peripheral_aresetn;
  logic       mb_reset;

  logic            HCLKOpen;
  logic            HRESETnOpen;
  logic [64-1:0]   HRDATAEXT;
  logic            HREADYEXT;
  logic            HRESPEXT;
  logic            HSELEXT;
  logic [55:0]     HADDR;
  logic [64-1:0]   HWDATA;
  logic [64/8-1:0] HWSTRB;
  logic            HWRITE;
  logic [2:0]      HSIZE;
  logic [2:0]      HBURST;
  logic [1:0]      HTRANS;
  logic            HREADY;
  logic [3:0]      HPROT;
  logic            HMASTLOCK;

  logic            RVVIStall;

  logic [31:0]     GPIOIN, GPIOOUT, GPIOEN;

  logic [3:0]     m_axi_awid;
  logic [7:0]     m_axi_awlen;
  logic [2:0]     m_axi_awsize;
  logic [1:0]     m_axi_awburst;
  logic [3:0]     m_axi_awcache;
  logic [31:0]    m_axi_awaddr;
  logic [2:0]     m_axi_awprot;
  logic           m_axi_awvalid;
  logic           m_axi_awready;
  logic           m_axi_awlock;
  logic [63:0]    m_axi_wdata;
  logic [7:0]     m_axi_wstrb;
  logic           m_axi_wlast;
  logic           m_axi_wvalid;
  logic           m_axi_wready;
  logic [3:0]     m_axi_bid;
  logic [1:0]     m_axi_bresp;
  logic           m_axi_bvalid;
  logic           m_axi_bready;
  logic [3:0]     m_axi_arid;
  logic [7:0]     m_axi_arlen;
  logic [2:0]     m_axi_arsize;
  logic [1:0]     m_axi_arburst;
  logic [2:0]     m_axi_arprot;
  logic [3:0]     m_axi_arcache;
  logic           m_axi_arvalid;
  logic [31:0]    m_axi_araddr;
  logic           m_axi_arlock;
  logic           m_axi_arready;
  logic [3:0]     m_axi_rid;
  logic [63:0]    m_axi_rdata;
  logic [1:0]     m_axi_rresp;
  logic           m_axi_rvalid;
  logic           m_axi_rlast;
  logic           m_axi_rready;

  // Extra Bus signals
  logic [3:0]     BUS_axi_arregion;
  logic [3:0]     BUS_axi_arqos;
  logic [3:0]     BUS_axi_awregion;
  logic [3:0]     BUS_axi_awqos;

  // Bus signals
  logic [3:0]     BUS_axi_awid;
  logic [7:0]     BUS_axi_awlen;
  logic [2:0]     BUS_axi_awsize;
  logic [1:0]     BUS_axi_awburst;
  logic [3:0]     BUS_axi_awcache;
  logic [30:0]    BUS_axi_awaddr;
  logic [2:0]     BUS_axi_awprot;
  logic           BUS_axi_awvalid;
  logic           BUS_axi_awready;
  logic           BUS_axi_awlock;
  logic [63:0]    BUS_axi_wdata;
  logic [7:0]     BUS_axi_wstrb;
  logic           BUS_axi_wlast;
  logic           BUS_axi_wvalid;
  logic           BUS_axi_wready;
  logic [3:0]     BUS_axi_bid;
  logic [1:0]     BUS_axi_bresp;
  logic           BUS_axi_bvalid;
  logic           BUS_axi_bready;
  logic [3:0]     BUS_axi_arid;
  logic [7:0]     BUS_axi_arlen;
  logic [2:0]     BUS_axi_arsize;
  logic [1:0]     BUS_axi_arburst;
  logic [2:0]     BUS_axi_arprot;
  logic [3:0]     BUS_axi_arcache;
  logic           BUS_axi_arvalid;
  logic [30:0]    BUS_axi_araddr;
  logic           BUS_axi_arlock;
  logic           BUS_axi_arready;
  logic [3:0]     BUS_axi_rid;
  logic [63:0]    BUS_axi_rdata;
  logic [1:0]     BUS_axi_rresp;
  logic           BUS_axi_rvalid;
  logic           BUS_axi_rlast;
  logic           BUS_axi_rready;

  logic           BUSCLK;

  logic            c0_init_calib_complete;
  logic            dbg_clk;
  logic [511 : 0]  dbg_bus;

  logic            CLK208;

  assign GPIOIN = {25'b0, SDCCD, SDCWP, 2'b0, GPI};
  assign GPO = GPIOOUT[4:0];
  assign ahblite_resetn = peripheral_aresetn;
  assign cpu_reset = bus_struct_reset;

  logic [3:0] SDCCSin;
  assign SDCCS = SDCCSin[0];


  // reset controller XILINX IP
  sysrst sysrst
    (.slowest_sync_clk(CPUCLK),
     .ext_reset_in(c0_ddr4_ui_clk_sync_rst),
     .aux_reset_in(south_rst),
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
                    .UARTSin, .UARTSout, .SDCIn, .SDCCmd, .SDCCS(SDCCSin), .SDCCLK, .ExternalStall(RVVIStall));


  // ahb lite to axi bridge
  ahbaxibridge ahbaxibridge
    (.s_ahb_hclk(CPUCLK),
     .s_ahb_hresetn(peripheral_aresetn),
     .s_ahb_hsel(HSELEXT),
     .s_ahb_haddr(HADDR),
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
     .m_axi_aresetn(~reset),
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

  ddr4 ddr4
    (.c0_init_calib_complete(c0_init_calib_complete),
     .dbg_clk(dbg_clk), // open
     .c0_sys_clk_p(default_250mhz_clk1_0_p),
     .c0_sys_clk_n(default_250mhz_clk1_0_n),
     .sys_rst(reset),
     .dbg_bus(dbg_bus), // open

     // ddr4 I/O
     .c0_ddr4_adr(c0_ddr4_adr),
     .c0_ddr4_ba(c0_ddr4_ba),
     .c0_ddr4_cke(c0_ddr4_cke),
     .c0_ddr4_cs_n(c0_ddr4_cs_n),
     .c0_ddr4_dm_dbi_n(c0_ddr4_dm_dbi_n),
     .c0_ddr4_dq(c0_ddr4_dq),
     .c0_ddr4_dqs_c(c0_ddr4_dqs_c),
     .c0_ddr4_dqs_t(c0_ddr4_dqs_t),
     .c0_ddr4_odt(c0_ddr4_odt),
     .c0_ddr4_bg(c0_ddr4_bg),
     .c0_ddr4_reset_n(c0_ddr4_reset_n),
     .c0_ddr4_act_n(c0_ddr4_act_n),
     .c0_ddr4_ck_c(c0_ddr4_ck_c),
     .c0_ddr4_ck_t(c0_ddr4_ck_t),
     .c0_ddr4_ui_clk(BUSCLK),
     .c0_ddr4_ui_clk_sync_rst(c0_ddr4_ui_clk_sync_rst),
     .c0_ddr4_aresetn(~reset),

     // axi
     .c0_ddr4_s_axi_awid(BUS_axi_awid),
     .c0_ddr4_s_axi_awaddr(BUS_axi_awaddr[30:0]),
     .c0_ddr4_s_axi_awlen(BUS_axi_awlen),
     .c0_ddr4_s_axi_awsize(BUS_axi_awsize),
     .c0_ddr4_s_axi_awburst(BUS_axi_awburst),
     .c0_ddr4_s_axi_awlock(BUS_axi_awlock),
     .c0_ddr4_s_axi_awcache(BUS_axi_awcache),
     .c0_ddr4_s_axi_awprot(BUS_axi_awprot),
     .c0_ddr4_s_axi_awqos(BUS_axi_awqos),
     .c0_ddr4_s_axi_awvalid(BUS_axi_awvalid),
     .c0_ddr4_s_axi_awready(BUS_axi_awready),
     .c0_ddr4_s_axi_wdata(BUS_axi_wdata),
     .c0_ddr4_s_axi_wstrb(BUS_axi_wstrb),
     .c0_ddr4_s_axi_wlast(BUS_axi_wlast),
     .c0_ddr4_s_axi_wvalid(BUS_axi_wvalid),
     .c0_ddr4_s_axi_wready(BUS_axi_wready),
     .c0_ddr4_s_axi_bready(BUS_axi_bready),
     .c0_ddr4_s_axi_bid(BUS_axi_bid),
     .c0_ddr4_s_axi_bresp(BUS_axi_bresp),
     .c0_ddr4_s_axi_bvalid(BUS_axi_bvalid),
     .c0_ddr4_s_axi_arid(BUS_axi_arid),
     .c0_ddr4_s_axi_araddr(BUS_axi_araddr[30:0]),
     .c0_ddr4_s_axi_arlen(BUS_axi_arlen),
     .c0_ddr4_s_axi_arsize(BUS_axi_arsize),
     .c0_ddr4_s_axi_arburst(BUS_axi_arburst),
     .c0_ddr4_s_axi_arlock(BUS_axi_arlock),
     .c0_ddr4_s_axi_arcache(BUS_axi_arcache),
     .c0_ddr4_s_axi_arprot(BUS_axi_arprot),
     .c0_ddr4_s_axi_arqos(BUS_axi_arqos),
     .c0_ddr4_s_axi_arvalid(BUS_axi_arvalid),
     .c0_ddr4_s_axi_arready(BUS_axi_arready),
     .c0_ddr4_s_axi_rready(BUS_axi_rready),
     .c0_ddr4_s_axi_rlast(BUS_axi_rlast),
     .c0_ddr4_s_axi_rvalid(BUS_axi_rvalid),
     .c0_ddr4_s_axi_rresp(BUS_axi_rresp),
     .c0_ddr4_s_axi_rid(BUS_axi_rid),
     .c0_ddr4_s_axi_rdata(BUS_axi_rdata),

     .addn_ui_clkout1(CPUCLK),
     .addn_ui_clkout2(CLK208));

  assign RVVIStall = '0;

endmodule
