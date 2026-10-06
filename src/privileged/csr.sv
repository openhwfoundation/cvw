///////////////////////////////////////////
// csr.sv
//
// Written: David_Harris@hmc.edu 9 January 2021
// Modified:
//          dottolia@hmc.edu 7 April 2021
//
// Purpose: Counter Control and Status Registers
//          See RISC-V Privileged Mode Specification 20190608
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

module csr import cvw::*;  #(parameter cvw_t P) (
  input  logic                     clk, reset,
  input  logic                     FlushM, FlushW,
  input  logic                     StallE, StallM, StallW,
  input  logic [31:0]              InstrM,                    // current instruction
  input  logic [31:0]              InstrOrigM,                // Original compressed or uncompressed instruction in Memory stage for Illegal Instruction XTVAL
  input  logic [P.XLEN-1:0]        PCM,                       // program counter, next PC going to trap/return logic
  input  logic [P.XLEN-1:0]        PCSpillM,                  // program counter, next PC going to trap/return logic aligned after an instruction spill
  input  logic [P.XLEN-1:0]        SrcAM, IEUAdrxTvalM,       // SrcA and memory address from IEU
  input  logic                     CSRReadM, CSRWriteM,       // read or write CSR
  input  logic                     TrapM,                     // trap is occurring
  input  logic                     TrapToM, TrapToHSM, TrapToVSM,// resolved trap target
  input  logic                     mretM, sretM,              // return instruction
  input  logic                     InterruptM,                // interrupt is occurring
  input  logic                     ExceptionM,                // interrupt is occurring
  input  logic                     MTimerInt,                 // timer interrupt
  input  logic                     MExtInt, SExtInt,          // external interrupt (from PLIC)
  input  logic                     MSwInt,                    // software interrupt
  input  logic [63:0]              MTIME_CLINT,               // TIME value from CLINT
  input  logic [P.XLEN-1:0]        HGEIPIn,                   // guest external interrupt sources
  input  logic                     InstrValidM,               // current instruction is valid
  input  logic                     FRegWriteM,                // writes to floating point registers change STATUS.FS
  input  logic [4:0]               SetFflagsM,                // Set floating point flag bits in FCSR
  input  logic [1:0]               NextPrivilegeModeM,        // STATUS bits updated based on next privilege mode
  input  logic [1:0]               PrivilegeModeW,            // current privilege mode
  input  logic                     VirtModeW,                 // current V Bit
  input  logic                     HLVHSVLegalM,              // Legal HLV/HLVX/HSV memory access in M stage
  input  logic [4:0]               CauseM,                    // Trap cause
  input  logic                     SelHPTW,                   // hardware page table walker active, so base endianness on supervisor mode
  // inputs for performance counters
  input  logic                     LoadStallD, StoreStallD,
  input  logic                     ICacheStallF,
  input  logic                     DCacheStallM,
  input  logic                     BPDirWrongM,
  input  logic                     BTAWrongM,
  input  logic                     RASPredPCWrongM,
  input  logic                     IClassWrongM,
  input  logic                     BPWrongM,                  // branch predictor is wrong
  input  logic [3:0]               IClassM,
  input  logic                     DCacheMiss,
  input  logic                     DCacheAccess,
  input  logic                     ICacheMiss,
  input  logic                     ICacheAccess,
  input  logic                     sfencevmaM,
  input  logic                     InvalidateICacheM,
  input  logic                     DivBusyE,                  // integer divide busy
  input  logic                     FDivBusyE,                 // floating point divide busy
  // outputs from CSRs
  output logic [1:0]               STATUS_MPP,
  output logic                     MSTATUS_MPV,
  output logic                     STATUS_SPP, STATUS_TSR, STATUS_TVM,
  output logic                     HSTATUS_SPV,
  output logic                     HSTATUS_SPVP,
  output logic                     HSTATUS_VTSR, HSTATUS_VTW, HSTATUS_VTVM,
  output logic                     HSTATUS_HU,
  output logic                     VSSTATUS_SPP, VSSTATUS_SIE,
  output logic [63:0]              MEDELEG_REGW,
  output logic [63:0]              HEDELEG_REGW,
  output logic [15:0]              HIDELEG_REGW,
  output logic [15:0]              HIE_REGW,
  output logic [P.XLEN-1:0]        HGEIE_REGW,
  output logic [P.XLEN-1:0]        SATP_REGW,
  output logic [15:0]              MIP_REGW, MIE_REGW, MIDELEG_REGW,
  output logic                     STATUS_MIE, STATUS_SIE,
  output logic                     STATUS_MXR, STATUS_SUM, STATUS_MPRV, STATUS_TW,
  output logic [1:0]               STATUS_FS,
  output var logic [7:0]           PMPCFG_ARRAY_REGW[P.PMP_ENTRIES-1:0],
  output var logic [P.PA_BITS-3:0] PMPADDR_ARRAY_REGW[P.PMP_ENTRIES-1:0],
  output logic [2:0]               FRM_REGW,
  output logic [3:0]               ENVCFG_CBE,
  output logic                     ENVCFG_PBMTE,              // Page-based memory type enable
  output logic                     ENVCFG_ADUE,               // HPTW A/D Update enable
  // PC logic output from privileged unit to IFU
  output logic [P.XLEN-1:0]        EPCM,                      // Exception Program counter to IFU PC logic
  output logic [P.XLEN-1:0]        TrapVectorM,               // Trap vector, to IFU PC logic
  //
  output logic [P.XLEN-1:0]        CSRReadValW,               // value read from CSR
  output logic                     IllegalCSRAccessM,         // Illegal CSR access: CSR doesn't exist or is inaccessible at this privilege level
  output logic                     VirtualCSRAccessM,         // CSR access that raises a virtual-instruction exception
  output logic                     VirtualCMOInstrM,          // CBO instruction that raises a virtual-instruction exception
  output logic                     HLVHSVBareM,               // VS-stage and G-stage translation are both Bare for HLV/HSV
  output logic                     BigEndianM                 // memory access is big-endian based on privilege mode and STATUS register endian fields
);

  localparam MIP = 12'h344;
  localparam SIP = 12'h144;

  logic [P.XLEN-1:0]       CSRMReadValM, CSRSReadValM, CSRUReadValM, CSRCReadValM;
  logic [P.XLEN-1:0]       CSRReadValM;
  logic [P.XLEN-1:0]       CSRSrcM;
  logic [P.XLEN-1:0]       CSRRWM, CSRRSM, CSRRCM;
  logic [P.XLEN-1:0]       CSRWriteValM;
  logic [P.XLEN-1:0]       MSTATUS_REGW, SSTATUS_REGW, MSTATUSH_REGW;
  logic                    STATUS_MXR_INT, STATUS_SUM_INT;
  logic [1:0]              STATUS_FS_INT;
  logic                    BigEndianM_Int;
  logic [P.XLEN-1:0]       STVEC_REGW, MTVEC_REGW;
  logic [P.XLEN-1:0]       MEPC_REGW, SEPC_REGW;
  logic [P.XLEN-1:0]       VSTVEC_REGW, VSEPC_REGW;
  logic [P.XLEN-1:0]       SEPCSel, STVecSelM;
  logic [31:0]             MCOUNTINHIBIT_REGW, MCOUNTEREN_REGW, SCOUNTEREN_REGW;
  logic                    WriteMSTATUSM, WriteMSTATUSHM, WriteSSTATUSM;
  logic                    CSRMWriteM, CSRSWriteM, CSRUWriteM;
  logic                    UngatedCSRMWriteM;
  logic                    WriteFRMM, SetOrWriteFFLAGSM;
  logic [P.XLEN-1:0]       UnalignedNextEPCM, NextEPCM, NextXtvalM;
  logic [P.XLEN-1:0]       NextHtvalM; // Value for htval on trap
  logic [5:0]              NextCauseM;
  logic [11:0]             CSRAdrM_In, CSRAdrM;
  logic                    IllegalCSRCAccessM, IllegalCSRMAccessM, IllegalCSRSAccessM, IllegalCSRUAccessM;
  logic                    VirtualCSRCAccessM;
  logic                    InsufficientCSRPrivilegeM;
  logic                    IllegalCSRMWriteReadonlyM;
  logic [P.XLEN-1:0]       CSRReadVal2M;
  logic [15:0]             MIP_REGW_writeable;
  logic [P.XLEN-1:0]       TVecM,NextFaultXtvalM;
  logic                    MTrapM, STrapM;
  logic                    SelMtvecM;
  logic [4:0]              TrapCauseCodeM;
  logic [P.XLEN-1:0]       TVecAlignedM;
  logic                    InstrValidNotFlushedM;
  logic                    STimerInt;
  logic [63:0]             MENVCFG_REGW;
  logic [63:0]             HENVCFG_REGW;
  logic [P.XLEN-1:0]       SENVCFG_REGW;
  logic [P.XLEN-1:0]       SATP_REGW_INT, VSATP_REGW, HGATP_REGW; // Internal SATP and Hypervisor ATPs
  logic                    ENVCFG_STCE; // supervisor timer counter enable
  logic                    TrapGVAM;
  logic                    TrapWritesVAToTvalM;
  logic                    VSSTATUS_SUM, VSSTATUS_MXR, VSSTATUS_UBE;
  logic [1:0]              VSSTATUS_FS;
  logic                    HSTATUS_VSBE;
  logic [31:0]             HCOUNTEREN_REGW;
  logic [11:0]             HVIP_REGW;
  logic [15:0]             HIP_MIP_REGW;
  logic [63:0]             HTIMEDELTA_REGW;
  logic [P.XLEN-1:0]       CSRHReadValM;
  logic                    IllegalCSRHAccessM;
  logic                    WriteHIEM, WriteVSIEM;

  // only valid unflushed instructions can access CSRs
  assign InstrValidNotFlushedM = InstrValidM & ~StallW & ~FlushW;

  ///////////////////////////////////////////
  // XTVAL: gets value from PC, Instruction, or load/store address (for MTVAL/STVAL/VSTVAL)
  ///////////////////////////////////////////

  always_comb
    if (InterruptM)           NextFaultXtvalM = '0;
    else case (CauseM)
      12, 1, 20:              NextFaultXtvalM = PCSpillM;  // Instruction page/access/guest-page faults report the faulting half of a spilled fetch
      3:                      NextFaultXtvalM = PCM;       // Breakpoint reports the address of the ebreak itself, not the second half of a spilled fetch
      2, 22:                  NextFaultXtvalM = {{(P.XLEN-32){1'b0}}, InstrOrigM}; // Illegal/virtual instruction fault
      0, 4, 6, 13, 15, 5, 7, 21, 23: NextFaultXtvalM = IEUAdrxTvalM; // Instruction misaligned, Load/Store Misaligned/page/access/guest-page faults
      default:                NextFaultXtvalM = '0; // Ecall, interrupts
    endcase

  if (P.H_SUPPORTED) begin: trapwritesva
    // Identify traps that write a virtual address to tval.
    // Cause 3 (breakpoint) is included because this implementation writes PC
    // for [C.]EBREAK (also permitted by spec) and address breakpoints write VA.
    // Guest-page-fault causes are included for future two-stage support.
    always_comb
      case (CauseM)
        5'd0, 5'd1, 5'd3, 5'd4, 5'd5, 5'd6, 5'd7, 5'd12, 5'd13, 5'd15, 5'd20, 5'd21, 5'd23:
          TrapWritesVAToTvalM = 1'b1;
        default:
          TrapWritesVAToTvalM = 1'b0;
      endcase
  end else begin: no_trapwritesva
    assign TrapWritesVAToTvalM = 1'b0;
  end

  if (P.H_SUPPORTED) begin: trapcause_h
    // H spec translates delegated VS interrupt causes 10/6/2 into 9/5/1 for VS trap state and vectoring.
    always_comb
      if (TrapToVSM & InterruptM)
        case (CauseM)
          5'd10: TrapCauseCodeM = 5'd9;
          5'd6:  TrapCauseCodeM = 5'd5;
          5'd2:  TrapCauseCodeM = 5'd1;
          default:
            TrapCauseCodeM = CauseM;
        endcase
      else
        TrapCauseCodeM = CauseM;
  end else begin: trapcause_noh
    assign TrapCauseCodeM = CauseM;
  end

  ///////////////////////////////////////////
  // Trap Vectoring & Returns; vectored traps must be aligned to 64-byte address boundaries
  ///////////////////////////////////////////

  // Select trap vector from STVEC/MTVEC (and VSTVEC when H is supported) and word-align
  if (P.H_SUPPORTED) begin: tvec_h
    mux2 #(P.XLEN) stvecselmux(STVEC_REGW, VSTVEC_REGW, TrapToVSM, STVecSelM);
  end else begin: tvec_noh
    assign STVecSelM = STVEC_REGW;
  end
  assign SelMtvecM = P.H_SUPPORTED ? TrapToM : (NextPrivilegeModeM == P.M_MODE);
  mux2 #(P.XLEN) tvecmux(STVecSelM, MTVEC_REGW, SelMtvecM, TVecM);
  assign TVecAlignedM = {TVecM[P.XLEN-1:2], 2'b00};

  // Support vectored interrupts
  if (P.VECTORED_INTERRUPTS_SUPPORTED) begin : vec
    logic VectoredM;
    logic [P.XLEN-1:0] TVecPlusCauseM;
    assign VectoredM = InterruptM & (TVecM[1:0] == 2'b01);
    assign TVecPlusCauseM = {TVecAlignedM[P.XLEN-1:6], TrapCauseCodeM[3:0], 2'b00}; // 64-byte alignment allows concatenation rather than addition
    mux2 #(P.XLEN) trapvecmux(TVecAlignedM, TVecPlusCauseM, VectoredM, TrapVectorM);
  end else
    assign TrapVectorM = TVecAlignedM; // unvectored interrupt handler can be at any word-aligned address. This is called Sstvecd

  // Trap Returns
  // A trap sets the PC to TrapVector
  // A return sets the PC to MEPC or SEPC/VSEPC.
  // Per the H spec 22.6.4, HS-mode SRET (V=0) always returns using SEPC even when
  // hstatus.SPV requests entry into VS/VU; only VS-mode SRET (V=1) uses VSEPC.
  if (P.H_SUPPORTED) begin: epc_h
    logic UseVSEPCM;
    assign UseVSEPCM = VirtModeW;
    mux2 #(P.XLEN) sepcselmux(SEPC_REGW, VSEPC_REGW, UseVSEPCM, SEPCSel);
    mux2 #(P.XLEN) epcmux(SEPCSel, MEPC_REGW, mretM, EPCM);
  end else begin: epc_noh
    mux2 #(P.XLEN) epcmux(SEPC_REGW, MEPC_REGW, mretM, EPCM);
  end

  ///////////////////////////////////////////
  // CSRWriteValM
  ///////////////////////////////////////////

  always_comb begin
    // Choose either rs1 or uimm[4:0] as source
    CSRSrcM = InstrM[14] ? {{(P.XLEN-5){1'b0}}, InstrM[19:15]} : SrcAM;

    // CSR set and clear for MIP/SIP should only touch internal state, not interrupt inputs
    if (CSRAdrM == MIP | CSRAdrM == SIP) CSRReadVal2M = {{(P.XLEN-16){1'b0}}, MIP_REGW_writeable};
    else                                 CSRReadVal2M = CSRReadValM;

    // Compute AND/OR modification
    CSRRWM =   CSRSrcM;
    CSRRSM =   CSRReadVal2M | CSRSrcM;
    CSRRCM =   CSRReadVal2M & ~CSRSrcM;
    case (InstrM[13:12])
      2'b01:   CSRWriteValM = CSRRWM;
      2'b10:   CSRWriteValM = CSRRSM;
      2'b11:   CSRWriteValM = CSRRCM;
      default: CSRWriteValM = CSRReadValM;
    endcase
  end

  ///////////////////////////////////////////
  // CSR Write values
  ///////////////////////////////////////////

  assign CSRAdrM_In = InstrM[31:20];
  if (P.H_SUPPORTED) begin: csradr_h
    csrhvirt #(P) csrhvirt(.CSRAdrM_In, .CSRReadM, .CSRWriteM, .TrapM, .ExceptionM,
      .VirtModeW, .PrivilegeModeW, .MCOUNTEREN_REGW, .HCOUNTEREN_REGW, .HENVCFG_REGW,
      .VirtualCSRCAccessM, .TrapWritesVAToTvalM, .HLVHSVLegalM, .CSRAdrM, .VirtualCSRAccessM, .TrapGVAM);
  end else begin: csradr_noh
    assign CSRAdrM = CSRAdrM_In;
    assign VirtualCSRAccessM = 1'b0;
    assign TrapGVAM = 1'b0;
  end
  assign UnalignedNextEPCM = TrapM ? PCM : CSRWriteValM;
  assign NextEPCM = P.ZCA_SUPPORTED ? {UnalignedNextEPCM[P.XLEN-1:1], 1'b0} : {UnalignedNextEPCM[P.XLEN-1:2], 2'b00}; // 3.1.15 alignment
  assign NextCauseM = TrapM ? {InterruptM, TrapCauseCodeM}: {CSRWriteValM[P.XLEN-1], CSRWriteValM[4:0]};
  assign NextXtvalM = TrapM ? NextFaultXtvalM : CSRWriteValM;
  assign UngatedCSRMWriteM = CSRWriteM & (PrivilegeModeW == P.M_MODE);
  assign CSRMWriteM = UngatedCSRMWriteM & InstrValidNotFlushedM;
  assign CSRSWriteM = CSRWriteM & (|PrivilegeModeW) & InstrValidNotFlushedM;
  assign CSRUWriteM = CSRWriteM  & InstrValidNotFlushedM;
  if (P.H_SUPPORTED) begin: trap_sel_h
    assign MTrapM = TrapM & TrapToM;
    assign STrapM = TrapM & TrapToHSM & P.S_SUPPORTED;
  end else begin: trap_sel_noh
    assign MTrapM = TrapM & (NextPrivilegeModeM == P.M_MODE);
    assign STrapM = TrapM & (NextPrivilegeModeM == P.S_MODE) & P.S_SUPPORTED;
  end

  ///////////////////////////////////////////
  // CSRs
  ///////////////////////////////////////////

  csri #(P) csri(.clk, .reset,
    .CSRMWriteM, .CSRSWriteM, .CSRWriteValM, .CSRAdrM,
    .MExtInt, .SExtInt, .MTimerInt, .STimerInt, .MSwInt,
    .HIP_MIP_REGW, .WriteHIEM, .WriteVSIEM, .HIDELEG_REGW, .HIE_REGW,
    .MIDELEG_REGW, .ENVCFG_STCE, .MIP_REGW, .MIE_REGW, .MIP_REGW_writeable);

  csrsr #(P) csrsr(.clk, .reset, .StallW,
    .WriteMSTATUSM, .WriteMSTATUSHM, .WriteSSTATUSM,
    .TrapToM, .TrapToHSM, .FRegWriteM, .PrivilegeModeW, .VirtModeW, .TrapGVAM,
    .mretM, .sretM, .WriteFRMM, .SetOrWriteFFLAGSM, .CSRWriteValM, .SelHPTW,
    .MSTATUS_REGW, .SSTATUS_REGW, .MSTATUSH_REGW,
    .STATUS_MPP, .MSTATUS_MPV, .STATUS_SPP, .STATUS_TSR, .STATUS_TW,
    .STATUS_MIE, .STATUS_SIE, .STATUS_MXR(STATUS_MXR_INT), .STATUS_SUM(STATUS_SUM_INT),
    .STATUS_MPRV, .STATUS_TVM, .STATUS_FS(STATUS_FS_INT), .BigEndianM(BigEndianM_Int));

  csrm #(P) csrm(.clk, .reset,
    .UngatedCSRMWriteM, .CSRMWriteM, .MTrapM, .CSRAdrM,
    .NextEPCM, .NextCauseM, .NextXtvalM, .MSTATUS_REGW, .MSTATUSH_REGW,
    .CSRWriteValM, .CSRMReadValM, .MTVEC_REGW,
    .MEPC_REGW, .MCOUNTEREN_REGW, .MCOUNTINHIBIT_REGW,
    .MEDELEG_REGW, .MIDELEG_REGW,.PMPCFG_ARRAY_REGW, .PMPADDR_ARRAY_REGW,
    .MIP_REGW, .MIE_REGW, .WriteMSTATUSM, .WriteMSTATUSHM,
    .IllegalCSRMAccessM, .IllegalCSRMWriteReadonlyM,
    .MENVCFG_REGW);


  if (P.S_SUPPORTED) begin : csrs
    logic STCE;
    assign STCE = P.SSTC_SUPPORTED & (PrivilegeModeW == P.M_MODE | (MCOUNTEREN_REGW[1] & ENVCFG_STCE));
    csrs #(P) csrs(.clk, .reset,
      .CSRSWriteM, .STrapM, .CSRAdrM,
      .NextEPCM, .NextCauseM, .NextXtvalM, .SSTATUS_REGW,
      .STATUS_TVM,
      .CSRWriteValM, .PrivilegeModeW,
      .CSRSReadValM, .STVEC_REGW, .SEPC_REGW,
      .SCOUNTEREN_REGW,
      .SATP_REGW(SATP_REGW_INT), .MIP_REGW, .MIE_REGW, .MIDELEG_REGW, .MTIME_CLINT, .STCE,
      .WriteSSTATUSM, .IllegalCSRSAccessM, .STimerInt, .SENVCFG_REGW);
  end else begin
    assign WriteSSTATUSM = 1'b0;
    assign CSRSReadValM = '0;
    assign SEPC_REGW = '0;
    assign STVEC_REGW = '0;
    assign SCOUNTEREN_REGW = '0;
    assign SATP_REGW_INT = '0;
    assign IllegalCSRSAccessM = 1'b1;
    assign STimerInt = '0;
    assign SENVCFG_REGW = '0;
  end

  if (P.H_SUPPORTED) begin:csrh
    csrh #(P) csrh(.clk, .reset,
      .CSRMWriteM, .CSRSWriteM, .CSRWriteM, .CSRAdrM, .CSRWriteValM,
      .PrivilegeModeW, .VirtModeW, .FRegWriteM, .WriteFRMM, .SetOrWriteFFLAGSM,
      .TrapGVAM, .MTIME_CLINT, .HGEIPIn,
      .STATUS_TVM, .MCOUNTEREN_TM(MCOUNTEREN_REGW[1]),
      .MENVCFG_STCE(MENVCFG_REGW[63]), .MENVCFG_PBMTE(MENVCFG_REGW[62]), .MENVCFG_ADUE(MENVCFG_REGW[61]),
      .TrapToM, .TrapToHSM, .TrapToVSM, .sretM, .InstrM, .InstrOrigM,
      .NextEPCM, .NextCauseM, .NextTvalM(NextXtvalM), .NextHtvalM, .HIE_REGW,
      .CSRHReadValM, .IllegalCSRHAccessM,
      .HSTATUS_SPV, .HSTATUS_VTSR, .HSTATUS_VTW, .HSTATUS_VTVM,
      .HSTATUS_SPVP, .HSTATUS_HU,
      .HSTATUS_VSBE, .VSSTATUS_SPP, .VSSTATUS_SIE, .VSSTATUS_SUM, .VSSTATUS_MXR, .VSSTATUS_UBE, .VSSTATUS_FS,
      .HEDELEG_REGW, .HIDELEG_REGW, .WriteHIEM, .WriteVSIEM, .HGEIE_REGW, .HCOUNTEREN_REGW, .HVIP_REGW, .HIP_MIP_REGW, .HTIMEDELTA_REGW, .HENVCFG_REGW,
      .VSTVEC_REGW, .VSEPC_REGW, .VSATP_REGW, .HGATP_REGW);
  end else begin: no_csrh
    assign CSRHReadValM = '0;
    assign IllegalCSRHAccessM = 1'b1;
    assign HSTATUS_SPV = 1'b0;
    assign HSTATUS_SPVP = 1'b0;
    assign HSTATUS_VTSR = 1'b0;
    assign HSTATUS_VTW = 1'b0;
    assign HSTATUS_VTVM = 1'b0;
    assign HSTATUS_HU = 1'b0;
    assign HSTATUS_VSBE = 1'b0;
    assign VSSTATUS_SPP = 1'b0;
    assign VSSTATUS_SIE = 1'b0;
    assign VSSTATUS_SUM = 1'b0;
    assign VSSTATUS_MXR = 1'b0;
    assign VSSTATUS_UBE = 1'b0;
    assign VSSTATUS_FS = '0;
    assign HEDELEG_REGW = '0;
    assign HIDELEG_REGW = '0;
    assign WriteHIEM = 1'b0;
    assign WriteVSIEM = 1'b0;
    assign HGEIE_REGW = '0;
    assign HCOUNTEREN_REGW = '0;
    assign HVIP_REGW = '0;
    assign HIP_MIP_REGW = '0;
    assign HTIMEDELTA_REGW = '0;
    assign HENVCFG_REGW = '0;
    assign VSTVEC_REGW = '0;
    assign VSEPC_REGW = '0;
    assign VSATP_REGW = '0;
    assign HGATP_REGW = '0;
  end

  // SATP Mux
  if (P.H_SUPPORTED) begin: satp_mux
      mux2 #(P.XLEN) satpmux(SATP_REGW_INT, VSATP_REGW, VirtModeW, SATP_REGW);
  end else begin: satp_nomux
      assign SATP_REGW = SATP_REGW_INT;
  end

  // Until two-stage translation is integrated, htval trap writes stay zero.
  assign NextHtvalM = '0;

  if (P.H_SUPPORTED & P.VIRTMEM_SUPPORTED) begin: hlsv_bare
    if (P.XLEN == 64) begin: hlsv_bare64
      assign HLVHSVBareM = (VSATP_REGW[63:60] == 4'h0) & (HGATP_REGW[63:60] == 4'h0);
    end else begin: hlsv_bare32
      assign HLVHSVBareM = ~VSATP_REGW[31] & ~HGATP_REGW[31];
    end
  end else begin: hlsv_novirtmem
    assign HLVHSVBareM = 1'b1;
  end

  // Effective status bits for VS-mode
  if (P.H_SUPPORTED) begin: status_vs
    assign STATUS_MXR = VirtModeW ? VSSTATUS_MXR : STATUS_MXR_INT;
    assign STATUS_SUM = VirtModeW ? VSSTATUS_SUM : STATUS_SUM_INT;
    assign STATUS_FS  = VirtModeW ? VSSTATUS_FS : STATUS_FS_INT;
  end else begin: status_noh
    assign STATUS_MXR = STATUS_MXR_INT;
    assign STATUS_SUM = STATUS_SUM_INT;
    assign STATUS_FS  = STATUS_FS_INT;
  end

  if (P.BIGENDIAN_SUPPORTED) begin: endian
    if (P.H_SUPPORTED) begin: endian_h
      logic BigEndianVirtM, BigEndianHLVHSVM, BigEndianVirtSelM;
      assign BigEndianVirtM = (PrivilegeModeW == P.S_MODE) ? HSTATUS_VSBE : VSSTATUS_UBE;
      assign BigEndianHLVHSVM = HSTATUS_SPVP ? HSTATUS_VSBE : VSSTATUS_UBE;
      mux2 #(1) bigendianvirtmux(BigEndianM_Int, BigEndianVirtM, VirtModeW & ~SelHPTW, BigEndianVirtSelM);
      mux2 #(1) bigendianhlsvmux(BigEndianVirtSelM, BigEndianHLVHSVM, HLVHSVLegalM, BigEndianM);
    end else begin: endian_noh
      assign BigEndianM = BigEndianM_Int;
    end
  end else begin: endian_n
    assign BigEndianM = 1'b0;
  end

  // Floating Point CSRs in User Mode only needed if Floating Point is supported
  if (P.F_SUPPORTED) begin : csru
    csru #(P) csru(.clk, .reset, .InstrValidNotFlushedM,
      .CSRUWriteM, .CSRAdrM, .CSRWriteValM, .STATUS_FS, .CSRUReadValM,
      .SetFflagsM, .FRM_REGW, .WriteFRMM, .SetOrWriteFFLAGSM,
      .IllegalCSRUAccessM);
  end else begin
    assign FRM_REGW = '0;
    assign CSRUReadValM = '0;
    assign IllegalCSRUAccessM = 1'b1;
    assign WriteFRMM = 1'b0;
    assign SetOrWriteFFLAGSM = 1'b0;
  end

  // counters are always instantiated but may read as zero if not supported
  csrc #(P) counters(.clk, .reset, .StallE, .StallM, .FlushM,
    .InstrValidNotFlushedM, .LoadStallD, .StoreStallD, .CSRWriteM, .CSRMWriteM,
    .BPDirWrongM, .BTAWrongM, .RASPredPCWrongM, .IClassWrongM, .BPWrongM,
    .IClassM, .DCacheMiss, .DCacheAccess, .ICacheMiss, .ICacheAccess, .sfencevmaM,
    .InterruptM, .ExceptionM, .InvalidateICacheM, .ICacheStallF, .DCacheStallM, .DivBusyE, .FDivBusyE,
    .CSRAdrM, .PrivilegeModeW, .VirtModeW, .CSRWriteValM,
    .MCOUNTINHIBIT_REGW, .MCOUNTEREN_REGW, .SCOUNTEREN_REGW, .HCOUNTEREN_REGW,
    .MTIME_CLINT, .HTIMEDELTA_REGW,  .CSRCReadValM, .IllegalCSRCAccessM, .VirtualCSRCAccessM);

  csrenv #(P) csrenv(.InstrM, .PrivilegeModeW, .VirtModeW, .MENVCFG_REGW, .HENVCFG_REGW,
    .SENVCFG_REGW, .ENVCFG_CBE, .ENVCFG_STCE, .ENVCFG_PBMTE, .ENVCFG_ADUE, .VirtualCMOInstrM);

  // merge CSR Reads
  assign CSRReadValM = CSRUReadValM | CSRSReadValM | CSRMReadValM | CSRCReadValM | CSRHReadValM;
  flopenrc #(P.XLEN) CSRValWReg(clk, reset, FlushW, ~StallW, CSRReadValM, CSRReadValW);

  // merge illegal accesses: illegal if none of the CSR addresses is legal or privilege is insufficient
  assign InsufficientCSRPrivilegeM = (CSRAdrM[9:8] == 2'b11 & PrivilegeModeW != P.M_MODE) |
                                     (CSRAdrM[9:8] == 2'b01 & PrivilegeModeW == P.U_MODE);
  assign IllegalCSRAccessM = ((IllegalCSRCAccessM & IllegalCSRMAccessM &
    IllegalCSRSAccessM & IllegalCSRUAccessM & IllegalCSRHAccessM |
    InsufficientCSRPrivilegeM) & CSRReadM) | IllegalCSRMWriteReadonlyM;
endmodule
