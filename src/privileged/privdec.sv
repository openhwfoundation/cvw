///////////////////////////////////////////
// privdec.sv
//
// Written:  David Harris David_Harris@hmc.edu 9 January 2021
// Modified: Rose Thompson, Jinghe Yu, Domenico Ottolia, Katherine Parry
//
// Purpose: Privileged instruction decoder.
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

module privdec import cvw::*; #(parameter cvw_t P) (
  input  logic         clk, reset,
  input  logic         StallM,                              // Memory stage stalled: the wfi stays in M
  input  logic [31:7]  InstrM,                              // privileged instruction function field
  input  logic         PrivilegedM,                         // is this a privileged instruction (from IEU controller)
  input  logic         IllegalIEUFPUInstrM,                 // Not a legal IEU instruction
  input  logic         IllegalCSRAccessM,                   // Not a legal CSR access
  input  logic         VirtualCSRAccessM,                   // CSR access that should trap as virtual instruction
  input  logic         VirtualCMOInstrM,                    // CBO instruction that should trap as virtual instruction
  input  logic         HLVHSVInstrM,                        // Valid HLV/HLVX/HSV system-instruction encoding
  input  logic [1:0]   PrivilegeModeW,                      // current privilege level
  input  logic         VirtModeW,                           // current V
  input  logic         STATUS_TSR, STATUS_TVM, STATUS_TW,   // status bits (HS)
  input  logic         HSTATUS_VTSR, HSTATUS_VTVM, HSTATUS_VTW, // status bits (VS)
  input  logic         IntPendingM,                         // a locally enabled interrupt is pending: ends any wait
  output logic         IllegalInstrFaultM,                  // Illegal instruction
  output logic         VirtualInstrFaultM,                  // Virtual instruction exception
  output logic         EcallFaultM, BreakpointFaultM,       // Ecall or breakpoint; traps without retiring
  output logic         sretM, mretM, RetM,                  // return instructions
  output logic         WaitM,                               // wfi in M is waiting for an interrupt: stall the pipeline
  output logic         WaitedM,                             // wfi in M has waited (not a delayed WaitM): it retires before an interrupt is taken
  output logic         sfencevmaM,                          // address-translation fence instructions
  output logic         sfencevmaAllM                        // sfence.vma with rs2=x0: flush all TLB entries including global
);

  logic                rs1zeroM, rdzeroM;                   // rs1 / rd field = 0
  logic                IllegalPrivilegedInstrM;             // privileged instruction isn't a legal one or in legal mode
  logic                wfiM;                                // wfi instruction
  logic                TWTimeoutM;                          // mstatus.TW/hstatus.VTW time limit reached: illegal or virtual instruction
  logic                WaitedNextM;                         // WaitedM for the next cycle
  logic                ebreakM, ecallM;                     // ebreak / ecall instructions
  logic                sretInstrM;                          // sret encoding, before checking privilege mode
  logic                sinvalvmaM;                          // sinval.vma
  logic                presfencevmaM;                       // sfence.vma before checking privilege mode
  logic                sfencewinvalM, sfenceinvalirM;       // sfence.w.inval, sfence.inval.ir
  logic                hfencevvmaM, hfencegvmaM;            // hfence.vvma, hfence.gvma
  logic                hinvalvvmaM, hinvalgvmaM;            // hinval.vvma, hinval.gvma
  logic                vmaM;                                // sfence.vma or sinval.vma
  logic                hvvmaM, hgvmaM;                      // HFENCE/HINVAL operations
  logic                fenceinvalM;                         // sfence.w.inval or sfence.inval.ir
  logic                TSRM, TVMM;

  ///////////////////////////////////////////
  // Decode privileged instructions
  ///////////////////////////////////////////

  assign rs1zeroM =    InstrM[19:15] == 5'b0;
  assign rdzeroM  =    InstrM[11:7]  == 5'b0;

  // svinval instructions
  // any svinval instruction is treated as sfence.vma on Wally
  assign sinvalvmaM     = (InstrM[31:25] ==  7'b0001011)                 & rdzeroM;
  assign sfencewinvalM  = (InstrM[31:20] == 12'b000110000000) & rs1zeroM & rdzeroM;
  assign sfenceinvalirM = (InstrM[31:20] == 12'b000110000001) & rs1zeroM & rdzeroM;
  assign presfencevmaM  = (InstrM[31:25] ==  7'b0001001)                 & rdzeroM;
  if (P.H_SUPPORTED) begin: hfence_decode_h
    assign hfencevvmaM  = (InstrM[31:25] ==  7'b0010001) & (InstrM[14:12] == 3'b000) & rdzeroM; // hfence.vvma
    assign hfencegvmaM  = (InstrM[31:25] ==  7'b0110001) & (InstrM[14:12] == 3'b000) & rdzeroM; // hfence.gvma
    assign hinvalvvmaM  = P.SVINVAL_SUPPORTED & (InstrM[31:25] ==  7'b0010011) & (InstrM[14:12] == 3'b000) & rdzeroM; // hinval.vvma
    assign hinvalgvmaM  = P.SVINVAL_SUPPORTED & (InstrM[31:25] ==  7'b0110011) & (InstrM[14:12] == 3'b000) & rdzeroM; // hinval.gvma
  end else begin: hfence_decode_noh
    assign hfencevvmaM  = 1'b0;
    assign hfencegvmaM  = 1'b0;
    assign hinvalvvmaM  = 1'b0;
    assign hinvalgvmaM  = 1'b0;
  end
  assign vmaM           =  presfencevmaM | (sinvalvmaM & P.SVINVAL_SUPPORTED);      // sfence.vma or sinval.vma
  assign fenceinvalM    = (sfencewinvalM | sfenceinvalirM) & P.SVINVAL_SUPPORTED;   // sfence.w.inval or sfence.inval.ir
  assign hvvmaM         = hfencevvmaM | hinvalvvmaM;
  assign hgvmaM         = hfencegvmaM | hinvalgvmaM;

  // In VS-mode, use hstatus.V* bits instead of mstatus.T* bits.
  if (P.H_SUPPORTED) begin: status_bits_h
    assign TSRM = VirtModeW ? HSTATUS_VTSR : STATUS_TSR;
    assign TVMM = VirtModeW ? HSTATUS_VTVM : STATUS_TVM;
  end else begin: status_bits_noh
    assign TSRM = STATUS_TSR;
    assign TVMM = STATUS_TVM;
  end

  assign sretInstrM = PrivilegedM & (InstrM[31:20] == 12'b000100000010) & rs1zeroM;
  assign sretM =      sretInstrM & P.S_SUPPORTED & (PrivilegeModeW == P.M_MODE | PrivilegeModeW == P.S_MODE & ~TSRM);
  assign mretM =      PrivilegedM & (InstrM[31:20] == 12'b001100000010) & rs1zeroM & (PrivilegeModeW == P.M_MODE);
  assign RetM =       sretM | mretM;
  assign ecallM =     PrivilegedM & (InstrM[31:20] == 12'b000000000000) & rs1zeroM;
  assign ebreakM =    PrivilegedM & (InstrM[31:20] == 12'b000000000001) & rs1zeroM;
  assign wfiM =       PrivilegedM & (InstrM[31:20] == 12'b000100000101) & rs1zeroM;

  // Conservatively flush on any supported address-translation fence/invalidation instruction.
  // HFENCE.VVMA is valid in M/HS, HFENCE.GVMA only in M or HS with mstatus.TVM=0.
  // HINVAL.VVMA/HINVAL.GVMA inherit the same permissions as HFENCE.VVMA/HFENCE.GVMA.
  assign sfencevmaM = PrivilegedM & P.VIRTMEM_SUPPORTED &
                      ((PrivilegeModeW == P.M_MODE & (vmaM | fenceinvalM | hvvmaM | hgvmaM)) |
                       (PrivilegeModeW == P.S_MODE &
                        ((vmaM & ~TVMM) | fenceinvalM | // sfence.w.inval & sfence.inval.ir not affected by TVM
                         (P.H_SUPPORTED & ~VirtModeW & (hvvmaM | (hgvmaM & ~STATUS_TVM))))));
  // rs2 (InstrM[24:20]) = x0 means flush all ASIDs including global mappings; rs2 != x0 is ASID-specific
  // and must preserve global (G=1) entries (RISC-V Privileged spec sfence.vma semantics).
  assign sfencevmaAllM = sfencevmaM & ~|InstrM[24:20];

  ///////////////////////////////////////////
  // Wait: wfi (Privileged Spec 3.3.3, mstatus.TW 3.1.6.6)
  // The waiting wfi stays in M while WaitM stalls the whole pipeline, so the instruction
  // in W keeps forwarding.  The wait ends when a locally enabled interrupt is pending (any
  // privilege level, regardless of global enables), or when the mstatus.TW time limit
  // (WFI_TIMEOUT_BIT) raises an illegal instruction.  The signals are named for any instruction that
  // waits in M; here that is only wfi (Zawrs adds wrs.nto and wrs.sto).
  ///////////////////////////////////////////

  assign WaitM = wfiM & ~IntPendingM & ~TWTimeoutM;

  // Counter of waiting cycles, held while the wfi stays in M and cleared when M advances,
  // so it never outlives its wfi.  It saturates at WFI_TIMEOUT_BIT, the time limit.
  if (P.U_SUPPORTED) begin : waitcnt
    logic [P.WFI_TIMEOUT_BIT:0] WaitCount, WaitCountNext;
    assign WaitCountNext = StallM ? WaitCount + {{P.WFI_TIMEOUT_BIT{1'b0}}, WaitM & ~WaitCount[P.WFI_TIMEOUT_BIT]} : '0;
    flopr #(P.WFI_TIMEOUT_BIT+1) waitcountreg(clk, reset, WaitCountNext, WaitCount);
    // With H, the limit also applies in VS-mode when hstatus.VTW=1; at V=1 with mstatus.TW=0
    // it raises a virtual instruction exception instead (see virtinstr below).
    assign TWTimeoutM = wfiM & ((STATUS_TW & PrivilegeModeW != P.M_MODE) | // exclusion-tag: pmd-tw-timeout
                                (P.H_SUPPORTED & VirtModeW & PrivilegeModeW == P.S_MODE & HSTATUS_VTW) |
                                (P.S_SUPPORTED & PrivilegeModeW == P.U_MODE)) &
                        WaitCount[P.WFI_TIMEOUT_BIT];
  end else assign TWTimeoutM = 1'b0;

  // Set once the wfi in M has waited, and held until M advances.  An interrupt that ends the wait is then
  // taken on the next instruction (mepc = pc + 4), while one already enabled and pending is taken on the wfi
  // itself.  This is not WaitM delayed a cycle: the cycle the wait ends, M can still be stalled for
  // another reason (IFU or external stall), and the wfi must keep WaitedM until it moves to W.
  assign WaitedNextM = StallM & (WaitM | WaitedM);
  flopr #(1) waitedreg(clk, reset, WaitedNextM, WaitedM);

  ///////////////////////////////////////////
  // Extract exceptions by name and handle them
  ///////////////////////////////////////////

  assign BreakpointFaultM = ebreakM; // could have other causes from a debugger
  assign EcallFaultM = ecallM;

  ///////////////////////////////////////////
  // Fault on illegal instructions
  ///////////////////////////////////////////

  assign IllegalPrivilegedInstrM = PrivilegedM & ~(sretM | mretM | ecallM | ebreakM | wfiM | sfencevmaM);

  // Virtual Instruction Exception Detection
  // V=1: what HS can execute (mstatus.TSR/TVM/TW=0) but this mode can't is virtual (norm:H_cause_virtual_instruction).
  if (P.H_SUPPORTED) begin: virtinstr
    logic VirtualPrivM, VirtualWfiM, CMOFault;
    logic SatpCSRM;
    // sret and VM fences illegal at V=1: all in VU; sret if VTSR, sfence/sinval.vma if VTVM, and hfence/hinval in VS.
    assign VirtualPrivM = PrivilegedM & (sretInstrM | P.VIRTMEM_SUPPORTED & (vmaM | fenceinvalM | hvvmaM | hgvmaM)) &
                          ~(sretM | sfencevmaM);
    // wfi time limit at V=1 from hstatus.VTW (VS) or from S-mode being implemented (VU) rather than mstatus.TW
    assign VirtualWfiM  = TWTimeoutM & ~STATUS_TW;
    // In VS-mode, satp is virtualized when hstatus.VTVM=1.
    assign SatpCSRM = (PrivilegeModeW == P.S_MODE) & (InstrM[31:20] == 12'h180) & (|InstrM[13:12]);
    // CBO/envcfg cases are classified in csrenv, which owns the envcfg state.
    assign CMOFault = IllegalIEUFPUInstrM & VirtualCMOInstrM;
    // norm:hlsv_virtinst: HLV/HLVX/HSV at V=1.  The controller decodes the other illegal HLV/HSV cases (HLVHSVEnW).
    assign VirtualInstrFaultM = VirtModeW & (VirtualPrivM | VirtualWfiM | HLVHSVInstrM | HSTATUS_VTVM & SatpCSRM) |
                                VirtualCSRAccessM | CMOFault;
  end else begin: novirtinstr
    assign VirtualInstrFaultM = 1'b0;
  end

  // Prevent double-reporting. If it's Virtual, it's not Illegal.
  assign IllegalInstrFaultM = (IllegalIEUFPUInstrM | IllegalPrivilegedInstrM | IllegalCSRAccessM |
                               TWTimeoutM) & ~VirtualInstrFaultM;
endmodule
