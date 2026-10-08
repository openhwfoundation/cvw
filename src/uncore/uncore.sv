///////////////////////////////////////////
// uncore.sv
//
// Written: David_Harris@hmc.edu 9 January 2021
// Modified: Ben Bracker 6 Mar 2021 to better fit AMBA 3 AHB-Lite spec
//
// Purpose: System-on-Chip components outside the core
//          Memories, peripherals, external bus control
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

module uncore import cvw::*;  #(parameter cvw_t P)(
  // AHB Bus Interface
  input  logic                 HCLK, HRESETn,
  input  logic                 TIMECLK,
  input  logic [P.PA_BITS-1:0] HADDR,
  input  logic [P.AHBW-1:0]    HWDATA,
  input  logic [P.XLEN/8-1:0]  HWSTRB,
  input  logic                 HWRITE,
  input  logic [2:0]           HSIZE,
  input  logic [2:0]           HBURST,
  input  logic [3:0]           HPROT,
  input  logic [1:0]           HTRANS,
  input  logic                 HMASTLOCK,
  input  logic [P.AHBW-1:0]    HRDATAEXT,
  input  logic                 HREADYEXT, HRESPEXT,
  output logic [P.AHBW-1:0]    HRDATA,
  output logic                 HREADY, HRESP,
  output logic                 HSELEXT,
  // peripheral pins
  output logic                 MTimerInt, MSwInt,         // Timer and software interrupts from CLINT
  output logic                 MExtInt, SExtInt,          // External interrupts from PLIC
  output logic [63:0]          MTIME_CLINT,               // MTIME, from CLINT
  input  logic [31:0]          GPIOIN,                    // GPIO pin input value
  output logic [31:0]          GPIOOUT, GPIOEN,           // GPIO pin output value and enable
  input  logic                 UARTSin,                   // UART serial input
  output logic                 UARTSout,                  // UART serial output
  input  logic                 SPIIn,
  output logic                 SPIOut,
  output logic [3:0]           SPICS,
  output logic                 SPICLK,
  input  logic                 SDCIn,
  output logic                 SDCCmd,
  output logic [3:0]           SDCCS,
  output logic                 SDCCLK,
  output logic [3:0]           PWMGPIO
);

  logic [P.XLEN-1:0]           HREADRam, HREADSDC;

  logic [12:0]                 HSELRegions;
  logic                        HSELDTIM, HSELIROM, HSELRam, HSELCLINT, HSELPLIC, HSELGPIO, HSELUART,HSELSDC, HSELSPI, HSELPWM;
  logic                        HSELDTIMD, HSELIROMD, HSELEXTD, HSELRamD, HSELCLINTD, HSELPLICD, HSELGPIOD, HSELUARTD, HSELSDCD, HSELSPID, HSELPWMD;
  logic                        HRESPRam,  HRESPSDC;
  logic                        HREADYRam, HRESPSDCD;
  logic [P.XLEN-1:0]           HREADBootRom;
  logic                        HSELBootRom, HSELBootRomD, HRESPBootRom, HREADYBootRom, HREADYSDC;
  logic                        HSELNoneD;
  logic                        UARTIntr,GPIOIntr, SPIIntr;
  logic [3:0]                  PWMIntr;                     // one PLIC source per PWM comparator, as in the FU540
  logic                        SDCIntM;

  logic                        PCLK, PRESETn, PWRITE, PENABLE;
  logic [6:0]                  PSEL;
  logic [31:0]                 PADDR;
  logic [P.XLEN-1:0]           PWDATA;
  logic [P.XLEN/8-1:0]         PSTRB;
  /* verilator lint_off UNDRIVEN */ // undriven in rv32e configuration
  logic [6:0]                  PREADY;
  logic [6:0][P.XLEN-1:0]      PRDATA;
  /* verilator lint_on UNDRIVEN */
  logic [P.XLEN-1:0]           HREADBRIDGE;
  logic                        HRESPBRIDGE, HREADYBRIDGE, HSELBRIDGE, HSELBRIDGED;
  /* SDC Interrupt (SPI Controller) */
  logic                        SDCIntr;


  // Determine which region of physical memory (if any) is being accessed
  // Use a trimmed down portion of the PMA checker - only the address decoders
  // Set access types to all 1 as don't cares because the MMU has already done access checking
  adrdecs #(P) adrdecs(HADDR, 1'b1, 1'b1, 1'b1, HSIZE[1:0], HSELRegions);

  // unswizzle HSEL signals
  assign {HSELPWM, HSELSPI, HSELSDC, HSELPLIC, HSELUART, HSELGPIO, HSELCLINT, HSELRam, HSELBootRom, HSELEXT, HSELIROM, HSELDTIM} = HSELRegions[12:1];

  // AHB -> APB bridge
  ahbapbbridge #(P, 7) ahbapbbridge (
    .HCLK, .HRESETn, .HSEL({HSELPWM, HSELSDC, HSELSPI, HSELUART, HSELPLIC, HSELCLINT, HSELGPIO}), .HADDR, .HWDATA, .HWSTRB, .HWRITE, .HTRANS, .HREADY,
    .HRDATA(HREADBRIDGE), .HRESP(HRESPBRIDGE), .HREADYOUT(HREADYBRIDGE),
    .PCLK, .PRESETn, .PSEL, .PWRITE, .PENABLE, .PADDR, .PWDATA, .PSTRB, .PREADY, .PRDATA);
  assign HSELBRIDGE = HSELGPIO | HSELCLINT | HSELPLIC | HSELUART | HSELSPI | HSELSDC | HSELPWM; // if any of the bridge signals are selected

  // on-chip RAM
  if (P.UNCORE_RAM_SUPPORTED) begin : ram
    ram_ahb #(.P(P), .RANGE(P.UNCORE_RAM_RANGE), .PRELOAD(P.UNCORE_RAM_PRELOAD)) ram (
      .HCLK, .HRESETn, .HSELRam, .HADDR, .HWRITE, .HREADY,
      .HTRANS, .HWDATA, .HWSTRB, .HREADRam, .HRESPRam, .HREADYRam);
  end else assign {HREADRam, HRESPRam, HREADYRam} = '0;

 if (P.BOOTROM_SUPPORTED) begin : bootrom
    rom_ahb #(.P(P), .RANGE(P.BOOTROM_RANGE), .PRELOAD(P.BOOTROM_PRELOAD))
    bootrom(.HCLK, .HRESETn, .HSELRom(HSELBootRom), .HADDR, .HREADY, .HTRANS,
      .HREADRom(HREADBootRom), .HRESPRom(HRESPBootRom), .HREADYRom(HREADYBootRom));
  end else assign {HREADBootRom, HRESPBootRom, HREADYBootRom} = '0;

  // memory-mapped I/O peripherals
  if (P.CLINT_SUPPORTED == 1) begin : clint
    clint_apb #(P) clint(.PCLK, .PRESETn, .PSEL(PSEL[1]), .PADDR(PADDR[15:0]), .PWDATA, .PSTRB, .PWRITE, .PENABLE,
      .PRDATA(PRDATA[1]), .PREADY(PREADY[1]), .MTIME(MTIME_CLINT), .MTimerInt, .MSwInt);
  end else begin : clint
    assign MTIME_CLINT = '0;
    assign MTimerInt = 1'b0; assign MSwInt = 1'b0;
  end

  if (P.PLIC_SUPPORTED == 1) begin : plic
    plic_apb #(P) plic(.PCLK, .PRESETn, .PSEL(PSEL[2]), .PADDR(PADDR[27:0]), .PWDATA, .PSTRB, .PWRITE, .PENABLE,
      .PRDATA(PRDATA[2]), .PREADY(PREADY[2]), .UARTIntr, .GPIOIntr, .SDCIntr, .SPIIntr, .PWMIntr, .MExtInt, .SExtInt);
  end else begin : plic
    assign MExtInt = 1'b0;
    assign SExtInt = 1'b0;
  end

  if (P.GPIO_SUPPORTED == 1) begin : gpio
    gpio_apb #(P) gpio(
      .PCLK, .PRESETn, .PSEL(PSEL[0]), .PADDR(PADDR[7:0]), .PWDATA, .PSTRB, .PWRITE, .PENABLE,
      .PRDATA(PRDATA[0]), .PREADY(PREADY[0]),
      .iof0({28'b0, PWMGPIO[3:0]}), .iof1(), .GPIOIN, .GPIOOUT, .GPIOEN, .GPIOIntr);
  end else begin : gpio
    assign GPIOOUT = '0; assign GPIOEN = '0; assign GPIOIntr = 1'b0;
  end

  if (P.UART_SUPPORTED == 1) begin : uartgen // Hack to work around Verilator bug https://github.com/verilator/verilator/issues/4769
    uart_apb #(P) uart(
      .PCLK, .PRESETn, .PSEL(PSEL[3]), .PADDR(PADDR[2:0]), .PWDATA, .PSTRB, .PWRITE, .PENABLE,
      .PRDATA(PRDATA[3]), .PREADY(PREADY[3]),
      .SIN(UARTSin), .DSRb(1'b1), .DCDb(1'b1), .CTSb(1'b0), .RIb(1'b1), // from E1A driver from RS232 interface
      .SOUT(UARTSout), .RTSb(), .DTRb(),                                // to E1A driver to RS232 interface
      .OUT1b(), .OUT2b(), .INTR(UARTIntr), .TXRDYb(), .RXRDYb());       // to CPU
  end else begin : uart
    assign UARTSout = 1'b0; assign UARTIntr = 1'b0;
  end

  if (P.SPI_SUPPORTED == 1) begin : spi
    spi_apb  #(P) spi (
      .PCLK, .PRESETn, .PSEL(PSEL[4]), .PADDR(PADDR[7:0]), .PWDATA, .PSTRB, .PWRITE, .PENABLE,
      .PREADY(PREADY[4]), .PRDATA(PRDATA[4]),
      .SPIOut, .SPIIn, .SPICS, .SPICLK, .SPIIntr);
  end else begin : spi
    assign SPIOut = 1'b0; assign SPICS = '0; assign SPIIntr = 1'b0; assign SPICLK = 1'b0;
  end

  if (P.SDC_SUPPORTED == 1) begin : sdc
    spi_apb #(P) sdc(
      .PCLK, .PRESETn, .PSEL(PSEL[5]), .PADDR(PADDR[7:0]), .PWDATA, .PSTRB, .PWRITE, .PENABLE,
      .PREADY(PREADY[5]), .PRDATA(PRDATA[5]),
      .SPIOut(SDCCmd), .SPIIn(SDCIn), .SPICS(SDCCS), .SPICLK(SDCCLK), .SPIIntr(SDCIntr));
  end else begin : sdc
    assign SDCCmd = '0; assign SDCCS = 4'b0; assign SDCIntr = 1'b0; assign SDCCLK = 1'b0;
  end

  if (P.PWM_SUPPORTED == 1) begin : pwm
    pwm_apb #(P) pwm(
      .PCLK, .PRESETn, .PSEL(PSEL[6]), .PADDR(PADDR[7:0]), .PWDATA, .PSTRB, .PWRITE, .PENABLE,
      .PREADY(PREADY[6]), .PRDATA(PRDATA[6]),
      .PWMIntr, .PWMGPIO);
  end else begin : pwm
    assign PWMIntr = '0; assign PWMGPIO = '0;
  end

  // AHB Read Multiplexer
  assign HRDATA = ({P.XLEN{HSELRamD}} & HREADRam) |
                  ({P.XLEN{HSELEXTD}} & HRDATAEXT) |
                  ({P.XLEN{HSELBRIDGED}} & HREADBRIDGE) |
                  ({P.XLEN{HSELBootRomD}} & HREADBootRom);

  assign HRESP = HSELRamD & HRESPRam |
                 HSELEXTD & HRESPEXT |
                 HSELBRIDGE & HRESPBRIDGE |
                 HSELBootRomD & HRESPBootRom;

  assign HREADY = HSELRamD & HREADYRam |
                  HSELEXTD & HREADYEXT |
                  HSELBRIDGED & HREADYBRIDGE |
                  HSELBootRomD & HREADYBootRom |
                  HSELNoneD; // don't lock up the bus if no region is being accessed

  // Address Decoder Delay (figure 4-2 in spec)
  // The select for HREADY needs to be based on the address phase address.  If the device
  // takes more than 1 cycle to respond it needs to hold on to the old select until the
  // device is ready.  Hence this register must be selectively enabled by HREADY.
  // However on reset None must be selected.
  flopenl #(13) hseldelayreg(HCLK, ~HRESETn, HREADY, HSELRegions, 13'b1,
    {HSELPWMD, HSELSPID, HSELSDCD, HSELPLICD, HSELUARTD, HSELGPIOD, HSELCLINTD,
      HSELRamD, HSELBootRomD, HSELEXTD, HSELIROMD, HSELDTIMD, HSELNoneD});
  flopenr #(1) hselbridgedelayreg(HCLK, ~HRESETn, HREADY, HSELBRIDGE, HSELBRIDGED);
endmodule
