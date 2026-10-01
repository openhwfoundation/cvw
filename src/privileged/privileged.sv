///////////////////////////////////////////
// privileged.sv
//
// Written: David_Harris@hmc.edu 5 January 2021
// Modified:
//
// Purpose: Implements the CSRs, Exceptions, and Privileged operations
//          See RISC-V Privileged Mode Specification 20190608
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software
// is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
// OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
///////////////////////////////////////////

module privileged import cvw::*;  #(parameter cvw_t P) (
  input  logic              clk, reset,
  input  logic              StallD, StallE, StallM, StallW,
  input  logic              FlushD, FlushE, FlushM, FlushW,
  // CSR Reads and Writes, and values needed for traps
  input  logic              CSRReadM, CSRWriteM,                            // Read or write CSRs
  input  logic [P.XLEN-1:0] SrcAM,                                          // GPR register to write
  input  logic [31:0]       InstrM,                                         // Instruction
  input  logic [31:0]       InstrOrigM,                                     // Original compressed or uncompressed instruction in Memory stage for Illegal Instruction MTVAL
  input  logic [P.XLEN-1:0] IEUAdrxTvalM,                                   // address from IEU
  input  logic [P.XLEN-1:0] PCM,                                            // program counter
  input  logic [P.XLEN-1:0] PCSpillM,                                       // program counter
  // control signals
  input  logic              InstrValidM,                                    // Current instruction is valid (not flushed)
  input  logic              CommittedM, CommittedF,                         // current instruction is using bus; don't interrupt
  input  logic              PrivilegedM,                                    // privileged instruction
  // processor events for performance counter logging
  input  logic              FRegWriteM,                                     // instruction will write floating-point registers
  input  logic              VRegWriteM,                                     // instruction writes a vector register
  input  logic              LoadStallD,                                     // load instruction is stalling
  input  logic              StoreStallD,                                    // store instruction is stalling
  input  logic              ICacheStallF,                                   // I cache stalled
  input  logic              DCacheStallM,                                   // D cache stalled
  input  logic              BPDirWrongM,                                // branch predictor guessed wrong direction
  input  logic              BTAWrongM,                                      // branch predictor guessed wrong target
  input  logic              RASPredPCWrongM,                                // return address stack guessed wrong target
  input  logic              IClassWrongM,                                   // branch predictor guessed wrong instruction class
  input  logic              BPWrongM,                                       // branch predictor is wrong
  input  logic [3:0]        IClassM,                                    // actual instruction class
  input  logic              DCacheMiss,                                     // data cache miss
  input  logic              DCacheAccess,                                   // data cache accessed (hit or miss)
  input  logic              ICacheMiss,                                     // instruction cache miss
  input  logic              ICacheAccess,                                   // instruction cache access
  input  logic              DivBusyE,                                       // integer divide busy
  input  logic              FDivBusyE,                                      // floating point divide busy
  // fault sources
  input  logic              InstrAccessFaultF,                              // instruction access fault
  input  logic              LoadAccessFaultM, StoreAmoAccessFaultM,         // load or store access fault
  input  logic              HPTWInstrAccessFaultF,                          // hardware page table access fault while fetching instruction PTE
  input  logic              HPTWInstrPageFaultF,                            // hardware page table page fault while fetching instruction PTE
  input  logic              InstrPageFaultF,                                // page faults
  input  logic              LoadPageFaultM, StoreAmoPageFaultM,             // page faults
  input  logic              InstrMisalignedFaultM,                          // misaligned instruction fault
  input  logic              LoadMisalignedFaultM, StoreAmoMisalignedFaultM, // misaligned data fault
  input  logic              IllegalIEUFPUVPUInstrD,                            // illegal instruction from IEU or FPU
  input  logic              MTimerInt, MExtInt, SExtInt, MSwInt,            // interrupt sources
  input  logic [63:0]       MTIME_CLINT,                                    // timer value from CLINT
  input  logic [4:0]        SetFflagsM,                                     // set FCSR flags from FPU
  input  logic              WriteVLVTYPEM,                                  // vconfig commits new vl/vtype this cycle
  input  logic [P.XLEN-1:0] NewVLM,                                         // new vl
  input  logic [7:0]        NewVTYPEM,                                      // new vtype config
  input  logic              NewVILLM,                                       // new vill flag
  input  logic              SetVXSATM,                                      // saturating V op set vxsat
  input  logic              ClearVSTARTM,                                   // reset vstart when vector instruction completed
  input  logic              SelHPTW,                                        // HPTW in use.  Causes system to use S-mode endianness for accesses
  // CSR outputs
  output logic [P.XLEN-1:0] CSRReadValW,                                    // Value read from CSR
  output logic [1:0]        PrivilegeModeW,                                 // current privilege mode
  output logic [P.XLEN-1:0] SATP_REGW,                                      // supervisor address translation register
  output logic              STATUS_MXR, STATUS_SUM, STATUS_MPRV,            // status register bits
  output logic [1:0]        STATUS_MPP, STATUS_FS,                          // status register bits
  output logic [1:0]        STATUS_VS,                                      // vector context status (mstatus.VS)
  output logic [P.XLEN-1:0] VTYPE_REGW,                                     // vector type
  output logic [P.XLEN-1:0] VL_REGW,                                        // vector length
  output logic [$clog2(P.VLEN)-1:0] VSTART_REGW,                            // vector start element index
  output logic [1:0]        VXRM_REGW,                                      // fixed-point rounding mode
  output var logic [7:0]    PMPCFG_ARRAY_REGW[P.PMP_ENTRIES-1:0],           // PMP configuration entries to MMU
  output var logic [P.PA_BITS-3:0] PMPADDR_ARRAY_REGW [P.PMP_ENTRIES-1:0],  // PMP address entries to MMU
  output logic [2:0]        FRM_REGW,                                       // FPU rounding mode
  output logic [3:0]        ENVCFG_CBE,                                     // Cache block operation enables
  output logic              ENVCFG_PBMTE,                                   // Page-based memory type enable
  output logic              ENVCFG_ADUE,                                    // HPTW A/D Update enable
  // PC logic output from privileged unit to IFU
  output logic [P.XLEN-1:0] EPCM,                                           // Exception Program counter to IFU PC logic
  output logic [P.XLEN-1:0] TrapVectorM,                                    // Trap vector, to IFU PC logic
  // control outputs
  output logic              RetM, TrapM,                                    // return instruction, or trap
  output logic              sfencevmaM,                                     // sfence.vma instruction
  input  logic              InvalidateICacheM,                              // fence instruction
  output logic              BigEndianM,                                     // Use big endian in current privilege mode
  // Fault outputs
  output logic              wfiM, IntPendingM                               // Stall in Memory stage for WFI until interrupt pending or timeout
);

  logic [4:0]               CauseM;                                         // trap cause
  logic [15:0]              MEDELEG_REGW;                                   // exception delegation CSR
  logic [11:0]              MIDELEG_REGW;                                   // interrupt delegation CSR
  logic                     sretM, mretM;                                   // supervisor / machine return instruction
  logic                     IllegalCSRAccessM;                              // Illegal access to CSR
  logic                     IllegalIEUFPUVPUInstrM;                            // Illegal IEU or FPU instruction, delayed to Mem stage
  logic                     InstrPageFaultM;                                // Instruction page fault, delayed to Mem stage
  logic                     InstrAccessFaultM;                              // Instruction access fault, delayed to Mem stages
  logic                     IllegalInstrFaultM;                             // Illegal instruction fault
  logic                     STATUS_SPP, STATUS_TSR, STATUS_TW, STATUS_TVM;  // Status bits needed within privileged unit
  logic                     STATUS_MIE, STATUS_SIE;                         // status bits: interrupt enables
  logic [11:0]              MIP_REGW, MIE_REGW;                             // interrupt pending and enable bits
  logic [1:0]               NextPrivilegeModeM;                             // next privilege mode based on trap or return
  logic                     DelegateM;                                      // trap should be delegated
  logic                     InterruptM;                                     // interrupt occurring
  logic                     ExceptionM;                                     // Memory stage instruction caused a fault
  logic                     HPTWInstrAccessFaultM;                          // Hardware page table access fault while fetching instruction PTE
  logic                     HPTWInstrPageFaultM;                            // Hardware page table page fault while fetching instruction PTE
  logic                     BreakpointFaultM, EcallFaultM;                  // breakpoint and Ecall traps should retire

  logic                     wfiW;

  // track the current privilege level
  privmode #(P) privmode(.clk, .reset, .StallW, .TrapM, .mretM, .sretM, .DelegateM,
    .STATUS_MPP, .STATUS_SPP, .NextPrivilegeModeM, .PrivilegeModeW);

  // decode privileged instructions
  privdec #(P) pmd(.clk, .reset, .StallW, .FlushW, .InstrM(InstrM[31:7]),
    .PrivilegedM, .IllegalIEUFPUVPUInstrM, .IllegalCSRAccessM,
    .PrivilegeModeW, .STATUS_TSR, .STATUS_TVM, .STATUS_TW, .TrapM, .IllegalInstrFaultM,
    .EcallFaultM, .BreakpointFaultM, .sretM, .mretM, .RetM, .wfiM, .wfiW, .sfencevmaM);

  // Control and Status Registers
  csr #(P) csr(.clk, .reset, .FlushM, .FlushW, .StallE, .StallM, .StallW,
    .InstrM, .InstrOrigM, .PCM, .PCSpillM, .SrcAM, .IEUAdrxTvalM,
    .CSRReadM, .CSRWriteM, .TrapM, .mretM, .sretM, .InterruptM,
    .MTimerInt, .MExtInt, .SExtInt, .MSwInt,
    .MTIME_CLINT, .InstrValidM, .FRegWriteM, .VRegWriteM,
    .WriteVLVTYPEM, .NewVLM, .NewVTYPEM, .NewVILLM, .SetVXSATM, .ClearVSTARTM,
    .VTYPE_REGW, .VL_REGW, .VSTART_REGW, .VXRM_REGW,
    .LoadStallD, .StoreStallD,
    .BPDirWrongM, .BTAWrongM, .RASPredPCWrongM, .BPWrongM,
    .sfencevmaM, .ExceptionM, .InvalidateICacheM, .ICacheStallF, .DCacheStallM, .DivBusyE, .FDivBusyE,
    .IClassWrongM, .IClassM, .DCacheMiss, .DCacheAccess, .ICacheMiss, .ICacheAccess,
    .NextPrivilegeModeM, .PrivilegeModeW, .CauseM, .SelHPTW,
    .STATUS_MPP, .STATUS_SPP, .STATUS_TSR, .STATUS_TVM,
    .STATUS_MIE, .STATUS_SIE, .STATUS_MXR, .STATUS_SUM, .STATUS_MPRV, .STATUS_TW, .STATUS_FS, .STATUS_VS,
    .MEDELEG_REGW, .MIP_REGW, .MIE_REGW, .MIDELEG_REGW,
    .SATP_REGW, .PMPCFG_ARRAY_REGW, .PMPADDR_ARRAY_REGW,
    .SetFflagsM, .FRM_REGW, .ENVCFG_CBE, .ENVCFG_PBMTE, .ENVCFG_ADUE,
    .EPCM, .TrapVectorM,
    .CSRReadValW, .IllegalCSRAccessM, .BigEndianM);

  // pipeline early-arriving trap sources
  privpiperegs ppr(.clk, .reset, .StallD, .StallE, .StallM, .FlushD, .FlushE, .FlushM,
    .InstrPageFaultF, .InstrAccessFaultF, .HPTWInstrAccessFaultF, .HPTWInstrPageFaultF, .IllegalIEUFPUVPUInstrD,
    .InstrPageFaultM, .InstrAccessFaultM, .HPTWInstrAccessFaultM, .HPTWInstrPageFaultM, .IllegalIEUFPUVPUInstrM);

  // trap logic
  trap #(P) trap(.reset,
    .InstrMisalignedFaultM, .InstrAccessFaultM, .HPTWInstrAccessFaultM, .HPTWInstrPageFaultM, .IllegalInstrFaultM,
    .BreakpointFaultM, .LoadMisalignedFaultM, .StoreAmoMisalignedFaultM,
    .LoadAccessFaultM, .StoreAmoAccessFaultM, .EcallFaultM, .InstrPageFaultM,
    .LoadPageFaultM, .StoreAmoPageFaultM, .PrivilegeModeW,
    .MIP_REGW, .MIE_REGW, .MIDELEG_REGW, .MEDELEG_REGW, .STATUS_MIE, .STATUS_SIE,
    .InstrValidM, .CommittedM, .CommittedF,
    .TrapM, .wfiM, .wfiW, .InterruptM, .ExceptionM, .IntPendingM, .DelegateM, .CauseM);
endmodule
