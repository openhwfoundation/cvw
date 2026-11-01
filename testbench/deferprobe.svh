// deferprobe.svh: monitor for synchronous exceptions deferred by TrapM's ~CommittedF term (issue #845).
// Included from testbench.sv under `ifdef DEFER_PROBE.  Debug aid only.
// Checks, every cycle:
//   I1  CommittedF -> IFUStallF                     (the pipeline is frozen while an exception is deferred)
//   I2  ExceptionM & CommittedF -> StallW            (the faulting instruction cannot leave M)
//   I3  a faulting M-stage instruction never moves to W without a trap  (exception lost)
//   I4  when the deferred exception is finally taken: same PCM, same cause and xtval (unless an interrupt wins)
//   I5  while deferred, the faulting instruction's own access is squashed (LSUFlushW) whenever it requests the LSU
// Counts deferral episodes, cycles, vanished (pulse) faults, and HPTW walks that fault while the trap is held off.
  integer dp_episodes = 0, dp_cycles = 0, dp_taken = 0, dp_intpreempt = 0, dp_vanished = 0, dp_rewalks = 0;
  integer dp_err = 0, dp_maxlen = 0, dp_len = 0;
  logic        dp_pend;            // the current M-stage instruction had a deferred exception
  logic        dp_vanish;          // and its ExceptionM dropped at some point while still deferred
  logic [63:0] dp_pc, dp_tval;
  logic [4:0]  dp_cause;
  logic        dp_ExceptionM, dp_TrapM, dp_InterruptM, dp_CommittedF;
  logic [4:0]  dp_CauseM;

  assign dp_ExceptionM = dut.core.priv.priv.trap.ExceptionM;
  assign dp_TrapM      = dut.core.TrapM;
  assign dp_InterruptM = dut.core.priv.priv.trap.InterruptM;
  assign dp_CauseM     = dut.core.priv.priv.trap.CauseM;
  assign dp_CommittedF = dut.core.ifu.CommittedF;

  always @(posedge clk) begin
    if (reset) begin
      dp_pend <= 1'b0; dp_vanish <= 1'b0;
    end else begin
      if (dp_CommittedF & ~dut.core.ifu.IFUStallF) begin
        $display("DEFERPROBE ERROR I1 [%0t] CommittedF without IFUStallF PCF=%h", $time, dut.core.ifu.PCF);
        dp_err = dp_err + 1;
      end
      if (dp_ExceptionM & dp_CommittedF & ~dut.core.StallW) begin
        $display("DEFERPROBE ERROR I2 [%0t] deferred exception but M not stalled PCM=%h", $time, dut.core.PCM);
        dp_err = dp_err + 1;
      end
      if (4'(dut.core.lsu.hptw.hptw.WalkerState) == 4'd13 & dut.core.lsu.hptw.hptw.DTLBWalk & ~dp_TrapM) dp_rewalks = dp_rewalks + 1;
      if (dp_ExceptionM & ~dp_TrapM) begin
        dp_cycles = dp_cycles + 1;
        if (~dp_pend) begin
          dp_episodes = dp_episodes + 1;
          dp_pc = dut.core.PCM; dp_cause = dp_CauseM; dp_tval = dut.core.priv.priv.csr.NextFaultXtvalM;
          dp_len = 0;
        end
        if (|dut.core.lsu.LSURWM & ~dut.core.lsu.SelHPTW & ~dut.core.lsu.LSUFlushW) begin
          $display("DEFERPROBE ERROR I5 [%0t] deferred faulting access not squashed PCM=%h LSURWM=%b", $time, dut.core.PCM, dut.core.lsu.LSURWM);
          dp_err = dp_err + 1;
        end
      end
      if (dp_pend | (dp_ExceptionM & ~dp_TrapM)) dp_len = dp_len + 1;
      if (dp_pend & ~dp_ExceptionM & ~dp_TrapM) dp_vanish <= 1'b1;
      // Leaving M: trap, or advance to W
      if (dp_pend | (dp_ExceptionM & ~dp_TrapM)) begin
        if (dp_TrapM & ~dut.core.StallW) begin
          if (dp_pend) begin
            if (dp_len > dp_maxlen) dp_maxlen = dp_len;
            if (dp_vanish) dp_vanished = dp_vanished + 1;
            if (dp_InterruptM) dp_intpreempt = dp_intpreempt + 1;
            else begin
              dp_taken = dp_taken + 1;
              $display("DEFERPROBE EPISODE [%0t] PCM=%h cause=%0d tval=%h len=%0d vanished=%b", $time, dp_pc, dp_cause, dp_tval, dp_len, dp_vanish);
              if (dut.core.PCM != dp_pc | dp_CauseM != dp_cause | dut.core.priv.priv.csr.NextFaultXtvalM != dp_tval) begin
                $display("DEFERPROBE ERROR I4 [%0t] deferred PCM=%h cause=%0d tval=%h taken as PCM=%h cause=%0d tval=%h",
                         $time, dp_pc, dp_cause, dp_tval, dut.core.PCM, dp_CauseM, dut.core.priv.priv.csr.NextFaultXtvalM);
                dp_err = dp_err + 1;
              end
            end
          end
          dp_pend <= 1'b0; dp_vanish <= 1'b0;
        end else if (~dut.core.StallW) begin
          if (dp_pend | dp_ExceptionM) begin
            $display("DEFERPROBE ERROR I3 [%0t] deferred exception lost: PCM=%h cause=%0d moved to W without a trap",
                     $time, dp_pc, dp_cause);
            dp_err = dp_err + 1;
          end
          dp_pend <= 1'b0; dp_vanish <= 1'b0;
        end else if (dp_ExceptionM & ~dp_TrapM) dp_pend <= 1'b1;
      end
    end
  end

  final $display("DEFERPROBE SUMMARY episodes=%0d cycles=%0d taken=%0d interrupt_preempted=%0d vanished_then_taken=%0d dtlb_walk_fault_no_trap=%0d max_len=%0d errors=%0d",
                 dp_episodes, dp_cycles, dp_taken, dp_intpreempt, dp_vanished, dp_rewalks, dp_maxlen, dp_err);
