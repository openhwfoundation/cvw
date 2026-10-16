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
// https://github.com/openhwfoundation/cvw
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

module wallypipelinedsoc import cvw::*; #(parameter cvw_t P) (
  input  logic                 clk,                 // Clock
  input  logic                 reset_ext,           // external asynchronous reset pin
  output logic                 reset,               // reset synchronized to clk to prevent races on release
  // AHB Interface
  input  logic [P.AHBW-1:0]    HRDATAEXT,           // AHB read data from external memory
  input  logic                 HREADYEXT, HRESPEXT, // AHB ready and response from external memory
  output logic                 HSELEXT,             // AHB select for external memory
  // fpga debug signals
  input  logic                 ExternalStall,       // External stall (FPGA debug)
  // outputs to external memory, shared with uncore memory
  output logic                 HCLK, HRESETn,       // AHB clock and reset (active low)
  output logic [P.PA_BITS-1:0] HADDR,               // AHB address
  output logic [P.AHBW-1:0]    HWDATA,              // AHB write data
  output logic [P.XLEN/8-1:0]  HWSTRB,              // AHB byte write enables
  output logic                 HWRITE,              // AHB write (1) or read (0)
  output logic [2:0]           HSIZE,               // AHB transfer size
  output logic [2:0]           HBURST,              // AHB burst type
  output logic [3:0]           HPROT,               // AHB protection.  Wally does not use
  output logic [1:0]           HTRANS,              // AHB transfer type: 00 IDLE, 10 NONSEQ, 11 SEQ
  output logic                 HMASTLOCK,           // AHB master lock.  Wally does not use
  output logic                 HREADY,              // AHB ready
  // I/O Interface
  input  logic                 TIMECLK,             // Optional clock for CLINT MTIME counter
  input  logic [31:0]          GPIOIN,              // GPIO input values
  output logic [31:0]          GPIOOUT,             // output values for GPIO
  output logic [31:0]          GPIOEN,              // output enables for GPIO
  input  logic                 UARTSin,             // UART serial input
  output logic                 UARTSout,            // UART serial output
  input  logic                 SPIIn,               // SPI pins in
  output logic                 SPIOut,              // SPI pins out
  output logic [3:0]           SPICS,               // SPI chip select pins
  output logic                 SPICLK,              // SPI clock
  input  logic                 SDCIn,               // SD card data[0], to SPI data in
  output logic                 SDCCmd,              // SD card command, from SPI data out
  output logic [3:0]           SDCCS,               // SD card chip select, from SPI chip select
  output logic                 SDCCLK,              // SD card clock, from SPI clock
  output logic [3:0]           PWMGPIO              // PWM GPIO output
);

  // Uncore signals
  logic [P.AHBW-1:0]          HRDATA;            // from AHB mux in uncore
  logic                       HRESP;             // response from AHB
  logic                       MTimerInt, MSwInt; // timer and software interrupts from CLINT
  logic [63:0]                MTIME_CLINT;       // from CLINT to CSRs
  logic                       MExtInt, SExtInt;  // from PLIC

  // synchronize reset to SOC clock domain
  synchronizer resetsync(.clk, .d(reset_ext), .q(reset));

  // instantiate processor and internal memories
  wallypipelinedcore #(P) core(.clk, .reset,
    .MTimerInt, .MExtInt, .SExtInt, .MSwInt, .MTIME_CLINT,
    .HRDATA, .HREADY, .HRESP, .HCLK, .HRESETn, .HADDR, .HWDATA, .HWSTRB,
    .HWRITE, .HSIZE, .HBURST, .HPROT, .HTRANS, .HMASTLOCK, .ExternalStall
  );

  // instantiate uncore if a bus interface exists
  if (P.BUS_SUPPORTED) begin : uncoregen // Hack to work around Verilator bug https://github.com/verilator/verilator/issues/4769
    uncore #(P) uncore(.HCLK, .HRESETn, .TIMECLK,
      .HADDR, .HWDATA, .HWSTRB, .HWRITE, .HSIZE, .HBURST, .HPROT, .HTRANS, .HMASTLOCK, .HRDATAEXT,
      .HREADYEXT, .HRESPEXT, .HRDATA, .HREADY, .HRESP, .HSELEXT,
      .MTimerInt, .MSwInt, .MExtInt, .SExtInt, .GPIOIN, .GPIOOUT, .GPIOEN, .UARTSin,
      .UARTSout, .MTIME_CLINT, .SPIIn, .SPIOut, .SPICS, .SPICLK, .SDCIn, .SDCCmd, .SDCCS, .SDCCLK, .PWMGPIO);
  end else begin
    assign {HRDATA, HREADY, HRESP, HSELEXT, MTimerInt, MSwInt, MExtInt, SExtInt,
            MTIME_CLINT, GPIOOUT, GPIOEN, UARTSout, SPIOut, SPICS, SPICLK, SDCCmd, SDCCS, SDCCLK, PWMGPIO} = '0;
  end

endmodule
