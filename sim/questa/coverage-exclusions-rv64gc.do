#///////////////////////////////////////////
#// coverage-exclusions-rv64gc.do
#//
#// Written: David_Harris@hmc.edu 19 March 2023
#//
#// Purpose: Set of exclusions from coverage for rv64gc configuration
#//          For example, signals hardwired to 0 should not be checked for toggle coverage
#//
#// A component of the CORE-V-WALLY configurable RISC-V project.
#// https://github.com/openhwfoundation/cvw
#//
#// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
#//
#// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#//
#// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
#// except in compliance with the License, or, at your option, the Apache License version 2.0. You
#// may obtain a copy of the License at
#//
#// https://solderpad.org/licenses/SHL-2.1/
#//
#// Unless required by applicable law or agreed to in writing, any work distributed under the
#// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
#// either express or implied. See the License for the specific language governing permissions
#// and limitations under the License.
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

set WALLY $::env(WALLY)
set SRC ${WALLY}/src

# a hack to describe coverage exclusions without hardcoding linenumbers:
do ${WALLY}/sim/questa/GetLineNum.do

# (lzc used to be excluded wholesale because its (i<64) loop confused the coverage tool; every lzc bin is now
# reported and hit, so all of its instances, including the Zbb clz/ctz counter, are counted.)

#################
# FPU Exclusions
#################
# DH 4/22/23: FDIVSQRT can't go directly from done to busy again
coverage exclude -scope /core/fpu/fpu/fdivsqrt/fdivsqrtfsm -ftrans state DONE->BUSY
# DH 4/22/23: The busy->idle transition only occurs if a FlushE occurs while the divider is busy.  The flush is caused by a trap or return,
# which won't happen while the divider is busy.
coverage exclude -scope /core/fpu/fpu/fdivsqrt/fdivsqrtfsm -ftrans state BUSY->IDLE
# All Memory-stage stalls have resolved by time fdivsqrt finishes regular operation in this configuration, so can't test StallM
coverage exclude -scope /core/fpu/fpu/fdivsqrt/fdivsqrtfsm -linerange [GetLineNum ${SRC}/fpu/fdivsqrt/fdivsqrtfsm.sv "exclusion-tag: fdivsqrtfsm stallm"] -item b 1
coverage exclude -scope /core/fpu/fpu/fdivsqrt/fdivsqrtfsm -linerange [GetLineNum ${SRC}/fpu/fdivsqrt/fdivsqrtfsm.sv "exclusion-tag: fdivsqrtfsm stallm"] -item s 1
# Division by zero never sets sticky/guard/overflow/round to cause inexact or underflow result, but check out of paranoia
# (FpInexact row 14 and Underflow row 22 are the DivByZero_1 rows)
coverage exclude -scope /core/fpu/fpu/postprocess/flags -fecexprrow [GetLineNum ${SRC}/fpu/postproc/flags.sv "assign FpInexact"] 14
coverage exclude -scope /core/fpu/fpu/postprocess/flags -fecexprrow [GetLineNum ${SRC}/fpu/postproc/flags.sv "assign Underflow"] 22
# Underflow row 5 needs FullRe other than 0 or 1 while Me == 0, but a subnormal (Me = 0) rounds to FullRe = 0 or 1
coverage exclude -scope /core/fpu/fpu/postprocess/flags -fecexprrow [GetLineNum ${SRC}/fpu/postproc/flags.sv "assign Underflow"] 5
# Convert int to fp will never underflow
coverage exclude -scope /core/fpu/fpu/postprocess/cvtshiftcalc -fecexprrow [GetLineNum ${SRC}/fpu/postproc/cvtshiftcalc.sv "assign CvtResUf"] 4
# without Q support, an instruction with FMT = 11 is rejected as an unsupported format before the case statement,
# so the FMT field here is 00, 01, or 10.  Rows 1, 3 and 5 each need all three compares false (FMT = 11).
coverage exclude -scope /core/fpu/fpu/fctrl -feccondrow [GetLineNum ${SRC}/fpu/fctrl.sv "fmv int to fp"] 1 3 5
# fmvp.q.x (funct7 1011011) has FMT = 11, so without Q support it is rejected as an unsupported format
# before the case statement and its case arm cannot be selected.
coverage exclude -scope /core/fpu/fpu/fctrl -linerange [GetLineNum ${SRC}/fpu/fctrl.sv "7'b1011011: if"] -item b 1
coverage exclude -scope /core/fpu/fpu/fctrl -feccondrow [GetLineNum ${SRC}/fpu/fctrl.sv "fmv fp to int"] 1 3 5
# The same FMT = 11 case is the implicit else of both ifs, so their all-false branches cannot be taken either.
coverage exclude -scope /core/fpu/fpu/fctrl -linerange [GetLineNum ${SRC}/fpu/fctrl.sv "fmv int to fp"] -code b -allfalse
coverage exclude -scope /core/fpu/fpu/fctrl -linerange [GetLineNum ${SRC}/fpu/fctrl.sv "fmv fp to int"] -code b -allfalse
# j0 can only be 1 in iteration 0, j1 can only be 1 in iteration 1
coverage exclude -scope /core/fpu/fpu/fdivsqrt/fdivsqrtiter/iterations[0]/stage/fdivsqrtstage/uslc4 -fecexprrow [GetLineNum ${SRC}/fpu/fdivsqrt/fdivsqrtuslc4cmp.sv "assign sqrtspecial"] 4 6
coverage exclude -scope /core/fpu/fpu/fdivsqrt/fdivsqrtiter/iterations[1]/stage/fdivsqrtstage/uslc4 -fecexprrow [GetLineNum ${SRC}/fpu/fdivsqrt/fdivsqrtuslc4cmp.sv "assign sqrtspecial"] 6
coverage exclude -scope /core/fpu/fpu/fdivsqrt/fdivsqrtiter/iterations[2]/stage/fdivsqrtstage/uslc4 -fecexprrow [GetLineNum ${SRC}/fpu/fdivsqrt/fdivsqrtuslc4cmp.sv "assign sqrtspecial"] 1 2 4 6
coverage exclude -scope /core/fpu/fpu/fdivsqrt/fdivsqrtiter/iterations[3]/stage/fdivsqrtstage/uslc4 -fecexprrow [GetLineNum ${SRC}/fpu/fdivsqrt/fdivsqrtuslc4cmp.sv "assign sqrtspecial"] 1 2 4 6
# outside of iterations 1 and 0, (j0 | j1) is always 0 so sqrtspecial is always 0
# need to exclude scenarios where sqrtspecial is 1 for the ternary operators that assign mk2, mk1, mk0, and mkm1
coverage exclude -scope /core/fpu/fpu/fdivsqrt/fdivsqrtiter/iterations[2]/stage/fdivsqrtstage/uslc4 -linerange [GetLineNum ${SRC}/fpu/fdivsqrt/fdivsqrtuslc4cmp.sv "assign mk2"]  -item b 1
coverage exclude -scope /core/fpu/fpu/fdivsqrt/fdivsqrtiter/iterations[2]/stage/fdivsqrtstage/uslc4 -linerange [GetLineNum ${SRC}/fpu/fdivsqrt/fdivsqrtuslc4cmp.sv "assign mk1"]  -item b 1
coverage exclude -scope /core/fpu/fpu/fdivsqrt/fdivsqrtiter/iterations[2]/stage/fdivsqrtstage/uslc4 -linerange [GetLineNum ${SRC}/fpu/fdivsqrt/fdivsqrtuslc4cmp.sv "assign mk0"]  -item b 1
coverage exclude -scope /core/fpu/fpu/fdivsqrt/fdivsqrtiter/iterations[2]/stage/fdivsqrtstage/uslc4 -linerange [GetLineNum ${SRC}/fpu/fdivsqrt/fdivsqrtuslc4cmp.sv "assign mkm1"] -item b 1
coverage exclude -scope /core/fpu/fpu/fdivsqrt/fdivsqrtiter/iterations[3]/stage/fdivsqrtstage/uslc4 -linerange [GetLineNum ${SRC}/fpu/fdivsqrt/fdivsqrtuslc4cmp.sv "assign mk2"]  -item b 1
coverage exclude -scope /core/fpu/fpu/fdivsqrt/fdivsqrtiter/iterations[3]/stage/fdivsqrtstage/uslc4 -linerange [GetLineNum ${SRC}/fpu/fdivsqrt/fdivsqrtuslc4cmp.sv "assign mk1"]  -item b 1
coverage exclude -scope /core/fpu/fpu/fdivsqrt/fdivsqrtiter/iterations[3]/stage/fdivsqrtstage/uslc4 -linerange [GetLineNum ${SRC}/fpu/fdivsqrt/fdivsqrtuslc4cmp.sv "assign mk0"]  -item b 1
coverage exclude -scope /core/fpu/fpu/fdivsqrt/fdivsqrtiter/iterations[3]/stage/fdivsqrtstage/uslc4 -linerange [GetLineNum ${SRC}/fpu/fdivsqrt/fdivsqrtuslc4cmp.sv "assign mkm1"] -item b 1
# outside of iteration 0, j0 is always 0 so the ternary operator that assigns mkj1 cannot be fully covered
coverage exclude -scope /core/fpu/fpu/fdivsqrt/fdivsqrtiter/iterations[3]/stage/fdivsqrtstage/uslc4 -linerange [GetLineNum ${SRC}/fpu/fdivsqrt/fdivsqrtuslc4cmp.sv "assign mkj1"] -item b 1
coverage exclude -scope /core/fpu/fpu/fdivsqrt/fdivsqrtiter/iterations[2]/stage/fdivsqrtstage/uslc4 -linerange [GetLineNum ${SRC}/fpu/fdivsqrt/fdivsqrtuslc4cmp.sv "assign mkj1"] -item b 1
coverage exclude -scope /core/fpu/fpu/fdivsqrt/fdivsqrtiter/iterations[1]/stage/fdivsqrtstage/uslc4 -linerange [GetLineNum ${SRC}/fpu/fdivsqrt/fdivsqrtuslc4cmp.sv "assign mkj1"] -item b 1

##################
# Cache Exclusions
##################

### Exclude D$ states and logic for the I$ instance
# This is cleaner than trying to set an I$-specific pragma in cachefsm.sv (which would exclude it for the D$ instance too)
# Also exclude the write line to ready transition for the I$ since we can't get a flush during this operation.
coverage exclude -scope /core/ifu/bus/icache/icache/cachefsm -fstate CurrState STATE_FLUSH STATE_FLUSH_WRITEBACK STATE_FLUSH_WRITEBACK STATE_WRITEBACK
coverage exclude -scope /core/ifu/bus/icache/icache/cachefsm -ftrans CurrState STATE_WRITE_LINE->STATE_ACCESS STATE_FETCH->STATE_ACCESS
# I$ does not flush
coverage exclude -scope /core/ifu/bus/icache/icache/cachefsm -fecexprrow [GetLineNum ${SRC}/cache/cachefsm.sv "exclusion-tag: icache FlushCache"] 2
# the I$ never flushes, so the LRU address mux never selects FlushAdr (branch 1, s[1])
coverage exclude -scope /core/ifu/bus/icache/icache/AdrSelMuxLRU -linerange [GetLineNum ${SRC}/generic/mux.sv "exclusion-tag: mux3"] -item b 1
coverage exclude -scope /core/ifu/bus/icache/icache/cachefsm -linerange [GetLineNum ${SRC}/cache/cachefsm.sv "exclusion-tag: icache FLUSHStatement"] -item bs 1
# exclude the unreachable logic
set start [GetLineNum ${SRC}/cache/cachefsm.sv "exclusion-tag-start: icache case"]
set end [GetLineNum ${SRC}/cache/cachefsm.sv "exclusion-tag-end: icache case"]
coverage exclude -scope /core/ifu/bus/icache/icache/cachefsm -linerange $start-$end
coverage exclude -scope /core/ifu/bus/icache/icache/cachefsm -linerange [GetLineNum ${SRC}/cache/cachefsm.sv "exclusion-tag: icache WRITEBACKStatement"]
# exclude Atomic Operation logic
coverage exclude -scope /core/ifu/bus/icache/icache/cachefsm -fecexprrow [GetLineNum ${SRC}/cache/cachefsm.sv "exclusion-tag: cache AnyMiss"] 6
coverage exclude -scope /core/ifu/bus/icache/icache/cachefsm -fecexprrow [GetLineNum ${SRC}/cache/cachefsm.sv "exclusion-tag: icache storeAMO1"] 2-4
coverage exclude -scope /core/ifu/bus/icache/icache/cachefsm -fecexprrow [GetLineNum ${SRC}/cache/cachefsm.sv "exclusion-tag: icache AnyUpdateHit"] 2
# output signal logic
coverage exclude -scope /core/ifu/bus/icache/icache/cachefsm -fecexprrow [GetLineNum ${SRC}/cache/cachefsm.sv "exclusion-tag: icache StallStates"] 8 12 14
# Dirty, flush and writeback controls.  The read-only I$ never writes (CacheRW[0] = 0), has no CMOs, never has a
# dirty line and never enters STATE_WRITEBACK, STATE_FLUSH or STATE_FLUSH_WRITEBACK.  The rows listed are the ones
# that need one of those; the other rows of each expression are hit.
coverage exclude -scope /core/ifu/bus/icache/icache/cachefsm -fecexprrow [GetLineNum ${SRC}/cache/cachefsm.sv "assign SetDirty ="] 1 2 4 5 6 8
coverage exclude -scope /core/ifu/bus/icache/icache/cachefsm -fecexprrow [GetLineNum ${SRC}/cache/cachefsm.sv "assign ClearDirty ="] 4-8
coverage exclude -scope /core/ifu/bus/icache/icache/cachefsm -fecexprrow [GetLineNum ${SRC}/cache/cachefsm.sv "assign SelVictim ="] 2-8 10
coverage exclude -scope /core/ifu/bus/icache/icache/cachefsm -fecexprrow [GetLineNum ${SRC}/cache/cachefsm.sv "assign SelWriteback ="] 2-8 10
coverage exclude -scope /core/ifu/bus/icache/icache/cachefsm -fecexprrow [GetLineNum ${SRC}/cache/cachefsm.sv "assign FlushWayCntEn ="] 2 3 4 6 7 8
coverage exclude -scope /core/ifu/bus/icache/icache/cachefsm -fecexprrow [GetLineNum ${SRC}/cache/cachefsm.sv "exclusion-tag: icache CacheBusW"] 1-4 6 8 9 10 12
# SelAdrData/SelAdrTag: CacheRW[0] and STATE_WRITEBACK rows as above, and resetDelay_1 (needs every other term 0 in
# the cycle after reset): the I$ is then always missing on the cold-cache fetch of the reset vector, so AnyMiss masks it.
coverage exclude -scope /core/ifu/bus/icache/icache/cachefsm -fecexprrow [GetLineNum ${SRC}/cache/cachefsm.sv "exclusion-tag: icache SelAdrCauses"] 4 10 14
coverage exclude -scope /core/ifu/bus/icache/icache/cachefsm -fecexprrow [GetLineNum ${SRC}/cache/cachefsm.sv "exclusion-tag: icache SelAdrTag"] 8 12
# CacheBusRW[1] (bimodal): LineDirty_1 and STATE_WRITEBACK_1.  Excluding one row of a bimodal pair leaves the
# other row independent, so LineDirty_0 and STATE_WRITEBACK_0 still count.
coverage exclude -scope /core/ifu/bus/icache/icache/cachefsm -fecexprrow [GetLineNum ${SRC}/cache/cachefsm.sv "exclusion-tag: icache CacheBusRCauses"] 2 12
# I$ CacheEn L211 reset_1 (FEC row 8): reset=1 while CurrState==STATE_ACCESS, Stall=1, StallConditions=0.
# Reset is asserted only by the testbench, before each program runs, and the I$ is not stalled during
# that reset, so no RISC-V program can drive this term.  (The D$ instance of this same row IS covered
# because the D$ is stalled out of reset; the I$ Stall is 0 at reset.)
coverage exclude -scope /core/ifu/bus/icache/icache/cachefsm -fecexprrow [GetLineNum ${SRC}/cache/cachefsm.sv "exclusion-tag: dcache CacheEn"] 8

# cache.sv AdrSelMuxData and AdrSelMuxTag and CacheBusAdrMux, excluding unhit Flush branch
coverage exclude -scope /core/ifu/bus/icache/icache/AdrSelMuxData -linerange [GetLineNum ${SRC}/generic/mux.sv "exclusion-tag: mux3"] -item b 1
coverage exclude -scope /core/ifu/bus/icache/icache/AdrSelMuxTag -linerange [GetLineNum ${SRC}/generic/mux.sv "exclusion-tag: mux3"] -item b 1
coverage exclude -scope /core/ifu/bus/icache/icache/CacheBusAdrMux -linerange [GetLineNum ${SRC}/generic/mux.sv "exclusion-tag: mux3"] -item b 1 3
# CacheWay Dirty logic. -scope does not accept wildcards.
set numcacheways 4
for {set i 0} {$i < $numcacheways} {incr i} {
    # rows 2-4 need SetDirty = 1 (row 1, SetDirty_0, is hit)
    coverage exclude -scope /core/ifu/bus/icache/icache/CacheWays[$i] -fecexprrow [GetLineNum ${SRC}/cache/cacheway.sv "exclusion-tag: icache SetDirtyWay"] 2-4
    coverage exclude -scope /core/ifu/bus/icache/icache/CacheWays[$i] -fecexprrow [GetLineNum ${SRC}/cache/cacheway.sv "exclusion-tag: icache SelectedWiteWordEn"] 4 6
    # below: flushD can't go high during an icache write b/c of pipeline stall
    coverage exclude -scope /core/ifu/bus/icache/icache/CacheWays[$i] -fecexprrow [GetLineNum ${SRC}/cache/cacheway.sv "exclusion-tag: cache SetValidEN"] 4
    # and the I$ never clears valid bits (no CMOs): ClearValidWay_1 and both FlushStage rows need ClearValidWay = 1
    coverage exclude -scope /core/ifu/bus/icache/icache/CacheWays[$i] -fecexprrow [GetLineNum ${SRC}/cache/cacheway.sv "exclusion-tag: cache ClearValidEN"] 2-4
    # No CMO to clear valid bits of I$
    coverage exclude -scope /core/ifu/bus/icache/icache/CacheWays[$i] -linerange [GetLineNum ${SRC}/cache/cacheway.sv "// exclusion-tag: icache ClearValidBits"]
    coverage exclude -scope /core/ifu/bus/icache/icache/CacheWays[$i] -fecexprrow [GetLineNum ${SRC}/cache/cacheway.sv "// exclusion-tag: icache ClearValidWay"] 2-4
    # No dirty ways in read-only I$
    # (HitDirtyWay_0, row 3, is hit)
    coverage exclude -scope /core/ifu/bus/icache/icache/CacheWays[$i] -fecexprrow [GetLineNum ${SRC}/cache/cacheway.sv "// exclusion-tag: icache DirtyWay"] 1 2 4
}
# I$ buscachefsm does not perform atomics or write/writeback.  The bare -linerange lines below are whole dead
# FSM arms (their branches, conditions, statements and the state they enter) for the read-only cache.
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -linerange [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm AtomicReadData"]
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -linerange [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm AtomicElse"] -item s 1
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -linerange [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm AtomicPhase"]
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -linerange [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm AtomicWait"] -item bs 1
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -linerange [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm FetchWriteback"] -item b 2
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -linerange [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm FetchWriteback"] -item s 1
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -linerange [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm WritebackWriteback"]
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -linerange [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm WritebackWriteback2"] -item bs 1
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -linerange [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm HREADY4"] -item bs 1
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -linerange [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm HREADY6"] -item bs 1
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -feccondrow [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm FetchWriteback"] 1 2 3 4 6
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -linerange [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm HREADY4"] -item c 1
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -linerange [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm HREADY6"] -item c 1
# HTRANS: ATOMIC_READ_DATA_PHASE_1 (row 12) is a dead state for the I$, and CacheAccess_0 (row 13) needs
# FinalBeatCount outside a cache burst, which needs a BeatCount left stale by a flush in mid burst; the I$ is never
# flushed in mid burst (see HBURST below).  (Row 5, HREADY_0, used to be excluded as "HREADY is always 1", but the
# I$ does see HREADY = 0 in ADR_PHASE, at the HREADYread branch, so it is counted.)
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -feccondrow [GetLineNum ${SRC}/ebu/buscachefsm.sv "assign HTRANS"] 12 13
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -fecexprrow [GetLineNum ${SRC}/ebu/buscachefsm.sv "assign BeatCntEn"] 4
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -fecexprrow [GetLineNum ${SRC}/ebu/buscachefsm.sv "assign CacheAccess"] 4
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -fecexprrow [GetLineNum ${SRC}/ebu/buscachefsm.sv "assign BusStall"] 10 12 18
# CacheBusAck: HREADY_0 (row 3) at the final beat of a burst (the slave never stalls and the burst owner keeps the
# bus), and CacheAccess_0 (row 1) needs FinalBeatCount outside a burst, as for HTRANS row 13.
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -fecexprrow [GetLineNum ${SRC}/ebu/buscachefsm.sv "assign CacheBusAck"] 1 3

# I$ AHBBuscachefsm dead FSM states/transitions: the read-only cache never enters the writeback/atomic
# states, and DATA_PHASE->ADR_PHASE needs a flush during an uncached fetch's data phase (see CaptureEn below).
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -fstate CurrState CACHE_WRITEBACK ATOMIC_READ_DATA_PHASE ATOMIC_PHASE
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -ftrans CurrState ADR_PHASE->CACHE_WRITEBACK CACHE_FETCH->CACHE_WRITEBACK CACHE_WRITEBACK->ADR_PHASE CACHE_WRITEBACK->CACHE_FETCH DATA_PHASE->ADR_PHASE ATOMIC_READ_DATA_PHASE->ATOMIC_PHASE ATOMIC_READ_DATA_PHASE->ADR_PHASE ATOMIC_PHASE->MEM3 ATOMIC_PHASE->ADR_PHASE

# I$ AHBBuscachefsm HREADY1: ADR_PHASE->CACHE_WRITEBACK on BusWrite -- read-only cache never writes back.
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -linerange [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm HREADY1"] -item bs 1

# I$ AHBBuscachefsm FetchWait: CACHE_FETCH->CACHE_FETCH back-to-back read -- the I$ never pipelines a second line fetch.
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -linerange [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm FetchWait"] -item bs 1
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -feccondrow [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm FetchWait"] 1 2 4 6

# I$ AHBBuscachefsm AtomicElse: the ATOMIC_READ_DATA_PHASE->itself else; the state is dead (no atomics in a read-only cache).
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -linerange [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm AtomicElse"] -item b 1

# I$ AHBBuscachefsm SelBusBeat: the BusRW[0]/BusWrite/DATA_PHASE/ATOMIC_*/CACHE_WRITEBACK select terms are
# write/atomic/writeback paths a read-only cache never drives (only the CACHE_FETCH term is live).
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -fecexprrow [GetLineNum ${SRC}/ebu/buscachefsm.sv "assign SelBusBeat"] 1 2 4 6 7 8 9 10 11 12 14

# I$ AHBBuscachefsm CACHE_FETCH fetch-done (HREADY & FinalBeatCount & ~|CacheBusRW -> ADR_PHASE) _0 rows
# (HREADY_0 row 1, FinalBeatCount_0 row 3, ~|CacheBusRW_0 row 5) are dead: the cache holds CacheBusRW until
# CacheBusAck = HREADY & FinalBeatCount, so ~|CacheBusRW implies both, and a request still pending at the final
# beat is taken by the higher-priority FetchWriteback/FetchWait branches.
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -feccondrow [GetLineNum ${SRC}/ebu/buscachefsm.sv "FinalBeatCount & ~\|CacheBusRW\\)  NextState = ADR_PHASE"] 1 3 5

# I$ AHBBuscachefsm HTRANS (CacheAccess & |BeatCount) CacheAccess_0: dead -- BeatCount is reset outside cache states.
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -feccondrow [GetLineNum ${SRC}/ebu/buscachefsm.sv "CacheAccess & \\|BeatCount\\) ?"] 1

# I$ AHBBuscachefsm HBURST (|CacheBusRW & ~Flush) | (CacheAccess & |BeatCount): the second-term rows
# CacheAccess_0 (5), CacheAccess_1 (6), |BeatCount_1 (8) are unreachable -- they need a flush landing mid
# CACHE_FETCH burst, but in this in-order pipe the I$ never takes a mid-burst flush (the pipe is stalled).
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -feccondrow [GetLineNum ${SRC}/ebu/buscachefsm.sv "assign HBURST"] 5 6 8

# I$ AHBBuscachefsm CaptureEn ((~Flush & DATA_PHASE) & BusRW[1]) Flush_1: unreachable -- CVW (in-order) never
# flushes an in-flight uncached fetch bus transaction.  BusRW[1]_0 (row 5) is an uncached write in DATA_PHASE,
# which the I$ never makes.
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -fecexprrow [GetLineNum ${SRC}/ebu/buscachefsm.sv "assign CaptureEn"] 2 5

# I$ AHBBuscachefsm ADR_PHASE (HREADY & |BusRW) HREADY_0: unreachable in this in-order pipe -- an uncached
# fetch's bus request is a single ADR cycle; whenever the LSU holds the bus the front-end is stalled and not
# initiating a new fetch, so that 1-cycle uncached request never coincides with an LSU grant.
coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm -feccondrow [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm HREADY0"] 1

# (bpred BPWrongE InstrValidD_0, row 5, used to be excluded as a single-issue invariant; the regression with
# the tests of #1900 and #1909 hits it, so it is counted.)

## D$ Exclusions.
# InvalidateCache is I$ only:
coverage exclude -scope /core/lsu/bus/dcache/dcache/cachefsm -linerange [GetLineNum ${SRC}/cache/cachefsm.sv "exclusion-tag: dcache InvalidateCheck"] -item b 2
coverage exclude -scope /core/lsu/bus/dcache/dcache/cachefsm -linerange [GetLineNum ${SRC}/cache/cachefsm.sv "exclusion-tag: dcache InvalidateCheck"] -item s 1
# (CacheEn row 10 is InvalidateCache_1; the D$ InvalidateCache is tied 1'b0 in lsu.sv)
coverage exclude -scope /core/lsu/bus/dcache/dcache/cachefsm -fecexprrow [GetLineNum ${SRC}/cache/cachefsm.sv "exclusion-tag: dcache CacheEn"] 10
coverage exclude -scope /core/lsu/bus/dcache/dcache/cachefsm -fecexprrow [GetLineNum ${SRC}/cache/cachefsm.sv "exclusion-tag: cache AnyMiss"] 4

# D$ cachefsm L123 (|CMOpM & ~CMOWriteback) condition, CMOWriteback_1 (feccondrow 4): priority-masked.
# The higher-priority L122 else-if ((AnyMiss | CMOWriteback) & ~READ_ONLY_CACHE) fires first whenever
# CMOWriteback=1 (D$ READ_ONLY_CACHE=0), so L123 is only ever evaluated with CMOWriteback=0 and
# CMOWriteback_1 is unreachable.
coverage exclude -scope /core/lsu/bus/dcache/dcache/cachefsm -feccondrow [GetLineNum ${SRC}/cache/cachefsm.sv "any CMO without dirty writeback"] 4

# D$ cachefsm L193 LoadMiss = (Hit ~| InvalidateCache) & CacheRWM[1], InvalidateCache_1 (FEC row 4):
# D$ InvalidateCache is tied 1'b0 in lsu.sv, so InvalidateCache can never be 1.  (The "cache AnyMiss"
# exclusion above resolves via GetLineNum to L95/AnyMiss; this anchor catches the L193 LoadMiss copy.)
coverage exclude -scope /core/lsu/bus/dcache/dcache/cachefsm -fecexprrow [GetLineNum ${SRC}/cache/cachefsm.sv "assign LoadMiss"] 4

# D$ cachefsm L195 CacheBusRW[0] CacheCMOpM[1]/[2] terms (FEC rows 13-16): the writeback-CMO term
# (STATE_WRITEBACK & (CMOpM[1]|CMOpM[2]) & ~CacheBusAck) is logically subsumed by the earlier OR term
# (STATE_WRITEBACK & ~CacheBusAck), so CacheCMOpM[1]/[2] never independently drive CacheBusRW[0].
coverage exclude -scope /core/lsu/bus/dcache/dcache/cachefsm -fecexprrow [GetLineNum ${SRC}/cache/cachefsm.sv "icache CacheBusW"] 13 14 15 16

# D$ InvalidateCache is tied to 1'b0 in lsu.sv (the data cache has no invalidate-all), so the
# InvalidateCache & ~InvalidateFlushStage invalidate paths can never be exercised in the D$: the rows that need
# InvalidateCache = 1 (InvalidateCache_1 and both InvalidateFlushStage rows) cannot be hit.
coverage exclude -scope /core/lsu/bus/dcache/dcache/cachefsm -feccondrow [GetLineNum ${SRC}/cache/cachefsm.sv "exclusion-tag: dcache InvalidateCheck"] 2-4
coverage exclude -scope /core/lsu/bus/dcache/dcache/vict/cacheLRU -feccondrow [GetLineNum ${SRC}/cache/cacheLRU.sv "InvalidateCache & ~InvalidateFlushStage"] 4-6
set numcacheways 4
for {set i 0} {$i < $numcacheways} {incr i} {
    # D$ InvalidateCache tied 1'b0 (lsu.sv): the invalidate branch and its statement can never run, and the
    # condition rows that need InvalidateCache = 1 (InvalidateCache_1 and both InvalidateFlushStage rows) cannot be hit.
    set line [GetLineNum ${SRC}/cache/cacheway.sv "exclusion-tag: dcache invalidateway"]
    coverage exclude -scope /core/lsu/bus/dcache/dcache/CacheWays[$i] -linerange $line -item bs 1
    coverage exclude -scope /core/lsu/bus/dcache/dcache/CacheWays[$i] -feccondrow $line 2-4
    # InvalidateCacheDelay is always 0 for D$ because it is flushed, not invalidated
    coverage exclude -scope /core/lsu/bus/dcache/dcache/CacheWays[$i] -fecexprrow [GetLineNum ${SRC}/cache/cacheway.sv "exclusion-tag: dcache HitWay"] 2
    # (SetValidEN and ClearValidEN FlushStage_1, row 4, used to be excluded here on the argument that FlushStage
    # cannot rise while SetValidWay is set; both rows are hit in the D$, so they are counted.)
# Not right; other ways can get flushed and dirtied simultaneously    coverage exclude -scope /core/lsu/bus/dcache/dcache/CacheWays[$i] -linerange [GetLineNum ${SRC}/cache/cacheway.sv "exclusion-tag: cache UpdateDirty"] -item c 1 -feccondrow 6
}
# D$ writeback, flush, write_line, or flush_writeback states can't be cancelled by a flush
coverage exclude -scope /core/lsu/bus/dcache/dcache/cachefsm -ftrans CurrState STATE_WRITEBACK->STATE_ACCESS STATE_FLUSH->STATE_ACCESS STATE_WRITE_LINE->STATE_ACCESS STATE_FLUSH_WRITEBACK->STATE_ACCESS
# D$ FETCH->ACCESS: the case statement leaves STATE_FETCH only for STATE_WRITE_LINE; the transition Questa
# infers comes from the synchronous reset term (reset | FlushStage).  FlushStage (LSUFlushW) cannot fire
# mid-fetch: FlushW needs a trap, and interrupts are masked while the cache is committed while the owning
# instruction's exceptions were resolved before its access issued; HPTWFlushW is only asserted before the
# walker has a bus transaction (hptw.sv).  The transition is seen only when the testbench resets between
# back-to-back ELFs in one session.
coverage exclude -scope /core/lsu/bus/dcache/dcache/cachefsm -ftrans CurrState STATE_FETCH->STATE_ACCESS

####################
# Unused / illegal peripheral accesses
####################

# Region decoders (adrdec Sel = Match & Supported & AccessValid & SizeValid; rows 1-8 are Match_0/1,
# Supported_0/1, AccessValid_0/1, SizeValid_0/1).
set line [GetLineNum ${SRC}/mmu/adrdec.sv "exclusion-tag: adrdecSel"]
# The instruction side drives the MMU with ReadAccessM and WriteAccessM tied low and ExecuteAccessF tied high (see
# the mmu instantiation in ifu.sv), so AccessRW is 0 and AccessRX/AccessRWXC are 1 there, and the fetch size is fixed.
# Peripherals qualified by AccessRW never select: every row except AccessValid_0 needs AccessValid = 1.  AccessValid_0
# (row 5) is reachable by fetching from the peripheral's address range, so it is counted.
foreach dec {clintdec gpiodec uartdec plicdec spidec pwmdec} {
  coverage exclude -scope /core/ifu/immu/immu/pmachecker/adrdecs/$dec -fecexprrow $line 1-4 6-8
}
# DTIM and SDC are not supported and qualified by AccessRW: no row can be reached.  IROM and external memory are not
# supported: Supported_0 (row 3) is hit and every other row needs Supported = 1.
coverage exclude -scope /core/ifu/immu/immu/pmachecker/adrdecs/dtimdec -fecexprrow $line 1-8
coverage exclude -scope /core/ifu/immu/immu/pmachecker/adrdecs/sdcdec -fecexprrow $line 1-8
coverage exclude -scope /core/ifu/immu/immu/pmachecker/adrdecs/iromdec -fecexprrow $line 1 2 4-8
coverage exclude -scope /core/ifu/immu/immu/pmachecker/adrdecs/ddr4dec -fecexprrow $line 1 2 4-8
# The boot ROM and RAM decoders do select on fetches: only Supported_0, AccessValid_0 and SizeValid_0 are unreachable.
coverage exclude -scope /core/ifu/immu/immu/pmachecker/adrdecs/bootromdec -fecexprrow $line 3 5 7
coverage exclude -scope /core/ifu/immu/immu/pmachecker/adrdecs/uncoreramdec -fecexprrow $line 3 5 7

# PMA Regions 1, 2, and 3 (dtim, irom, ddr4) are never used in the rv64gc configuration, so exclude coverage
set line [GetLineNum ${SRC}/mmu/pmachecker.sv "exclusion-tag: unused-atomic"]
coverage exclude -scope /core/lsu/dmmu/dmmu/pmachecker -fecexprrow $line 2 4
coverage exclude -scope /core/ifu/immu/immu/pmachecker -fecexprrow $line 2 4
set line [GetLineNum ${SRC}/mmu/pmachecker.sv "exclusion-tag: unused-tim"]
coverage exclude -scope /core/lsu/dmmu/dmmu/pmachecker -fecexprrow $line 2 4
coverage exclude -scope /core/ifu/immu/immu/pmachecker -fecexprrow $line 2 4
set line [GetLineNum ${SRC}/mmu/pmachecker.sv "exclusion-tag: unused-cacheable"]
coverage exclude -scope /core/lsu/dmmu/dmmu/pmachecker -fecexprrow $line 2
coverage exclude -scope /core/ifu/immu/immu/pmachecker -fecexprrow $line 2

# rv64gc has no DTIM, no IROM and no external memory, so SelRegions 1, 2 and 3 are tied low and the
# rows that need them asserted cannot be reached.
set line [GetLineNum ${SRC}/mmu/pmachecker.sv "assign IdempotentRegion"]
coverage exclude -scope /core/lsu/dmmu/dmmu/pmachecker -fecexprrow $line 2 4 6
coverage exclude -scope /core/ifu/immu/immu/pmachecker -fecexprrow $line 2 4 6

# MisalignedFaultAllowedM (~Cacheable & ~TLBMiss & Idempotent), TLBMiss_1 row: unreachable.  PBMemoryType is
# the PTE's PBMT field only on a TLB hit and 00 otherwise, and with PBMemoryType = 00 pmachecker drives
# Cacheable = SelRegions[3]|[4]|[5] and Idempotent = SelRegions[1]|[2]|[3]|[4]|[5].  rv64gc has no DTIM, no
# IROM and no external memory, so SelRegions 1, 2 and 3 are tied low and the two are the same signal: while
# the TLB misses, Idempotent & ~Cacheable cannot hold.  A non-cacheable idempotent region only exists through
# PBMT = NC, which requires the TLB hit that this row needs to be absent.
set line [GetLineNum ${SRC}/mmu/mmu.sv "assign MisalignedFaultAllowedM"]
coverage exclude -scope /core/lsu/dmmu/dmmu -fecexprrow $line 4
coverage exclude -scope /core/ifu/immu/immu -fecexprrow $line 4

# The instruction side ties AtomicAccessM low, so every row that needs an atomic access is
# unreachable in the instruction MMU.
set line [GetLineNum ${SRC}/mmu/mmu.sv "assign MisalignedCausesAccessFaultM"]
coverage exclude -scope /core/ifu/immu/immu -fecexprrow $line 4
set line [GetLineNum ${SRC}/mmu/mmu.sv "assign MisalignedFaultAllowedM"]
coverage exclude -scope /core/ifu/immu/immu -fecexprrow $line 6

# The following peripherals are always supported (Supported_0, row 3); the boot ROM, CLINT and RAM accept every
# access size (SizeValid_0, row 7)
set line [GetLineNum ${SRC}/mmu/adrdec.sv "exclusion-tag: adrdecSel"]
coverage exclude -scope /core/lsu/dmmu/dmmu/pmachecker/adrdecs/bootromdec -fecexprrow $line 3 7
coverage exclude -scope /core/lsu/dmmu/dmmu/pmachecker/adrdecs/gpiodec -fecexprrow $line 3
coverage exclude -scope /core/lsu/dmmu/dmmu/pmachecker/adrdecs/uartdec -fecexprrow $line 3
coverage exclude -scope /core/lsu/dmmu/dmmu/pmachecker/adrdecs/plicdec -fecexprrow $line 3
coverage exclude -scope /core/lsu/dmmu/dmmu/pmachecker/adrdecs/spidec -fecexprrow $line 3
coverage exclude -scope /core/lsu/dmmu/dmmu/pmachecker/adrdecs/pwmdec -fecexprrow $line 3

# LSU MemAccessDoneM clear (reset | FlushW | ~StallW), FlushW_1 row (FlushW while StallW): the two cannot
# coincide in this testbench.  FlushW is LatestUnstalledW, which requires ~StallW, or FlushWCause = TrapM &
# ~WFIInterruptedM.  StallW is (IFUStallF & ~FlushDCause) | (LSUStallM & ~FlushWCause) | ExternalStall;
# FlushDCause includes TrapM and the LSU term is gated by ~FlushWCause, so both drop when FlushWCause is set,
# and ExternalStall is the RVVI backpressure, tied low unless the synthesizable RVVI testbench is built.
set line [GetLineNum ${SRC}/lsu/lsu.sv "reset \\| FlushW \\| ~StallW"]
coverage exclude -scope /core/lsu -feccondrow $line 6

set line [GetLineNum ${SRC}/mmu/adrdec.sv "exclusion-tag: adrdecSel"]
coverage exclude -scope /core/lsu/dmmu/dmmu/pmachecker/adrdecs/clintdec -fecexprrow $line 3 7
coverage exclude -scope /core/lsu/dmmu/dmmu/pmachecker/adrdecs/uncoreramdec -fecexprrow $line 3 7

# DTIM, IROM, external memory and SDC are not supported: Supported_0 (row 3) is hit and every other row needs
# Supported = 1.
foreach dec {dtimdec iromdec ddr4dec sdcdec} {
  coverage exclude -scope /core/lsu/dmmu/dmmu/pmachecker/adrdecs/$dec -fecexprrow $line 1 2 4-8
}

# No DTIM or IROM
coverage exclude -scope /core/ifu/bus/icache/UnCachedDataMux -linerange [GetLineNum ${SRC}/generic/mux.sv "exclusion-tag: mux3"] -item b 1
coverage exclude -scope /core/lsu/bus/dcache/UnCachedDataMux -linerange [GetLineNum ${SRC}/generic/mux.sv "exclusion-tag: mux3"] -item b 1

####################
# Unused access types due to sharing IFU and LSU logic
####################

## The lsu never executes instructions so 'ExecuteAccessF' will never be 1
set line [GetLineNum ${SRC}/mmu/pmachecker.sv "AccessRWXC ="]
coverage exclude -scope /core/lsu/dmmu/dmmu/pmachecker -fecexprrow $line 6
set line [GetLineNum ${SRC}/mmu/pmachecker.sv "ReadAccessM \\| ExecuteAccessF"]
coverage exclude -scope /core/lsu/dmmu/dmmu/pmachecker -fecexprrow $line 4
set line [GetLineNum ${SRC}/mmu/pmachecker.sv "ExecuteAccessF & PMAAccessFault"]
coverage exclude -scope /core/lsu/dmmu/dmmu/pmachecker -fecexprrow $line 2-4
set line [GetLineNum ${SRC}/mmu/mmu.sv "ExecuteAccessF \\| ReadAccessM"]
coverage exclude -scope /core/lsu/dmmu/dmmu -fecexprrow $line 2
set line [GetLineNum ${SRC}/mmu/mmu.sv "TLBPageFault & ExecuteAccessF"]
coverage exclude -scope /core/lsu/dmmu/dmmu -fecexprrow $line 1 2 4
set line [GetLineNum ${SRC}/mmu/mmu.sv "PMAInstrAccessFaultF    \\|"]
coverage exclude -scope /core/lsu/dmmu/dmmu -fecexprrow $line 2 4 5 6
set line [GetLineNum ${SRC}/mmu/pmpchecker.sv "EnforcePMP & ExecuteAccessF"]
coverage exclude -scope /core/lsu/dmmu/dmmu/pmp/pmpchecker -fecexprrow $line 1-4 6
# (and in the IFU, ExecuteAccessF_0, row 5)
coverage exclude -scope /core/ifu/immu/immu/pmp/pmpchecker -fecexprrow $line 5


## The IFU has ReadAccess = WriteAccess = 0 and ExecuteAccess = 1 hardwired, so exclude alternatives
set line [GetLineNum ${SRC}/mmu/pmachecker.sv "ReadAccessM \\| WriteAccessM"]
coverage exclude -scope /core/ifu/immu/immu/pmachecker -fecexprrow $line 2 4
set line [GetLineNum ${SRC}/mmu/pmachecker.sv "WriteAccessM \\| ExecuteAccessF"]
coverage exclude -scope /core/ifu/immu/immu/pmachecker -fecexprrow $line 1-5 7 8
set line [GetLineNum ${SRC}/mmu/pmachecker.sv "ReadAccessM \\| ExecuteAccessF"]
coverage exclude -scope /core/ifu/immu/immu/pmachecker -fecexprrow $line 1-3
set line [GetLineNum ${SRC}/mmu/pmachecker.sv "ExecuteAccessF & PMAAccessFault"]
coverage exclude -scope /core/ifu/immu/immu/pmachecker -fecexprrow $line 1
set line [GetLineNum ${SRC}/mmu/pmachecker.sv "ReadAccessM & ~WriteAccessM & PMAAccessFault"]
coverage exclude -scope /core/ifu/immu/immu/pmachecker -fecexprrow $line 1 2 4-6
set line [GetLineNum ${SRC}/mmu/pmachecker.sv "PMAStoreAmoAccessFaultM ="]
coverage exclude -scope /core/ifu/immu/immu/pmachecker -fecexprrow $line 2 4-6
set line [GetLineNum ${SRC}/mmu/pmachecker.sv "AccessRWXC \\| AtomicAccessM"]
coverage exclude -scope /core/ifu/immu/immu/pmachecker -fecexprrow $line 3 6-8
set line [GetLineNum ${SRC}/mmu/mmu.sv "ExecuteAccessF \\| ReadAccessM"]
coverage exclude -scope /core/ifu/immu/immu -fecexprrow $line 1 3 4
set line [GetLineNum ${SRC}/mmu/mmu.sv "ReadAccessM & ~WriteAccessM"]
coverage exclude -scope /core/ifu/immu/immu -fecexprrow $line 2-4
set line [GetLineNum ${SRC}/mmu/mmu.sv "DataMisalignedM & WriteAccessM"]
coverage exclude -scope /core/ifu/immu/immu -fecexprrow $line 1 2 4-6
set line [GetLineNum ${SRC}/mmu/mmu.sv "TLBPageFault & ExecuteAccessF"]
coverage exclude -scope /core/ifu/immu/immu -fecexprrow $line 3
set line [GetLineNum ${SRC}/mmu/mmu.sv "TLBPageFault & ReadNoAmoAccessM"]
coverage exclude -scope /core/ifu/immu/immu -fecexprrow $line 1 2 4
set line [GetLineNum ${SRC}/mmu/mmu.sv "StoreAmoPageFaultM \="]
coverage exclude -scope /core/ifu/immu/immu -fecexprrow $line 1 2 4 6
set line [GetLineNum ${SRC}/mmu/mmu.sv "DataMisalignedM & ReadNoAmoAccessM"]
coverage exclude -scope /core/ifu/immu/immu -fecexprrow $line 1 2 4-6
set line [GetLineNum ${SRC}/mmu/pmpchecker.sv "EnforcePMP & WriteAccessM"]
coverage exclude -scope /core/ifu/immu/immu/pmp/pmpchecker -fecexprrow $line 1-4 6 8
set line [GetLineNum ${SRC}/mmu/pmpchecker.sv "EnforcePMP & ReadAccessM"]
coverage exclude -scope /core/ifu/immu/immu/pmp/pmpchecker -fecexprrow $line 1-6 8
set line [GetLineNum ${SRC}/mmu/mmu.sv "LoadAccessFaultM     \="]
coverage exclude -scope /core/ifu/immu/immu -fecexprrow $line 2 4-6 8-10
set line [GetLineNum ${SRC}/mmu/mmu.sv "StoreAmoAccessFaultM \="]
coverage exclude -scope /core/ifu/immu/immu -fecexprrow $line 2 4-6 8-10
set line [GetLineNum ${SRC}/mmu/tlb/tlbcontrol.sv "ReadAccess \\| WriteAccess"]
coverage exclude -scope /core/ifu/immu/immu/tlb/tlb/tlbcontrol -fecexprrow $line 1 3-6
set line [GetLineNum ${SRC}/mmu/tlb/tlbcontrol.sv "CAMHit & TLBAccess"]
coverage exclude -scope /core/ifu/immu/immu/tlb/tlb/tlbcontrol -fecexprrow $line 3
set line [GetLineNum ${SRC}/mmu/tlb/tlbcontrol.sv "~CAMHit & TLBAccess"]
coverage exclude -scope /core/ifu/immu/immu/tlb/tlb/tlbcontrol -fecexprrow $line 3

# IMMU only makes word-sized accesses (Size = 2'b10), so the byte, halfword and doubleword arms of the
# misalignment case never run, and the fetch address bit 0 is always 0 (row 4, VAdr[0]_1, of the word arm).
foreach arm {"2'b00:  DataMisalignedM" "2'b01:  DataMisalignedM" "2'b11:  DataMisalignedM"} {
  coverage exclude -scope /core/ifu/immu/immu -linerange [GetLineNum ${SRC}/mmu/mmu.sv $arm] -item bs 1
}
coverage exclude -scope /core/ifu/immu/immu -fecexprrow [GetLineNum ${SRC}/mmu/mmu.sv "2'b10:  DataMisalignedM"] 4

# IMMU never disables translations (DisableTranslation_1).  (UpdateDA Translate_0, row 5, used to be excluded too;
# it is hit.)
coverage exclude -scope /core/ifu/immu/immu/tlb/tlb/tlbcontrol -fecexprrow [GetLineNum ${SRC}/mmu/tlb/tlbcontrol.sv "assign Translate"] 2
# never reaches this when ENVCFG_ADUE_1 because HPTW updates A bit first
coverage exclude -scope /core/ifu/immu/immu/tlb/tlb/tlbcontrol -fecexprrow [GetLineNum ${SRC}/mmu/tlb/tlbcontrol.sv "assign PrePageFault"] 18




###############
# HPTW exclusions
###############

# RV64GC HPTW never starts at L1_ADR
set line [GetLineNum ${SRC}/mmu/hptw.sv "InitialWalkerState == L1_ADR"]
coverage exclude -scope /core/lsu/hptw/hptw -feccondrow $line 2

# (HPTWLoadPageFault row 7, HPTWStoreAmoPageFault row 3 and HPTWUpdateDA row 3 used to be excluded here as
# unreachable; every row of the three expressions is hit, so they are counted.)

# UPDATE_PTE never self-loops on a cache-bus stall: the PTE being A/D-updated was just read during the
# same uninterrupted walk (LSU stalled, line cannot be evicted), so it is resident/writable in the D$ and
# the UPDATE_PTE store hits.  DCacheBusStallM therefore cannot assert in UPDATE_PTE, so the
# UPDATE_PTE -> UPDATE_PTE branch/statement is unreachable.
set line [GetLineNum ${SRC}/mmu/hptw.sv "DCacheBusStallM.*UPDATE_PTE"]
coverage exclude -scope /core/lsu/hptw/hptw -linerange $line

# (SvMode==SV57)_0 on the PPN-source mux is unreachable: the L4_ADR/L4_RD walker states in the non-masking
# condition only exist when SvMode==SV57 (InitialWalkerState=L4_ADR is gated on SV57), so SvMode can never
# differ from SV57 while in an L4 state.  Remaining mux terms are covered by the NextWalkerState FSM case.
set line [GetLineNum ${SRC}/mmu/hptw.sv "P\.SV57_SUPPORTED & SvMode == P.SV57 & "]
coverage exclude -scope /core/lsu/hptw/hptw -feccondrow $line 1

###############
# Other exclusions
###############

# IMMU PMP does not support CBO instructions (CMOpM is tied low): every row that needs a CMO, or a CBO access fault
coverage exclude -scope /core/ifu/immu/immu/pmp/pmpchecker -fecexprrow [GetLineNum ${SRC}/mmu/pmpchecker.sv "exclusion-tag: immu-pmpcbom"] 1-4 6
coverage exclude -scope /core/ifu/immu/immu/pmp/pmpchecker -fecexprrow [GetLineNum ${SRC}/mmu/pmpchecker.sv "exclusion-tag: immu-pmpcboz"] 1-4 6
coverage exclude -scope /core/ifu/immu/immu/pmp/pmpchecker -fecexprrow [GetLineNum ${SRC}/mmu/pmpchecker.sv "exclusion-tag: immu-pmpcboaccess"] 2 4

# No irom
set line [GetLineNum ${SRC}/ifu/ifu.sv "~ITLBMissF & ~CacheableF & ~SelIROM"]
coverage exclude -scope /core/ifu -feccondrow $line 6
set line [GetLineNum ${SRC}/ifu/ifu.sv "~ITLBMissF & CacheableF & ~SelIROM"]
coverage exclude -scope /core/ifu -feccondrow $line 4

# no DTIM
set line [GetLineNum ${SRC}/lsu/lsu.sv "assign BusRW"]
coverage exclude -scope /core/lsu -feccondrow $line 4
set line [GetLineNum ${SRC}/lsu/lsu.sv "assign CacheRWM"]
coverage exclude -scope /core/lsu -feccondrow $line 2

# Exclude system reset case in ebu
set line [GetLineNum ${SRC}/ebu/ebufsmarb.sv "BeatCounter\\("]
coverage exclude -scope /core/ebu/ebu/ebufsmarb -fecexprrow $line 1
set line [GetLineNum ${SRC}/ebu/ebufsmarb.sv "FinalBeatReg\\("]
coverage exclude -scope /core/ebu/ebu/ebufsmarb -fecexprrow $line 1
# (The ARBITRATE: if condition, row 2 both_1, used to be excluded here; it is hit, so it is counted.)

set line [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm AtomicElse"]
coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -linerange $line-$line  -item bc 1

set line [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm AtomicWait"]
coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -linerange $line-$line -item bc 1

# The WritebackWriteback, FetchWriteback and FetchWait branches support back to back pipelined cache writebacks
# and fetches.  The cache never issues these requests: it holds one request until CacheBusAck.  Exclude the taken
# branch, its statement and the condition rows that need the request, but not the CACHE_FETCH/CACHE_WRITEBACK
# case arm on the same line (branch item 1 of the first two), which is hit.  (A bare -linerange would also
# exclude that arm and the FSM state whose encoding is reported on the line.)
set line [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm WritebackWriteback"]
coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -linerange $line -item b 2
coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -linerange $line -item s 1
coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -feccondrow $line 1 2 4 6

set line [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm FetchWriteback"]
coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -linerange $line -item b 2
coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -linerange $line -item s 1
coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -feccondrow $line 1 2 3 4 6

set line [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm FetchWait"]
coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -linerange $line -item bs 1
coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -feccondrow $line 1 2 4 6

# HREADY is low for a requester only while the other requester owns the bus (EBU arbitration; ram_ahb never
# stalls).  Once the cache owns the bus for a burst, HREADY stays high, so the HREADY_0 rows of the CACHE_FETCH and
# CACHE_WRITEBACK conditions are unreachable.  (The D$ ADR_PHASE HREADY0 row used to be excluded too; it is hit.)

#set line [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm HREADY1"]
#coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -linerange $line-$line -item c 1 -feccondrow 1

#set line [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm HREADY2"]
#coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -linerange $line-$line -item c 1 -feccondrow 1

# DATA_PHASE ~BusAtomic_0 (BusAtomic_1, row 4): priority-masked by the HREADY & BusAtomic branch above it.
set line [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm HREADY3"]
coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -feccondrow $line 4

# CACHE_WRITEBACK -> CACHE_FETCH: HREADY_0, and FinalBeatCount_0 (CacheBusRW[1] is only raised with CacheBusAck).
set line [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm HREADY4"]
coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -feccondrow $line 1 3

set line [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm HREADY5"]
coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -feccondrow $line 1

# CACHE_WRITEBACK -> ADR_PHASE: HREADY_0, and ~|CacheBusRW_0 (a pending request is taken by the branches above).
set line [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm HREADY6"]
coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -feccondrow $line 1 5

# D$ AHBBuscachefsm CACHE_FETCH fetch-done branch (HREADY & FinalBeatCount & ~|CacheBusRW -> ADR_PHASE) _0
# condition rows 1, 3, 5: the cache holds CacheBusRW until CacheBusAck = HREADY & FinalBeatCount, so ~|CacheBusRW
# implies both, and a request still pending at the final beat is taken by FetchWriteback/FetchWait first.
set line [GetLineNum ${SRC}/ebu/buscachefsm.sv "FinalBeatCount & ~\|CacheBusRW\\)  NextState = ADR_PHASE"]
coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -feccondrow $line 1 3 5

# D$ AHBBuscachefsm BeatCountReg/BeatCountDelayedReg reset (~HRESETn | BeatCntReset) HRESETn_0: a reset
# coincident with an in-flight beat never happens for the D$ (no D$ bus transaction is active at power-on reset).
coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -fecexprrow [GetLineNum ${SRC}/ebu/buscachefsm.sv "BeatCountReg\\("] 1
coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -fecexprrow [GetLineNum ${SRC}/ebu/buscachefsm.sv "BeatCountDelayedReg\\("] 1

# D$ AHBBuscachefsm BeatCntEn (NextState==ADR_PHASE)_0: a pending cached request with HREADY forces
# NextState to a cache state (priority-masked).
coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -fecexprrow [GetLineNum ${SRC}/ebu/buscachefsm.sv "assign BeatCntEn"] 9

# D$ AHBBuscachefsm HTRANS pipelined-request term CacheAccess_0 (row 15): FinalBeatCount outside a cache burst
# needs a BeatCount left stale by a flush at the final beat.  The bus is then in ADR_PHASE, where the first HTRANS
# term masks the row whenever a request is pending, or in the DATA_PHASE/MEM3 of an uncached access, during which
# the cache makes no request.
coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -feccondrow [GetLineNum ${SRC}/ebu/buscachefsm.sv "assign HTRANS"] 15

# D$ AHBBuscachefsm CaptureEn ((~Flush & DATA_PHASE) & BusRW[1]) Flush_1: unreachable for the D$ -- a
# DATA_PHASE access with BusRW[1] is a committed, non-speculative uncached load read; the D$ Flush input
# (LSUFlushW) has no branch-mispredict component, so Flush is always 0 here.
coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -fecexprrow [GetLineNum ${SRC}/ebu/buscachefsm.sv "assign CaptureEn"] 2

# CacheBusAck HREADY_0 (row 5): at the final beat of a burst, see the HREADY note above.
coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -fecexprrow [GetLineNum ${SRC}/ebu/buscachefsm.sv "assign CacheBusAck"] 5

coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -linerange [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm AtomicElse"] -item s 1
coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -linerange [GetLineNum ${SRC}/ebu/buscachefsm.sv "exclusion-tag: buscachefsm AtomicWait"] -item s 1

# these transitions will not happen (DATA_PHASE->ADR_PHASE used to be listed too; it is hit)
coverage exclude -scope /core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm -ftrans CurrState ATOMIC_READ_DATA_PHASE->ADR_PHASE ATOMIC_PHASE->ADR_PHASE CACHE_FETCH->CACHE_WRITEBACK

# TLB not recently used never has all RU bits = 1 because it will then clear all to 0, so the last bit of
# the TLB NRU priority encoder never sees ~RUBits[31]_0 with every lower bit 1 (row 1 of poh[31]).  This used to
# be a -du exclusion of priorityonehot, which also hid the PMP priority and cache LRU encoders.
foreach tlb {/core/ifu/immu/immu/tlb/tlb /core/lsu/dmmu/dmmu/tlb/tlb} {
  coverage exclude -scope "$tlb/lru/nru/poh\[31\]" -fecexprrow [GetLineNum ${SRC}/generic/priorityonehot.sv {assign y\[i\]}] 1
}

# Excluding pmpadrdecs[0] coverage case for PAgePMPAdrIn being hardwired to 1
coverage exclude -scope /core/ifu/immu/immu/pmp/pmpchecker/pmp/pmpadrdecs[0] -fecexprrow [GetLineNum ${SRC}/mmu/pmpadrdec.sv "exclusion-tag: PAgePMPAdrIn"] 1
coverage exclude -scope /core/lsu/dmmu/dmmu/pmp/pmpchecker/pmp/pmpadrdecs[0] -fecexprrow [GetLineNum ${SRC}/mmu/pmpadrdec.sv "exclusion-tag: PAgePMPAdrIn"] 1

# StallD always equals StallF so LatestUnstalledD is always 0
coverage exclude -scope /core/hzu -fecexprrow [GetLineNum ${SRC}/hazard/hazard.sv "StallD always equals StallF"] 1 4
coverage exclude -scope /core/hzu -fecexprrow [GetLineNum ${SRC}/hazard/hazard.sv "coverage tag: LatestUnstalledD always 0"] 2

####################
# Privileged
####################

# Instruction Misaligned never asserted because compressed instructions are accepted
coverage exclude -scope /core/priv/priv/trap -fecexprrow [GetLineNum ${SRC}/privileged/trap.sv "assign ExceptionM"] 2

# Attempting to access fflags, frm, fcsr with mstatus.FS = 0 traps, so checking for (STATUS_FS != 2'b00)
# before enabling writes to these CSRs is redundant and uncoverable
coverage exclude -scope /core/priv/priv/csr/csru/csru -fecexprrow [GetLineNum ${SRC}/privileged/csru.sv "assign WriteFRMM"] 3
coverage exclude -scope /core/priv/priv/csr/csru/csru -fecexprrow [GetLineNum ${SRC}/privileged/csru.sv "assign WriteFFLAGSM"] 3

# Attempted writes to the nonextistant MTIME register trap, so WriteHPMCOUNTERM cannot be set for that address (0xb01)
# The scope is the generate block inside the csrc instance named counters; an earlier version of
# these two lines named counters twice, so vsim reported the scope as not found and excluded nothing.
coverage exclude -scope /core/priv/priv/csr/counters/cntr[1] -fecexprrow [GetLineNum ${SRC}/privileged/csrc.sv "MTIME traps"] 2 4
coverage exclude -scope /core/priv/priv/csr/counters/cntr[1] -linerange [GetLineNum ${SRC}/privileged/csrc.sv "assign NextHPMCOUNTERM"] -item b 1

# rv64gc divides integers in the FPU (IDIV_ON_FPU), so the integer divider never runs and DivBusyE is never
# asserted: row 2 (DivBusyE_1) of the division-cycles event cannot be reached.  FDivBusyE's rows are hit.
coverage exclude -scope /core/priv/priv/csr/counters -fecexprrow [GetLineNum ${SRC}/privileged/csrc.sv "division cycles"] 2

# CounterEvent[0] is tied high because MCYCLE always increments, so the FEC row that needs it low
# cannot be reached.
coverage exclude -scope /core/priv/priv/csr/counters/cntr[0] -fecexprrow [GetLineNum ${SRC}/privileged/csrc.sv "MCYCLE, CYCLE, and MINSTRET are always incremented"] 1

# Counter 1 does not exist, so CounterEvent[1] is tied low and CounterInc[1] can never assert: rows 2-4 need
# CounterEvent[1] = 1 (row 1, CounterEvent[1]_0, is hit).
coverage exclude -scope /core/priv/priv/csr/counters/cntr[1] -fecexprrow [GetLineNum ${SRC}/privileged/csrc.sv "MCYCLE, CYCLE, and MINSTRET are always incremented"] 2-4

# CounterEvent[31:25] is tied low until those event sources are implemented, so counters 25 through
# 31 can never increment no matter what their event selector or inhibit bit hold: every row except
# CounterEvent_0 (row 3, hit) needs CounterEvent = 1.
for {set i 25} {$i < 32} {incr i} {
  coverage exclude -scope /core/priv/priv/csr/counters/cntr[$i] -fecexprrow [GetLineNum ${SRC}/privileged/csrc.sv "user-defined counters are incremented only if the event is enabled"] 1 2 4-6
}

# rv64gc implements all 32 counters, which makes three range checks in the counter read logic
# degenerate.  They exist for configurations with fewer counters.
#   MHPMEVENTBASE + COUNTERS - 3 = 0x340 is above MHPMEVENTLAST = 0x33F, so the guarded comparison
#   is always true: its _0 condition row, and the else branch and statement (the read-only-zero
#   fallback for absent event selectors, reported on the else line), never run.
coverage exclude -scope /core/priv/priv/csr/counters -feccondrow [GetLineNum ${SRC}/privileged/csrc.sv "MHPMEVENTBASE\\+P.COUNTERS-3"] 1
coverage exclude -scope /core/priv/priv/csr/counters -linerange [GetLineNum ${SRC}/privileged/csrc.sv "unused event selectors are read-only zero"] -item bs 1
#   CSRAdrM >= MHPMCOUNTERBASE+COUNTERS & CSRAdrM < MHPMCOUNTERBASE+32 is 0xB20 <= x < 0xB20, empty: the
#   branch, the two _1 condition rows and the read-only-zero statement on the next line never run.
set line [GetLineNum ${SRC}/privileged/csrc.sv "CSRAdrM >= MHPMCOUNTERBASE\\+P.COUNTERS"]
coverage exclude -scope /core/priv/priv/csr/counters -linerange $line -item b 1
coverage exclude -scope /core/priv/priv/csr/counters -feccondrow $line 2 4
coverage exclude -scope /core/priv/priv/csr/counters -linerange [expr {$line + 1}] -item s 1
#   CSRAdrM >= HPMCOUNTERBASE+COUNTERS & CSRAdrM < HPMCOUNTERBASE+32 is 0xC20 <= x < 0xC20, empty: the branch,
#   the rows that need the range true (both CSRWriteM rows and the two _1 rows) and the statement on the next line.
set line [GetLineNum ${SRC}/privileged/csrc.sv "CSRAdrM >= HPMCOUNTERBASE\\+P.COUNTERS"]
coverage exclude -scope /core/priv/priv/csr/counters -linerange $line -item b 1
coverage exclude -scope /core/priv/priv/csr/counters -feccondrow $line 1 2 4 6
coverage exclude -scope /core/priv/priv/csr/counters -linerange [expr {$line + 1}] -item s 1

# attempting to write stimecmp with STCE=0 traps, causing CSRSWriteM to go low
coverage exclude -scope /core/priv/priv/csr/csrs/csrs -fecexprrow [GetLineNum ${SRC}/privileged/csrs.sv "assign WriteSTIMECMPM"] 5

# mode != m_mode and TVM = 1 causes a trap, causing CSRSWriteM to go low
coverage exclude -scope /core/priv/priv/csr/csrs/csrs -fecexprrow [GetLineNum ${SRC}/privileged/csrs.sv "assign WriteSATPM"] 5 8

####################
# EBU
####################

# (The EBU BeatCounter flop used to be excluded whole, as idle only with multicycle bus latency; all of its
# branches and statements are hit, so it is counted.)

####################
# IFU
####################

# (ITLBMissOrUpdateRawF InstrUpdateAF_1, row 4, used to be excluded here as unreachable; it is hit, so it is counted.)

# I$ fetchbuffer CaptureBeat: CaptureEn_0 is unreachable for beats 1..7.  In the read-only I$ with HREADY
# always 1, CaptureEn is high on every beat of a CACHE_FETCH, so it is never 0 at a matching delayed beat
# (the D$ reaches CaptureEn=0 via writeback beats, which the I$ never does).  Beat 0 is covered (idle/reset).
set fbline [GetLineNum ${SRC}/ebu/ahbcacheinterface.sv "index == BeatCountDelayed"]
for {set i 1} {$i < 8} {incr i} {
    coverage exclude -scope /core/ifu/bus/icache/ahbcacheinterface/fetchbufferbeat[$i] -fecexprrow $fbline 1
}

# FlushDCache = FlushDCacheM & ~SelHPTW : the SelHPTW=1 input-term (Row 4) is unreachable.  fence.i is the
# only asserter of FlushDCacheM, and while fence.i is in M it pins the front end to an already-translated
# page (NextValidPCE=PCE), so no ITLB walk can begin while FlushDCacheM=1; a walk that starts earlier stalls
# fence.i out of M.  See https://github.com/openhwfoundation/cvw/issues/1788.
set line [GetLineNum ${SRC}/lsu/lsu.sv "exclusion-tag: lsu FlushDCacheSelHPTW"]
coverage exclude -scope /core/lsu/bus/dcache -fecexprrow $line 4
