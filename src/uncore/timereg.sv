///////////////////////////////////////////
// timereg.sv
//
// Written: David_Harris@hmc.edu 14 January 2021
// Modified:
//
// Purpose: Unfinished MTIME counter that can run from an asynchronous TIMECLK, moved out of clint_apb.sv.
//   Kept for future work; it is commented out and nothing instantiates it.
//
//   clint_apb.sv would replace its MTIME logic with
//     timereg tr(PCLK, PRESETn, TIMECLK, memwrite & (entry==16'hBFF8), 1'b0, PWDATA, MTIME, done);                          // RV64
//     timereg tr(PCLK, PRESETn, TIMECLK, memwrite & (entry==16'hBFF8), memwrite & (entry == 16'hBFFC), PWDATA, MTIME, done); // RV32
//   with TIMECLK brought back as a wallypipelinedsoc/uncore input.
//
//   Before enabling it:
//     - timregsync is a typo for timeregsync, and sync should be the synchronizer module
//     - binarytogray, graytobinary and gcreg need N = 64 / WIDTH = 64
//     - the commented TIMEBASE_SYNC parameter does not exist; if (1) always selects the PCLK counter
//     - it uses asynchronous active-low resets, unlike the rest of the design
//     - one module per file
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
