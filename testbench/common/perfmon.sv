///////////////////////////////////////////
// perfmon.sv
//
// Written: David_Harris@hmc.edu
// Created: 10 October 2026
//
// Purpose: Cycle accounting for performance verification. Every cycle between reset and
//          test completion either retires an instruction or is charged to exactly one
//          cause, so lost cycles that no cause explains, or that cost more than the
//          microarchitecture should, stand out. Enabled with the PERF_MONITOR testbench
//          parameter; writes one CSV row per ELF to +PERF_FILE (default <prefix>perf.csv)
//          and a per-PC breakdown of lost cycles to the same name with .csv -> pc.csv.
//
// A cycle retires when InstrValidM & ~StallW & ~FlushW (the minstret event). A lost cycle is
//   1. a W-stage stall, charged to the LSU (page walk, D$, uncached bus, misaligned spill)
//      or the IFU (ITLB walk, I$, uncached bus, fetch spill),
//   2. a W-stage flush, charged to a trap or to wfi, or
//   3. a bubble reaching M, charged to the cause recorded when the bubble was created.
//      A shadow tag pipeline follows each bubble from the stage where a flush created it.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

/* verilator lint_off WIDTHTRUNC */
/* verilator lint_off WIDTHEXPAND */
module perfmon import cvw::*; #(parameter cvw_t P) (
  input logic  clk,
  input logic  reset,
  input logic  CopyRAM,           // test reached tohost: close the window and write the results
  input string elffilename,
  input string sim_log_prefix
);

  // Cause codes for lost cycles
  typedef enum int {
    C_NONE, C_STARTUP,
    // bubbles, charged where a flush created them
    C_TRAP, C_RET, C_CSRW, C_FENCE, C_BPWRONG,
    C_LOADUSE, C_STORELOAD, C_CSRRD, C_MDU, C_FCVTINT, C_FPU, C_DSTALL_OTHER, C_DIV,
    // W-stage stalls
    C_LSU_HPTW, C_LSU_DCACHE, C_LSU_BUS, C_LSU_SPILL, C_LSU_OTHER,
    C_IFU_ITLB, C_IFU_ICACHE, C_IFU_BUS, C_IFU_SPILL, C_IFU_OTHER, C_EXTSTALL,
    // W-stage flushes
    C_W_TRAP, C_W_WFI,
    C_UNKNOWN, C_NUM
  } cause_t;

  string causeName[C_NUM] = '{"none", "startup",
    "trap", "ret", "csrw", "fence", "bpwrong",
    "loaduse", "storeload", "csrrd", "mdu", "fcvtint", "fpu", "dstall_other", "div",
    "lsu_hptw", "lsu_dcache", "lsu_bus", "lsu_spill", "lsu_other",
    "ifu_itlb", "ifu_icache", "ifu_bus", "ifu_spill", "ifu_other", "extstall",
    "w_trap", "w_wfi",
    "unknown"};

  // Stall episodes: contiguous runs of a raw stall signal, whether or not they cost a cycle
  typedef enum int {E_DCACHE, E_ICACHE, E_HPTW, E_DIV, E_LSUBUS, E_IFUBUS, E_SPILLM, E_SPILLF, E_NUM} episode_t;
  string episodeName[E_NUM] = '{"dcache", "icache", "hptw", "div", "lsubus", "ifubus", "spillm", "spillf"};
  string cacheCols[11] = '{"fill", "fill_dirty", "flush_eps", "cmo_eps", "cancel_eps", "other_eps", "other_max", "other_pc",
                           "fills_done", "fills_unreported", "refill"};

  localparam NEVENTS = 25;        // HPM events 0-24 defined in csrc.sv

  // Pipeline and hazard signals
  logic StallD, StallE, StallM, StallW, FlushD, FlushE, FlushM, FlushW;
  logic TrapM, RetM, CSRWriteFenceM, BPWrongE, DivBusyE, FDivBusyE, IFUStallF, LSUStallM;
  logic InstrValidM, Retire;
  logic [P.XLEN-1:0] PCF, PCD, PCE, PCM;
  assign StallD = dut.core.hzu.StallD;   assign FlushD = dut.core.hzu.FlushD;
  assign StallE = dut.core.hzu.StallE;   assign FlushE = dut.core.hzu.FlushE;
  assign StallM = dut.core.hzu.StallM;   assign FlushM = dut.core.hzu.FlushM;
  assign StallW = dut.core.hzu.StallW;   assign FlushW = dut.core.hzu.FlushW;
  assign TrapM = dut.core.hzu.TrapM;     assign RetM = dut.core.hzu.RetM;
  assign CSRWriteFenceM = dut.core.hzu.CSRWriteFenceM;
  assign BPWrongE = dut.core.hzu.BPWrongE;
  assign DivBusyE = dut.core.hzu.DivBusyE; assign FDivBusyE = dut.core.hzu.FDivBusyE;
  assign IFUStallF = dut.core.hzu.IFUStallF; assign LSUStallM = dut.core.hzu.LSUStallM;
  assign InstrValidM = dut.core.InstrValidM;
  assign Retire = InstrValidM & ~StallW & ~FlushW;
  assign PCF = dut.core.ifu.PCF; assign PCD = dut.core.ifu.PCD;
  assign PCE = dut.core.ifu.PCE; assign PCM = dut.core.ifu.PCM;

  // Stall sub-causes
  logic HPTWStall, DCacheStallM, LSUBusStallM, SpillStallM, ITLBMissOrUpdateAF, ICacheStallF, IFUBusStall, SelSpillNextF;
  assign HPTWStall = dut.core.lsu.HPTWStall;
  assign DCacheStallM = dut.core.lsu.DCacheStallM;
  assign LSUBusStallM = dut.core.lsu.LSUBusStallM;
  assign SpillStallM = dut.core.lsu.SpillStallM;
  assign ITLBMissOrUpdateAF = dut.core.ifu.ITLBMissOrUpdateAF;
  assign ICacheStallF = dut.core.ifu.ICacheStallF;
  assign IFUBusStall = dut.core.ifu.BusStall;
  assign SelSpillNextF = dut.core.ifu.SelSpillNextF;

  // Decode-stage stall sub-causes and the operands needed to check them
  logic LoadStallD, StoreStallD, CSRRdStallD, MDUStallD, FCvtIntStallD, FPUStallD, FenceM, RegWriteE;
  logic [31:0] InstrD;
  logic [4:0] RdE;
  assign LoadStallD = dut.core.ieu.c.LoadStallD;
  assign StoreStallD = dut.core.ieu.c.StoreStallD;
  assign CSRRdStallD = dut.core.ieu.c.CSRRdStallD;
  assign MDUStallD = dut.core.ieu.c.MDUStallD;
  assign FCvtIntStallD = dut.core.ieu.c.FCvtIntStallD;
  assign FPUStallD = dut.core.hzu.FPUStallD;
  assign FenceM = dut.core.ieu.c.FenceM;
  assign RegWriteE = dut.core.ieu.c.RegWriteE;
  assign InstrD = dut.core.ifu.InstrD;
  assign RdE = dut.core.ieu.c.RdE;

  // Cache misses, invalidations, and the physical line addresses they apply to
  logic ICacheMiss, DCacheMiss, InvalidateICacheM, FlushDCacheM;
  logic [3:0] CMOpM;
  logic [P.PA_BITS-1:0] PCPF, PAdrM;
  assign ICacheMiss = dut.core.ICacheMiss;
  assign DCacheMiss = dut.core.DCacheMiss;
  assign InvalidateICacheM = dut.core.InvalidateICacheM;
  assign FlushDCacheM = dut.core.FlushDCacheM;
  assign CMOpM = dut.core.lsu.CMOpM;
  assign PCPF = dut.core.ifu.PCPF;
  assign PAdrM = dut.core.lsu.PAdrM;
  // Cache FSM states (cachefsm.sv statetype): 0 ACCESS, 1 FETCH, 2 WRITEBACK, 3 WRITE_LINE, 4 ADDRESS_SETUP, 5 FLUSH, 6 FLUSH_WRITEBACK
  logic [3:0] CacheState[2];      // [0] I$, [1] D$
  if (P.ICACHE_SUPPORTED) begin : istate assign CacheState[0] = dut.core.ifu.bus.icache.icache.cachefsm.CurrState; end
  else begin : noistate assign CacheState[0] = '0; end
  if (P.DCACHE_SUPPORTED) begin : dstate assign CacheState[1] = dut.core.lsu.bus.dcache.dcache.cachefsm.CurrState; end
  else begin : nodstate assign CacheState[1] = '0; end
  localparam ILINEBITS = $clog2(P.ICACHE_LINELENINBITS/8);
  localparam DLINEBITS = $clog2(P.DCACHE_LINELENINBITS/8);
  // Re-fills (a line filled again with no invalidation in between) are counted for information only:
  // the caches use tree pseudo-LRU, which may evict a line after a single fill into its set, and
  // bin/CacheSim.py already checks every hit and miss against an exact cache model.

  // Integer source registers an instruction really reads, from its expanded encoding
  function automatic logic [1:0] intSources(logic [31:0] instr);  // {uses rs2, uses rs1}
    logic [6:0] op;
    logic [2:0] f3;
    logic [4:0] f5;
    op = instr[6:0]; f3 = instr[14:12]; f5 = instr[31:27];
    case (op)
      7'b0110111, 7'b0010111, 7'b1101111: return 2'b00;          // lui, auipc, jal
      7'b1100111, 7'b0000011, 7'b0010011, 7'b0011011: return 2'b01; // jalr, loads, op-imm(-32)
      7'b0000111, 7'b0100111: return 2'b01;                       // FP load/store: only the base is integer
      7'b1100011, 7'b0100011, 7'b0110011, 7'b0111011, 7'b0101111: return 2'b11; // branch, store, op(-32), AMO
      7'b1010011: return (f5 == 5'b11010 | f5 == 5'b11110) ? 2'b01 : 2'b00; // fcvt.f.x, fmv.f.x read rs1
      7'b1000011, 7'b1000111, 7'b1001011, 7'b1001111: return 2'b00; // FMA
      7'b1110011: return (f3 == 3'b000) ? 2'b11 : (f3[2] ? 2'b00 : 2'b01); // sfence/hfence, csrr[wsc], csrr[wsc]i
      7'b0001111: return (f3 == 3'b010) ? 2'b01 : 2'b00;          // cbo reads rs1; fence, fence.i do not
      default:    return 2'b11;                                   // unknown: assume both
    endcase
  endfunction

  logic [1:0] SrcD;
  logic TrueDepD;
  assign SrcD = intSources(InstrD);
  assign TrueDepD = RegWriteE & (RdE != 5'b0) &
                    ((SrcD[0] & InstrD[19:15] == RdE) | (SrcD[1] & InstrD[24:20] == RdE));

  // Cause of the bubble a flush creates in each stage
  function automatic cause_t flushCause(logic includeBP);
    if (TrapM)          return C_TRAP;
    if (RetM)           return C_RET;
    if (CSRWriteFenceM) return FenceM ? C_FENCE : C_CSRW;
    if (includeBP & BPWrongE) return C_BPWRONG;
    return C_NONE;
  endfunction

  function automatic cause_t dStallCause();
    if (LoadStallD)    return C_LOADUSE;
    if (StoreStallD)   return C_STORELOAD;
    if (CSRRdStallD)   return C_CSRRD;
    if (MDUStallD)     return C_MDU;
    if (FCvtIntStallD) return C_FCVTINT;
    if (FPUStallD)     return C_FPU;
    return C_DSTALL_OTHER;
  endfunction

  cause_t causeFlushD, causeFlushE, causeFlushM;
  logic [P.XLEN-1:0] pcFlushD, pcFlushE, pcFlushM;
  always_comb begin
    causeFlushD = flushCause(1'b1);
    pcFlushD = (causeFlushD == C_BPWRONG) ? PCE : PCM;
    causeFlushE = flushCause(~(DivBusyE | FDivBusyE));
    pcFlushE = (causeFlushE == C_BPWRONG) ? PCE : PCM;
    if (causeFlushE == C_NONE) begin causeFlushE = dStallCause(); pcFlushE = PCD; end // D stalled, E did not
    causeFlushM = flushCause(1'b0);
    pcFlushM = PCM;
    if (causeFlushM == C_NONE) begin causeFlushM = C_DIV; pcFlushM = PCE; end        // E stalled, M did not
  end

  // Shadow tags: why each stage holds a bubble, following the D/E/M pipeline registers
  cause_t tagD, tagE, tagM;
  logic [P.XLEN-1:0] tagPCD, tagPCE, tagPCM;
  always_ff @(posedge clk)
    if (reset) begin
      {tagD, tagE, tagM} <= {C_STARTUP, C_STARTUP, C_STARTUP};
      {tagPCD, tagPCE, tagPCM} <= '0;
    end else begin
      if (~StallM) begin tagM <= FlushM ? causeFlushM : tagE; tagPCM <= FlushM ? pcFlushM : tagPCE; end
      if (~StallE) begin tagE <= FlushE ? causeFlushE : tagD; tagPCE <= FlushE ? pcFlushE : tagPCD; end
      if (~StallD) begin tagD <= FlushD ? causeFlushD : C_NONE; tagPCD <= FlushD ? pcFlushD : '0; end
    end

  // Charge this cycle
  cause_t cause;
  logic [P.XLEN-1:0] causePC;
  always_comb begin
    cause = C_NONE; causePC = PCM;
    if (Retire) cause = C_NONE;
    else if (StallW) begin
      if (LSUStallM & ~TrapM) begin
        causePC = PCM;
        if (HPTWStall)         cause = C_LSU_HPTW;
        else if (DCacheStallM) cause = C_LSU_DCACHE;
        else if (LSUBusStallM) cause = C_LSU_BUS;
        else if (SpillStallM)  cause = C_LSU_SPILL;
        else                   cause = C_LSU_OTHER;
      end else if (IFUStallF) begin
        causePC = PCF;
        if (ITLBMissOrUpdateAF) cause = C_IFU_ITLB;
        else if (ICacheStallF)  cause = C_IFU_ICACHE;
        else if (IFUBusStall)   cause = C_IFU_BUS;
        else if (SelSpillNextF) cause = C_IFU_SPILL;
        else                    cause = C_IFU_OTHER;
      end else cause = C_EXTSTALL;
    end else if (FlushW) cause = TrapM ? C_W_TRAP : (StallM ? C_W_WFI : C_UNKNOWN);
    else if (~InstrValidM) begin
      cause = (tagM == C_NONE) ? C_UNKNOWN : tagM;
      causePC = tagPCM;
    end else cause = C_UNKNOWN;
  end

  // Per-ELF accumulation
  logic        Running;
  longint      Cycles, Instret;
  longint      CauseCycles[C_NUM];
  longint      FalseDep[C_NUM];        // structural-stall bubbles with no true integer dependency
  longint      FalseDepNoIntWrite;     // ... of which the E-stage instruction writes no integer register (e.g. an FP load)
  longint      BPFlushes;              // mispredictions, counted as the flushes they cause in D
  // Cache stall episodes classified by the FSM states they pass through: [cache][kind]
  // kind 0 clean fill, 1 dirty fill (writeback then fetch), 2 flush, 3 CMO writeback, 4 other
  longint      CacheEp[2][6];
  longint      OtherMax[2];
  logic [63:0] OtherPC[2];
  logic [4:0]  Visited[2];            // {CMO, pipeline flush of the cache's stage, cache flush, writeback, fetch} seen during the episode
  longint      Fills[2], FillsUnreported[2];   // completed fills; fills that ended without a CacheMiss pulse
  logic        SawMiss[2];
  logic [3:0]  PrevState[2];
  logic        PrevFromFill[2];      // the current ADDRESS_SETUP follows a WRITE_LINE (a fill), not a CMO or flush
  always_ff @(posedge clk)
    for (int c = 0; c < 2; c++) begin
      PrevState[c] <= CacheState[c];
      if (CacheState[c] == 4'd3) PrevFromFill[c] <= 1;
      else if (CacheState[c] == 4'd0) PrevFromFill[c] <= 0;
    end
  longint      ReMiss[2];                            // I$/D$ re-fills of a line not invalidated since its last fill
  logic        LineFill[2][longint];                 // lines filled since the last invalidation
  longint      EventCount[NEVENTS];
  longint      EpCount[E_NUM], EpSum[E_NUM], EpMax[E_NUM];
  logic [63:0] EpMaxPC[E_NUM];
  int          EpLen[E_NUM];
  logic [63:0] EpStartPC[E_NUM];
  logic [E_NUM-1:0] EpSig;
  longint      PCHist[bit [69:0]];     // {pc, cause} -> cycles
  int          AnomPrinted[3];       // PERFANOM lines printed per rule: cache stall without fill, unknown, false dependency
  string       perffile, pcfile;
  logic        Trace;                  // +PERF_TRACE: print each cache fill and invalidation, for triage
  logic [31:0] HPMEvents;

  // in episode_t order, E_DCACHE in bit 0
  assign EpSig = {SelSpillNextF, SpillStallM, IFUBusStall, LSUBusStallM, DivBusyE | FDivBusyE, HPTWStall, ICacheStallF, DCacheStallM};
  assign HPMEvents = dut.core.priv.priv.csr.counters.CounterEvent;

  initial begin
    if (!$value$plusargs("PERF_FILE=%s", perffile)) perffile = {sim_log_prefix, "perf.csv"};
    pcfile = {perffile.substr(0, perffile.len()-5), "pc.csv"};
    Trace = $test$plusargs("PERF_TRACE");
  end

  function automatic void clearStats();
    Cycles = 0; Instret = 0; AnomPrinted = '{0, 0, 0}; FalseDepNoIntWrite = 0;
    for (int i = 0; i < C_NUM; i++) begin CauseCycles[i] = 0; FalseDep[i] = 0; end
    BPFlushes = 0;
    for (int i = 0; i < 2; i++) begin
      ReMiss[i] = 0; LineFill[i].delete();
      for (int k = 0; k < 6; k++) CacheEp[i][k] = 0;
      OtherMax[i] = 0; OtherPC[i] = 0; Visited[i] = 0; Fills[i] = 0; FillsUnreported[i] = 0; SawMiss[i] = 0;
    end
    for (int i = 0; i < NEVENTS; i++) EventCount[i] = 0;
    for (int i = 0; i < E_NUM; i++) begin EpCount[i] = 0; EpSum[i] = 0; EpMax[i] = 0; EpMaxPC[i] = 0; EpLen[i] = 0; EpStartPC[i] = 0; end
    PCHist.delete();
  endfunction

  function automatic void endEpisode(int e);
    EpCount[e]++; EpSum[e] += longint'(EpLen[e]);
    if (longint'(EpLen[e]) > EpMax[e]) begin EpMax[e] = longint'(EpLen[e]); EpMaxPC[e] = EpStartPC[e]; end
    if (e == E_DCACHE || e == E_ICACHE) begin
      int c, kind;
      c = (e == E_DCACHE);
      if (Visited[c][2])      kind = 2;                       // flush
      else if (Visited[c][0]) kind = Visited[c][1] ? 1 : 0;   // fill, dirty or clean
      else if (Visited[c][1] | Visited[c][4]) kind = 3;       // CMO, with or without a writeback (one stall cycle re-reads the SRAM)
      // a miss cancelled by a flush of the cache's stage (a trap, or a mispredict for the I$), or a D$ miss pre-empted
      // by a page table walk, never leaves ACCESS
      else if (Visited[c][3]) kind = 4;
      else                    kind = 5;                       // stalled without fetching, writing back or flushing
      CacheEp[c][kind]++;
      if (kind == 5) begin
        if (longint'(EpLen[e]) > OtherMax[c]) begin OtherMax[c] = longint'(EpLen[e]); OtherPC[c] = EpStartPC[e]; end
        if (AnomPrinted[0] < 20) begin
          $display("PERFANOM %s %s_stall_without_fill pc=%h len=%0d t=%0t", elffilename, episodeName[e], EpStartPC[e], EpLen[e], $time);
          AnomPrinted[0]++;
        end
      end
      Visited[c] = 0;
    end
    EpLen[e] = 0;
  endfunction

  function automatic void noteMiss(int c, longint line);
    if (LineFill[c].exists(line)) ReMiss[c]++;
    LineFill[c][line] = 1;
  endfunction

  bit FilesOpened = 0;   // the output files are started fresh by the first ELF of the simulation

  function automatic void writeResults();
    integer fd, fp;
    fd = $fopen(perffile, FilesOpened ? "a" : "w");
    if (!FilesOpened) begin
      $fwrite(fd, "elf,cycles,instret,lost");
      for (int i = C_STARTUP; i < C_NUM; i++) $fwrite(fd, ",%s", causeName[i]);
      for (int i = C_LOADUSE; i <= C_FCVTINT; i++) $fwrite(fd, ",falsedep_%s", causeName[i]);
      $fwrite(fd, ",falsedep_nointwrite");
      $fwrite(fd, ",bp_flushes");
      for (int c = 0; c < 2; c++) begin
        string k;
        k = c ? "dcache" : "icache";
        foreach (cacheCols[j]) $fwrite(fd, ",%s_%s", k, cacheCols[j]);
      end
      for (int e = 0; e < E_NUM; e++) $fwrite(fd, ",ep_%s_n,ep_%s_sum,ep_%s_max,ep_%s_maxpc", episodeName[e], episodeName[e], episodeName[e], episodeName[e]);
      for (int i = 0; i < NEVENTS; i++) $fwrite(fd, ",hpm%0d", i);
      $fwrite(fd, "\n");
    end
    $fwrite(fd, "%s,%0d,%0d,%0d", elffilename, Cycles, Instret, Cycles - Instret);
    for (int i = C_STARTUP; i < C_NUM; i++) $fwrite(fd, ",%0d", CauseCycles[i]);
    for (int i = C_LOADUSE; i <= C_FCVTINT; i++) $fwrite(fd, ",%0d", FalseDep[i]);
    $fwrite(fd, ",%0d", FalseDepNoIntWrite);
    $fwrite(fd, ",%0d", BPFlushes);
    for (int c = 0; c < 2; c++)
      $fwrite(fd, ",%0d,%0d,%0d,%0d,%0d,%0d,%0d,%h,%0d,%0d,%0d", CacheEp[c][0], CacheEp[c][1], CacheEp[c][2], CacheEp[c][3],
              CacheEp[c][4], CacheEp[c][5], OtherMax[c], OtherPC[c], Fills[c], FillsUnreported[c], ReMiss[c]);
    for (int e = 0; e < E_NUM; e++) $fwrite(fd, ",%0d,%0d,%0d,%h", EpCount[e], EpSum[e], EpMax[e], EpMaxPC[e]);
    for (int i = 0; i < NEVENTS; i++) $fwrite(fd, ",%0d", EventCount[i]);
    $fwrite(fd, "\n");
    $fclose(fd);
    fp = $fopen(pcfile, FilesOpened ? "a" : "w");
    FilesOpened = 1;
    foreach (PCHist[k]) $fwrite(fp, "%s,%h,%s,%0d\n", elffilename, k[69:6], causeName[k[5:0]], PCHist[k]);
    $fclose(fp);
  endfunction

  always_ff @(posedge clk) begin
    if (reset) begin
      Running <= 1'b1;
      clearStats();
    end else if (Running) begin
      Cycles++;
      if (Retire) Instret++;
      else begin
        CauseCycles[cause]++;
        PCHist[{64'(causePC), 6'(cause)}]++;
        if (cause == C_UNKNOWN && AnomPrinted[1] < 20) begin
          $display("PERFANOM %s unknown pc=%h t=%0t", elffilename, causePC, $time);
          AnomPrinted[1]++;
        end
      end
      // Bubbles created by structural stalls that had no true integer dependency
      if (FlushE & ~StallE & StallD & ~TrueDepD &
          (LoadStallD | CSRRdStallD | MDUStallD | FCvtIntStallD) & ~(TrapM | RetM | CSRWriteFenceM | BPWrongE)) begin
        FalseDep[dStallCause()]++;
        if (~RegWriteE) FalseDepNoIntWrite++;
        if (AnomPrinted[2] < 20) begin
          $display("PERFANOM %s falsedep_%s pc=%h instrD=%h rdE=x%0d t=%0t", elffilename, causeName[dStallCause()], PCD, InstrD, RdE, $time);
          AnomPrinted[2]++;
        end
      end
      if (FlushD & ~StallD & causeFlushD == C_BPWRONG) BPFlushes++;
      for (int c = 0; c < 2; c++) begin
        if (CacheState[c] == 4'd1) Visited[c][0] = 1;
        if (CacheState[c] == 4'd2 || CacheState[c] == 4'd6) Visited[c][1] = 1;
        if (CacheState[c] == 4'd5 || CacheState[c] == 4'd6) Visited[c][2] = 1;
        if (c ? (FlushW | HPTWStall) : FlushD) Visited[c][3] = 1;   // the walker also pre-empts a D$ miss that has not started
        if (c && CMOpM != 0) Visited[c][4] = 1;
        // a fill writes the line in WRITE_LINE and ends when ADDRESS_SETUP returns to ACCESS; CacheMiss must pulse
        // once in between (in WRITE_LINE, or in ADDRESS_SETUP on older RTL)
        if (CacheState[c] == 4'd3) SawMiss[c] = (c ? DCacheMiss : ICacheMiss);
        else if (CacheState[c] == 4'd4 && (c ? DCacheMiss : ICacheMiss)) SawMiss[c] = 1;
        if (PrevState[c] == 4'd4 && CacheState[c] != 4'd4 && PrevFromFill[c]) begin
          Fills[c]++;
          if (!SawMiss[c]) FillsUnreported[c]++;
        end
      end
      // only fills load a line; older RTL also pulses CacheMiss after D$ flushes and CMOs
      if (CacheState[0] == 4'd3) noteMiss(0, longint'(PCPF >> ILINEBITS));
      if (CacheState[1] == 4'd3) noteMiss(1, longint'(PAdrM >> DLINEBITS));
      if (Trace) begin
        if (ICacheMiss) $display("PERFTRACE t=%0t cyc=%0d icache_miss line=%h pcf=%h pcpf=%h", $time, Cycles, PCPF >> ILINEBITS, PCF, PCPF);
        if (DCacheMiss) $display("PERFTRACE t=%0t cyc=%0d dcache_miss line=%h pcm=%h", $time, Cycles, PAdrM >> DLINEBITS, PCM);
        if (InvalidateICacheM) $display("PERFTRACE t=%0t cyc=%0d invalidate_icache stallM=%b pcm=%h", $time, Cycles, StallM, PCM);
        if (CacheState[0] == 4'd1 && PrevState[0] != 4'd1) $display("PERFTRACE t=%0t cyc=%0d icache_fetch_start pcf=%h pcpf=%h", $time, Cycles, PCF, PCPF);
      end
      if (InvalidateICacheM) LineFill[0].delete();
      if (FlushDCacheM | (CMOpM[0] | CMOpM[2])) LineFill[1].delete();
      for (int e = 0; e < E_NUM; e++)
        if (EpSig[e]) begin
          if (EpLen[e] == 0) EpStartPC[e] = (e == E_ICACHE || e == E_IFUBUS || e == E_SPILLF) ? 64'(PCF) : 64'(PCM);
          EpLen[e]++;
        end else if (EpLen[e] != 0) endEpisode(e);
      for (int i = 0; i < NEVENTS; i++) EventCount[i] += longint'(HPMEvents[i]);
      if (CopyRAM) begin
        for (int e = 0; e < E_NUM; e++) if (EpLen[e] != 0) endEpisode(e);
        writeResults();
        Running <= 1'b0;
      end
    end
  end
endmodule
