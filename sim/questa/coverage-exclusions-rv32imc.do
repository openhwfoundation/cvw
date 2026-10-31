#///////////////////////////////////////////
#// coverage-exclusions-rv32imc.do
#//
#// Written: Claude for David_Harris@hmc.edu 27 October 2026
#//
#// Purpose: Set of exclusions from coverage for the rv32imc configuration
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
# top scope is /core.  Every exclusion names an instance, an FEC row by its target (ExcludeRows), FSM
# transitions by name, or branches/statements on a line marked with an exclusion-tag comment (TagLine).
# Exclude only what cannot be reached, so that losing a reachable item shows up in the report.
#
# rv32imc (config/rv32imc/config.vh): RV32 with M and U modes only (S_SUPPORTED = 0), no virtual memory
# (VIRTMEM_SUPPORTED = 0: no TLBs or page table walker), no PMP (PMP_ENTRIES = 0), no caches
# (DCACHE_SUPPORTED = ICACHE_SUPPORTED = 0), no branch predictor (BPRED_SUPPORTED = 0), and no F/D/Q, A,
# Zicbo* or Zifencei.  Instructions come from the IROM and data from the DTIM, both at 0x80000000-0x807FFFFF
# and tightly integrated; the AHB bus reaches only the peripherals (CLINT, PLIC, UART, GPIO, SPI, PWM).  The
# boot ROM, uncore RAM, external memory and SD card controller are absent.

set WALLY $::env(WALLY)
set SRC ${WALLY}/src
do ${WALLY}/sim/questa/CoverageExclude.do

set IMMU /core/ifu/immu/immu
set DMMU /core/lsu/dmmu/dmmu
set CNT  /core/priv/priv/csr/counters
set ARB  /core/ebu/ebu/ebufsmarb
set LBUS /core/lsu/bus/passthrough/ahbinterface/busfsm

######################################################################################################
# IFUBUS: the IFU never uses the AHB bus
######################################################################################################

# The only executable region is the IROM, which is tightly integrated; the executable bus regions (boot ROM,
# uncore RAM, external memory) are absent (BOOTROM_SUPPORTED = UNCORE_RAM_SUPPORTED = EXT_MEM_SUPPORTED = 0).
# A fetch from any other address fails the PMA check, and ifu.sv requests the bus only for
# ~SelIROM & ~IFUFaultF, so the IFU bus interface never sees a request: its bus FSM stays in ADR_PHASE and
# its fetch buffer is never written.  The whole instance is excluded; the items it reports as hit are only
# its reset and idle (ADR_PHASE, no request) activity.
coverage exclude -scope /core/ifu/bus/passthrough/ahbinterface -recursive
# The EBU's IFU input stage (address save/restore registers and its HREADY gate) only serves IFU requests;
# its hits are the reset of the save register and HREADY passing through to the idle IFU bus FSM.
coverage exclude -scope /core/ebu/ebu/IFUInput -recursive

# With no IFU request the arbiter never sees both masters at once (both = LSUReq & IFUReq), so it stays in
# IDLE: the ARBITRATE state, the beat counter and final-beat register (enabled only in ARBITRATE), the IFU
# select/save/restore controls and the LSU disable (IFUReqDelay) never act.  The beat counter and final-beat
# register instances are excluded whole; their only hits are their reset.
coverage exclude -scope $ARB/BeatCounter -recursive
coverage exclude -scope $ARB/FinalBeatReg -recursive
ExcludeRows $ARB e {LSUReq_1 IFUReq_1}
ExcludeRows $ARB c {both_0 both_1 HREADY_0 HREADY_1 FinalBeatD_0 FinalBeatD_1}
ExcludeRows $ARB e [list "(CurrState == IDLE)_0" "(CurrState == IDLE)_1" both_1]
ExcludeRows $ARB e [list "(CurrState == ARBITRATE)_1"]
ExcludeRows $ARB e [list "(NextState == ARBITRATE)_1"] [TagLine ${SRC}/ebu/ebufsmarb.sv arb-ifuselect]
ExcludeRows $ARB e [list "(NextState == ARBITRATE)_1"] [TagLine ${SRC}/ebu/ebufsmarb.sv arb-lsuselect]
ExcludeRows $ARB e [list "(NextState == ARBITRATE)_1" HREADY_0 HREADY_1]
ExcludeRows $ARB e [list "(CurrState != ARBITRATE)_0" "(CurrState != ARBITRATE)_1" IFUReqDelay_1]
ExcludeRows $ARB e [list "(NextState == IDLE)_0"]
ExcludeRows $ARB e [list "(BeatCount == Threshold)_0"]
coverage exclude -scope $ARB -linerange [TagLine ${SRC}/ebu/ebufsmarb.sv arb-idle] -item b 2
coverage exclude -scope $ARB -linerange [TagLine ${SRC}/ebu/ebufsmarb.sv arb-idle] -item s 1
coverage exclude -scope $ARB -linerange [TagLine ${SRC}/ebu/ebufsmarb.sv arb-arbitrate-exit]-[TagLine ${SRC}/ebu/ebufsmarb.sv arb-arbitrate-hold] -code bs
coverage exclude -scope $ARB -linerange [TagLine ${SRC}/ebu/ebufsmarb.sv arb-ifuselect] -item b 1
coverage exclude -scope $ARB -linerange [TagLine ${SRC}/ebu/ebufsmarb.sv arb-lsuselect] -item b 1
# The beat-count resets (~HRESETn | BeatCntReset [| FinalBeat]) need BeatCntReset = 0, i.e. NextState =
# ARBITRATE; their HRESETn_0 rows need that during reset too, when the arbiter is held in IDLE.
ExcludeRows $ARB e {HRESETn_0 HRESETn_1 BeatCntReset_0 BeatCntReset_1 FinalBeat_0 FinalBeat_1}
ExcludeRows $ARB e {HRESETn_0 HRESETn_1 BeatCntReset_0} [TagLine ${SRC}/ebu/ebufsmarb.sv arb-finalbeat-reset]

# The EBU disables the LSU's HREADY only in the cycle after an IFU request (LSUDisable = IFUReqDelay).
ExcludeRows /core/ebu/ebu/LSUInput e {Disable_1}

# Without IFU bus transfers, CommittedF (an I$ or IFU bus operation in flight) is always 0.
ExcludeRows /core/priv/priv/trap e {CommittedF_1} [TagLine ${SRC}/privileged/trap.sv trap-committed]
ExcludeRows /core/priv/priv/trap e {CommittedF_1} [TagLine ${SRC}/privileged/trap.sv trap-trapm]

# The spill decision's IFUCacheBusStallF term is the IFU bus stall (there is no I$), always 0.  In the same
# expression, ITLBMissOrUpdateRawF and InstrPageFaultF need virtual memory (VIRTMEM_SUPPORTED = 0), and
# InstrAccessFaultF_1 needs a faulting first half whose bits [1:0] are 11: a faulting fetch is never from the
# IROM, so its bits come from the IFU fetch buffer, which resets to 0 and is never written, and
# EarlyCompressedF = 1 masks the term.
ExcludeRows /core/ifu/Spill/spill e {IFUCacheBusStallF_1 ITLBMissOrUpdateRawF_1 InstrPageFaultF_1 InstrAccessFaultF_1}
# The spill FSM's (CurrState == STATE_SPILL) & IFUCacheBusStallF rows are reported hit by
# tests/coverage32imc/iromtopspill: its second-half fetch at 0x80800000 makes BusRW pulse for zero time before
# IFUFaultF settles, and the IFU bus FSM never sees the request.  Those glitch hits are left as reported.

######################################################################################################
# LSUHREADY0: the LSU never requests while HREADY is low
######################################################################################################

# The LSU is the only bus master (IFUBUS).  An LSU transfer runs ADR_PHASE -> DATA_PHASE -> MEM3 -> ADR_PHASE,
# leaving DATA_PHASE only when the slave raises HREADY, and a data phase is never abandoned (BusCommitted
# blocks interrupts, and a faulting access never starts).  After a transfer HADDR selects no region
# (HSELNoneD), so HREADY = 1 whenever the LSU bus FSM is in ADR_PHASE.
ExcludeRows $LBUS c {HREADY_0} [TagLine ${SRC}/ebu/busfsm.sv busfsm-adr-request]
# For the same reason the FSM never leaves DATA_PHASE for ADR_PHASE: that needs a reset or a flush (a trap)
# during the data phase.
coverage exclude -scope $LBUS -ftrans CurrState DATA_PHASE->ADR_PHASE

######################################################################################################
# NOATOMIC: no A extension (ZAAMO_SUPPORTED = ZALRSC_SUPPORTED = 0)
######################################################################################################

# No atomic bus transfers: BusAtomic = 0, so the LSU bus FSM never enters its ATOMIC_* states.  The HREADY_0
# row of the HTRANS expression (with the atomic rows below) is the LSUHREADY0 case above.
ExcludeRows $LBUS c {HREADY_0 HREADY_1 BusAtomic_1} [TagLine ${SRC}/ebu/busfsm.sv busfsm-data-atomic]
ExcludeRows $LBUS c {BusAtomic_1} [TagLine ${SRC}/ebu/busfsm.sv busfsm-data-done]
ExcludeRows $LBUS c [list HREADY_0 "(CurrState == ATOMIC_READ_DATA_PHASE)_0" "(CurrState == ATOMIC_READ_DATA_PHASE)_1" BusAtomic_0 BusAtomic_1]
ExcludeRows $LBUS e [list "(CurrState == ATOMIC_PHASE)_1" "(CurrState == ATOMIC_READ_DATA_PHASE)_1"]
ExcludeRows $LBUS e [list BusAtomic_1 "(CurrState == ATOMIC_READ_DATA_PHASE)_0" "(CurrState == ATOMIC_READ_DATA_PHASE)_1"]
# Excluding the two ATOMIC_* states also excludes every transition into or out of them.
coverage exclude -scope $LBUS -fstate CurrState ATOMIC_READ_DATA_PHASE ATOMIC_PHASE
coverage exclude -scope $LBUS -linerange [TagLine ${SRC}/ebu/busfsm.sv busfsm-data-atomic] -item b 2
coverage exclude -scope $LBUS -linerange [TagLine ${SRC}/ebu/busfsm.sv busfsm-data-atomic] -item s 1
coverage exclude -scope $LBUS -linerange [TagLine ${SRC}/ebu/busfsm.sv busfsm-atomic-start]-[TagLine ${SRC}/ebu/busfsm.sv busfsm-atomic-end] -code bs

# Only an AMO reads and writes in one access (ReadAccessM & WriteAccessM) or needs an atomic-capable region.
ExcludeRows $DMMU/pmachecker e {AtomicAccessM_1 AtomicAllowed_0 AtomicAllowed_1}
ExcludeRows $DMMU/pmachecker e {WriteAccessM_1} [TagLine ${SRC}/mmu/pmachecker.sv pma-load-fault]
ExcludeRows $DMMU e {WriteAccessM_1}

# sc is the only instruction with ResultSrc = 100 (SCE, and the SC input of the Writeback result mux), and
# ImmSrc = 101 (zero offset) is used only by atomics and CMOs (also absent: NOCMO).
ExcludeRows /core/ieu/c e [list "(ResultSrcE == 4)_1"]
ExcludeRows /core/ieu/c e {SCE_1}
coverage exclude -scope /core/ieu/dp/resultmuxW -linerange [TagLine ${SRC}/generic/mux.sv mux5] -item b 1
coverage exclude -scope /core/ieu/dp/ext -linerange [TagLine ${SRC}/ieu/extend.sv imm-atomic-case] -item b 1
coverage exclude -scope /core/ieu/dp/ext -linerange [TagLine ${SRC}/ieu/extend.sv imm-atomic-undefined] -item s 1

######################################################################################################
# NOCMO: no cache management operations (ZICBOM_SUPPORTED = ZICBOZ_SUPPORTED = ZICBOP_SUPPORTED = 0)
######################################################################################################

# CMOFunctD is constant 0, so no CMO is decoded and CMOpM = 0.  (The ExecuteAccessF_1 row in the first
# DMMU expression is the DMMU tie-off below.)
coverage exclude -scope /core/ieu/c -linerange [TagLine ${SRC}/ieu/controller.sv cmo-decode] -item b 1
ExcludeRows $DMMU/pmachecker e {ExecuteAccessF_1 |CMOpM_1}
ExcludeRows $DMMU/pmachecker e {|CMOpM_1} [TagLine ${SRC}/mmu/pmachecker.sv pma-store-fault]

######################################################################################################
# NOS: no supervisor mode (S_SUPPORTED = 0)
######################################################################################################

# sie, sip, medeleg and mideleg do not exist without S mode, so accessing one is an illegal instruction, which
# traps and flushes Writeback: CSRSWriteM / CSRMWriteM are never asserted for those addresses.
ExcludeRows /core/priv/priv/csr/csri e [list CSRSWriteM_1 "(CSRAdrM == 324)_1"]
ExcludeRows /core/priv/priv/csr/csri e [list CSRSWriteM_1 "(CSRAdrM == 260)_1"]
coverage exclude -scope /core/priv/priv/csr/csri -linerange [TagLine ${SRC}/privileged/csri.sv csri-write-sip] -item bs 1
coverage exclude -scope /core/priv/priv/csr/csri -linerange [TagLine ${SRC}/privileged/csri.sv csri-write-sie] -item bs 1
ExcludeRows /core/priv/priv/csr/csrm e [list CSRMWriteM_1 "(CSRAdrM == 770)_1"]
ExcludeRows /core/priv/priv/csr/csrm e [list CSRMWriteM_1 "(CSRAdrM == 771)_1"]

# Every trap goes to M mode (there is no S mode to delegate to), so NextPrivilegeModeM is always M.
ExcludeRows /core/priv/priv/csr/csrsr c [list "(NextPrivilegeModeM == 3)_0"]
coverage exclude -scope /core/priv/priv/csr/csrsr -linerange [TagLine ${SRC}/privileged/csrsr.sv csrsr-trap-to-s] -item b 1

# The supervisor interrupt enables mie[9,5,1] are read-only zero (MIE_WRITE_MASK = 0x888), so no supervisor
# interrupt is ever valid; the privilege mode is never S and mstatus.SIE is tied to 0.
ExcludeRows /core/priv/priv/trap c [list {MIDELEG_REGW\[9\]_0} {MIDELEG_REGW\[9\]_1} {ValidIntsM\[9\]_1}]
ExcludeRows /core/priv/priv/trap c [list {MIDELEG_REGW\[1\]_0} {MIDELEG_REGW\[1\]_1} {ValidIntsM\[1\]_1}]
ExcludeRows /core/priv/priv/trap c [list {MIDELEG_REGW\[5\]_0} {MIDELEG_REGW\[5\]_1} {ValidIntsM\[5\]_1}]
ExcludeRows /core/priv/priv/trap e [list "(PrivilegeModeW == 1)_0" "(PrivilegeModeW == 1)_1" STATUS_SIE_0 STATUS_SIE_1]
coverage exclude -scope /core/priv/priv/trap -linerange [TagLine ${SRC}/privileged/trap.sv trap-sint-start]-[TagLine ${SRC}/privileged/trap.sv trap-sint-end] -code bs

# menvcfg.FIOM is writable only with S mode and virtual memory, so MENVCFG_REGW[0] is always 0.
ExcludeRows /core/priv/priv/csr e [list {MENVCFG_REGW\[0\]_1}]

######################################################################################################
# NOVM: no virtual memory (VIRTMEM_SUPPORTED = 0): no TLBs, no page table walker, sfence.vma illegal
######################################################################################################

# No page faults, page table walks (SelHPTW, HPTW faults, HPTWStall, HPTWFlushW), TLB misses or sfence.vma.
ExcludeRows /core/priv/priv/trap e {HPTWInstrAccessFaultM_1}
ExcludeRows /core/priv/priv/trap e {InstrPageFaultM_1 HPTWInstrPageFaultM_1}
coverage exclude -scope /core/priv/priv/trap -linerange [TagLine ${SRC}/privileged/trap.sv trap-instr-page-fault] -item bs 1
coverage exclude -scope /core/priv/priv/trap -linerange [TagLine ${SRC}/privileged/trap.sv trap-store-page-fault]-[TagLine ${SRC}/privileged/trap.sv trap-load-page-fault] -code bs
# Page faults are mcause 12, 13 and 15: case items 12 (on the "12, 1" line) and 13, 15 of the xtval selection.
coverage exclude -scope /core/priv/priv/csr -linerange [TagLine ${SRC}/privileged/csr.sv xtval-instr-fault] -item b 1
coverage exclude -scope /core/priv/priv/csr -linerange [TagLine ${SRC}/privileged/csr.sv xtval-data-fault] -item b 4 5
ExcludeRows /core/ifu c {ITLBMissOrUpdateRawF_1}
ExcludeRows /core/ifu e {sfencevmaM_1 StallMQ_0 StallMQ_1}
ExcludeRows /core/ifu e {sfencevmaAllM_1 StallMQ_0 StallMQ_1}
ExcludeRows /core/ifu e [list {ITLBWalkFaultHeldF\[1\]_1} HPTWInstrAccessFaultF_1]
ExcludeRows /core/ifu e [list {ITLBWalkFaultHeldF\[0\]_1} HPTWInstrPageFaultF_1]
ExcludeRows /core/ifu e {HPTWInstrAccessFaultHeldF_1 HPTWInstrPageFaultHeldF_1}
ExcludeRows /core/ifu e {ITLBMissOrUpdateRawF_1 ITLBWalkFaultF_0 ITLBWalkFaultF_1}
ExcludeRows /core/ifu e {InstrPageFaultF_1 ITLBWalkFaultF_1}
ExcludeRows /core/ifu e {ITLBMissOrUpdateAF_1}
ExcludeRows $IMMU e {TLBMiss_1} [TagLine ${SRC}/mmu/mmu.sv mmu-instr-fault]
ExcludeRows $DMMU e {TLBMiss_1} [TagLine ${SRC}/mmu/mmu.sv mmu-load-fault]
ExcludeRows $DMMU e {TLBMiss_1} [TagLine ${SRC}/mmu/mmu.sv mmu-store-fault]
ExcludeRows /core/lsu e {LoadPageFaultM_1 StoreAmoPageFaultM_1}
ExcludeRows /core/lsu e {SelHPTW_1 LSULoadPageFaultM_1 LSUStoreAmoPageFaultM_1}
ExcludeRows /core/lsu e {HPTWStall_1}
ExcludeRows /core/lsu e {HPTWFlushW_1}
ExcludeRows /core/lsu e {SelHPTW_1} [TagLine ${SRC}/lsu/lsu.sv lsu-gated-stall]
# CommittedM's walker term and the hold-access logic: MemAccessDoneM is tied to 0 without the walker
# (lsu.sv), so HoldAccessM = 0 and the read data mux always selects ReadDataM.  (DCacheCommittedM: NOCACHE.)
ExcludeRows /core/lsu e {SelHPTW_1 DCacheCommittedM_1 MemAccessDoneM_1}
ExcludeRows /core/lsu e {MemAccessDoneM_1 SelHPTW_0 SelHPTW_1} [TagLine ${SRC}/lsu/lsu.sv lsu-hold-access]
ExcludeRows /core/lsu c {HoldAccessM_1}
coverage exclude -scope /core/lsu/readdataselmux -linerange [TagLine ${SRC}/generic/mux.sv mux2] -item b 1
# Translation is disabled only for the walker or a D$ flush (FlushDCacheM, set only by fence.i: NOFENCEI).
ExcludeRows /core/lsu e {SelHPTW_1 FlushDCacheM_1}
# sfence.vma is illegal (sfencevmaM = 0), so its HPM event (21) never fires.
ExcludeRows $CNT e {sfencevmaM_1 InstrValidNotFlushedM_0 InstrValidNotFlushedM_1}
ExcludeGenRows $CNT cntr\[21\] e [list {MCOUNTINHIBIT_REGW\[21\]_0} {MCOUNTINHIBIT_REGW\[21\]_1} {CounterEvent\[21\]_1} {(MHPMEVENT_REGW\[21\] != 0)_*}]

######################################################################################################
# NOPMP: no PMP entries (PMP_ENTRIES = 0)
######################################################################################################

# The pmpaddr and pmpcfg read ranges PMPADDR0 <= adr < PMPADDR0 + 0 and PMPCFG0 <= adr < PMPCFG0 + 0 are empty.
ExcludeRows /core/priv/priv/csr/csrm c [list "(CSRAdrM >= 944)_1" "(CSRAdrM < (944 + 0))_1"]
ExcludeRows /core/priv/priv/csr/csrm c [list "(CSRAdrM >= 928)_1" "(CSRAdrM < (928 + (0 / 4)))_1"]
coverage exclude -scope /core/priv/priv/csr/csrm -linerange [TagLine ${SRC}/privileged/csrm.sv csrm-pmp-read-start]-[TagLine ${SRC}/privileged/csrm.sv csrm-pmp-read-end] -code bs

######################################################################################################
# NOFPU: no floating point (F_SUPPORTED = D_SUPPORTED = Q_SUPPORTED = ZFH_SUPPORTED = 0)
######################################################################################################

# No FP divider (FDivBusyE), FPU stall, FP-to-integer result (FWriteIntE, FCvtIntE), FP load/store size, or
# FP register / frm / fflags write (which would set mstatus.FS to dirty).
ExcludeRows $CNT e {FDivBusyE_1}
ExcludeRows /core/hzu e {FDivBusyE_1} [TagLine ${SRC}/hazard/hazard.sv hzu-stalle-cause]
ExcludeRows /core/hzu e {FPUStallD_1}
ExcludeRows /core/ieu/c e {FWriteIntE_1}
ExcludeRows /core/ieu/c e {FCvtIntE_1 MatchDE_0 MatchDE_1}
ExcludeRows /core/ieu/c e {FCvtIntStallD_1}
coverage exclude -scope /core/lsu -linerange [TagLine ${SRC}/lsu/lsu.sv lsu-fp-size] -item b 1
coverage exclude -scope /core/priv/priv/csr/csrsr -linerange [TagLine ${SRC}/privileged/csrsr.sv csrsr-fs-dirty] -item bs 1

# FlushECause: a divide mispredicted as a taken branch (BPWrongE & DivBusyE) needs a branch predictor
# (BPRED_SUPPORTED = 0, so BPWrongE = PCSrcE, never 1 for a divide); FDivBusyE needs an FPU.
ExcludeRows /core/hzu e {DivBusyE_1 FDivBusyE_1} [TagLine ${SRC}/hazard/hazard.sv hzu-flushe-cause]

######################################################################################################
# NOFENCEI and NOCACHE: no Zifencei (ZIFENCEI_SUPPORTED = 0) and no caches
######################################################################################################

# fence.i is illegal, so InvalidateICacheM = 0 and FenceXD = 0; the D$ and I$ stalls are 0.
ExcludeRows /core/ieu/c e {FenceXD_1}
ExcludeRows $CNT e {InvalidateICacheM_1 InstrValidNotFlushedM_0 InstrValidNotFlushedM_1}
ExcludeRows /core/lsu e {DCacheStallM_1}
ExcludeRows /core/ifu e {ICacheStallF_1}
# HBURST is nonzero only for cache line bursts.
ExcludeRows $ARB c [list {(HBURST\[2:1\] == 0)_0}]

######################################################################################################
# HPM events that cannot fire on rv32imc
######################################################################################################

# Events tied to 0: 9 (return address stack wrong: BPRED_SUPPORTED = 0, RASPredPCWrongM = 0), 13-18 (D$ and
# I$ events: no caches) and 20 (fence.i: NOFENCEI); 21 is under NOVM.  Events 25-31 have no source
# (CounterEvent[31:25] = 0 in every configuration).  Every row of these counters' increment needs the event.
ExcludeRows $CNT e {RASPredPCWrongM_1 InstrValidNotFlushedM_0 InstrValidNotFlushedM_1}
foreach i {9 13 14 15 16 17 18 20 25 26 27 28 29 30 31} {
    ExcludeGenRows $CNT cntr\[$i\] e [list "MCOUNTINHIBIT_REGW\\\[$i\\\]_0" "MCOUNTINHIBIT_REGW\\\[$i\\\]_1" "CounterEvent\\\[$i\\\]_1" "(MHPMEVENT_REGW\\\[$i\\\] != 0)_*"]
}
# MCYCLE's event (CounterEvent[0]) is tied to 1 and counter 1 (time) has no event (CounterEvent[1] = 0), in
# every configuration.
ExcludeGenRows $CNT cntr\[0\] e [list {CounterEvent\[0\]_0}]
ExcludeGenRows $CNT cntr\[1\] e [list {CounterEvent\[1\]_1} {MCOUNTINHIBIT_REGW\[1\]_0} {MCOUNTINHIBIT_REGW\[1\]_1}]
# mhpmcounter1 (0xB01) and mhpmcounter1h (0xB81) do not exist (time is not an M-mode counter): a write traps
# as an illegal instruction, which flushes Writeback, so CSRMWriteM is never asserted with those addresses.
ExcludeGenRows $CNT cntr\[1\] e [list CSRMWriteM_1 "(CSRAdrM == (2816 + 1))_1"]
ExcludeGenRows $CNT cntr\[1\] e [list CSRMWriteM_1 "(CSRAdrM == (2944 + 1))_1"]
coverage exclude -scope $CNT/cntr\[1\] -linerange [TagLine ${SRC}/privileged/csrc.sv next-hpmcounter] -item b 1
coverage exclude -scope $CNT/cntr\[1\] -linerange [TagLine ${SRC}/privileged/csrc.sv next-hpmcounterh] -item b 1

# COUNTERS = 32: all 29 event selectors and all 32 counters exist, so the "absent selector/counter reads zero"
# ranges are empty: MHPMEVENTBASE + COUNTERS - 3 is past the last selector, and base + COUNTERS <= adr <
# base + 32 is empty for mhpmcounter, hpmcounter, mhpmcounterh and hpmcounterh.
ExcludeRows $CNT c [list "(CSRAdrM < ((803 + 32) - 3))_0"]
ExcludeRows $CNT c [list "(CSRAdrM >= (2816 + 32))_1" "(CSRAdrM < (2816 + 32))_1"]
ExcludeRows $CNT c [list CSRWriteM_0 CSRWriteM_1 "(CSRAdrM >= (3072 + 32))_1" "(CSRAdrM < (3072 + 32))_1"]
ExcludeRows $CNT c [list "(CSRAdrM >= (2944 + 32))_1" "(CSRAdrM < (2944 + 32))_1"]
ExcludeRows $CNT c [list CSRWriteM_0 CSRWriteM_1 "(CSRAdrM >= (3200 + 32))_1" "(CSRAdrM < (3200 + 32))_1"]
foreach tag {unused-event-zero unused-mhpmcounter-range unused-mhpmcounter-zero unused-hpmcounter-range unused-hpmcounter-zero
             unused-mhpmcounterh-range unused-mhpmcounterh-zero unused-hpmcounterh-range unused-hpmcounterh-zero} {
    coverage exclude -scope $CNT -linerange [TagLine ${SRC}/privileged/csrc.sv $tag] -code bs
}

######################################################################################################
# MMU tie-offs and region decoders
######################################################################################################

# The IMMU checks only fetches: ifu.sv ties its ReadAccessM = WriteAccessM = 0, CMOpM = 0,
# AtomicAccessM = 0, ExecuteAccessF = 1 and Size = word.  So it never makes a read, write, atomic or CMO
# check, never raises a load/store or misaligned data fault, and selects only regions whose access type
# includes execute.  Fetch addresses are halfword aligned (VAdr[0] = 0).
ExcludeRows $IMMU/pmachecker e {ReadAccessM_1 WriteAccessM_1} [TagLine ${SRC}/mmu/pmachecker.sv pma-access-rw]
ExcludeRows $IMMU/pmachecker e {ReadAccessM_0 ReadAccessM_1 WriteAccessM_0 WriteAccessM_1 ExecuteAccessF_0 |CMOpM_0 |CMOpM_1}
ExcludeRows $IMMU/pmachecker e {ReadAccessM_0 ReadAccessM_1 ExecuteAccessF_0} [TagLine ${SRC}/mmu/pmachecker.sv pma-access-rx]
ExcludeRows $IMMU/pmachecker e {AccessRWXC_0 AtomicAccessM_1 AtomicAllowed_0 AtomicAllowed_1}
ExcludeRows $IMMU/pmachecker e {ExecuteAccessF_0} [TagLine ${SRC}/mmu/pmachecker.sv pma-instr-fault]
ExcludeRows $IMMU/pmachecker e {WriteAccessM_0 WriteAccessM_1 ReadAccessM_1 PMAAccessFault_0 PMAAccessFault_1}
ExcludeRows $IMMU/pmachecker e {WriteAccessM_1 |CMOpM_1 PMAAccessFault_0 PMAAccessFault_1}
ExcludeRows $IMMU e {ReadAccessM_1 WriteAccessM_0 WriteAccessM_1}
ExcludeRows $IMMU e [list {VAdr\[0\]_1}]
ExcludeRows $IMMU e {DataMisalignedM_0 DataMisalignedM_1 ReadNoAmoAccessM_1}
ExcludeRows $IMMU e {DataMisalignedM_0 DataMisalignedM_1 WriteAccessM_1}
ExcludeRows $IMMU e {PMALoadAccessFaultM_1 TLBMiss_0 TLBMiss_1}
ExcludeRows $IMMU e {PMAStoreAmoAccessFaultM_1 TLBMiss_0 TLBMiss_1}
foreach tag {mmu-size-byte mmu-size-half mmu-size-double} {
    coverage exclude -scope $IMMU -linerange [TagLine ${SRC}/mmu/mmu.sv $tag] -item bs 1
}
# The DMMU checks only loads and stores: lsu.sv ties its ExecuteAccessF = 0, so it never makes an execute
# check or raises an instruction access fault.
ExcludeRows $DMMU/pmachecker e {ExecuteAccessF_1} [TagLine ${SRC}/mmu/pmachecker.sv pma-access-rx]
ExcludeRows $DMMU/pmachecker e {ExecuteAccessF_1 PMAAccessFault_0 PMAAccessFault_1}
ExcludeRows $DMMU e {PMAInstrAccessFaultF_1 TLBMiss_0 TLBMiss_1}

# Region decoders: Sel = Match & Supported & AccessValid & SizeValid, where Supported is a configuration
# constant.  Supported_0 cannot be reached for a supported region, and no row but Supported_0 can be reached
# for an unsupported one (ddr4dec = external memory, boot ROM, uncore RAM, SD card).
foreach mmu [list $IMMU $DMMU] {
    foreach dec {dtimdec iromdec clintdec gpiodec plicdec spidec pwmdec} {
        ExcludeRows $mmu/pmachecker/adrdecs/$dec e {Supported_0}
    }
    foreach dec {ddr4dec bootromdec uncoreramdec sdcdec} {
        ExcludeRows $mmu/pmachecker/adrdecs/$dec e {Match_0 Match_1 Supported_1 AccessValid_0 AccessValid_1 SizeValid_0 SizeValid_1}
    }
}
ExcludeRows $DMMU/pmachecker/adrdecs/uartdec e {Supported_0}
# In the IMMU the read/write-only regions (DTIM and peripherals) see AccessValid = AccessRW = 0, so only
# their AccessValid_0 row can be reached.  The IROM sees AccessValid = AccessRX = 1 and a word access, which
# its size mask admits.  The SD card region is unsupported and read/write only, so even its Supported_0 row
# needs AccessValid = 1.  The UART admits only byte accesses, and fetches are words, so its Sel is
# constant 0 and none of its rows can be reached.
foreach dec {dtimdec clintdec gpiodec plicdec spidec pwmdec} {
    ExcludeRows $IMMU/pmachecker/adrdecs/$dec e {Match_0 Match_1 Supported_1 AccessValid_1 SizeValid_0 SizeValid_1}
}
ExcludeRows $IMMU/pmachecker/adrdecs/iromdec e {AccessValid_0 SizeValid_0}
ExcludeRows $IMMU/pmachecker/adrdecs/sdcdec e {Supported_0}
ExcludeRows $IMMU/pmachecker/adrdecs/uartdec e {Match_0 Match_1 Supported_0 Supported_1 AccessValid_0 AccessValid_1 SizeValid_0 SizeValid_1}
# The external memory, boot ROM and uncore RAM regions are absent (SelRegions[3], [4], [5] = 0).  The DTIM
# and IROM share one address range, so a load or store that selects the IROM always selects the DTIM too
# (DMMU SelRegions[2] alone never happens), and the IMMU never selects the read/write-only DTIM
# (IMMU SelRegions[1] = 0).
foreach mmu [list $IMMU $DMMU] {
    ExcludeRows $mmu/pmachecker e [list {SelRegions\[3\]_1} {SelRegions\[4\]_1} {SelRegions\[5\]_1}] [TagLine ${SRC}/mmu/pmachecker.sv unused-cacheable]
}
ExcludeRows $IMMU/pmachecker e [list {SelRegions\[1\]_1} {SelRegions\[3\]_1} {SelRegions\[4\]_1} {SelRegions\[5\]_1}]
ExcludeRows $IMMU/pmachecker e [list {SelRegions\[1\]_1} {SelRegions\[3\]_1} {SelRegions\[5\]_1}] [TagLine ${SRC}/mmu/pmachecker.sv unused-atomic]
ExcludeRows $IMMU/pmachecker e [list {SelRegions\[1\]_1}] [TagLine ${SRC}/mmu/pmachecker.sv unused-tim]
ExcludeRows $DMMU/pmachecker e [list {SelRegions\[2\]_1} {SelRegions\[3\]_1} {SelRegions\[4\]_1} {SelRegions\[5\]_1}]
ExcludeRows $DMMU/pmachecker e [list {SelRegions\[3\]_1} {SelRegions\[5\]_1}] [TagLine ${SRC}/mmu/pmachecker.sv unused-atomic]
ExcludeRows $DMMU/pmachecker e [list {SelRegions\[2\]_1}] [TagLine ${SRC}/mmu/pmachecker.sv unused-tim]

######################################################################################################
# Structural: unreachable in every configuration with this microarchitecture
######################################################################################################

# C extension (ZCA_SUPPORTED = 1): IALIGN = 16, so every branch or jump target is a legal instruction address
# and InstrMisalignedFaultE = IEUAdrE[1] & ~ZCA_SUPPORTED is 0.  The three page-fault rows of the same
# expression are NOVM.
ExcludeRows /core/priv/priv/trap e {InstrMisalignedFaultM_1 BothInstrPageFaultM_1 LoadPageFaultM_1 StoreAmoPageFaultM_1}

# The wfi wait counter clears whenever M advances, and M holds the same instruction while stalled, so the
# counter reaches its limit only with the wfi still in M: wfiM_0 never sees the counter's top bit set.
ExcludeRows /core/priv/priv/pmd e {wfiM_0} [TagLine ${SRC}/privileged/privdec.sv pmd-tw-timeout]

# StallFCause = 0, so StallF = StallD and LatestUnstalledD = ~StallD & StallF is always 0.
ExcludeRows /core/hzu e {StallD_0 StallF_1}
ExcludeRows /core/hzu e {LatestUnstalledD_1}

# reset_1 rows need Fetch stalled while reset is asserted.  Nothing stalls Fetch during reset on rv32imc:
# there is no I$, the bus FSMs, divider and spill FSM are held in reset, and no wfi is in Memory.
ExcludeRows /core/ifu c {reset_1}
ExcludeRows /core/ifu e {reset_1} [TagLine ${SRC}/ifu/ifu.sv ifu-irom-ce]
ExcludeRows /core/ifu e {reset_1} [TagLine ${SRC}/ifu/ifu.sv ifu-pc-enable]

# Integer divider FSM.  While BUSY the divide holds Execute (StallE), so Memory holds a bubble that cannot
# trap, return or write a CSR, and a misprediction flush of Execute is masked by DivBusyE: FlushE never
# arrives in BUSY, so BUSY never returns straight to IDLE.  A divide starts (DivStartE) only from IDLE, so
# DONE never goes straight to BUSY.
coverage exclude -scope /core/mdu/mdu/div/div -ftrans state BUSY->IDLE DONE->BUSY
