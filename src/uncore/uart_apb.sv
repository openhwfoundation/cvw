///////////////////////////////////////////
// uart_apb.sv
//
// Written:  David Harris David_Harris@hmc.edu 21 January 2021
// Modified: Ben Bracker bbracker@hmc.edu
//
// Purpose: APB interface to the PC16550D-compatible UART.
//          Compatible with the UART in the Imperas Virtio model.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module uart_apb import cvw::*; #(parameter cvw_t P) (
  input  logic                PCLK, PRESETn,
  input  logic                PSEL,
  input  logic [2:0]          PADDR,
  input  logic [P.XLEN-1:0]   PWDATA,
  input  logic [P.XLEN/8-1:0] PSTRB,
  input  logic                PWRITE,
  input  logic                PENABLE,
  output logic [P.XLEN-1:0]   PRDATA,
  output logic                PREADY,
  input  logic                SIN, DSRb, DCDb, CTSb, RIb,           // from E1A driver from RS232 interface
  output logic                SOUT, RTSb, DTRb,                     // to E1A driver to RS232 interface
  output logic                OUT1b, OUT2b, INTR, TXRDYb, RXRDYb);  // to CPU

  // UART interface signals
  logic [2:0]      entry;
  logic            MEMRb, MEMWb, memread, memwrite;
  logic [7:0]      Din, Dout;

  assign memwrite = PWRITE & PENABLE & PSEL;  // only write in access phase
  assign memread  = ~PWRITE & PENABLE & PSEL;
  assign PREADY   = 1'b1; // CLINT never takes >1 cycle to respond
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
