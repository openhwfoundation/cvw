#///////////////////////////////////////////
#// coverage-exclusions-rv32gc.do
#//
#// Written: Claude for David_Harris@hmc.edu 27 October 2026
#//
#// Purpose: Set of exclusions from coverage for the rv32gc configuration
#//          For example, signals hardwired to 0 should not be checked for toggle coverage
#//
#// A component of the CORE-V-WALLY configurable RISC-V project.
#// https://github.com/openhwfoundation/cvw
#//
#// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
#//
#// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#////////////////////////////////////////////////////////////////////////////////////////////////

# This file should be a last resort.  It's preferable to put
# // coverage off
# statements inline with the code whenever possible.

# sim/Makefile (QuestaCodeCoverage) applies this file in Coverage View mode to the merged database, whose
# top scope is /core (wally-run.do saves /testbench/dut/core).  Applying it there, rather than in each
# simulation, matters: with Questa 2023.4, -fecexprrow/-feccondrow exclude single rows only in the form
#   coverage exclude -scope <scope> -fecexprrow <line> <row> [<row>|<row>-<row>] ...
# Combined with "-linerange <line> -item e 1" the row list is read as a line number and the whole expression
# is excluded instead.  Row lists are space separated; "2,4" excludes row 2 only.  A bare -linerange also
# excludes the FSM states and transitions Questa reports on that line, so name the items to exclude.
# Exclude only rows that cannot be reached, so that losing a reachable row shows up in the report.
#
# rv32gc (config/rv32gc/config.vh): XLEN = 32 with Sv32 only (SV39/48/57_SUPPORTED = 0), no Svpbmt or Svnapot
# (SVPBMT_SUPPORTED = SVNAPOT_SUPPORTED = 0), no hardware misaligned accesses (ZICCLSM_SUPPORTED = 0), no quad
# precision, integer division in the MDU (IDIV_ON_FPU = 0), 32 counters and a 32-bit AHB bus.  Memory: boot ROM and
# uncore RAM (both cacheable), CLINT, GPIO, UART, PLIC, SPI and PWM.  There is no DTIM, IROM, external memory or SD
# card controller (DTIM/IROM/EXT_MEM/SDC_SUPPORTED = 0).
#
# FEC rows are named by their targets (ExcludeRows, ExcludeGenRows, ExcludeTermRows in CoverageExclude.do), and
# source lines by exclusion-tag comments in the RTL (TagLine), so nothing here depends on line or row numbers.

set WALLY $::env(WALLY)
set SRC ${WALLY}/src
do ${WALLY}/sim/questa/CoverageExclude.do

set FPU   /core/fpu/fpu
set IC    /core/ifu/bus/icache/icache
set ICBUS /core/ifu/bus/icache/ahbcacheinterface
set DC    /core/lsu/bus/dcache/dcache
set DCBUS /core/lsu/bus/dcache/ahbcacheinterface
set IMMU  /core/ifu/immu/immu
set DMMU  /core/lsu/dmmu/dmmu
set HPTW  /core/lsu/hptw/hptw
set CNT   /core/priv/priv/csr/counters

######################################################################################################
# FPU and integer divider
######################################################################################################

# The FP divider (fdivsqrtfsm) and the integer divider (mdu div, used because IDIV_ON_FPU = 0) have the same FSM.
# DONE -> BUSY: a divide starts only from IDLE (IFDivStartE and DivStartE both require state == IDLE).
# BUSY -> IDLE: only reset or FlushE & ~StallM leave BUSY early.  A busy divider stalls E, so M holds the bubble
# left behind the divide (InstrValidM = 0) and no trap, xRET or CSR fence can be raised in M; FlushECause ignores
# BPWrongE while the divider is busy.  The testbench asserts reset only between programs.
coverage exclude -scope $FPU/fdivsqrt/fdivsqrtfsm -ftrans state DONE->BUSY BUSY->IDLE
coverage exclude -scope /core/mdu/mdu/div/div -ftrans state DONE->BUSY BUSY->IDLE

# Square root digit selection, sqrtspecial = SqrtE & (j1 | j0).  The on-the-fly register C starts at 0 and each
# radix-4 step shifts in 11 (CNext = {2'b11, C[DIVb+1:2]}).  So j0 = ~C[DIVb+1] is 1 only at step 0, where
# j1 = ~C[DIVb-1] is 1 too, and j1 is 1 with j0 = 0 only at step 1.  With DIVCOPIES = 2, iteration 0 performs steps
# 0, 2, 4, ... and iteration 1 steps 1, 3, 5, ...: j0_1 (which needs j1 = 0) is never seen, iteration 0 never sees
# j1_1 (which needs j0 = 0), and iteration 1 never sees j0 = 1 (the true branch of mkj1 = j0 ? 0 : 8).
set USLC4 $FPU/fdivsqrt/fdivsqrtiter/iterations
ExcludeRows "${USLC4}\[0\]/stage/fdivsqrtstage/uslc4" e {j1_1 j0_1}
ExcludeRows "${USLC4}\[1\]/stage/fdivsqrtstage/uslc4" e {j0_1}
coverage exclude -scope "${USLC4}\[1\]/stage/fdivsqrtstage/uslc4" -linerange [TagLine ${SRC}/fpu/fdivsqrt/fdivsqrtuslc4cmp.sv uslc4-mkj1] -item b 1

# A divide by zero is a divider special case: the divider loads U = 0 and UM = 1.0 and goes straight to DONE, so
# the quotient has no bits below its leading one and Guard = Round = Sticky = 0 (DivSticky = ~WZeroM &
# ~SpecialCaseM = 0); Overflow is gated by ~DivByZero.  The DivByZero_1 rows of Underflow and FpInexact need one of
# Round/Sticky/Guard (or Overflow) set.
ExcludeRows $FPU/postprocess/flags e {DivByZero_1 +UfPlus1_*}
ExcludeRows $FPU/postprocess/flags e {DivByZero_1 +Overflow_*}

# The (FullRe == 1)_0 row of Underflow needs FullRe other than 0 or 1 while Me == 0, but a subnormal (Me = 0) rounds
# to FullRe = 0 or 1 (as in coverage-exclusions-rv64gc.do).
ExcludeRows $FPU/postprocess/flags e {{(FullRe == 1)_0} +UfPlus1_*}

# funct7 1011011 (fmvp.q.x) has FMT = 11, quad precision.  Q_SUPPORTED = 0, so fctrl rejects the instruction as an
# unsupported format before this case statement and the arm is never selected.
coverage exclude -scope $FPU/fctrl -linerange [TagLine ${SRC}/fpu/fctrl.sv fmvp-q-x] -item b 1

######################################################################################################
# IEU
######################################################################################################

# BaseW64D and BW64D are set only by RV64 word (W) instructions, which the decoders gate with XLEN == 64.
ExcludeRows /core/ieu/c e {BaseW64D_1 BW64D_1}

# aes32e passes {24'h0, SboxOut} to aesmixcolumns32, so bytes a0 = a1 = a2 = 0 and the inputs of gm0 (a0 ^ a1) and
# gm1 (a1 ^ a2) are always 0: their a[7] (reduce) branch is never taken.
set AES32E /core/ieu/dp/alu/bitmanipalu/balu/zknde/genblk1/ZKN32/genblk2/aes32e/mb
foreach gm {gm0 gm1} {
  coverage exclude -scope $AES32E/$gm -linerange [TagLine ${SRC}/ieu/aes/galoismultforward8.sv gf-reduce] -item b 1
}

######################################################################################################
# Hazard unit
######################################################################################################

# StallFCause is tied to 0, so StallF = StallD and LatestUnstalledD = ~StallD & StallF is always 0.
ExcludeRows /core/hzu e {StallD_0 StallF_1}
ExcludeRows /core/hzu e {LatestUnstalledD_1}

######################################################################################################
# Privileged unit
######################################################################################################

# With C supported, instructions are 2-byte aligned and every jump/branch target has bit 0 cleared, so an
# instruction address misaligned fault never occurs.
ExcludeRows /core/priv/priv/trap e {InstrMisalignedFaultM_1}

# The wfi wait counter clears whenever M advances, and M holds the same instruction while it is stalled, so the
# counter reaches its limit (q[16]) only with the wfi still in M: wfiM_0 is never seen with q[16] = 1.
ExcludeRows /core/priv/priv/pmd e {wfiM_0} [TagLine ${SRC}/privileged/privdec.sv pmd-tw-timeout]

# A write to satp from S mode with mstatus.TVM = 1, or to stimecmp/stimecmph from S mode with STCE = 0 (STCE reads 1
# in M mode), is an illegal CSR access.  It traps, so CSRSWriteM is 0 and these write enables never see the other
# term false.
ExcludeRows /core/priv/priv/csr/csrs/csrs e {{(PrivilegeModeW == 3)_0} STATUS_TVM_1}
ExcludeRows /core/priv/priv/csr/csrs/csrs e {STCE_0 {+(CSRAdrM == 333)*}}
ExcludeRows /core/priv/priv/csr/csrs/csrs e {STCE_0 {+(CSRAdrM == 349)*}}

# Accessing frm, fflags or fcsr with mstatus.FS = 0 is an illegal instruction.  It traps, so CSRUWriteM is 0
# whenever STATUS_FS = 0.
ExcludeRows /core/priv/priv/csr/csru/csru e {{(STATUS_FS != 0)_0} {+(CSRAdrM == 2)*}}
ExcludeRows /core/priv/priv/csr/csru/csru e {{(STATUS_FS != 0)_0} {+(CSRAdrM == 1)*}}

# Counter 1 has no CSR: 0xB01/0xB81 would be mtime/mtimeh, which Wally maps in the CLINT, not in the CSR space.
# csrc treats them as nonexistent, so an access is illegal and traps and CSRMWriteM is never 1 for them; the
# counter's write enables and its write mux branches cannot be reached.
ExcludeGenRows $CNT {cntr[1]} e {CSRMWriteM_1 {(CSRAdrM == (2816 + 1))_1}}
ExcludeGenRows $CNT {cntr[1]} e {CSRMWriteM_1 {(CSRAdrM == (2944 + 1))_1}}
coverage exclude -scope "$CNT/cntr\[1\]" -linerange [TagLine ${SRC}/privileged/csrc.sv next-hpmcounter] -item b 1
coverage exclude -scope "$CNT/cntr\[1\]" -linerange [TagLine ${SRC}/privileged/csrc.sv next-hpmcounterh] -item b 1

# CounterEvent[0] (mcycle) is tied to 1 and CounterEvent[1] (no counter 1) to 0, so CounterEvent[0]_0 and
# CounterEvent[1]_1, and the MCOUNTINHIBIT[1] rows that need CounterEvent[1] = 1, cannot be reached.
ExcludeGenRows $CNT {cntr[0]} e {{CounterEvent\[0\]_0}}
ExcludeGenRows $CNT {cntr[1]} e {{CounterEvent\[1\]_1} {MCOUNTINHIBIT_REGW\[1\]_*}}

# CounterEvent[31:25] is tied to 0 (no event sources yet), so counters 25-31 never increment: every row but
# CounterEvent_0 needs CounterEvent = 1.
for {set i 25} {$i < 32} {incr i} {
  ExcludeGenRows $CNT "cntr\[$i\]" e [list "MCOUNTINHIBIT_REGW\\\[$i\\\]_*" "CounterEvent\\\[$i\\\]_1" "(MHPMEVENT_REGW\\\[$i\\\] != 0)_*"]
}

# rv32gc implements all 32 counters (COUNTERS = 32), which makes the range checks for absent counters degenerate.
# MHPMEVENTBASE + COUNTERS - 3 = 0x340 is above the last event selector (0x33F), so that guard is always true and the
# read-only-zero branch for absent event selectors never runs.  The absent mhpmcounter, hpmcounter, mhpmcounterh and
# hpmcounterh ranges, BASE + COUNTERS <= CSRAdrM < BASE + 32, are empty, so their branches, read-only-zero statements
# and the condition rows that need the range true never run.
ExcludeRows $CNT c {{(CSRAdrM < ((803 + 32) - 3))_0}}
coverage exclude -scope $CNT -linerange [TagLine ${SRC}/privileged/csrc.sv unused-event-zero] -item bs 1
foreach {range base} {mhpmcounter 2816 hpmcounter 3072 mhpmcounterh 2944 hpmcounterh 3200} {
  set terms [list "(CSRAdrM >= ($base + 32))_1" "(CSRAdrM < ($base + 32))_1"]
  if {$range eq "hpmcounter" || $range eq "hpmcounterh"} { lappend terms CSRWriteM_* }
  ExcludeRows $CNT c $terms [TagLine ${SRC}/privileged/csrc.sv unused-$range-range]
  coverage exclude -scope $CNT -linerange [TagLine ${SRC}/privileged/csrc.sv unused-$range-range] -item b 1
  coverage exclude -scope $CNT -linerange [TagLine ${SRC}/privileged/csrc.sv unused-$range-zero] -item s 1
}

######################################################################################################
# IFU
######################################################################################################

# There is no IROM (IROM_SUPPORTED = 0), so SelIROM is tied to 0 and the uncached-data mux never selects it.
ExcludeTermRows /core/ifu c {SelIROM_1}
coverage exclude -scope /core/ifu/bus/icache/UnCachedDataMux -linerange [TagLine ${SRC}/generic/mux.sv mux3] -item b 1

# BusCommittedF without CacheCommittedF needs an uncached fetch (see the I$ bus FSM below): the I$ bus FSM leaves
# ADR_PHASE only for CACHE_FETCH, which it enters with the I$ in STATE_FETCH (committed), and both return together
# on CacheBusAck.
ExcludeRows /core/ifu e {BusCommittedF_1}

# I$ (cache READ_ONLY_CACHE = 1).  The IFU ties FlushCache and CMOpM to 0 and never writes (CacheRWF[0] = 0), and a
# read-only cache has no dirty bits (Dirty = 0, so LineDirty = HitDirtyWay = 0).  So the I$ never enters
# STATE_WRITEBACK, STATE_FLUSH or STATE_FLUSH_WRITEBACK, never sets a dirty bit or clears a valid bit, and never
# selects FlushAdr or the writeback address.  The rows below need one of these.
coverage exclude -scope $IC/cachefsm -fstate CurrState STATE_WRITEBACK STATE_FLUSH STATE_FLUSH_WRITEBACK
coverage exclude -scope $IC/cachefsm -linerange [TagLine ${SRC}/cache/cachefsm.sv "icache FLUSHStatement"] -item bs 1
coverage exclude -scope $IC/cachefsm -linerange [TagLine ${SRC}/cache/cachefsm.sv "icache WRITEBACKStatement"] -item bs 1
coverage exclude -scope $IC/cachefsm -linerange [TagLine ${SRC}/cache/cachefsm.sv cachefsm-writeback-arm]-[TagLine ${SRC}/cache/cachefsm.sv cachefsm-flush-writeback-wait]
ExcludeTermRows $IC/cachefsm e {{CacheRWF\[0\]_1} FlushCache_1 AnyUpdateHit_1 LineDirty_1 {(CurrState == STATE_WRITEBACK)_1}
  {(CurrState == STATE_FLUSH)_1} {(CurrState == STATE_FLUSH_WRITEBACK)_1}}
ExcludeRows $IC/cachefsm e {Hit_*} [TagLine ${SRC}/cache/cachefsm.sv "icache storeAMO1"]
ExcludeRows $IC/cachefsm e {{(CurrState == STATE_ACCESS)_*} {(CurrState == STATE_WRITE_LINE)_*}} [TagLine ${SRC}/cache/cachefsm.sv "icache SetDirty"]
ExcludeRows $IC/cachefsm e {{(CurrState == STATE_FLUSH)_0} LineDirty_0} [TagLine ${SRC}/cache/cachefsm.sv "icache ClearDirty"]
ExcludeRows $IC/cachefsm e {CacheBusAck_* {(CurrState == STATE_ACCESS)_*} AnyMiss_* {+(CurrState == STATE_WRITE_LINE)*}}
ExcludeRows $IC/cachefsm e {CacheBusAck_* {(CurrState == STATE_ACCESS)_*} AnyMiss_*} [TagLine ${SRC}/cache/cachefsm.sv cachefsm-sel-writeback]
ExcludeRows $IC/cachefsm e {LineDirty_* CacheBusAck_* {+(CurrState == STATE_FLUSH)*}}
ExcludeRows $IC/cachefsm e {{(CurrState == STATE_ACCESS)_*} LoadMiss_* CacheBusAck_*} [TagLine ${SRC}/cache/cachefsm.sv "icache CacheBusW"]
foreach mux {AdrSelMuxData AdrSelMuxTag AdrSelMuxLRU} {
  coverage exclude -scope $IC/$mux -linerange [TagLine ${SRC}/generic/mux.sv mux3] -item b 1
}
coverage exclude -scope $IC/CacheBusAdrMux -linerange [TagLine ${SRC}/generic/mux.sv mux3] -item b 1 3
for {set i 0} {$i < 4} {incr i} {
  set way "$IC/CacheWays\[$i\]"
  ExcludeRows $way e {ClearValid_1 SelectedWay_*}
  ExcludeRows $way e {SetDirty_1 SelectedWay_*}
  ExcludeRows $way e {SetDirtyWay_1}
  ExcludeRows $way e {ClearValidWay_1 FlushStage_*}
  ExcludeRows $way e {SelecteDirty_* HitDirtyWay_1}
  coverage exclude -scope $way -linerange [TagLine ${SRC}/cache/cacheway.sv "icache ClearValidBits"] -item bs 1
}

# The I$ is flushed by FlushD, which comes from a trap, xRET, CSR fence or branch mispredict.  While the I$ fills a
# line it stalls the pipeline, which freezes the instructions in E and M, so these can only arrive in the cycle the
# miss is detected, and a trap waits for CommittedF (interrupts are held while committed).  So a fill (STATE_FETCH,
# STATE_WRITE_LINE) is never flushed, and a way is never written (SetValidWay) in a flushed cycle.
coverage exclude -scope $IC/cachefsm -ftrans CurrState STATE_FETCH->STATE_ACCESS STATE_WRITE_LINE->STATE_ACCESS
for {set i 0} {$i < 4} {incr i} {
  set way "$IC/CacheWays\[$i\]"
  ExcludeRows $way e {FlushStage_1 +SetDirtyWay_*}
  ExcludeRows $way e {FlushStage_1} [TagLine ${SRC}/cache/cacheway.sv "cache SetValidEN"]
}

# resetDelay is 1 only in the first cycle after reset, when the cold I$ is missing on the reset vector fetch, so
# the AnyMiss term of SelAdrData/SelAdrTag is 1 and masks it.  The I$ CacheEn reset_1 row needs reset while the I$
# is in STATE_ACCESS and stalled without a stall condition; the I$ is not stalled during reset.
ExcludeRows $IC/cachefsm e {resetDelay_1 {+CacheRWF\[0\]*}}
ExcludeRows $IC/cachefsm e {resetDelay_1} [TagLine ${SRC}/cache/cachefsm.sv "icache SelAdrTag"]
ExcludeRows $IC/cachefsm e {reset_1} [TagLine ${SRC}/cache/cachefsm.sv "dcache CacheEn"]

# I$ bus FSM (buscachefsm READ_ONLY_CACHE = 1).  The IFU makes an uncached bus fetch (BusRW) only for a fetch with
# CacheableF = 0 that does not fault.  Without Svpbmt (SVPBMT_SUPPORTED = 0) Cacheable is CacheableRegion, and the
# only executable regions (boot ROM, uncore RAM) are cacheable; a fetch from a peripheral faults.  So BusRW = 0, and
# the FSM only uses ADR_PHASE and CACHE_FETCH: DATA_PHASE, MEM3, the atomic states and CACHE_WRITEBACK (a read-only
# cache never writes) are never entered.
coverage exclude -scope $ICBUS/AHBBuscachefsm -fstate CurrState DATA_PHASE MEM3 ATOMIC_READ_DATA_PHASE ATOMIC_PHASE CACHE_WRITEBACK
coverage exclude -scope $ICBUS/AHBBuscachefsm -linerange [TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm HREADY2"]-[TagLine ${SRC}/ebu/buscachefsm.sv buscachefsm-mem3-done]
coverage exclude -scope $ICBUS/AHBBuscachefsm -linerange [TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm WritebackWriteback"]-[TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm WritebackWriteback2"]
coverage exclude -scope $ICBUS/AHBBuscachefsm -linerange [TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm HREADY0"] -item b 2
coverage exclude -scope $ICBUS/AHBBuscachefsm -linerange [TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm HREADY0"] -item s 1
coverage exclude -scope $ICBUS/AHBBuscachefsm -linerange [TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm HREADY1"] -item bs 1
ExcludeRows $ICBUS/AHBBuscachefsm c {HREADY_* |BusRW_1} [TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm HREADY0"]
ExcludeTermRows $ICBUS/AHBBuscachefsm e {{(CurrState == DATA_PHASE)_1} {(CurrState == ATOMIC_PHASE)_1}
  {(CurrState == ATOMIC_READ_DATA_PHASE)_1} {(CurrState == CACHE_WRITEBACK)_1} {(NextState == CACHE_WRITEBACK)_1}}
ExcludeTermRows $ICBUS/AHBBuscachefsm c {{(CurrState == ATOMIC_READ_DATA_PHASE)_1}}
ExcludeRows $ICBUS/AHBBuscachefsm e {Flush_* {BusRW\[1\]_*}}
ExcludeRows $ICBUS/AHBBuscachefsm e {{(CurrState == ADR_PHASE)_*} {BusRW\[0\]_1} BusWrite_1 {(CurrState == DATA_PHASE)_*}
  {(CurrState == ATOMIC_PHASE)_*} {(CurrState == ATOMIC_READ_DATA_PHASE)_*}}

# The cache holds a bus request until CacheBusAck = HREADY & FinalBeatCount, so it never raises CacheBusRW again
# at the final beat of a fetch (no pipelined second request: FetchWriteback, FetchWait), and ~|CacheBusRW implies
# HREADY & FinalBeatCount in CACHE_FETCH.  The I$ never writes (CacheBusRW[0] = 0).
foreach fsm [list $ICBUS/AHBBuscachefsm $DCBUS/AHBBuscachefsm] {
  coverage exclude -scope $fsm -linerange [TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm FetchWriteback"] -item b 2
  coverage exclude -scope $fsm -linerange [TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm FetchWriteback"] -item s 1
  coverage exclude -scope $fsm -linerange [TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm FetchWait"] -item bs 1
  ExcludeRows $fsm c {HREADY_* FinalBeatCount_* {CacheBusRW\[0\]_1}} [TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm FetchWriteback"]
  ExcludeRows $fsm c {HREADY_* FinalBeatCount_1 {CacheBusRW\[1\]_1}} [TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm FetchWait"]
  ExcludeRows $fsm c {HREADY_0 FinalBeatCount_0 ~|CacheBusRW_0} [TagLine ${SRC}/ebu/buscachefsm.sv buscachefsm-fetch-done]
}
coverage exclude -scope $DCBUS/AHBBuscachefsm -ftrans CurrState CACHE_FETCH->CACHE_WRITEBACK

# BeatCount is nonzero outside CACHE_FETCH/CACHE_WRITEBACK only after a burst cut short by a flush, or in the MEM3
# that ends the bus write of an uncached cbo.zero (BeatCntReset waits for ADR_PHASE).  A burst is never flushed
# (I$: see the fill note above; D$: a trap waits for the committed access, and an access that faults on its own is
# squashed before it reaches the bus, lsu.sv SelfFaultM), and an uncached cbo.zero never reaches the bus (see the LSU
# below).  So CacheAccess = 0 never comes with FinalBeatCount or |BeatCount.  HREADY is low only while the other
# requester owns the bus, and a burst owner keeps it with no wait states (RAM_LATENCY = 0), so HREADY_0 is never
# seen at the final beat.  BeatCntEn's
# (NextState == ADR_PHASE)_0 row needs a pending request with HREADY that goes to neither a cache state (the first
# term) nor ADR_PHASE: that is DATA_PHASE, which the I$ never enters and the D$ enters only without a cache request.
foreach fsm [list $ICBUS/AHBBuscachefsm $DCBUS/AHBBuscachefsm] {
  ExcludeRows $fsm c {CacheAccess_0 {+(CurrState == ATOMIC_READ_DATA_PHASE)*}}
  ExcludeRows $fsm c {CacheAccess_0} [TagLine ${SRC}/ebu/buscachefsm.sv buscachefsm-htrans-burst]
  ExcludeRows $fsm e {CacheAccess_0 HREADY_0 +FinalBeatCount_*}
  ExcludeRows $fsm e {{(NextState == ADR_PHASE)_0} +|CacheBusRW_*}
}
ExcludeRows $ICBUS/AHBBuscachefsm c {CacheAccess_* |BeatCount_1 +Flush_*}
ExcludeRows $DCBUS/AHBBuscachefsm c {CacheAccess_0 +|BeatCount_* +Flush_*}

# I$ fetch buffer: CaptureEn = 0 at a nonzero BeatCountDelayed needs an I$ line fill that pauses or stops after its
# first beat.  It never does: the slaves add no wait states (RAM_LATENCY = 0, rom_ahb ties HREADY to 1), the EBU
# keeps the bus with the IFU for the whole burst, and the fill is never flushed (see the fill note above).
for {set i 1} {$i < 16} {incr i} {
  ExcludeGenRows $ICBUS "fetchbufferbeat\[$i\]" e [list CaptureEn_0 "+($i == BeatCountDelayed)*"]
}

######################################################################################################
# LSU
######################################################################################################

# There is no DTIM (DTIM_SUPPORTED = 0), so SelDTIM is tied to 0 and the uncached-data mux never selects it.
ExcludeTermRows /core/lsu c {SelDTIM_1}
coverage exclude -scope /core/lsu/bus/dcache/UnCachedDataMux -linerange [TagLine ${SRC}/generic/mux.sv mux3] -item b 1

# Every region that accepts a cache block operation (uncore RAM; external memory is not supported) is cacheable,
# and without Svpbmt no page changes that.  The peripheral decoders need AccessRW, which a CMO does not set.  So a
# cbo.zero with CacheableM = 0 takes an access fault and is squashed (SelfFaultM) before it reaches the bus; it is
# never performed (MemAccessDoneM, HoldAccessM) and the bus never sees BusCMOZero.
ExcludeRows /core/lsu e {HoldAccessM_1 +CacheableM_*}

# D$.  The LSU ties the D$ InvalidateCache to 0 (the data cache has no invalidate-all), so the invalidate branches and
# every row that needs InvalidateCache = 1, or InvalidateFlushStage with it, cannot be reached.
ExcludeTermRows $DC/cachefsm c {InvalidateCache_1}
ExcludeTermRows $DC/cachefsm e {InvalidateCache_1}
ExcludeRows $DC/cachefsm c {InvalidateFlushStage_*}
coverage exclude -scope $DC/cachefsm -linerange [TagLine ${SRC}/cache/cachefsm.sv "dcache InvalidateCheck"] -item b 2
coverage exclude -scope $DC/cachefsm -linerange [TagLine ${SRC}/cache/cachefsm.sv "dcache InvalidateCheck"] -item s 1
ExcludeRows $DC/vict/cacheLRU c {InvalidateCache_1 InvalidateFlushStage_*}
for {set i 0} {$i < 4} {incr i} {
  set way "$DC/CacheWays\[$i\]"
  ExcludeRows $way c {InvalidateCache_1 InvalidateFlushStage_*}
  ExcludeRows $way e {InvalidateCacheDelay_1}
  coverage exclude -scope $way -linerange [TagLine ${SRC}/cache/cacheway.sv "dcache invalidateway"] -item bs 1
}

# D$ cachefsm.  (|CMOpM & ~CMOWriteback) is the else-if after ((AnyMiss | CMOWriteback) & ~READ_ONLY_CACHE), which
# takes every CMOWriteback = 1 case first.  In CacheBusRW[0], the term STATE_WRITEBACK & (CMOpM[1] | CMOpM[2]) &
# ~CacheBusAck is contained in the earlier STATE_WRITEBACK & ~CacheBusAck term, so CacheCMOpM[1]/[2] never decide it.
ExcludeRows $DC/cachefsm c {CMOWriteback_1 +|CMOpM_*}
ExcludeRows $DC/cachefsm e {{CacheCMOpM\[1\]_*} {CacheCMOpM\[2\]_*}} [TagLine ${SRC}/cache/cachefsm.sv "icache CacheBusW"]

# D$ states leave for STATE_ACCESS early only on reset | FlushStage (LSUFlushW).  A trap's FlushW waits for the
# committed access (interrupts are held while the cache is committed), an access that faults on its own is
# squashed by SelfFaultM before it reaches the cache, and HPTWFlushW is asserted only before the walker has a bus
# transaction (hptw.sv).  The testbench asserts reset only between programs.
coverage exclude -scope $DC/cachefsm -ftrans CurrState STATE_WRITEBACK->STATE_ACCESS STATE_FETCH->STATE_ACCESS STATE_FLUSH->STATE_ACCESS STATE_WRITE_LINE->STATE_ACCESS STATE_FLUSH_WRITEBACK->STATE_ACCESS

# D$ bus FSM.  An AMO or LR/SC is allowed only in DTIM, external memory or uncore RAM; the first two are not
# supported and uncore RAM is cacheable (no Svpbmt), so an uncached atomic (BusAtomic) takes an access fault and
# never reaches the bus: the atomic states are never entered.
coverage exclude -scope $DCBUS/AHBBuscachefsm -fstate CurrState ATOMIC_READ_DATA_PHASE ATOMIC_PHASE
coverage exclude -scope $DCBUS/AHBBuscachefsm -linerange [TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm AtomicReadData"]-[TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm AtomicWait"]
coverage exclude -scope $DCBUS/AHBBuscachefsm -linerange [TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm HREADY2"] -item b 2
coverage exclude -scope $DCBUS/AHBBuscachefsm -linerange [TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm HREADY2"] -item s 1
ExcludeRows $DCBUS/AHBBuscachefsm c {BusAtomic_1} [TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm HREADY3"]
ExcludeTermRows $DCBUS/AHBBuscachefsm e {{(CurrState == ATOMIC_PHASE)_1} {(CurrState == ATOMIC_READ_DATA_PHASE)_1}}
ExcludeTermRows $DCBUS/AHBBuscachefsm c {{(CurrState == ATOMIC_READ_DATA_PHASE)_1}}

# D$ bus FSM, CACHE_WRITEBACK.  As for fetches, the cache holds one request until CacheBusAck, so it never raises
# CacheBusRW[0] again at the final beat (WritebackWriteback) and raises CacheBusRW[1] only with CacheBusAck (at the
# final beat); a cacheable writeback holds CacheBusRW[0] until CacheBusAck, so ~|CacheBusRW implies the final beat.
# HREADY is never low at the final beat (see above).  BusCMOZero is never 1 on the bus (see the LSU above), so
# CACHE_WRITEBACK never goes to MEM3.
coverage exclude -scope $DCBUS/AHBBuscachefsm -linerange [TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm WritebackWriteback"] -item b 2
coverage exclude -scope $DCBUS/AHBBuscachefsm -linerange [TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm WritebackWriteback"] -item s 1
coverage exclude -scope $DCBUS/AHBBuscachefsm -linerange [TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm HREADY5"] -item bs 1
coverage exclude -scope $DCBUS/AHBBuscachefsm -ftrans CurrState CACHE_WRITEBACK->MEM3
ExcludeRows $DCBUS/AHBBuscachefsm c {HREADY_* FinalBeatCount_1 {CacheBusRW\[0\]_1}} [TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm WritebackWriteback"]
ExcludeRows $DCBUS/AHBBuscachefsm c {HREADY_0 FinalBeatCount_0} [TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm HREADY4"]
ExcludeRows $DCBUS/AHBBuscachefsm c {HREADY_* FinalBeatCount_* BusCMOZero_1} [TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm HREADY5"]
ExcludeRows $DCBUS/AHBBuscachefsm c {HREADY_0 FinalBeatCount_0 ~|CacheBusRW_0} [TagLine ${SRC}/ebu/buscachefsm.sv "buscachefsm HREADY6"]
ExcludeRows $DCBUS/AHBBuscachefsm e {BusCMOZero_1 +CacheAccess_*}

# D$ bus FSM: the D$ bus is never flushed in a data phase (a trap waits for the committed access, and an access that
# faults on its own is squashed before it reaches the bus), so DATA_PHASE -> ADR_PHASE and CaptureEn's Flush_1 row
# cannot be reached.
coverage exclude -scope $DCBUS/AHBBuscachefsm -ftrans CurrState DATA_PHASE->ADR_PHASE
ExcludeRows $DCBUS/AHBBuscachefsm e {Flush_1 {+BusRW\[1\]*}}

# Reset (HRESETn = 0) with BeatCntReset = 0 needs a bus request pending during reset.  The testbench asserts reset
# only between programs, when the LSU has no request, so BeatCntReset (NextState == ADR_PHASE, or IDLE in the
# arbiter) is 1 throughout reset.
ExcludeRows $DCBUS/AHBBuscachefsm e {HRESETn_0} [TagLine ${SRC}/ebu/buscachefsm.sv buscachefsm-beat-count-reset]
ExcludeRows $DCBUS/AHBBuscachefsm e {HRESETn_0} [TagLine ${SRC}/ebu/buscachefsm.sv buscachefsm-beat-count-delayed-reset]
ExcludeRows /core/ebu/ebu/ebufsmarb e {HRESETn_0 +FinalBeat_*}
ExcludeRows /core/ebu/ebu/ebufsmarb e {HRESETn_0} [TagLine ${SRC}/ebu/ebufsmarb.sv arb-finalbeat-reset]

######################################################################################################
# MMU (instruction and data) and page table walker
######################################################################################################

# The IFU ties the instruction MMU's ReadAccessM, WriteAccessM, AtomicAccessM and CMOpM to 0 and ExecuteAccessF to 1
# (ifu.sv), so in the IMMU AccessRWXC, the TLB's ReadAccess and TLBAccess are always 1, and ReadNoAmoAccessM, the
# load/store/CMO faults of the PMA and PMP checkers and the CBO faults are always 0.  The rows for the other values,
# and the rows whose non-masking condition needs one of them, cannot be reached.
ExcludeTermRows $IMMU e {ReadAccessM_1 WriteAccessM_1 ExecuteAccessF_0 ReadNoAmoAccessM_1 |CMOpM_1}
ExcludeRows $IMMU e {ReadAccessM_0 +ExecuteAccessF_*}
ExcludeRows $IMMU e {WriteAccessM_0 +ReadAccessM_*}
ExcludeRows $IMMU e {DataMisalignedM_* +ReadNoAmoAccessM_*}
ExcludeRows $IMMU e {DataMisalignedM_* +WriteAccessM_*}
ExcludeRows $IMMU e {PMALoadAccessFaultM_1 PMPLoadAccessFaultM_1 TLBMiss_*}
ExcludeRows $IMMU e {PMAStoreAmoAccessFaultM_1 PMPStoreAmoAccessFaultM_1 TLBMiss_*}
ExcludeRows $IMMU e {TLBPageFault_* +ReadNoAmoAccessM_*}
ExcludeRows $IMMU e {TLBPageFault_* +WriteAccessM_*}
ExcludeTermRows $IMMU/pmachecker e {ReadAccessM_1 WriteAccessM_1 ExecuteAccessF_0 |CMOpM_1 AccessRWXC_0 AtomicAccessM_1}
ExcludeRows $IMMU/pmachecker e {ReadAccessM_0 WriteAccessM_0 |CMOpM_0}
ExcludeRows $IMMU/pmachecker e {ReadAccessM_0} [TagLine ${SRC}/mmu/pmachecker.sv pma-access-rx]
ExcludeRows $IMMU/pmachecker e {AtomicAllowed_* +AtomicAccessM_*}
ExcludeRows $IMMU/pmachecker e {WriteAccessM_0 PMAAccessFault_* +ReadAccessM_*}
ExcludeRows $IMMU/pmachecker e {PMAAccessFault_* +|CMOpM_*}
ExcludeTermRows $IMMU/pmp/pmpchecker e {ReadAccessM_1 WriteAccessM_1 ExecuteAccessF_0 {|CMOpM\[2:0\]_1} {CMOpM\[3\]_1}
  PMPCBOMAccessFault_1 PMPCBOZAccessFault_1 PMPCMOAccessFault_1}
ExcludeRows $IMMU/pmp/pmpchecker e {MatchingR_* EnforcePMP_* {+|CMOpM\[2:0\]*}}
ExcludeRows $IMMU/pmp/pmpchecker e {MatchingW_* EnforcePMP_* {+CMOpM\[3\]*}}
ExcludeRows $IMMU/pmp/pmpchecker e {MatchingW_* EnforcePMP_* +WriteAccessM_* +PMPCMOAccessFault_*}
ExcludeRows $IMMU/pmp/pmpchecker e {WriteAccessM_0 MatchingR_* EnforcePMP_* +ReadAccessM_*}
ExcludeTermRows $IMMU/tlb/tlb/tlbcontrol e {ReadAccess_0 WriteAccess_1 |CMOpM_1 TLBAccess_0}
ExcludeRows $IMMU/tlb/tlb/tlbcontrol e {WriteAccess_0 |CMOpM_0}

# The IMMU fetches words (Size = 2'b10), so the byte, halfword and doubleword arms of the misalignment case never
# run, and fetch addresses are 2-byte aligned (VAdr[0] = 0).  The IFU also ties the IMMU's DisableTranslation to 0.
foreach size {byte half double} {
  coverage exclude -scope $IMMU -linerange [TagLine ${SRC}/mmu/mmu.sv mmu-size-$size] -item bs 1
}
ExcludeRows $IMMU e {{VAdr\[0\]_1}}
ExcludeRows $IMMU/tlb/tlb/tlbcontrol e {DisableTranslation_1}

# The LSU ties the data MMU's ExecuteAccessF to 0, so its instruction fault terms are always 0.
ExcludeTermRows $DMMU e {ExecuteAccessF_1 PMAInstrAccessFaultF_1 PMPInstrAccessFaultF_1}
ExcludeRows $DMMU e {TLBMiss_* +PMAInstrAccessFaultF_*}
ExcludeRows $DMMU e {TLBPageFault_* +ExecuteAccessF_*}
ExcludeTermRows $DMMU/pmachecker e {ExecuteAccessF_1}
ExcludeRows $DMMU/pmachecker e {PMAAccessFault_* +ExecuteAccessF_*}
ExcludeRows $DMMU/pmp/pmpchecker e {MatchingX_* EnforcePMP_* ExecuteAccessF_1}

# PMA regions 1-3 (DTIM, IROM, external memory) are not supported (DTIM/IROM/EXT_MEM_SUPPORTED = 0), so
# SelRegions[1], [2] and [3] are always 0 in both MMUs.
foreach mmu [list $IMMU $DMMU] {
  ExcludeTermRows $mmu/pmachecker e {{SelRegions\[1\]_1} {SelRegions\[2\]_1} {SelRegions\[3\]_1}}
}

# Region decoders: Sel = Match & Supported & AccessValid & SizeValid.  Supported is a configuration constant: 0 for
# the DTIM, IROM, external memory and SD card controller, 1 for the rest.  Instruction side: AccessValid is AccessRW
# (always 0 for a fetch) for the DTIM, SDC and peripherals, and AccessRX/AccessRWXC (always 1) for the IROM, boot
# ROM, uncore RAM and external memory; a fetch is a word, which every region but the UART (byte only) accepts.  Data
# side: the boot ROM, CLINT and RAM accept every access size.  The rows below need the other value of one of these.
foreach dec {dtimdec sdcdec uartdec} {
  ExcludeRows $IMMU/pmachecker/adrdecs/$dec e {Match_* Supported_* AccessValid_* SizeValid_*}
}
foreach dec {iromdec ddr4dec} {
  ExcludeRows $IMMU/pmachecker/adrdecs/$dec e {Match_* Supported_1 AccessValid_* SizeValid_*}
}
foreach dec {clintdec gpiodec plicdec spidec pwmdec} {
  ExcludeRows $IMMU/pmachecker/adrdecs/$dec e {Match_* Supported_* AccessValid_1 SizeValid_*}
}
foreach dec {bootromdec uncoreramdec} {
  ExcludeRows $IMMU/pmachecker/adrdecs/$dec e {Supported_0 AccessValid_0 SizeValid_0}
}
foreach dec {dtimdec iromdec ddr4dec sdcdec} {
  ExcludeRows $DMMU/pmachecker/adrdecs/$dec e {Match_* Supported_1 AccessValid_* SizeValid_*}
}
foreach dec {bootromdec uncoreramdec} {
  ExcludeRows $DMMU/pmachecker/adrdecs/$dec e {Supported_0 SizeValid_0}
}
foreach dec {clintdec gpiodec uartdec plicdec spidec pwmdec} {
  ExcludeRows $DMMU/pmachecker/adrdecs/$dec e {Supported_0}
}

# PMP entry 0 has no entry below it, so its TOR lower bound PAgePMPAdrIn is tied to 1.
foreach mmu [list $IMMU $DMMU] {
  ExcludeRows "$mmu/pmp/pmpchecker/pmp/pmpadrdecs\[0\]" e {PAgePMPAdrIn_0}
}

# Sv32 page table entries have no PBMT field: tlbram builds PTEAccessBits[11:8] as PTE[XLEN-1:XLEN-4] &
# {4{XLEN == 64}}, so PTE_PBMT is always 0.
foreach mmu [list $IMMU $DMMU] {
  ExcludeRows $mmu/tlb/tlb/tlbcontrol e {{(PTE_PBMT != 0)_1} {(PTE_PBMT == 3)_1}}
}

# TLB camlines.  Sv32 has two levels, so the walker writes PageType 0 (kilopage) or 1 (megapage) and PageType > 1
# never holds.  tlb.sv ties WritePTE_NAPOT to P.SVNAPOT_SUPPORTED & ..., which is 0, and the Match0Upper rows need it.
foreach mmu [list $IMMU $DMMU] {
  for {set i 0} {$i < 32} {incr i} {
    set cam "$mmu/tlb/tlb/tlbcam/camlines\[$i\]"
    ExcludeRows $cam e {{(PageType > 1)_1}}
    ExcludeRows $cam e {WritePTE_NAPOT_1 Match0Upper_* {(PageTypeWriteVal > 1)_1}}
  }
}

# The not-recently-used replacement clears the other RU bits whenever all would be 1, so the last stage of its
# priority encoder never sees ~RUBits[31] = 0 with every lower bit 1.
foreach mmu [list $IMMU $DMMU] {
  ExcludeGenRows $mmu/tlb/tlb/lru/nru {poh[31]} e {{~RUBits\[31\]_0}}
}

# Page table walker.  Sv32 walks start at L1_ADR (InitialWalkerState = L1_ADR when XLEN = 32) and only move down,
# so the L4/L3/L2 states never occur and (InitialWalkerState == L1_ADR) is always 1, which leaves L1_ADR -> LEAF
# unused.  L1_ADR is entered from IDLE or a chained LEAF, both of which clear the PTE register (PRegEn with
# NextPTE2 = 0), and an *_ADR state makes no memory access, so HPTWFaultM (a non-leaf PTE fault or an LSU access
# fault) is 0 there.
coverage exclude -scope $HPTW -linerange [TagLine ${SRC}/mmu/hptw.sv hptw-pagetype-l4]-[TagLine ${SRC}/mmu/hptw.sv hptw-pagetype-l2]
coverage exclude -scope $HPTW -linerange [TagLine ${SRC}/mmu/hptw.sv hptw-l4-adr]-[TagLine ${SRC}/mmu/hptw.sv hptw-l2-rd-next]
coverage exclude -scope $HPTW -linerange [TagLine ${SRC}/mmu/hptw.sv hptw-l1-adr-fault] -item b 2
coverage exclude -scope $HPTW -linerange [TagLine ${SRC}/mmu/hptw.sv hptw-l1-adr-fault] -item s 1
coverage exclude -scope $HPTW -linerange [TagLine ${SRC}/mmu/hptw.sv hptw-l1-adr-leaf] -item bs 1
ExcludeRows $HPTW c {{(InitialWalkerState == L1_ADR)_0} ValidNonLeafPTE_*}
ExcludeRows $HPTW e {{(NextWalkerState == L2_RD)_1} {(NextWalkerState == L3_RD)_1} {(NextWalkerState == L4_RD)_1}}

# UPDATE_PTE writes the PTE that the same walk just read, with the LSU stalled so the line cannot be evicted: the
# store hits in the D$, DCacheBusStallM is 0, and UPDATE_PTE never waits on itself.
coverage exclude -scope $HPTW -linerange [TagLine ${SRC}/mmu/hptw.sv hptw-update-pte-wait] -item bs 1
