///////////////////////////////////////////
// ahbapbbridge_tb.sv
// Purpose: Check APB strobes during pipelined AHB reads/writes, including APB wait states.
// Copyright (C) 2026 Harvey Mudd College & Oklahoma State University
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

module bridge_strobe_check import cvw::*; #(
  parameter int XLEN = 32,
  parameter int WAIT_CYCLES = 0
)(output bit Done = 0);
  function automatic cvw_t BridgeConfig();
    cvw_t Config;
    Config = '0;
    Config.XLEN = XLEN;
    Config.PA_BITS = 32;
    Config.BPRED_TYPE = BP_GSHARE;
    return Config;
  endfunction
  localparam cvw_t P = BridgeConfig();
  logic HCLK = 0, HRESETn = 0;
  always #5 HCLK = ~HCLK;
  logic HSEL = 0, HWRITE = 0, SelectedD = 0;
  logic [31:0] HADDR = 0;
  logic [1:0] HTRANS = 0;
  logic [XLEN-1:0] HWDATA = 0, HRDATA, PWDATA;
  logic [XLEN/8-1:0] HWSTRB = 0, PSTRB, ExpectedStrobe = 0;
  logic HRESP, HREADYOUT, PCLK, PRESETn, PSEL, PWRITE, PENABLE;
  logic [31:0] PADDR;
  wire HREADY = SelectedD ? HREADYOUT : 1'b1;
  int WaitCount = 0, Issued = 0, Completed = 0, Accesses = 0, Samples = 0;
  wire PREADY = WaitCount >= WAIT_CYCLES;
  wire [0:0][XLEN-1:0] PRDATA;
  assign PRDATA[0] = XLEN'(32'habc00000 + PADDR);
  bit Pending = 0, PendingWrite = 0, AcceptedSel = 0;
  logic [31:0] PendingAddr = 0;

  ahbapbbridge #(P, 1) dut(.*);

  always @(posedge HCLK) begin
    if (!HRESETn || !PSEL || !PENABLE) WaitCount <= 0;
    else if (!PREADY) WaitCount <= WaitCount + 1;
    // Check setup, access and every wait cycle, not just the final handshake. On AHB reads
    // HWSTRB is deliberately nonzero. During a data phase HWRITE describes the next transfer.
    if (HRESETn && PSEL) begin
      Samples++;
      if (PSTRB !== (PWRITE ? ExpectedStrobe : '0))
        $fatal(1, "XLEN=%0d wait=%0d PWRITE=%b PSTRB=%h expected=%h",
               XLEN, WAIT_CYCLES, PWRITE, PSTRB, PWRITE ? ExpectedStrobe : '0);
      if (PADDR !== PendingAddr || PWRITE !== PendingWrite)
        $fatal(1, "APB address/control changed during transfer");
      if (PWRITE && PWDATA !== XLEN'(PendingAddr ^ 32'hbaad1234))
        $fatal(1, "APB write data mismatch");
      if (PENABLE && PREADY) Accesses++;
    end
  end

  task automatic PrepareAddress;
    if (Issued < 100) begin
      HSEL = 1;
      HTRANS = 2'b10;
      HADDR = Issued * (XLEN / 8);
      HWRITE = 1'(Issued);
    end else begin
      HSEL = 0;
      HTRANS = 0;
    end
  endtask

  initial begin
    repeat (5) @(negedge HCLK);
    HRESETn = 1;
    PrepareAddress();
    while (Completed < 100) begin
      @(posedge HCLK);
      if (HREADY) begin
        if (Pending) begin
          if (!PendingWrite && HRDATA !== XLEN'(32'habc00000 + PendingAddr))
            $fatal(1, "AHB read data mismatch");
          if (HRESP) $fatal(1, "Unexpected AHB error");
          Completed++;
        end
        // Leave the current data-phase scoreboard stable until the APB monitor has sampled it.
        AcceptedSel = HSEL;
        #1;
        Pending = HSEL && HTRANS[1];
        PendingWrite = HWRITE;
        PendingAddr = HADDR;
        // Exercise zero, single-lane and full write strobes, while all reads carry nonzero HWSTRB.
        case ((Issued / 2) % 3)
          0: ExpectedStrobe = '0;
          1: ExpectedStrobe = (XLEN/8)'(1) << ((Issued / 6) % (XLEN / 8));
          2: ExpectedStrobe = '1;
        endcase
        if (Pending) Issued++;
        SelectedD = AcceptedSel;
        HWDATA = XLEN'(PendingAddr ^ 32'hbaad1234);
        HWSTRB = PendingWrite ? ExpectedStrobe : '1;
        PrepareAddress();
      end
    end
    #1;
    if (Accesses != Completed) $fatal(1, "APB transfer count mismatch");
    $display("PASS bridge XLEN=%0d wait=%0d transfers=%0d strobe samples=%0d",
             XLEN, WAIT_CYCLES, Completed, Samples);
    Done = 1;
  end
endmodule

module ahbapbbridge_tb;
  wire [3:0] Done;
  bridge_strobe_check #(32, 0) rv32(Done[0]);
  bridge_strobe_check #(32, 3) rv32_wait(Done[1]);
  bridge_strobe_check #(64, 0) rv64(Done[2]);
  bridge_strobe_check #(64, 3) rv64_wait(Done[3]);
  initial begin
    wait (&Done);
    $finish;
  end
  initial begin
    #100000;
    $fatal(1, "Bridge test timed out");
  end
endmodule
