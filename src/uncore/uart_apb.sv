///////////////////////////////////////////
// uart_apb.sv
//
// Written:  David Harris David_Harris@hmc.edu 21 January 2021
// Modified: Ben Bracker
//
// Purpose: APB interface to the PC16550D UART.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module uart_apb import cvw::*; #(parameter cvw_t P) (
  input  logic                PCLK, PRESETn,                        // APB clock and reset (active low)
  input  logic                PSEL,                                 // APB peripheral select
  input  logic [2:0]          PADDR,                                // APB address
  input  logic [P.XLEN-1:0]   PWDATA,                               // APB write data
  input  logic [P.XLEN/8-1:0] PSTRB,                                // APB byte write strobes
  input  logic                PWRITE,                               // APB write (1) or read (0)
  input  logic                PENABLE,                              // APB enable (access phase)
  output logic [P.XLEN-1:0]   PRDATA,                               // APB read data
  output logic                PREADY,                               // APB ready
  input  logic                SIN, DSRb, DCDb, CTSb, RIb,           // UART serial and modem control inputs
  output logic                SOUT, RTSb, DTRb,                     // UART serial and modem control outputs
  output logic                OUT1b, OUT2b, INTR, TXRDYb, RXRDYb);  // UART user outputs, interrupt, and DMA ready signals

  // UART interface signals
  logic [2:0]      entry;
  logic            MEMRb, MEMWb, memread, memwrite;
  logic [7:0]      Din, Dout;

  assign memwrite = PWRITE & PENABLE & PSEL;  // only write in access phase
  assign memread  = ~PWRITE & PENABLE & PSEL;
  assign PREADY   = 1'b1; // UART never takes >1 cycle to respond
  assign entry    = PADDR[2:0];
  assign MEMRb    = ~memread;
  assign MEMWb    = ~memwrite;

  assign Din = PWDATA[7:0];
  if (P.XLEN == 64) assign PRDATA = {Dout, Dout, Dout, Dout, Dout, Dout, Dout, Dout};
  else              assign PRDATA = {Dout, Dout, Dout, Dout};

  logic BAUDOUTb;  // loop tx clock BAUDOUTb back to rx clock RCLK
  uartPC16550D #(P.UART_PRESCALE) uartPC(
    // Processor Interface
    .PCLK, .PRESETn,
    .A(entry), .Din,
    .Dout,
    .MEMRb, .MEMWb,
    .INTR, .TXRDYb, .RXRDYb,
    // Clocks
    .BAUDOUTb, .RCLK(BAUDOUTb),
    // E1A Driver
    .SIN, .DSRb, .DCDb, .CTSb, .RIb,
    .SOUT, .RTSb, .DTRb, .OUT1b, .OUT2b
  );

endmodule
