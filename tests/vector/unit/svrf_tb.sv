// svrf_tb.sv
// Self-checking unit test of the speculative vector register file.
// Run: tests/vector/unit/run svrf
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module svrf_tb;
  localparam VLEN = 256, BLEN = 128, EU = 3, ENTRYBITS = 3, BEATBITS = 3, BANKS = VLEN/BLEN;

  logic                 clk = 0, reset = 1;
  logic [EU-1:0]        BeatValidW = '0, LastBeatW = '0, VRegWriteW = '0;
  logic [ENTRYBITS-1:0] OrderW [EU-1:0];
  logic [BEATBITS-1:0]  BeatW [EU-1:0];
  logic [BLEN-1:0]      ResultBeatW [EU-1:0];
  logic [BLEN/8-1:0]    ByteMaskW [EU-1:0];
  logic [4:0]           VdW [EU-1:0];
  logic [BANKS-1:0]     OldVdValidW = '0;
  logic [ENTRYBITS-1:0] OldVdOrderW [BANKS-1:0];
  logic [BLEN-1:0]      OldVdDataW [BANKS-1:0];
  logic [ENTRYBITS-1:0] HeadOrderW = '0;
  logic                 CommitW = 0;
  logic                 HeadCompleteW, HeadVRegWriteW;
  logic [4:0]           HeadVdW;
  logic [VLEN-1:0]      HeadDataW;
  int                   errors = 0;

  svrf #(VLEN, BLEN, EU, ENTRYBITS, BEATBITS) dut(.*);

  always #5 clk = ~clk;

  // Inputs change after the falling edge so each holds for exactly one rising edge
  task automatic idle;
    BeatValidW = '0; LastBeatW = '0; VRegWriteW = '0; OldVdValidW = '0; CommitW = 0;
    for (int eu = 0; eu < EU; eu++) begin
      OrderW[eu] = '0; BeatW[eu] = '0; ResultBeatW[eu] = '0; ByteMaskW[eu] = '0; VdW[eu] = '0;
    end
    for (int bank = 0; bank < BANKS; bank++) begin
      OldVdOrderW[bank] = '0; OldVdDataW[bank] = '0;
    end
  endtask

  task automatic step;
    @(negedge clk);
    idle();
  endtask

  task automatic beat(input int eu, input logic [ENTRYBITS-1:0] entry, input int number, input logic [BLEN-1:0] data,
                      input logic last, input logic [BLEN/8-1:0] bytemask = '1, input logic [4:0] vd = 5'd9,
                      input logic vregwrite = 1'b1);
    BeatValidW[eu] = 1'b1; LastBeatW[eu] = last; VRegWriteW[eu] = vregwrite;
    OrderW[eu] = entry; BeatW[eu] = BEATBITS'(number); ResultBeatW[eu] = data; ByteMaskW[eu] = bytemask; VdW[eu] = vd;
  endtask

  task automatic oldvd(input int bank, input logic [ENTRYBITS-1:0] entry, input logic [BLEN-1:0] data);
    OldVdValidW[bank] = 1'b1; OldVdOrderW[bank] = entry; OldVdDataW[bank] = data;
  endtask

  task automatic check(input string name, input logic [ENTRYBITS-1:0] entry, input logic complete,
                       input logic [VLEN-1:0] data = '0, input logic [4:0] vd = 5'd9, input logic vregwrite = 1'b1);
    HeadOrderW = entry;
    #1;
    if (HeadCompleteW !== complete) begin
      $display("FAIL %s: entry %0d complete = %b, expected %b", name, entry, HeadCompleteW, complete);
      errors++;
    end
    if (complete && (HeadDataW !== data || HeadVdW !== vd || HeadVRegWriteW !== vregwrite)) begin
      $display("FAIL %s: entry %0d data %h vd %0d write %b, expected %h %0d %b", name, entry, HeadDataW, HeadVdW,
               HeadVRegWriteW, data, vd, vregwrite);
      errors++;
    end
  endtask

  task automatic commit(input logic [ENTRYBITS-1:0] entry);
    HeadOrderW = entry; CommitW = 1'b1;
    step();
  endtask

  localparam logic [BLEN-1:0] A = {4{32'hAAAA_0001}}, B = {4{32'hBBBB_0002}}, C = {4{32'hCCCC_0003}}, D = {4{32'hDDDD_0004}};
  localparam logic [BLEN-1:0] OLD0 = {16{8'h11}}, OLD1 = {16{8'h22}};

  initial begin
    idle();
    repeat (2) @(negedge clk);
    reset = 0;

    // Two entries finish out of order: entry 1 waits, complete, while entry 0 is still filling
    beat(0, 3'd0, 0, A, 1'b0);
    step();
    beat(1, 3'd1, 0, C, 1'b0, '1, 5'd3); step();
    beat(1, 3'd1, 1, D, 1'b1, '1, 5'd3); step();
    check("incomplete head", 3'd0, 1'b0);
    check("younger done first", 3'd1, 1'b1, {D, C}, 5'd3);
    beat(0, 3'd0, 1, B, 1'b1); step();
    check("head completes", 3'd0, 1'b1, {B, A});

    // Commit clears only the committed entry
    commit(3'd0);
    check("commit clears", 3'd0, 1'b0);
    check("other entry stays", 3'd1, 1'b1, {D, C}, 5'd3);
    commit(3'd1);
    check("second commit clears", 3'd1, 1'b0);

    // Three EUs write three entries in the same cycle, and the beats land in opposite orders
    beat(0, 3'd2, 1, A, 1'b1, '1, 5'd1);
    beat(1, 3'd3, 0, B, 1'b0, '1, 5'd2);
    beat(2, 3'd4, 0, C, 1'b1, '1, 5'd4);
    step();
    beat(0, 3'd2, 0, B, 1'b0, '1, 5'd1);
    beat(1, 3'd3, 1, D, 1'b1, '1, 5'd2);
    step();
    check("EU0 beats reversed", 3'd2, 1'b1, {A, B}, 5'd1);
    check("EU1 beats", 3'd3, 1'b1, {D, B}, 5'd2);
    // EU2's last beat sets complete with slice 1 untouched: reset value
    check("EU2 one beat", 3'd4, 1'b1, {{BLEN{1'b0}}, C}, 5'd4);
    commit(3'd2); commit(3'd3); commit(3'd4);

    // Old vd first, then a result beat with bytes disabled keeps the old bytes
    oldvd(0, 3'd5, OLD0); step();
    oldvd(1, 3'd5, OLD1); beat(0, 3'd5, 0, A, 1'b0, 16'h00FF); step();
    beat(0, 3'd5, 1, B, 1'b1, 16'hFF00); step();
    check("byte-enabled merge", 3'd5, 1'b1, {B[127:64], OLD1[63:0], OLD0[127:64], A[63:0]});
    commit(3'd5);

    // The two banks init different entries in one cycle
    oldvd(0, 3'd6, OLD0); oldvd(1, 3'd7, OLD1); step();
    beat(0, 3'd6, 1, A, 1'b1, '0); step();
    beat(1, 3'd7, 0, B, 1'b1, '0); step();
    check("bank 0 init only", 3'd6, 1'b1, {{BLEN{1'b0}}, OLD0});
    check("bank 1 init only", 3'd7, 1'b1, {OLD1, {BLEN{1'b0}}});
    commit(3'd6); commit(3'd7);

    // A micro-op with no vector destination still completes, with its write off
    beat(2, 3'd0, 0, A, 1'b1, '0, 5'd7, 1'b0); step();
    check("no vector write", 3'd0, 1'b1, {B, A}, 5'd7, 1'b0);
    commit(3'd0);

    // Reused entry: new beats overwrite, and complete stays low until the new last beat
    beat(0, 3'd1, 0, B, 1'b0, '1, 5'd8); step();
    check("reuse not complete", 3'd1, 1'b0);
    beat(0, 3'd1, 1, A, 1'b1, '1, 5'd8); step();
    check("reuse complete", 3'd1, 1'b1, {A, B}, 5'd8);

    if (errors == 0) $display("svrf_tb PASSED");
    else             $display("svrf_tb FAILED: %0d errors", errors);
    $finish;
  end

endmodule
