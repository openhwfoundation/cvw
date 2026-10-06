///////////////////////////////////////////
// trap.sv
//
// Written: David_Harris@hmc.edu 9 January 2021
// Modified: dottolia@hmc.edu 14 April 2021: Add support for vectored interrupts
//
// Purpose: Handle Traps: Exceptions and Interrupts
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

module trap import cvw::*;  #(parameter cvw_t P) (
  input  logic                 reset,
  input  logic                 InstrMisalignedFaultM, InstrAccessFaultM, HPTWInstrAccessFaultM, HPTWInstrPageFaultM, IllegalInstrFaultM,
  input  logic                 BreakpointFaultM, LoadMisalignedFaultM, StoreAmoMisalignedFaultM,
  input  logic                 LoadAccessFaultM, StoreAmoAccessFaultM, EcallFaultM, InstrPageFaultM,
  input  logic                 LoadPageFaultM, StoreAmoPageFaultM, VirtualInstrFaultM, // various trap sources
  input  logic                 wfiM, wfiW,                                      // wait for interrupt instruction
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
  output logic                 DelegateM,                                       // Delegate trap to supervisor handler
  output logic [4:0]           CauseM,                                          // trap cause
  output logic                 TrapToM, TrapToHSM, TrapToVSM
);

  logic                        MIntGlobalEnM, HSIntGlobalEnM, VSIntGlobalEnM;   // Global interrupt enables
  logic                        Committed;                                       // LSU or IFU has committed to a bus operation that can't be interrupted
  logic                        BothInstrAccessFaultM, BothInstrPageFaultM;      // instruction or HPTW ITLB fill caused an Instruction Access Fault
  logic [15:0]                 PendingIntsM, ValidIntsM, EnabledIntsM;          // interrupts are pending, valid, or enabled
  logic [15:0]                 MEnabledIntsM, HSEnabledIntsM, VSEnabledIntsM;   // interrupt sets by target mode
  // TODO: Add cause priority for LCOFI when that interrupt source is implemented.
  logic                        DelegateToVSM;                                  // trap delegated from HS to VS
  logic [5:0]                  CauseIdxM;                                      // cause index for 64-bit delegation CSRs
  logic                        HidelegHitM, HedelegHitM;

  ///////////////////////////////////////////
  // Determine pending enabled interrupts
  // interrupt if any sources are pending
  // & with a M stage valid bit to avoid interrupts from interrupt a nonexistent flushed instruction (in the M stage)
  // & with ~CommittedM to make sure MEPC isn't chosen so as to rerun the same instr twice
  ///////////////////////////////////////////

  assign CauseIdxM      = {1'b0, CauseM};
  assign MIntGlobalEnM  = (PrivilegeModeW != P.M_MODE) | STATUS_MIE; // if M ints enabled or lower priv 3.1.9
  assign PendingIntsM = MIP_REGW & MIE_REGW;
  assign IntPendingM   = |PendingIntsM;
  assign Committed     = CommittedM | CommittedF;
  if (P.H_SUPPORTED) begin: enabledints_h
    // HS traps use sstatus.SIE only in HS; VS traps use vsstatus.SIE only in VS.
    assign HSIntGlobalEnM = (PrivilegeModeW == P.U_MODE) |
                            ((PrivilegeModeW == P.S_MODE) & (VirtModeW | STATUS_SIE));
    assign VSIntGlobalEnM = VirtModeW &
                            ((PrivilegeModeW == P.U_MODE) |
                             ((PrivilegeModeW == P.S_MODE) & VSSTATUS_SIE));
    assign MEnabledIntsM  = MIntGlobalEnM  ? PendingIntsM & ~MIDELEG_REGW                 : '0;
    assign HSEnabledIntsM = HSIntGlobalEnM ? PendingIntsM &  MIDELEG_REGW & ~HIDELEG_REGW : '0;
    assign VSEnabledIntsM = VSIntGlobalEnM ? PendingIntsM &  MIDELEG_REGW &  HIDELEG_REGW : '0;
    assign EnabledIntsM   = MEnabledIntsM | HSEnabledIntsM | VSEnabledIntsM;
  end else begin: enabledints_noh
    assign HSIntGlobalEnM = (PrivilegeModeW == P.U_MODE) | ((PrivilegeModeW == P.S_MODE) & STATUS_SIE);
    assign VSIntGlobalEnM = 1'b0;
    assign MEnabledIntsM  = MIntGlobalEnM  ? PendingIntsM & ~MIDELEG_REGW : '0;
    assign HSEnabledIntsM = HSIntGlobalEnM ? PendingIntsM &  MIDELEG_REGW : '0;
    assign VSEnabledIntsM = '0;
    assign EnabledIntsM   = MEnabledIntsM | HSEnabledIntsM;
  end
  assign ValidIntsM    = Committed ? '0 : EnabledIntsM;
  assign InterruptM    = (|ValidIntsM) & InstrValidM & (~wfiM | wfiW); // suppress interrupt if the memory system has partially processed a request. Delay interrupt until wfi is in the W stage.
  // wfiW is to support possible but unlikely back to back wfi instructions. wfiM would be high in the M stage, while also in the W stage.
  if (P.H_SUPPORTED) begin: deleg_h
    /* verilator lint_off WIDTHTRUNC */
    assign DelegateM = P.S_SUPPORTED & (InterruptM ? ((CauseM < 16) ? MIDELEG_REGW[CauseM] : 1'b0)
                                                    : MEDELEG_REGW[CauseIdxM]) &
                        ((PrivilegeModeW == P.U_MODE) | (PrivilegeModeW == P.S_MODE));
    /* verilator lint_on WIDTHTRUNC */
  end else begin: deleg_noh
    assign DelegateM = P.S_SUPPORTED & (InterruptM ? MIDELEG_REGW[CauseM[3:0]] : MEDELEG_REGW[CauseIdxM]) &
                       ((PrivilegeModeW == P.U_MODE) | (PrivilegeModeW == P.S_MODE));
  end
  // Trap target one-hots.
  // With H: select M/HS/VS trap entry. Without H: TrapToVSM is tied low, a delegated trap is an
  // S-mode trap (TrapToHSM), and TrapToM marks the traps that are not delegated.
  if (P.H_SUPPORTED) begin: trapto_vs_h
    /* verilator lint_off WIDTHTRUNC */
    assign HidelegHitM   = (CauseM < 16) ? HIDELEG_REGW[CauseM] : 1'b0;
    /* verilator lint_on WIDTHTRUNC */
    assign HedelegHitM   = HEDELEG_REGW[CauseIdxM];
    assign DelegateToVSM = VirtModeW & DelegateM & (InterruptM ? HidelegHitM : HedelegHitM);
    assign TrapToVSM     = TrapM & DelegateToVSM;
    assign TrapToHSM     = TrapM & DelegateM & ~TrapToVSM;
    assign TrapToM       = TrapM & ~TrapToHSM & ~TrapToVSM;
  end else begin: trapto_vs_noh
    assign HidelegHitM   = 1'b0;
    assign HedelegHitM   = 1'b0;
    assign DelegateToVSM = 1'b0;
    assign TrapToVSM     = 1'b0;
    assign TrapToHSM     = TrapM & DelegateM;
    assign TrapToM       = TrapM & ~DelegateM;
  end

  ///////////////////////////////////////////
  // Trigger Traps
  // According to RISC-V Spec Section 1.6, exceptions are caused by instructions.  Interrupts are external asynchronous.
  // Traps are the union of exceptions and interrupts.
  ///////////////////////////////////////////

  assign BothInstrAccessFaultM = InstrAccessFaultM | HPTWInstrAccessFaultM;
  assign BothInstrPageFaultM = InstrPageFaultM | HPTWInstrPageFaultM;
  // coverage off -item e 1 -fecexprrow 2
  // excludes InstrMisalignedFaultM from coverage of this line, since misaligned instructions cannot occur in rv64gc.
  if (P.H_SUPPORTED) begin: exception_h
    assign ExceptionM = InstrMisalignedFaultM | BothInstrAccessFaultM | IllegalInstrFaultM |
                        LoadMisalignedFaultM | StoreAmoMisalignedFaultM |
                        BothInstrPageFaultM | LoadPageFaultM | StoreAmoPageFaultM |
                        BreakpointFaultM | EcallFaultM | VirtualInstrFaultM |
                        LoadAccessFaultM | StoreAmoAccessFaultM;
  end else begin: exception_noh
    assign ExceptionM = InstrMisalignedFaultM | BothInstrAccessFaultM | IllegalInstrFaultM |
                        LoadMisalignedFaultM | StoreAmoMisalignedFaultM |
                        BothInstrPageFaultM | LoadPageFaultM | StoreAmoPageFaultM |
                        BreakpointFaultM | EcallFaultM |
                        LoadAccessFaultM | StoreAmoAccessFaultM;
  end
  // coverage on
  assign TrapM = (ExceptionM & ~CommittedF) | InterruptM;

  ///////////////////////////////////////////
  // Cause priority defined in privileged spec
  ///////////////////////////////////////////

  always_comb
    if      (reset)                                           CauseM = 5'd0; // hard reset 3.3
    else if (ValidIntsM[11])                                  CauseM = 5'd11; // Machine External Int
    else if (ValidIntsM[3])                                   CauseM = 5'd3;  // Machine Sw Int
    else if (ValidIntsM[7])                                   CauseM = 5'd7;  // Machine Timer Int
    // if any of the interrupts are delegated to S mode they would be moved to lower priority than the undelegated ones
    else if (~MIDELEG_REGW[9] & ValidIntsM[9])                CauseM = 5'd9;  // not delegated Supervisor External Int
    else if (~MIDELEG_REGW[1] & ValidIntsM[1])                CauseM = 5'd1;  // not delegated Supervisor Sw Int
    else if (~MIDELEG_REGW[5] & ValidIntsM[5])                CauseM = 5'd5;  // not delegated Supervisor Timer Int
    else if (ValidIntsM[9])                                   CauseM = 5'd9;  // delegated Supervisor External Int
    else if (ValidIntsM[1])                                   CauseM = 5'd1;  // delegated Supervisor Sw Int
    else if (ValidIntsM[5])                                   CauseM = 5'd5;  // delegated Supervisor Timer Int
    else if (P.H_SUPPORTED & ValidIntsM[12])                  CauseM = 5'd12; // Supervisor Guest External Int
    else if (P.H_SUPPORTED & ValidIntsM[10])                  CauseM = 5'd10; // Virtual Supervisor External Int
    else if (P.H_SUPPORTED & ValidIntsM[2])                   CauseM = 5'd2;  // Virtual Supervisor Software Int
    else if (P.H_SUPPORTED & ValidIntsM[6])                   CauseM = 5'd6;  // Virtual Supervisor Timer Int
    else if (BothInstrPageFaultM)                             CauseM = 5'd12;
    else if (P.H_SUPPORTED & VirtualInstrFaultM)              CauseM = 5'd22; // Virtual Instruction Fault
    else if (BothInstrAccessFaultM)                           CauseM = 5'd1;
    else if (IllegalInstrFaultM)                              CauseM = 5'd2;
    // coverage off
    // Misaligned instructions cannot occur in rv64gc
    else if (InstrMisalignedFaultM)                           CauseM = 5'd0;
    // coverage on
    else if (BreakpointFaultM)                                CauseM = 5'd3;
    else if (EcallFaultM)                                     CauseM = (P.H_SUPPORTED & VirtModeW & (PrivilegeModeW == P.S_MODE)) ? 5'd10
                                                                                                                  : {1'b0, 2'b10, PrivilegeModeW};
    else if (StoreAmoMisalignedFaultM & ~P.ZICCLSM_SUPPORTED) CauseM = 5'd6;  // misaligned faults are higher priority if they always are taken
    else if (LoadMisalignedFaultM & ~P.ZICCLSM_SUPPORTED)     CauseM = 5'd4;
    // TODO: Add guest-page-fault cause generation (20/21/23) when two-stage translation fault signals are integrated.
    else if (StoreAmoPageFaultM)                              CauseM = 5'd15;
    else if (LoadPageFaultM)                                  CauseM = 5'd13;
    else if (StoreAmoAccessFaultM)                            CauseM = 5'd7;
    else if (LoadAccessFaultM)                                CauseM = 5'd5;
    else if (StoreAmoMisalignedFaultM & P.ZICCLSM_SUPPORTED)  CauseM = 5'd6; // See priority in Privileged Spec 3.1.15
    else if (LoadMisalignedFaultM & P.ZICCLSM_SUPPORTED)      CauseM = 5'd4;
    else                                                      CauseM = 5'd0;
endmodule
