///////////////////////////////////////////
// clint_apb.sv
//
// Written: David_Harris@hmc.edu 14 January 2021
// Modified:
//
// Purpose: Core-Local Interruptor
//   See FE310-G002-Manual-v19p05 for specifications
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

module clint_apb import cvw::*;  #(parameter cvw_t P) (
  input  logic                PCLK, PRESETn,
  input  logic                PSEL,
  input  logic [15:0]         PADDR,
  input  logic [P.XLEN-1:0]   PWDATA,
  input  logic [P.XLEN/8-1:0] PSTRB,
  input  logic                PWRITE,
  input  logic                PENABLE,
  output logic [P.XLEN-1:0]   PRDATA,
  output logic                PREADY,
  output logic [63:0] MTIME,
  output logic                MTimerInt, MSwInt
);

  // register map
  localparam CLINT_MSIP     = 16'h0000;
  localparam CLINT_MTIMECMP = 16'h4000;
  localparam CLINT_MTIME    = 16'hBFF8;

  logic                       MSIP;
  logic [15:0]                entry;
  logic                       memwrite;
  logic [63:0] MTIMECMP;
  integer                     i, j;

  assign memwrite = PWRITE & PENABLE & PSEL;  // only write in access phase
  assign PREADY   = 1'b1;                     // CLINT never takes >1 cycle to respond

  // word aligned reads
  if (P.XLEN==64) assign entry = {PADDR[15:3], 3'b000};
  else            assign entry = {PADDR[15:2], 2'b00};

  // DH 2/20/21: Eventually allow MTIME to run off a separate clock
  // This will require synchronizing MTIME to the system clock
  // before it is read or compared to MTIMECMP.
  // It will also require synchronizing the write to MTIMECMP.
  // Use req and ack signals synchronized across the clock domains.

  // register access
  if (P.XLEN==64) begin : clint // 64-bit
    always_ff @(posedge PCLK) begin
      case(entry)
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
        if (entry == CLINT_MSIP) MSIP <= PWDATA[0];
        if (entry == CLINT_MTIMECMP) begin
          for(i=0;i<P.XLEN/8;i++)
            if(PSTRB[i])
              MTIMECMP[i*8 +: 8] <= PWDATA[i*8 +: 8];
        end
      end

// eventually replace MTIME logic below with timereg
//    timereg tr(PCLK, PRESETn, TIMECLK, memwrite & (entry==16'hBFF8), 1'b0, PWDATA, MTIME, done);

    always_ff @(posedge PCLK)
      if (~PRESETn) begin
        MTIME <= '0;
      end else if (memwrite & entry == 16'hBFF8) begin
        // MTIME Counter.  Eventually change this to run off separate clock.  Synchronization then needed
        for(j=0;j<P.XLEN/8;j++)
          if(PSTRB[j])
            MTIME[j*8 +: 8] <= PWDATA[j*8 +: 8];
      end else MTIME <= MTIME + 1;
  end else begin : clint // 32-bit
    always_ff @(posedge PCLK) begin
      case(entry)
        16'h0000: PRDATA <= {31'b0, MSIP};
        16'h4000: PRDATA <= MTIMECMP[31:0];
        16'h4004: PRDATA <= MTIMECMP[63:32];
        16'hBFF8: PRDATA <= MTIME[31:0];
        16'hBFFC: PRDATA <= MTIME[63:32];
        default:  PRDATA <= '0;
      endcase
    end
    always_ff @(posedge PCLK)
      if (~PRESETn) begin
        MSIP <= 1'b0;
        MTIMECMP <= 64'hFFFFFFFFFFFFFFFF; // Spec says MTIMECMP is not reset, but we reset to maximum value to prevent spurious timer interrupts
      end else if (memwrite) begin
        if (entry == 16'h0000) MSIP <= PWDATA[0];
        if (entry == 16'h4000)
          for(j=0;j<P.XLEN/8;j++)
            if(PSTRB[j])
              MTIMECMP[j*8 +: 8] <= PWDATA[j*8 +: 8];
        if (entry == 16'h4004)
          for(j=0;j<P.XLEN/8;j++)
            if(PSTRB[j])
              MTIMECMP[32 + j*8 +: 8] <= PWDATA[j*8 +: 8];
        // MTIME Counter.  Eventually change this to run off separate clock.  Synchronization then needed
      end

// eventually replace MTIME logic below with timereg
//     timereg tr(PCLK, PRESETn, TIMECLK, memwrite & (entry==16'hBFF8), memwrite & (entry == 16'hBFFC), PWDATA, MTIME, done);
    always_ff @(posedge PCLK)
      if (~PRESETn) begin
        MTIME <= '0;
        // MTIMECMP is not reset
      end else if (memwrite & (entry == 16'hBFF8)) begin
        for(i=0;i<P.XLEN/8;i++)
          if(PSTRB[i])
            MTIME[i*8 +: 8] <= PWDATA[i*8 +: 8];
      end else if (memwrite & (entry == 16'hBFFC)) begin
        // MTIME Counter.  Eventually change this to run off separate clock.  Synchronization then needed
        for(i=0;i<P.XLEN/8;i++)
          if(PSTRB[i])
            MTIME[32 + i*8 +: 8]<= PWDATA[i*8 +: 8];
      end else MTIME <= MTIME + 1;
  end

  // Software interrupt when MSIP is set
  assign MSwInt = MSIP;
  // Timer interrupt when MTIME >= MTIMECMP
  assign MTimerInt = ({1'b0, MTIME} >= {1'b0, MTIMECMP}); // unsigned comparison

endmodule

/*
module timeregsync  import cvw::*;  #(parameter cvw_t P) (
  input  logic              clk, resetn,
  input  logic              we0, we1,
  input  logic [P.XLEN-1:0] wd,
  output logic [63:0]       q);

  if (P.XLEN==64)
    always_ff @(posedge clk or negedge resetn)
      if (~resetn)  q <= '0;
      else if (we0) q <= wd;
      else          q <= q + 1;
  else
    always_ff @(posedge clk or negedge resetn)
      if (~resetn)  q <= '0;
      else if (we0) q[31:0] <= wd;
      else if (we1) q[63:32] <= wd;
      else          q <= q + 1;
endmodule


module timereg  import cvw::*;  #(parameter cvw_t P) (
  input  logic              PCLK, PRESETn, TIMECLK,
  input  logic              we0, we1,
  input  logic [P.XLEN-1:0] PWDATA,
  output logic [63:0]       MTIME,
  output logic              done);

//  if (P.TIMEBASE_SYNC) begin : timereg // use PCLK for MTIME
  if (1) begin : timereg // use PCLK for MTIME
    timregsync timeregsync(.clk(PCLK), .resetn(PRESETn), .we0, .we1, .wd(PWDATA), .q(MTIME));
    assign done = 1;   // immediately completes
  end else begin       // use asynchronous TIMECLK
    // TIME counter runs on TIMECLK but bus interface runs on PCLK
    // Need to synchronize reads and writes
    // This is subtle because synchronizing a binary counter on a per-bit basis could give a mix of old and new bits
    // Instead, we use a Gray coded counter that only changes one bit per cycle
    // Synchronizing this for a read is safe because we are guaranteed to get either the old or the new value.
    // Writing to the counter requires a request/acknowledge handshake to ensure the write value is held long enough.
    // The handshake signals are synchronized in each direction across the interface
    // There is no back pressure on instructions, so if multiple counter writes occur too close together, the results are unpredictable.

    logic req, req_sync, ack, we0_stored, we1_stored, ack_stored, resetn_sync;
    logic [P.XLEN-1:0] wd_stored;
    logic [63:0] time_int, time_int_gc, time_gc, MTIME_GC;

    // When a write enable is asserted for a cycle, sample the enables and data and raise a request until it is acknowledged
    // When the acknowledge falls, the transaction is done and the system is ready for another write.
    // When adding asynchronous timebase, look at redoing this assuming write enable and data are held rather than pulsed.
    always_ff @(posedge PCLK or negedge PRESETn)
      if (~PRESETn)
        req <= 0; // don't bother resetting wd
      else begin
        req        <= we0 | we1 | req & ~ack;
        we0_stored <= we0;
        we1_stored <= we1;
        wd_stored  <= PWDATA;
        ack_stored <= ack;
        done       <= ack_stored & ~ack;
      end

    // synchronize the reset and request into the TIMECLK domain
    sync resetsync(TIMECLK, PRESETn, resetn_sync);
    sync rsync(TIMECLK, req, req_sync);
    // synchronize the acknowledge back to the PCLK domain to indicate the request was handled and can be lowered
    sync async(PCLK, req_sync, ack);

    timeregsync #(P) timeregsync(.clk(TIMECLK), .resetn(resetn_sync), .we0(we0_stored), .we1(we1_stored), .wd(wd_stored), .q(time_int));
    binarytogray b2g(time_int, time_int_gc);
    flop gcreg(TIMECLK, time_int_gc, time_gc);

    sync timesync[63:0](PCLK, time_gc, MTIME_GC);
    graytobinary g2b(MTIME_GC, MTIME);
  end
endmodule

module binarytogray #(parameter N) (
  input  logic [N-1:0] b,
  output logic [N-1:0] g);

  // G[N-1] = B[N-1]; G[i] = B[i] ^ B[i+1] for 0 <= i < N-1
  // requires single layer of N-1 XOR gates
  assign g = b ^ {1'b0, b[N-1:1]};
endmodule

module graytobinary #(parameter N) (
  input  logic [N-1:0] g,
  output logic [N-1:0] b);

  // B[N-1] = G[N-1]; B[i] = G[i] ^ B[i+1] for 0 <= i < N-1
  // requires rippling through N-1 XOR gates
    genvar i;
    assign b[N-1] = g[N-1];
    for (i=N-2; i >= 0; i--) begin : g2b
      assign b[i] = g[i] ^ b[i+1];
    end
endmodule
*/
