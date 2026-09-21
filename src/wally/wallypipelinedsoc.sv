///////////////////////////////////////////
// wally-pipelinedsoc.sv
//
// Written: David_Harris@hmc.edu 6 November 2020
// Modified:
//
// Purpose: System on chip including pipelined processor and uncore memories/peripherals
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

module wallypipelinedsoc import cvw::*; #(parameter cvw_t P)  (
  input  logic                clk,
  input  logic                reset_ext,        // external asynchronous reset pin
  output logic                reset,            // reset synchronized to clk to prevent races on release
  // AHB Interface
  input  logic [P.AHBW-1:0]   HRDATAEXT,
  input  logic                HREADYEXT, HRESPEXT,
  output logic                HSELEXT,
  // fpga debug signals
  input  logic                ExternalStall,
  // outputs to external memory, shared with uncore memory
  output logic                HCLK, HRESETn,
  output logic [P.PA_BITS-1:0]  HADDR,
  output logic [P.AHBW-1:0]     HWDATA,
  output logic [P.XLEN/8-1:0]   HWSTRB,
  output logic                HWRITE,
  output logic [2:0]          HSIZE,
  output logic [2:0]          HBURST,
  output logic [3:0]          HPROT,
  output logic [1:0]          HTRANS,
  output logic                HMASTLOCK,
  output logic                HREADY,
  // I/O Interface
  input  logic                TIMECLK,          // optional for CLINT MTIME counter
  input  logic [31:0]         GPIOIN,           // inputs from GPIO
  output logic [31:0]         GPIOOUT,          // output values for GPIO
  output logic [31:0]         GPIOEN,           // output enables for GPIO
  input  logic                UARTSin,          // UART serial data input
  output logic                UARTSout,         // UART serial data output
  input  logic                SPIIn,            // SPI pins in
  output logic                SPIOut,           // SPI pins out
  output logic [3:0]          SPICS,            // SPI chip select pins
  output logic                SPICLK,           // SPI clock
  input  logic                SDCIn,            // SDC DATA[0]     to     SPI DI
  output logic                SDCCmd,           // SDC CMD         from   SPI DO
  output logic [3:0]          SDCCS,            // SDC Card Detect from   SPI CS
  output logic                SDCCLK,           // SDC Clock       from   SPI Clock
  input  logic                tck, tms, tdi,
  output logic                tdo
);

  // Uncore signals
  logic [P.AHBW-1:0]          HRDATA;           // from AHB mux in uncore
  logic                       HRESP;            // response from AHB
  logic                       MTimerInt, MSwInt;// timer and software interrupts from CLINT
  logic [63:0]                MTIME_CLINT;      // from CLINT to CSRs
  logic                       MExtInt,SExtInt;  // from PLIC

  // Debug signals
  logic [6:0]                 DMIADDR;
  logic [31:0]                DMIDATA;
  logic [1:0]                 DMIOP;
  logic                       DMIREADY;
  logic                       DMIVALID;

  logic [31:0]                DMIRSPDATA;
  logic [1:0]                 DMIRSPOP;
  logic                       DMIRSPREADY;
  logic                       DMIRSPVALID;

  logic                       DebugNDMReset;
  logic                       DebugHaltReq;
  logic                       DebugResumeReq;
  logic                       DebugMode;
  logic                       DebugGPREnable;
  logic                       DebugCSREnable;
  logic                       DebugFPREnable;
  logic [P.LLEN-1:0]          DebugRegRDATA;
  logic [P.LLEN-1:0]          DebugRegWDATA;
  logic [11:0]                DebugRegAddr;
  logic                       DebugRegWrite;
  logic                       DebugHaveReset;
  logic                       DebugHaveResetAck;
  logic                       DebugResetHaltReq;


  // synchronize reset to SOC clock domain
  synchronizer resetsync(.clk, .d(reset_ext), .q(reset));

  // instantiate processor and internal memories
  wallypipelinedcore #(P) core(.clk, .reset(reset | DebugNDMReset),
    .MTimerInt, .MExtInt, .SExtInt, .MSwInt, .MTIME_CLINT,
    .HRDATA, .HREADY, .HRESP, .HCLK, .HRESETn, .HADDR, .HWDATA, .HWSTRB,
    .HWRITE, .HSIZE, .HBURST, .HPROT, .HTRANS, .HMASTLOCK, .ExternalStall,
    .DebugMode, .DebugHaltReq, .DebugResumeReq, .DebugGPREnable, .DebugCSREnable, .DebugFPREnable,
    .DebugRegRDATA, .DebugRegWDATA, .DebugRegAddr, .DebugRegWrite,
    .DebugHaveReset, .DebugHaveResetAck, .DebugResetHaltReq
   );

  // instantiate uncore if a bus interface exists
  if (P.BUS_SUPPORTED) begin : uncoregen // Hack to work around Verilator bug https://github.com/verilator/verilator/issues/4769
    uncore #(P) uncore(.HCLK, .HRESETn, .TIMECLK,
      .HADDR, .HWDATA, .HWSTRB, .HWRITE, .HSIZE, .HBURST, .HPROT, .HTRANS, .HMASTLOCK, .HRDATAEXT,
      .HREADYEXT, .HRESPEXT, .HRDATA, .HREADY, .HRESP, .HSELEXT,
      .MTimerInt, .MSwInt, .MExtInt, .SExtInt, .GPIOIN, .GPIOOUT, .GPIOEN, .UARTSin,
      .UARTSout, .MTIME_CLINT, .SPIIn, .SPIOut, .SPICS, .SPICLK, .SDCIn, .SDCCmd, .SDCCS, .SDCCLK);
  end else begin
    assign {HRDATA, HREADY, HRESP, HSELEXT, MTimerInt, MSwInt, MExtInt, SExtInt,
            MTIME_CLINT, GPIOOUT, GPIOEN, UARTSout, SPIOut, SPICS, SPICLK, SDCCmd, SDCCS, SDCCLK} = '0;
  end

  if (P.DEBUG_SUPPORTED) begin : debug
    dtm #(P) dtm(.clk, .reset, .tck, .tms, .tdi, .tdo,
      .DMIADDR, .DMIDATA, .DMIOP, .DMIREADY, .DMIVALID,
      .DMIRSPDATA, .DMIRSPOP, .DMIRSPREADY, .DMIRSPVALID);

    debug #(P) debug(.clk, .reset, .DebugNDMReset, .DebugHaltReq, .DebugResumeReq, .DebugMode,
      .DebugGPREnable, .DebugCSREnable, .DebugFPREnable,
      .DMIADDR, .DMIDATA, .DMIOP, .DMIREADY, .DMIVALID,
      .DMIRSPDATA, .DMIRSPOP, .DMIRSPREADY, .DMIRSPVALID,
      .DebugRegRDATA, .DebugRegWDATA, .DebugRegAddr, .DebugRegWrite,
      .DebugHaveReset, .DebugHaveResetAck, .DebugResetHaltReq);
  end else begin
    assign tdo = 1'bz;
    assign DebugGPREnable = 0;
    assign DebugCSREnable = 0;
    assign DebugFPREnable = 0;
    assign DebugRegWDATA = '0;
    assign DebugRegAddr = '0;
    assign DebugRegWrite = 0;
    assign DebugHaltReq = 0;
    assign DebugResumeReq = 0;
    assign DebugNDMReset = 0;
    assign DebugHaveResetAck = 0;
    assign DebugResetHaltReq = 0;
  end

endmodule
