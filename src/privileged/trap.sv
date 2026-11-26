///////////////////////////////////////////
// trap.sv
//
// Written:  David Harris David_Harris@hmc.edu 9 January 2021
// Modified: Domenico Ottolia dottolia@hmc.edu, Rose Thompson, Ben Bracker, Jinghe Yu, Kip Macsai-Goren, Thomas Fleming
//
// Purpose: Exception and interrupt prioritization.
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

module trap import cvw::*; #(parameter cvw_t P) (
  input  logic                 reset,
  input  logic                 InstrMisalignedFaultM, InstrAccessFaultM, HPTWInstrAccessFaultM, HPTWInstrPageFaultM, IllegalInstrFaultM,
  input  logic                 BreakpointFaultM, LoadMisalignedFaultM, StoreAmoMisalignedFaultM,
  input  logic                 LoadAccessFaultM, StoreAmoAccessFaultM, EcallFaultM, InstrPageFaultM,
  input  logic                 LoadPageFaultM, StoreAmoPageFaultM, VirtualInstrFaultM, // various trap sources
  input  logic                 WaitedM,                                         // wfi in M has waited: it retires before an interrupt
  input  logic [1:0]           PrivilegeModeW,                                  // current privilege mode
  input  logic                 VirtModeW,                                       // current V
  input  logic [15:0]          MIP_REGW, MIE_REGW, MIDELEG_REGW,                // interrupt pending, enabled, and delegate CSRs
  input  logic [63:0]          MEDELEG_REGW,                                    // exception delegation SR
  input  logic [63:0]          HEDELEG_REGW,                                    // HS->VS exception delegation
  input  logic [15:0]          HIDELEG_REGW,                                    // HS->VS interrupt delegation
  input  logic                 STATUS_MIE, STATUS_SIE, VSSTATUS_SIE,            // machine/HS/VS interrupt enables
  input  logic                 InstrValidM,                                     // current instruction is valid, not flushed
  input  logic                 CommittedM, CommittedF,                          // LSU/IFU has committed to a bus operation that can't be interrupted
  output logic                 TrapM,                                           // Trap is occurring
  output logic                 InterruptM,                                      // Interrupt is occurring
  output logic                 ExceptionM,                                      // exception is occurring
  output logic                 IntPendingM,                                     // Interrupt is pending, might occur if enabled
  output logic [4:0]           CauseM,                                          // trap cause
  output logic                 TrapToM, TrapToHSM, TrapToVSM
);

  logic                        MIntGlobalEnM, HSIntGlobalEnM, VSIntGlobalEnM;   // Global interrupt enables
  logic                        Committed;                                       // LSU or IFU has committed to a bus operation that can't be interrupted
  logic                        BothInstrAccessFaultM, BothInstrPageFaultM;      // instruction or HPTW ITLB fill caused an Instruction Access Fault
  logic [15:0]                 PendingIntsM, ValidIntsM;                        // interrupts are pending, or pending, enabled, and chosen target
  logic [15:0]                 MEnabledIntsM, HSEnabledIntsM, VSEnabledIntsM;   // interrupt sets by target mode
  logic                        IntToMM, IntToHSM;                               // target of the interrupt taken
  // TODO: Add cause priority for LCOFI when that interrupt source is implemented.
  logic                        DelegateM, DelegateToVSM;                        // trap delegated to HS (or S) / from HS to VS
  logic [5:0]                  CauseIdxM;                                      // cause index for 64-bit delegation CSRs

  ///////////////////////////////////////////
  // Determine pending enabled interrupts
  // interrupt if any sources are pending
  // & with a M stage valid bit to avoid interrupting a nonexistent flushed instruction (in the M stage)
  // & with ~CommittedM to make sure MEPC isn't chosen so as to rerun the same instr twice
  ///////////////////////////////////////////

  assign CauseIdxM      = {1'b0, CauseM};
  assign MIntGlobalEnM  = (PrivilegeModeW != P.M_MODE) | STATUS_MIE; // if M ints enabled or lower priv 3.1.9
  assign PendingIntsM = MIP_REGW & MIE_REGW;
  assign IntPendingM   = |PendingIntsM;
  assign Committed     = CommittedM | CommittedF; // exclusion-tag: trap-committed
  if (P.H_SUPPORTED) begin: enabledints_h
    // HS interrupts are always enabled at V=1 and in U; VS interrupts only at V=1 (V=1 implies VS or VU).
    assign HSIntGlobalEnM = (PrivilegeModeW == P.U_MODE) |
                            ((PrivilegeModeW == P.S_MODE) & (VirtModeW | STATUS_SIE));
    assign VSIntGlobalEnM = VirtModeW & ((PrivilegeModeW == P.U_MODE) | VSSTATUS_SIE);
    assign HSEnabledIntsM = HSIntGlobalEnM ? PendingIntsM &  MIDELEG_REGW & ~HIDELEG_REGW : '0;
    assign VSEnabledIntsM = VSIntGlobalEnM ? PendingIntsM &  MIDELEG_REGW &  HIDELEG_REGW : '0;
  end else begin: enabledints_noh
    assign HSIntGlobalEnM = (PrivilegeModeW == P.U_MODE) | ((PrivilegeModeW == P.S_MODE) & STATUS_SIE);
    assign VSIntGlobalEnM = 1'b0;
    assign HSEnabledIntsM = HSIntGlobalEnM ? PendingIntsM &  MIDELEG_REGW : '0;
    assign VSEnabledIntsM = '0;
  end
  assign MEnabledIntsM  = MIntGlobalEnM  ? PendingIntsM & ~MIDELEG_REGW : '0;

  // Interrupts to a more privileged mode are taken first (machine.adoc norm:intr_M_mode_pri note),
  // so the interrupt taken targets the most privileged mode with an enabled interrupt.
  assign IntToMM  = |MEnabledIntsM;
  assign IntToHSM = ~IntToMM & |HSEnabledIntsM;
  // Suppress interrupts if the memory system has partially processed a request, or if a wfi
  // in M has waited: it then retires and the interrupt is taken on the next instruction (mepc = pc + 4).
  // Gating ValidIntsM rather than InterruptM keeps CauseM consistent when the wait ends in an exception.
  assign ValidIntsM    = (Committed | WaitedM) ? '0 :
                         IntToMM ? MEnabledIntsM : IntToHSM ? HSEnabledIntsM : VSEnabledIntsM;
  assign InterruptM    = (|ValidIntsM) & InstrValidM;

  // Trap target one-hots.  An interrupt's target is known from the set it came from; an
  // exception is delegated by medeleg (and from HS to VS by hedeleg) when taken below M.
  assign DelegateM     = InterruptM ? ~IntToMM :
                         P.S_SUPPORTED & MEDELEG_REGW[CauseIdxM] & ((PrivilegeModeW == P.U_MODE) | (PrivilegeModeW == P.S_MODE));
  if (P.H_SUPPORTED) begin: trapto_vs_h
    assign DelegateToVSM = InterruptM ? ~IntToMM & ~IntToHSM : VirtModeW & DelegateM & HEDELEG_REGW[CauseIdxM];
  end else begin: trapto_vs_noh
    assign DelegateToVSM = 1'b0;
  end
  assign TrapToVSM     = TrapM & DelegateToVSM;
  assign TrapToHSM     = TrapM & DelegateM & ~DelegateToVSM;
  assign TrapToM       = TrapM & ~DelegateM;

  ///////////////////////////////////////////
  // Trigger Traps
  // According to RISC-V Spec Section 1.6, exceptions are caused by instructions.  Interrupts are external asynchronous.
  // Traps are the union of exceptions and interrupts.
  ///////////////////////////////////////////

  assign BothInstrAccessFaultM = InstrAccessFaultM | HPTWInstrAccessFaultM;
  assign BothInstrPageFaultM = InstrPageFaultM | HPTWInstrPageFaultM;
  // coverage off -item e 1 -fecexprrow 2
  // excludes InstrMisalignedFaultM from coverage of this line, since misaligned instructions cannot occur in rv64gc.
  // privdec ties VirtualInstrFaultM to 0 without H.
  assign ExceptionM = InstrMisalignedFaultM | BothInstrAccessFaultM | IllegalInstrFaultM |
                      LoadMisalignedFaultM | StoreAmoMisalignedFaultM |
                      BothInstrPageFaultM | LoadPageFaultM | StoreAmoPageFaultM |
                      BreakpointFaultM | EcallFaultM | VirtualInstrFaultM |
                      LoadAccessFaultM | StoreAmoAccessFaultM;
  // coverage on
  // An exception waits, like an interrupt, while the IFU has a committed I$ fill or bus fetch (CommittedF):
  // trapping would flush the fetch partway through its AHB transaction (issues #412, #845).  Only the LSU
  // can raise an exception after the fetch commits (a page table walk fault, a fault found once the walk
  // fills the DTLB, or a fault on the second half of a misaligned access); any other exception is present
  // before the fetch commits and traps then.  The wait is safe: CommittedF implies IFUStallF, so the instruction stays in M;
  // its own access is squashed (lsu.sv SelfFaultM), a misaligned access does not start its spill (align.sv
  // DataFaultM), and the walker holds its fault (hptw.sv FAULT) until the trap is taken.
  assign TrapM = (ExceptionM & ~CommittedF) | InterruptM; // exclusion-tag: trap-trapm

  ///////////////////////////////////////////
  // Cause priority defined in privileged spec
  ///////////////////////////////////////////

  always_comb
    if      (reset)                                               CauseM = 5'd0; // hard reset 3.3
    // Within each target mode: MEI, MSI, MTI, SEI, SSI, STI, SGEI, VSEI, VSSI, VSTI (norm:intr_M_mode_pri, norm:hsint_priority)
    else if (ValidIntsM[11])                                      CauseM = 5'd11; // Machine External Int
    else if (ValidIntsM[3])                                       CauseM = 5'd3;  // Machine Sw Int
    else if (ValidIntsM[7])                                       CauseM = 5'd7;  // Machine Timer Int
    else if (ValidIntsM[9])                                       CauseM = 5'd9;  // Supervisor External Int // exclusion-tag: trap-sint-start
    else if (ValidIntsM[1])                                       CauseM = 5'd1;  // Supervisor Sw Int
    else if (ValidIntsM[5])                                       CauseM = 5'd5;  // Supervisor Timer Int // exclusion-tag: trap-sint-end
    else if (P.H_SUPPORTED & ValidIntsM[12])                      CauseM = 5'd12; // Supervisor Guest External Int
    else if (P.H_SUPPORTED & ValidIntsM[10])                      CauseM = 5'd10; // Virtual Supervisor External Int
    else if (P.H_SUPPORTED & ValidIntsM[2])                       CauseM = 5'd2;  // Virtual Supervisor Software Int
    else if (P.H_SUPPORTED & ValidIntsM[6])                       CauseM = 5'd6;  // Virtual Supervisor Timer Int
    else if (BothInstrPageFaultM)                                 CauseM = 5'd12; // Instruction page fault // exclusion-tag: trap-instr-page-fault
    else if (BothInstrAccessFaultM)                               CauseM = 5'd1;  // Instruction access fault
    else if (P.H_SUPPORTED & VirtualInstrFaultM)                  CauseM = 5'd22; // Virtual Instruction Fault
    else if (IllegalInstrFaultM)                                  CauseM = 5'd2;  // Illegal instruction
    // coverage off
    // Misaligned instructions cannot occur in rv64gc
    else if (InstrMisalignedFaultM)                               CauseM = 5'd0;  // Instruction address misaligned
    // coverage on
    else if (BreakpointFaultM)                                    CauseM = 5'd3;  // Breakpoint
    else if (EcallFaultM)                                         CauseM = (P.H_SUPPORTED & VirtModeW & (PrivilegeModeW == P.S_MODE)) ? 5'd10
                                                                                                                  : {3'b010, PrivilegeModeW}; // Ecall: 8 from U, 9 from S, 10 from VS, 11 from M
    else if (StoreAmoMisalignedFaultM & ~P.ZICCLSM_SUPPORTED)     CauseM = 5'd6;  // misaligned faults are higher priority if they always are taken
    else if (LoadMisalignedFaultM & ~P.ZICCLSM_SUPPORTED)         CauseM = 5'd4;  // Load address misaligned
    // TODO: Add guest-page-fault cause generation (20/21/23) when two-stage translation fault signals are integrated.
    else if (StoreAmoPageFaultM)                                  CauseM = 5'd15; // Store/AMO page fault // exclusion-tag: trap-store-page-fault
    else if (LoadPageFaultM)                                      CauseM = 5'd13; // Load page fault // exclusion-tag: trap-load-page-fault
    else if (StoreAmoAccessFaultM)                                CauseM = 5'd7;  // Store/AMO access fault
    else if (LoadAccessFaultM)                                    CauseM = 5'd5;  // Load access fault
    else if (StoreAmoMisalignedFaultM & P.ZICCLSM_SUPPORTED)      CauseM = 5'd6; // See priority in Privileged Spec 3.1.15
    else if (LoadMisalignedFaultM & P.ZICCLSM_SUPPORTED)          CauseM = 5'd4;
    else                                                          CauseM = 5'd0;
endmodule
