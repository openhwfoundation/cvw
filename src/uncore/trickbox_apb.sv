///////////////////////////////////////////
// trickbox_apb.sv
//
// Written: David_Harris@hmc.edu 20 May 2025
// Modified:
//
// Purpose: Trickbox, superset of CLINT
//  https://docs.google.com/document/d/1erHBVchBtwmgZ0bCNjb88spYfN7CpRbhmSNFH6cO8CY/edit?tab=t.0
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

module trickbox_apb import cvw::*;  #(parameter XLEN = 64, NUM_HARTS = 1) (
  input  logic                PCLK, PRESETn,
  input  logic                PSEL,
  input  logic [15:0]         PADDR,
  input  logic [XLEN-1:0]     PWDATA,
  input  logic [XLEN/8-1:0]   PSTRB,
  input  logic                PWRITE,
  input  logic                PENABLE,
  output logic [XLEN-1:0]     PRDATA,
  output logic                PREADY,
  input  logic [63:0]         MTIME_IN,
  input  logic [NUM_HARTS-1:0] MTIP_IN, MSIP_IN, SSIP_IN, MEIP_IN, SEIP_IN,
  input  var logic [XLEN-1:0] HGEIP_IN[NUM_HARTS-1:0],
  output logic [63:0]         MTIME_OUT,
  output logic [NUM_HARTS-1:0] MTIP_OUT, MSIP_OUT, SSIP_OUT, MEIP_OUT, SEIP_OUT,
  output var logic  [XLEN-1:0] HGEIP_OUT[NUM_HARTS-1:0],
  output logic [XLEN-1:0]     TOHOST_OUT
);

  // register map
  localparam CLINT_MSIP     = 16'h0000;
  localparam CLINT_MTIMECMP = 16'h4000;
  localparam CLINT_MTIME    = 16'hBFF8;

  logic [63:0]                MTIMECMP[NUM_HARTS-1:0];
  logic [7:0]                 TRICKEN;
  logic [63:0]                MTIME;
  logic [NUM_HARTS-1:0]       MTIP, MSIP, SSIP, MEIP, SEIP;
  logic [XLEN-1:0]            TOHOST;
  logic [XLEN-1:0]            HGEIP[NUM_HARTS-1:0];
  logic [15:0]                entry;
  logic [9:0]                 hart;                   // which hart is being accessed
  logic                       memwrite;
  logic [63:0]                RD;
  genvar                      i;

  assign memwrite = PWRITE & PENABLE & PSEL;  // only write in access phase
  assign PREADY   = 1'b1;                     // CLINT never takes >1 cycle to respond
  assign hart = PADDR[12:3];                  // middle bits of address allow control of up to 1024 harts

  // read circuitry
  // 64-bit accesses, then reduce to 32-bit for RV32
  always_ff @(posedge PCLK) begin
    case (PADDR[15:13])
      3'b000: RD <= {63'b0, MSIP[hart]};     // *** memory map
      3'b001: RD <= {63'b0, SSIP[hart]};
      3'b010: RD <= MTIMECMP[hart];
      3'b011: RD <= {63'b0, MEIP[hart]};
      3'b100: RD <= {63'b0, SEIP[hart]};
      3'b101: case (hart)
        10'b0000000000: RD <= TOHOST;
        10'b0000000001: RD <= '0; // Reading COM1 has no effect; busy bit not yet implemented.  Later add busy bit
        10'b0000000010: RD <= {56'b0, TRICKEN};
        10'b1111111111: RD <= MTIME;
        default: RD <= '0;
      endcase
      3'b110: RD <= HGEIP[hart];
      default: RD <= '0;
    endcase
  end

  // word aligned reads
  if (XLEN == 64) assign PRDATA = RD;
  else            assign PRDATA = RD[PADDR[2]*32 +: 32]; // 32-bit register access to upper or lower half

  // write circuitry
  always_ff @(posedge PCLK)
    if (~PRESETn) begin
      MSIP <= '0;
      SSIP <= '0;
      MEIP <= '0;
      SEIP <= '0;
      TOHOST <= '0;
      TRICKEN <= '0;
    end else if (memwrite) begin
      case (PADDR[15:13])
        3'b000: MSIP[hart] <= PWDATA[0];
        3'b001: SSIP[hart] <= PWDATA[0];
        3'b011: MEIP[hart] <= PWDATA[0];
        3'b100: SEIP[hart] <= PWDATA[0];
        3'b101: case (hart)
          10'b0000000000: TOHOST <= PWDATA;
          10'b0000000001: $display("%c", PWDATA[7:0]); // COM1 prints to simulation console.  Eventually allow it to be redirected to a UART, and provide a busy bit.
          10'b0000000010: TRICKEN <= PWDATA[7:0];
        endcase
      endcase
    end
    // generate loop write circuits for MTIMECMP and HGEIP
    for (i=0; i<NUM_HARTS; i++)
      always_ff @(posedge PCLK)
        if (~PRESETn) begin
          MTIMECMP[i] <= 64'hFFFFFFFFFFFFFFFF; // Spec says MTIMECMP is not reset, but we reset to maximum value to prevent spurious timer interrupts
          HGEIP[i] <= 0;
        end else if (memwrite & (hart == i)) begin
          if (PADDR[15:13] == 3'b010) begin
            if (XLEN == 64) MTIMECMP[hart] <= PWDATA; // 64-bit write
            else            MTIMECMP[hart][PADDR[2]*32 +: 32] <= PWDATA; // 32-bit write
          end else if (PADDR[15:13] == 3'b110) begin
            HGEIP[hart] <= PWDATA;
          end
        end

  // mtime register
  always_ff @(posedge PCLK)
    if (~PRESETn) begin
      MTIME <= '0;
    end else if (memwrite & (PADDR[15:13] == 3'b101 && hart == 10'b1111111111)) begin
      if (XLEN == 64) MTIME <= PWDATA; // 64-bit write
      else            MTIME <= MTIME[PADDR[2]*32 +: 32]; // 32-bit write
    end else          MTIME <= MTIME + 1;

  // timer interrupt when MTIME >= MTIMECMP (unsigned)
  for (i=0;i<NUM_HARTS;i++)
    assign MTIP[i] = ({1'b0, MTIME} >= {1'b0, MTIMECMP[i]});

  // TRICKEN controls whether outputs come from TrickBox or are daisy-chained from elsewhere
  always_comb begin
    MSIP_OUT = TRICKEN[0] ? MSIP : MSIP_IN;
    SSIP_OUT = TRICKEN[1] ? SSIP : SSIP_IN;
    MEIP_OUT = TRICKEN[2] ? MEIP : MEIP_IN;
    SEIP_OUT = TRICKEN[3] ? SEIP : SEIP_IN;
    MTIP_OUT = TRICKEN[4] ? MTIP : MTIP_IN;
    MTIME_OUT = TRICKEN[5] ? MTIME : MTIME_IN;
    TOHOST_OUT = TRICKEN[7] ? TOHOST : '0;
    // NO COM1
  end

  for (i=0; i<NUM_HARTS;i++)
    assign HGEIP_OUT[i] = TRICKEN[6] ? HGEIP[i] : HGEIP_IN[i];

endmodule
