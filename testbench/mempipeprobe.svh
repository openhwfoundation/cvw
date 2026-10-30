// mempipeprobe.svh — cycle trace of the HPTW / LSU / D$ / bus / IFU arbitration.
// State legends: HPTW 0..9=L0_ADR,L0_RD,L1_ADR,L1_RD,L2_ADR,L2_RD,L3_ADR,L3_RD,L4_ADR,L4_RD 10=LEAF 11=IDLE 12=UPDATE_PTE 13=FAULT;
//   D$/I$ 0=ACCESS 1=FETCH 2=WRITEBACK 3=WRITE_LINE 4=ADDRESS_SETUP 5=FLUSH 6=FLUSH_WRITEBACK; busfsm 0=ADR 1=DATA 2=ATOMIC_READ 3=ATOMIC 4=MEM3 5=CACHE_FETCH 6=CACHE_WRITEBACK
// Debug aid only (issue #1538 / #1766). Included from testbench.sv under `ifdef MEMPIPE_PROBE.
// Plusargs: +PROBE_T0=<time> +PROBE_T1=<time> window (default whole run);
//           +PROBE_ALL=1 print every cycle in the window (default: only "interesting" cycles);
//           +PROBE_PA_LO=<hex> +PROBE_PA_HI=<hex> also print any D$/bus access whose PAdrM is in range.
  integer probe_t0, probe_t1, probe_all;
  logic [63:0] probe_pa_lo, probe_pa_hi;
  logic probe_interesting, probe_pahit;
  initial begin
    if (!$value$plusargs("PROBE_T0=%d", probe_t0)) probe_t0 = 0;
    if (!$value$plusargs("PROBE_T1=%d", probe_t1)) probe_t1 = 64'h7fffffffffffffff;
    if (!$value$plusargs("PROBE_ALL=%d", probe_all)) probe_all = 0;
    if (!$value$plusargs("PROBE_PA_LO=%h", probe_pa_lo)) probe_pa_lo = 64'hffffffffffffffff;
    if (!$value$plusargs("PROBE_PA_HI=%h", probe_pa_hi)) probe_pa_hi = 0;
  end
  assign probe_pahit = (|dut.core.lsu.bus.dcache.CacheRWM | |dut.core.lsu.bus.dcache.BusRW) &
                       (dut.core.lsu.PAdrM >= probe_pa_lo) & (dut.core.lsu.PAdrM <= probe_pa_hi);
  assign probe_interesting = (dut.core.lsu.hptw.hptw.WalkerState != 4'd11) |
                             dut.core.lsu.hptw.hptw.TLBMissOrUpdateDA | dut.core.lsu.HPTWFlushW | dut.core.lsu.LSUFlushW |
                             (dut.core.lsu.bus.dcache.dcache.cachefsm.CurrState != 4'd0) |
                             dut.core.ifu.ITLBMissF | dut.core.TrapM | probe_pahit;
  always @(posedge clk) begin
    if (~reset & ($time >= probe_t0) & ($time <= probe_t1) & (probe_all | probe_interesting)) begin
      $display("[%0t] S=%b%b%b%b%b F=%b%b%b%b %s | PCF=%h ITLBm=%b IFUst=%b I$=%0d | PCM=%h vM=%b MemRW=%b Adr=%h PA=%h | HPTW=%0d DTLBw=%b Dm=%b Im=%b St=%b Fl=%b Sel=%b SelAdr=%b PTE=%h DW=%b IW=%b | D$=%0d RW=%b Bus=%b Hit=%b En=%b Stall=%b SD=%b SV=%b SelT=%b SelD=%b SetT=%h SetD=%h D$st=%b BusSt=%b LSUFl=%b | busfsm=%0d HTRANS=%b HADDR=%h HRDY=%b | RdM=%h",
        $time,
        dut.core.StallF, dut.core.StallD, dut.core.StallE, dut.core.StallM, dut.core.StallW,
        dut.core.FlushD, dut.core.FlushE, dut.core.FlushM, dut.core.FlushW,
        dut.core.TrapM ? "TRAP" : "    ",
        dut.core.ifu.PCF, dut.core.ifu.ITLBMissF, dut.core.ifu.IFUStallF, dut.core.ifu.bus.icache.icache.cachefsm.CurrState,
        dut.core.PCM, dut.core.InstrValidM, dut.core.lsu.MemRWM, dut.core.lsu.IEUAdrM, dut.core.lsu.PAdrM,
        dut.core.lsu.hptw.hptw.WalkerState, dut.core.lsu.hptw.hptw.DTLBWalk,
        dut.core.lsu.DTLBMissOrUpdateDAM, dut.core.lsu.ITLBMissOrUpdateAF,
        dut.core.lsu.HPTWStall, dut.core.lsu.HPTWFlushW, dut.core.lsu.SelHPTW, dut.core.lsu.hptw.hptw.SelHPTWAdr,
        dut.core.lsu.hptw.hptw.PTE, dut.core.lsu.DTLBWriteM, dut.core.lsu.ITLBWriteF,
        dut.core.lsu.bus.dcache.dcache.cachefsm.CurrState, dut.core.lsu.bus.dcache.CacheRWM, dut.core.lsu.bus.dcache.BusRW,
        dut.core.lsu.bus.dcache.dcache.Hit, dut.core.lsu.bus.dcache.dcache.CacheEn, dut.core.lsu.bus.dcache.dcache.Stall,
        dut.core.lsu.bus.dcache.dcache.SetDirty, dut.core.lsu.bus.dcache.dcache.SetValid,
        dut.core.lsu.bus.dcache.dcache.SelAdrTag, dut.core.lsu.bus.dcache.dcache.SelAdrData,
        dut.core.lsu.bus.dcache.dcache.CacheSetTag, dut.core.lsu.bus.dcache.dcache.CacheSetData,
        dut.core.lsu.DCacheStallM, dut.core.lsu.LSUBusStallM, dut.core.lsu.LSUFlushW,
        dut.core.lsu.bus.dcache.ahbcacheinterface.AHBBuscachefsm.CurrState, dut.core.lsu.LSUHTRANS, dut.core.lsu.LSUHADDR, dut.core.lsu.LSUHREADY,
        dut.core.lsu.ReadDataM);
    end
  end
