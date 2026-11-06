///////////////////////////////////////////
// clint_apb.sv
//
// Written:  David Harris David_Harris@hmc.edu 14 January 2021
// Modified: Rose Thompson, Ben Bracker
//
// Purpose: Core-local interruptor (CLINT) on APB.
//          See FE310-G002-Manual-v19p05.
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

module clint_apb import cvw::*; #(parameter cvw_t P) (
  input  logic                PCLK, PRESETn,    // APB clock and reset (active low)
  input  logic                PSEL,             // APB peripheral select
  input  logic [15:0]         PADDR,            // APB address
  input  logic [P.XLEN-1:0]   PWDATA,           // APB write data
  input  logic [P.XLEN/8-1:0] PSTRB,            // APB byte write strobes
  input  logic                PWRITE,           // APB write (1) or read (0)
  input  logic                PENABLE,          // APB enable (access phase)
  output logic [P.XLEN-1:0]   PRDATA,           // APB read data
  output logic                PREADY,           // APB ready
  output logic [63:0]         MTIME,            // Machine timer value
  output logic                MTimerInt, MSwInt // Machine timer and software interrupts
);

  // register map
  localparam CLINT_MSIP      = 16'h0000;
  localparam CLINT_MTIMECMP  = 16'h4000;
  localparam CLINT_MTIMECMPH = 16'h4004;
  localparam CLINT_MTIME     = 16'hBFF8;
  localparam CLINT_MTIMEH    = 16'hBFFC;

  logic                       MSIP;
  logic [15:0]                entry;
  logic                       memwrite;
  logic [63:0]                MTIMECMP;
  integer                     i, j;

  assign memwrite = PWRITE & PENABLE & PSEL;  // only write in access phase
  assign PREADY   = 1'b1;                     // CLINT never takes >1 cycle to respond

  // word aligned reads
  if (P.XLEN == 64) assign entry = {PADDR[15:3], 3'b000};
  else              assign entry = {PADDR[15:2], 2'b00};

  // register access
  if (P.XLEN == 64) begin : clint // 64-bit
    always_ff @(posedge PCLK) begin
      case (entry)
        CLINT_MSIP:     PRDATA <= {63'b0, MSIP};
        CLINT_MTIMECMP: PRDATA <= MTIMECMP;
        CLINT_MTIME:    PRDATA <= MTIME;
        default:        PRDATA <= '0;
      endcase
    end
    always_ff @(posedge PCLK)
      if (~PRESETn) begin
        MSIP <= 1'b0;
        MTIMECMP <= 64'hFFFFFFFFFFFFFFFF; // Spec says MTIMECMP is not reset, but we reset to maximum value to prevent spurious timer interrupts
      end else if (memwrite) begin
        if ((entry == CLINT_MSIP) & PSTRB[0]) MSIP <= PWDATA[0]; // only a write of byte 0 changes MSIP
        if (entry == CLINT_MTIMECMP) begin
          for (i = 0; i < P.XLEN/8; i++)
            if (PSTRB[i])
              MTIMECMP[i*8 +: 8] <= PWDATA[i*8 +: 8];
        end
      end

    always_ff @(posedge PCLK)
      if (~PRESETn) begin
        MTIME <= '0;
      end else if (memwrite & entry == CLINT_MTIME) begin
        for (j = 0; j < P.XLEN/8; j++)
          if (PSTRB[j])
            MTIME[j*8 +: 8] <= PWDATA[j*8 +: 8];
      end else MTIME <= MTIME + 1;
  end else begin : clint // 32-bit
    always_ff @(posedge PCLK) begin
      case (entry)
        CLINT_MSIP:      PRDATA <= {31'b0, MSIP};
        CLINT_MTIMECMP:  PRDATA <= MTIMECMP[31:0];
        CLINT_MTIMECMPH: PRDATA <= MTIMECMP[63:32];
        CLINT_MTIME:     PRDATA <= MTIME[31:0];
        CLINT_MTIMEH:    PRDATA <= MTIME[63:32];
        default:         PRDATA <= '0;
      endcase
    end
    always_ff @(posedge PCLK)
      if (~PRESETn) begin
        MSIP <= 1'b0;
        MTIMECMP <= 64'hFFFFFFFFFFFFFFFF; // Spec says MTIMECMP is not reset, but we reset to maximum value to prevent spurious timer interrupts
      end else if (memwrite) begin
        if ((entry == CLINT_MSIP) & PSTRB[0]) MSIP <= PWDATA[0]; // only a write of byte 0 changes MSIP
        if (entry == CLINT_MTIMECMP)
          for (j = 0; j < P.XLEN/8; j++)
            if (PSTRB[j])
              MTIMECMP[j*8 +: 8] <= PWDATA[j*8 +: 8];
        if (entry == CLINT_MTIMECMPH)
          for (j = 0; j < P.XLEN/8; j++)
            if (PSTRB[j])
              MTIMECMP[32 + j*8 +: 8] <= PWDATA[j*8 +: 8];
      end

    always_ff @(posedge PCLK)
      if (~PRESETn) begin
        MTIME <= '0;
        // MTIMECMP is not reset
      end else if (memwrite & (entry == CLINT_MTIME)) begin
        for (i = 0; i < P.XLEN/8; i++)
          if (PSTRB[i])
            MTIME[i*8 +: 8] <= PWDATA[i*8 +: 8];
      end else if (memwrite & (entry == CLINT_MTIMEH)) begin
        for (i = 0; i < P.XLEN/8; i++)
          if (PSTRB[i])
            MTIME[32 + i*8 +: 8] <= PWDATA[i*8 +: 8];
      end else MTIME <= MTIME + 1;
  end

  // Software interrupt when MSIP is set
  assign MSwInt = MSIP;
  // Timer interrupt when MTIME >= MTIMECMP
  assign MTimerInt = ({1'b0, MTIME} >= {1'b0, MTIMECMP}); // unsigned comparison

endmodule
