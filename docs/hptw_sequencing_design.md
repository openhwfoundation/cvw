# HPTW / LSU / IFU arbitration redesign for issues #1538 and #1766

Branch: `dh/issue-1538-hptw-sequencing` (worktree /home/harris/cvw-1538), based on upstream main 9d97f39bb.

## 1. What actually goes wrong (empirical, probe trace of arch64vm_sv48_b on unmodified main)

Cycle trace (times in Verilator units, one line per cycle) around the lost store of 0x40 at PA 0x80000414:

```
76990 IDLE   DTLB miss (store 0xeb8) + ITLB miss (wrong-path PCF 0x28080000400) -> HPTWFlushW, HPTWStall, StartWalk (DTLBWalk=1)
77000-77040  DTLB walk L3..L1, leaf gigapage PTE 0x200000ff
77050 LEAF   DTLBWriteM; SelHPTWAdr=0 so the D$ tag SRAM is read at the store's set (0x10)
77060 IDLE   DTLB now hits; ITLB miss still pending -> HPTWFlushW again, HPTWStall; store presents Hit=1 SetDirty=1 but CacheEn=0 (stalled) -> not written yet (fine, will replay)
77070-77110  ITLB walk for the wrong-path VA; L1_ADR sees non-leaf PTE 0x200000e1 with A/D set -> DAUFaultM -> FAULT
77120 FAULT  HPTWStall=0 while SelHPTW=1: StallW=0, every stage advances. The store leaves M with CacheRW=00 (LSU datapath muxed to the walker). STORE LOST.
77130-77190  PCF advanced to 0x...404 (same unmapped page) -> second wrong-path walk -> FAULT again -> the next instruction drains through the same hole
77200 IDLE   BPWrongE has redirected PCF; the lw (0xec0) is in M. Its Hit is computed from the tag read launched in FAULT at the walker's address set -> false miss -> FETCH
77290 WRITE_LINE refills clean memory data 0xbeefcaf2 over the dirty way (the 0x30 line) -> load returns 0xbeefcaf2
```

#1766 (sv32 lockstep, lw reads 0x11 instead of 0xc) is the same FAULT-cycle hole: the lw retires while the datapath is muxed to the walker and captures walker residue.

Root causes, matching Rose Thompson's diagnosis that the HPTW does not track what it is sequencing:

R1. The FAULT state releases the pipeline (HPTWStall=0) while the LSU datapath is still switched to the walker (SelHPTW=1). Intended to let a fetch fault pulse reach the D stage; side effect: the M-stage memory access retires unexecuted.
R2. The fetch-side walk fault is a one-cycle pulse into a register enabled by ~StallD; when D is stalled the pulse is lost, the ITLB miss persists and the walk repeats, draining one corrupted instruction per iteration.
R3. FAULT leaves the D$ tag/valid/dirty/LRU read pointing at the walker's address set, so the resumed access decides hit/miss on stale state (false miss -> duplicate tag or dirty-line overwrite; false hit -> wrong data).
R4. Any TLB request at IDLE flushes the LSU access (HPTWFlushW) without knowing whether that access has already started on the D$/bus. Normally the ITLB miss and the M-stage access begin in the same cycle (F and M advance together), but an instruction spilling across a page boundary raises its second-half ITLB miss one cycle later, when the access may be mid-AHB-transaction. Flushing it abandons the transaction and replays it: double bus access for uncached loads/stores/AMOs.
R5. The order DTLB walk -> ITLB walk -> memory access exists only implicitly through IDLE re-entry and D$/bus stall state.

## 2. Design

### 2.1 hptw.sv: explicit request tracking and ordering (Rose's triplicated pending state)
- `DTLBReq = DTLBMissOrUpdateDAM`; `ITLBReq = ITLBMissOrUpdateAF & ~MemAccessInFlightM` (from LSU).
- `AcceptReq = IDLE & (DTLBReq | ITLBReq)`; `StartWalk = AcceptReq`.
- Registers `DTLBWalkPending`, `ITLBWalkPending` capture both requests at StartWalk; cleared as each walk completes (final LEAF or FAULT); a DTLB-walk FAULT also clears ITLBWalkPending (the access traps, nothing more to do); both reset on FlushW.
- `DTLBWalk = DTLBWalkPending` (serve the DTLB first). At the final LEAF of the DTLB walk, if `ITLBWalkPending`, chain directly to `InitialWalkerState` for the ITLB walk without passing through IDLE (the LSU access is never re-presented between the two walks, so no flush is needed).
- PTE register cleared at the end of every walk (final LEAF or FAULT), not only on transitions to IDLE, so a chained walk never evaluates stale PTE bits.
- `HPTWStall = (WalkerState != IDLE) | AcceptReq` — FAULT now stalls (fixes R1). For a DTLB-walk fault the trap overrides the stall (hazard masks LSUStallM with FlushWCause); for an ITLB-walk fault the M-stage access stays in M and executes after IDLE.
- `SelHPTWAdr = SelHPTW & ~(DTLBWriteM | ITLBWriteF | FAULT)` — FAULT reads the D$ at the LSU access's set like LEAF does (fixes R3). Set index bits lie in the page offset, so the untranslated address gives the right set (same reliance as LEAF today).
- `HPTWFlushW = (AcceptReq & ~MemAccessDoneM) | (WalkerState != IDLE & HPTWFaultM)` — the pre-emption flush happens only when a request is accepted, which by construction is only when the access has not started (fixes R4 together with 2.2).
- The memory access is performed last: after the last walk the walker is IDLE, HPTWStall=0, SelHPTW=0, and the LSU access runs; the IFU holds the pipeline only for unresolved ITLB requests (2.3), never for one that faulted.

### 2.2 lsu.sv: memory-access state (Rose's MemAccess register)
- `MemAccessInFlightM = (DCacheCommittedM | BusCommittedM) & ~MemAccessDoneM`: the M-stage access has been started by the D$/bus (fetch/writeback/data phase, or performed and holding in ADDRESS_SETUP/MEM3). The walker defers ITLB requests while it is set.
- `MemAccessPerformedM = (DCacheCommittedM | BusCommittedM) & ~DCacheBusStallM & ~SpillStallM & ~SelHPTW`: the access has completed and is holding its result (D$ ADDRESS_SETUP or bus MEM3, both halves of a misaligned spill done).
- `MemAccessDoneM`: set when performed while the pipeline is stalled (StallW=1), cleared when the pipeline advances (~StallW) or FlushW. `ReadDataHoldM` captures ReadDataM at that point. While MemAccessDoneM: the M->W register takes ReadDataHoldM, and CacheRWM/BusRW/BusCMOZero/CacheCMOpM are gated so the access is not re-issued. CommittedM includes MemAccessDoneM (interrupts stay blocked until the performed access retires).
- With this, a walk may start after a performed access without disturbing it (the walker reuses the D$/bus, the held result is delivered at retirement), and a walk never starts while an access is in flight. Idempotent accesses (cached load/store hits) that have not been performed are pre-empted and replayed exactly as before.
- Only instantiated when VIRTMEM_SUPPORTED (no walker, no pre-emption hazard).

### 2.3 ifu.sv: sticky walk fault and fetch-side stall ownership (fixes R2)
- `ITLBWalkFaultHeldF[1:0]` set by the walker's HPTWInstrAccessFaultF/HPTWInstrPageFaultF pulses, cleared when the fetch advances (~StallF). Outputs `HPTWInstrAccessFaultHeldF/HPTWInstrPageFaultHeldF` (pulse | held) replace the raw pulses into the privileged pipeline registers, so the fault is a level that survives any D-stage stall.
- `ITLBMissOrUpdateAF` (to the LSU) is masked by the held fault: no walk is re-requested for a fetch whose walk faulted; the fetch proceeds to D carrying the fault (or is flushed if wrong-path). The spill unit keeps the unmasked miss (it must not spill a faulting fetch).
- `IFUFaultF` includes the held fault (no I$/bus fetch of a faulting address, also for A-bit-update walks where ITLBMissF=0).
- `IFUStallF` includes the masked ITLB request: the fetch side owns the "fetch not ready" stall, including while the walker defers the request behind an in-flight access. The hazard unit already masks IFUStallF with FlushDCause, so a redirect (BPWrongE/trap/xret/fence) still moves PCF away from a wrong-path miss before it is ever walked when the walker has not accepted it yet.

### 2.4 Unchanged
- cache.sv/cachefsm.sv/cacheway.sv: no changes. The TagSetStale/StoreHitFirstStall patches of PR #1768 are unnecessary once the walker never releases the pipeline with the datapath muxed and always re-reads the access's set before returning to IDLE.
- sfence.vma global-entry handling: not touched (separate correctness topic, was part of #1768; re-evaluate separately).

## 3. Invariants after the change
I1. SelHPTW=1 implies StallW=1 unless TrapM (FlushWCause). The M->W register can never capture walker-muxed data.
I2. HPTWFlushW pre-empts an LSU access only in a cycle where DCacheCommittedM=BusCommittedM=0 (nothing started) or the access is already captured (MemAccessDoneM), so no AHB transaction is ever abandoned by the walker and no non-idempotent access is replayed.
I3. The last non-IDLE walker cycle (final LEAF or FAULT) launches the D$ SRAM read at the LSU access's set, so the first IDLE cycle has a valid Hit for the resumed access.
I4. A fetch whose walk faulted never re-requests a walk; its fault is a level until the fetch leaves F.
I5. Both TLB requests present when the walker leaves IDLE are served before the access runs, DTLB first.

## 4. Verification plan
- Baseline failures: arch64vm_sv48_b (Verilator), #1766 ELF (rv32gc Questa lockstep).
- Directed variants (tests/coverage, lockstep oracle + self-check): wrong-path ITLB miss (BTB alias) whose walk (a) fills, (b) PMA-faults on a PTE address, (c) faults on non-leaf reserved bits, overlapped with an M-stage {store hit, store miss, load hit, load miss, uncached load/store (PBMT=IO page, UART SCR), AMO hit/miss, cbo.zero, misaligned spill}; DTLB miss + wrong-path ITLB miss (the #1538 shape) with the same matrix; instruction spill across a page boundary whose second half misses the ITLB with each access type in M; A-bit update walk variants; load-use stall in D during the walk fault (#1766 shape).
- Regression: arch64vm_sv39/sv48/sv57 (+ sv57 A_and_D re-enabled), arch64vm_sv48_a/_b, wally64priv, coverage64gc, arch64m, arch64a_amo, arch64zicboz, arch64i/priv, arch32vm_sv32, wally32priv, buildroot short run; lint-wally; nightly lockstep set.
