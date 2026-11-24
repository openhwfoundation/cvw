// vregfile_tb.sv
// Self-checking unit test of the banked vector register file.
// Run: tests/vector/unit/run vregfile
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

`include "config.vh"

import cvw::*;

module vregfile_tb;
  `include "parameter-defs.vh"

  // rv64gcv: VLEN 256 (from config.vh), 2 banks of 128 bits
  localparam BLEN = P.VPU_BLEN, ORDERBITS = P.VPU_QUEUEDEPTH, BANKS = P.VPU_BANKS, BYTES = BLEN/8;
  localparam CYCLES = 2000;

  logic                 clk = 0, reset = 1;
  logic                 VectorStallE = 0;
  logic [4:0]           Vs1D = '0, Vs2D = '0, VdD = '0;
  logic                 OldVdD = 0;
  logic [ORDERBITS-1:0] OrderD = '0;
  logic                 DirectAccessD = 0;
  logic [4:0]           DirectVs1D = '0, DirectVs2D = '0;
  logic                 BanksDrainedD;
  logic [BLEN-1:0]      VRD1 [BANKS-1:0], VRD2 [BANKS-1:0], VRD3 [BANKS-1:0];
  logic [BANKS-1:0]     OldVdValid;
  logic [ORDERBITS-1:0] OldVdOrder [BANKS-1:0];
  logic [VLEN-1:0]      V0;
  logic                 VRegWriteW = 0;
  logic [4:0]           VdW = '0;
  logic [VLEN-1:0]      DataW = '0;
  logic [VLEN/8-1:0]    ByteMaskW = '0;
  int                   errors = 0, checks = 0;

  // model: register contents, and the chain: Chain[i] is the request in bank i+1
  logic [VLEN-1:0]      Model [31:0];
  typedef struct { logic [4:0] vs1, vs2, vd; logic oldvd; logic [ORDERBITS-1:0] order; } request_t;
  request_t             Chain [$];
  request_t             Current = '{default: '0};
  logic                 CurrentStall = 1;

  vregfile #(P) dut(.*);

  always #5 clk = ~clk;

  function automatic logic [VLEN-1:0] randvlen();
    for (int w = 0; w < VLEN/32; w++) randvlen[w*32 +: 32] = $urandom;
  endfunction

  // drive one request and one write after the rising edge; the write lands on the falling edge
  // the chain moves at the rising edge unless the cycle before stalled
  task automatic cycle(input request_t req, input logic write, input logic [4:0] vd, input logic [VLEN-1:0] data,
                       input logic [VLEN/8-1:0] bytemask, input logic stall = 1'b0,
                       input logic direct = 1'b0, input logic [4:0] dvs1 = '0, input logic [4:0] dvs2 = '0);
    @(posedge clk); #1;
    if (!CurrentStall) begin
      Chain.push_front(Current);
      if (Chain.size() > BANKS - 1) void'(Chain.pop_back());
    end
    Current = req; CurrentStall = stall;
    {Vs1D, Vs2D, VdD, OldVdD, OrderD} = {req.vs1, req.vs2, req.vd, req.oldvd, req.order};
    VectorStallE = stall;
    DirectAccessD = direct; DirectVs1D = dvs1; DirectVs2D = dvs2;
    VRegWriteW = write; VdW = vd; DataW = data; ByteMaskW = bytemask;
    @(negedge clk); #1;
    if (write) for (int b = 0; b < VLEN/8; b++) if (bytemask[b]) Model[vd][b*8 +: 8] = data[b*8 +: 8];
    check();
  endtask

  // bank 0 serves the request in Decode; bank i the request that has moved i times
  // a direct access replaces vs1 and vs2 in every bank; vd keeps streaming
  task automatic check;
    logic drained;
    drained = 1;
    for (int bank = 0; bank < BANKS; bank++) begin
      request_t req;
      logic     oldvd;
      logic [4:0] vs1, vs2;
      req   = (bank == 0) ? Current : (bank - 1 < Chain.size()) ? Chain[bank-1] : '{default: '0};
      oldvd = req.oldvd;
      if (bank > 0 && oldvd) drained = 0;
      vs1   = DirectAccessD ? DirectVs1D : req.vs1;
      vs2   = DirectAccessD ? DirectVs2D : req.vs2;
      checks++;
      if (VRD1[bank] !== Model[vs1][bank*BLEN +: BLEN] || VRD2[bank] !== Model[vs2][bank*BLEN +: BLEN] ||
          VRD3[bank] !== Model[req.vd][bank*BLEN +: BLEN] || OldVdValid[bank] !== oldvd ||
          (oldvd && OldVdOrder[bank] !== req.order)) begin
        errors++;
        if (errors < 10) $display("ERROR %0t bank %0d: request vs1 v%0d vs2 v%0d vd v%0d oldvd %0b order %0d", $time, bank,
                                  req.vs1, req.vs2, req.vd, req.oldvd, req.order);
      end
    end
    if (V0 !== Model[0]) begin errors++; $display("ERROR %0t: v0 copy", $time); end
    if (BanksDrainedD !== drained) begin errors++; $display("ERROR %0t: BanksDrainedD %0b, expected %0b", $time, BanksDrainedD, drained); end
  endtask

  function automatic request_t randrequest();
    randrequest = '{vs1: 5'($urandom), vs2: 5'($urandom), vd: 5'($urandom), oldvd: 1'($urandom), order: ORDERBITS'($urandom)};
  endfunction

  initial begin
    for (int r = 0; r < 32; r++) Model[r] = '0;
    repeat (2) @(posedge clk);
    #1 reset = 0;

    // fill every register through the commit port
    for (int r = 0; r < 32; r++) cycle('{default: '0}, 1'b1, 5'(r), randvlen(), '1);

    // Table 12: four instructions issued on back-to-back cycles, each reading a different vs2
    $display("Table 12: vs2 register served by each bank");
    for (int c = 0; c < 4 + BANKS - 1; c++) begin
      request_t req;
      string    row;
      req = (c < 4) ? '{vs1: 5'd0, vs2: 5'(c + 1), vd: 5'd0, oldvd: 1'b0, order: '0} : '{default: '0};
      cycle(req, 1'b0, '0, '0, '0);
      row = $sformatf("  cycle %0d:", c);
      for (int bank = 0; bank < BANKS; bank++) begin
        string served;
        served = "-  ";
        for (int r = 1; r <= 4; r++) if (VRD2[bank] === Model[r][bank*BLEN +: BLEN]) served = $sformatf("v%0d ", r);
        row = {row, $sformatf("  bank%0d=%s", bank, served)};
      end
      $display("%s", row);
    end

    // byte mask: write only the odd bytes of v5, then all of v0
    cycle('{default: '0}, 1'b1, 5'd5, randvlen(), {(VLEN/16){2'b10}});
    cycle('{default: '0}, 1'b1, 5'd0, randvlen(), '1);

    // stall: request v6 then hold two cycles; bank 1 keeps v6 until the stall ends
    cycle('{vs1: 5'd0, vs2: 5'd6, vd: 5'd0, oldvd: 1'b0, order: '0}, 1'b0, '0, '0, '0);
    cycle('{default: '0}, 1'b0, '0, '0, '0, 1'b1);
    cycle('{default: '0}, 1'b0, '0, '0, '0, 1'b1);
    if (VRD2[1] !== Model[6][BLEN +: BLEN]) begin errors++; $display("ERROR: bank 1 lost v6 during a stall"); end
    cycle('{default: '0}, 1'b0, '0, '0, '0);

    // drain: a direct micro-op right behind a request waits BANKS-1 cycles in Decode for it to leave the banks
    // then a direct access reads v7 and v8 from every bank while the vd of the direct micro-op itself still streams
    cycle('{vs1: 5'd1, vs2: 5'd2, vd: 5'd3, oldvd: 1'b1, order: '0}, 1'b0, '0, '0, '0);
    begin
      int waited;
      waited = 0;
      cycle('{default: '0}, 1'b0, '0, '0, '0);     // a direct micro-op behind the request reaches Decode
      while (!BanksDrainedD) begin waited++; cycle('{default: '0}, 1'b0, '0, '0, '0); end
      if (waited != BANKS - 1) begin errors++; $display("ERROR: waited %0d cycles, expected %0d", waited, BANKS - 1); end
      else $display("Drain: a direct micro-op behind a request waits %0d cycles", waited);
    end
    cycle('{vs1: 5'd0, vs2: 5'd0, vd: 5'd9, oldvd: 1'b1, order: '0}, 1'b0, '0, '0, '0, 1'b0, 1'b1, 5'd7, 5'd8);
    for (int c = 0; c < BANKS + 2; c++) cycle('{default: '0}, 1'b0, '0, '0, '0, 1'b0, 1'b1, 5'(c), 5'(c + 8));
    cycle('{default: '0}, 1'b0, '0, '0, '0);

    // random stream: a request most cycles, idle and stalled cycles between, commits to registers being streamed
    // a stalled Decode issues no request
    for (int c = 0; c < CYCLES; c++) begin
      request_t req;
      logic     stall;
      stall = ($urandom % 5 == 0);
      req   = ($urandom % 4 != 0 && !stall) ? randrequest() : '{default: '0};
      cycle(req, 1'($urandom % 2), 5'($urandom), randvlen(), ($urandom % 4 == 0) ? (VLEN/8)'(randvlen()) : '1, stall,
            1'($urandom % 6 == 0), 5'($urandom), 5'($urandom));
    end

    // reset clears the chain: no old vd beat after reset
    cycle('{vs1: 5'd1, vs2: 5'd2, vd: 5'd3, oldvd: 1'b1, order: ORDERBITS'(7)}, 1'b0, '0, '0, '0);
    @(posedge clk); #1 reset = 1; OldVdD = 0;
    @(posedge clk); #1;
    if (OldVdValid !== '0) begin errors++; $display("ERROR: old vd valid after reset"); end

    if (errors == 0) $display("vregfile_tb PASSED (%0d bank checks)", checks);
    else             $display("vregfile_tb FAILED with %0d errors", errors);
    $finish;
  end
endmodule
