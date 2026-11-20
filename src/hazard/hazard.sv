///////////////////////////////////////////
// hazard.sv
//
// Written:  David Harris David_Harris@hmc.edu 9 January 2021
// Modified: Rose Thompson, Katherine Parry, Jarred Allen
//
// Purpose: Pipeline stall and flush control.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module hazard (
  input  logic BPWrongE, CSRWriteFenceM, Replay1M, RetM, TrapM,
  input  logic BPRedirectD,            // Decode-stage branch prediction redirects fetch
  input  logic MemFault1M,             // slot 1's memory access faulted: its LSU stall is for a squashed access
  input  logic LateBrWrongM,           // a branch resolved in Memory went the other way from fetch
  input  logic StructuralStallD,
  input  logic LSUStallM, IFUStallF,
  input  logic FPUStallD, ExternalStall,
  input  logic DivBusyE, FDivBusyE,
  input  logic  WaitM,                 // wfi in M is waiting for an interrupt
  // Stall & flush outputs
  output logic StallF, StallD, StallE, StallM, StallW,
  output logic FlushD, FlushE, FlushM, FlushW
);

  logic StallFCause, StallDCause, StallECause, StallMCause, StallWCause;
  logic LatestUnstalledD, LatestUnstalledE, LatestUnstalledM;
  logic FlushDCause, FlushECause, FlushMCause, FlushWCause;

  // stalls and flushes
  // loads: stall for one cycle if the subsequent instruction depends on the load
  // branches and jumps: flush the next two instructions if the branch is mispredicted in the Execute stage
  // CSR Writes: stall all instructions after the CSR until it completes, except that PC must change when branch is resolved
  //             this also applies to other privileged instructions such as M/S/URET, ECALL/EBREAK
  // Exceptions: flush entire pipeline
  // Ret instructions: occur in M stage.  Might be possible to move earlier, but be careful about hazards

  // General stall and flush rules:
  // A stage must stall if the next stage is stalled
  // If any stages are stalled, the first stage that isn't stalled must flush.

  // Flush causes
  // Traps (TrapM) flush the entire pipeline, including W: the trapping instruction does not retire.
  //   This includes ecall and ebreak, which are not considered to retire (privileged spec, Environment Call and Breakpoint).
  // Trap returns (RetM) also flush the entire pipeline after the RetM (all stages except W) because all the subsequent instructions must be discarded.
  // Similarly, CSR writes and fences flush all subsequent instructions and refetch them in light of the new operating modes and cache/TLB contents
  // Branch misprediction is found in the Execute stage and must flush the next two instructions.
  //   However, an active division operation resides in the Execute stage, and when the BP incorrectly mispredicts the divide as a taken branch, the divide must still complete
  // A superscalar replay (Replay1M) discards everything fetched after the bundle and refetches from
  // slot 1's own PC, so it flushes exactly what a CSR write or fence does: D, E and M but not W.
  // Leaving W alone is the point -- slot 0 is architecturally before the faulting slot 1 and completed,
  // so it must still commit, just as a CSR write commits while the instructions behind it are flushed.
  // A branch resolved in Memory (LateBrWrongM) that fetch got wrong discards the same three stages, for
  // the same reason; slot 1 beside it, in Memory, is abandoned through Issue1W rather than FlushW.  Unlike
  // an Execute-stage misprediction, a divide already busy in Execute is behind the branch and wrong-path.
  assign FlushDCause = TrapM | RetM | CSRWriteFenceM | Replay1M | LateBrWrongM | BPWrongE;
  assign FlushECause = TrapM | RetM | CSRWriteFenceM | Replay1M | LateBrWrongM | (BPWrongE & ~(DivBusyE | FDivBusyE)); // exclusion-tag: hzu-flushe-cause
  assign FlushMCause = TrapM | RetM | CSRWriteFenceM | Replay1M | LateBrWrongM;
  assign FlushWCause = TrapM;

  // Stall causes
  //  Most data dependency stalls are identified in the decode stage
  //  Division stalls in the execute stage
  //  Flushing any stage has priority over the corresponding stage stall.
  //    Even if the register gave clear priority over enable, various FSMs still need to disable the stall, so it's best to gate the stall here with flush
  //  The IFU and LSU stall the entire pipeline on a cache miss, bus access, or other long operation.
  //    The IFU stalls the entire pipeline rather than just Fetch to avoid complications with instructions later in the pipeline causing Exceptions
  //    A trap could be asserted at the start of an IFU/LSU stall, and should flush the memory operation
  //  A waiting wfi in M (WaitM) stalls the entire pipeline in the same way, so the instruction in W keeps forwarding
  assign StallFCause = 1'b0;
  assign StallDCause = (StructuralStallD | FPUStallD) & ~FlushDCause;
  assign StallECause = (DivBusyE | FDivBusyE) & ~FlushECause; // exclusion-tag: hzu-stalle-cause
  assign StallMCause = 1'b0;
  // Need to gate IFUStallF when the equivalent FlushFCause = FlushDCause = 1.
  // assign StallWCause = ((IFUStallF & ~FlushDCause) | LSUStallM) & ~FlushWCause;
  // Because FlushWCause is a strict subset of FlushDCause, FlushWCause is factored out.
  // A slot 1 memory fault squashes its own access, so its LSU stall is ignored as a trap's is; only the
  // LSU stall, because a fault here means slot 1 holds the bundle's one memory operation.
  assign StallWCause = (IFUStallF & ~FlushDCause) | (((LSUStallM & ~MemFault1M) | WaitM) & ~FlushWCause) | ExternalStall;

  // Stall each stage for cause or if the next stage is stalled
  // coverage off: StallFCause is always 0
  assign StallF = StallFCause | StallD;
  // coverage on
  assign StallD = StallDCause | StallE;
  assign StallE = StallECause | StallM;
  // coverage off: StallMCause is always 0
  assign StallM = StallMCause | StallW;
  // coverage on
  assign StallW = StallWCause;

  // detect the first stage that is not stalled

  assign LatestUnstalledD = ~StallD & StallF; // coverage tag: StallD always equals StallF
  assign LatestUnstalledE = ~StallE & StallD;
  assign LatestUnstalledM = ~StallM & StallE;

  // Each stage flushes if the previous stage is the last one stalled (for cause) or the system has reason to flush
  assign FlushD = LatestUnstalledD | FlushDCause | BPRedirectD; // coverage tag: LatestUnstalledD always 0
  assign FlushE = LatestUnstalledE | FlushECause;
  assign FlushM = LatestUnstalledM | FlushMCause;
  assign FlushW = FlushWCause;
endmodule
