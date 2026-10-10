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
// https://github.com/openhwfoundation/cvw
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

module privileged import cvw::*; #(parameter cvw_t P) (
  input  logic              clk, reset,                                     // Clock and reset
  input  logic              StallD, StallE, StallM, StallW,                 // Stall Decode, Execute, Memory, Writeback stages
  input  logic              FlushD, FlushE, FlushM, FlushW,                 // Flush Decode, Execute, Memory, Writeback stages
  // CSR Reads and Writes, and values needed for traps
  input  logic              CSRReadM, CSRWriteM,                            // CSR read and CSR write instructions
  input  logic [P.XLEN-1:0] SrcAM,                                          // ALU source A in Memory stage, for CSR writes
  input  logic [31:0]       InstrM,                                         // Instruction in Memory stage
  input  logic [31:0]       InstrOrigM,                                     // Original compressed or uncompressed instruction in Memory stage for Illegal Instruction XTVAL
  input  logic [P.XLEN-1:0] IEUAdrxTvalM,                                   // IEUAdrM, or the address of the spilled half for xtval
  input  logic [P.XLEN-1:0] PCM,                                            // PC in Memory stage
  input  logic [P.XLEN-1:0] PCSpillM,                                       // PCM, or PCM + 2 if the second half of a spilled fetch faulted
  // control signals
  input  logic              InstrValidM,                                    // Instruction in Memory stage is valid
  input  logic              CommittedM, CommittedF,                         // LSU and IFU have started operations that must not be interrupted
  input  logic              PrivilegedM,                                    // Privileged instruction
  // processor events for performance counter logging
  input  logic              FRegWriteM,                                     // FP register write enable in Memory stage
  input  logic              LoadStallD,                                     // Load-use stall, for performance counters
  input  logic              StoreStallD,                                    // Store-load hazard stall, for performance counters
  input  logic              ICacheStallF,                                   // I$ busy with multicycle operation
  input  logic              DCacheStallM,                                   // D$ busy with multicycle operation
  input  logic              BPDirWrongM,                                    // Branch direction mispredicted in Memory stage
  input  logic              BTAWrongM,                                      // Branch target prediction was wrong
  input  logic              RASPredPCWrongM,                                // RAS return address prediction was wrong
  input  logic              IClassWrongM,                                   // Instruction class prediction was wrong
  input  logic              BPWrongM,                                       // Branch predictor was wrong in Memory stage
  input  logic [3:0]        IClassM,                                        // Instruction class in Memory stage, one-hot {call, return, jump, branch}
  input  logic              DCacheMiss,                                     // D$ miss, for performance counters
  input  logic              DCacheAccess,                                   // D$ access, for performance counters
  input  logic              ICacheMiss,                                     // I$ miss, for performance counters
  input  logic              ICacheAccess,                                   // I$ access, for performance counters
  input  logic              DivBusyE,                                       // Integer divider busy
  input  logic              FDivBusyE,                                      // FPU divider busy
  // fault sources
  input  logic              InstrAccessFaultF,                              // Instruction access fault in Fetch stage
  input  logic              LoadAccessFaultM, StoreAmoAccessFaultM,         // Load and store/AMO access faults
  input  logic              HPTWInstrAccessFaultF,                          // HPTW access fault during instruction page table walk, in Fetch stage
  input  logic              HPTWInstrPageFaultF,                            // HPTW page fault during instruction page table walk, in Fetch stage
  input  logic              InstrPageFaultF,                                // Instruction page fault in Fetch stage
  input  logic              LoadPageFaultM, StoreAmoPageFaultM,             // Load and store/AMO page faults
  input  logic              InstrMisalignedFaultM,                          // Instruction address misaligned fault
  input  logic              LoadMisalignedFaultM, StoreAmoMisalignedFaultM, // Load and store/AMO address misaligned faults
  input  logic              IllegalIEUFPUInstrD,                            // Illegal integer or FP instruction in Decode stage
  input  logic              MTimerInt, MExtInt, SExtInt, MSwInt,            // Interrupt sources: machine timer, machine and supervisor external, machine software
  input  logic [63:0]       MTIME_CLINT,                                    // MTIME from CLINT
  input  logic [4:0]        SetFflagsM,                                     // FP exception flags to set in fflags
  input  logic              SelHPTW,                                        // HPTW is accessing memory through the LSU
  // CSR outputs
  output logic [P.XLEN-1:0] CSRReadValW,                                    // CSR read value
  output logic [1:0]        PrivilegeModeW,                                 // Current privilege mode
  output logic [P.XLEN-1:0] SATP_REGW,                                      // satp CSR
  output logic              STATUS_MXR, STATUS_SUM, STATUS_MPRV,            // mstatus.MXR, SUM, MPRV: control address translation permissions
  output logic [1:0]        STATUS_MPP, STATUS_FS,                          // mstatus.MPP, FS: machine previous privilege mode, FPU state
  output var logic [7:0]    PMPCFG_ARRAY_REGW[P.PMP_ENTRIES-1:0],           // PMP configuration CSRs
  output var logic [P.PA_BITS-3:0] PMPADDR_ARRAY_REGW [P.PMP_ENTRIES-1:0],  // PMP address CSRs
  output logic [2:0]        FRM_REGW,                                       // Rounding mode from fcsr
  output logic [3:0]        ENVCFG_CBE,                                     // Cache block operation enables
  output logic              ENVCFG_PBMTE,                                   // Page-based memory types enabled
  output logic              ENVCFG_ADUE,                                    // HPTW A/D Update enable
  // PC logic output from privileged unit to IFU
  output logic [P.XLEN-1:0] EPCM,                                           // Return address (mepc or sepc) for mret/sret
  output logic [P.XLEN-1:0] TrapVectorM,                                    // Trap vector address
  // control outputs
  output logic              RetM, TrapM,                                    // mret or sret instruction, trap is occurring
  output logic              sfencevmaM,                                     // sfence.vma: invalidate TLB entries
  output logic              sfencevmaAllM,                                  // sfence.vma with rs2=x0: flush all TLB entries including global
  input  logic              InvalidateICacheM,                              // fence.i: invalidate the I$
  output logic              BigEndianM,                                     // Memory access is big-endian
  // Fault outputs
  output logic              wfiM, IntPendingM                               // wfi instruction, interrupt pending
);

  logic [4:0]               CauseM;                                         // trap cause
  logic [15:0]              MEDELEG_REGW;                                   // exception delegation CSR
  logic [11:0]              MIDELEG_REGW;                                   // interrupt delegation CSR
  logic                     sretM, mretM;                                   // supervisor / machine return instruction
  logic                     IllegalCSRAccessM;                              // Illegal access to CSR
  logic                     IllegalIEUFPUInstrM;                            // Illegal IEU or FPU instruction, delayed to Mem stage
  logic                     InstrPageFaultM;                                // Instruction page fault, delayed to Mem stage
  logic                     InstrAccessFaultM;                              // Instruction access fault, delayed to Mem stage
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
    .PrivilegedM, .IllegalIEUFPUInstrM, .IllegalCSRAccessM,
    .PrivilegeModeW, .STATUS_TSR, .STATUS_TVM, .STATUS_TW, .TrapM, .IllegalInstrFaultM,
    .EcallFaultM, .BreakpointFaultM, .sretM, .mretM, .RetM, .wfiM, .wfiW, .sfencevmaM, .sfencevmaAllM);

  // Control and Status Registers
  csr #(P) csr(.clk, .reset, .FlushM, .FlushW, .StallE, .StallM, .StallW,
    .InstrM, .InstrOrigM, .PCM, .PCSpillM, .SrcAM, .IEUAdrxTvalM,
    .CSRReadM, .CSRWriteM, .TrapM, .mretM, .sretM, .InterruptM,
    .MTimerInt, .MExtInt, .SExtInt, .MSwInt,
    .MTIME_CLINT, .InstrValidM, .FRegWriteM, .LoadStallD, .StoreStallD,
    .BPDirWrongM, .BTAWrongM, .RASPredPCWrongM, .BPWrongM,
    .sfencevmaM, .ExceptionM, .InvalidateICacheM, .ICacheStallF, .DCacheStallM, .DivBusyE, .FDivBusyE,
    .IClassWrongM, .IClassM, .DCacheMiss, .DCacheAccess, .ICacheMiss, .ICacheAccess,
    .NextPrivilegeModeM, .PrivilegeModeW, .CauseM, .SelHPTW,
    .STATUS_MPP, .STATUS_SPP, .STATUS_TSR, .STATUS_TVM,
    .STATUS_MIE, .STATUS_SIE, .STATUS_MXR, .STATUS_SUM, .STATUS_MPRV, .STATUS_TW, .STATUS_FS,
    .MEDELEG_REGW, .MIP_REGW, .MIE_REGW, .MIDELEG_REGW,
    .SATP_REGW, .PMPCFG_ARRAY_REGW, .PMPADDR_ARRAY_REGW,
    .SetFflagsM, .FRM_REGW, .ENVCFG_CBE, .ENVCFG_PBMTE, .ENVCFG_ADUE,
    .EPCM, .TrapVectorM,
    .CSRReadValW, .IllegalCSRAccessM, .BigEndianM);

  // pipeline early-arriving trap sources
  privpiperegs ppr(.clk, .reset, .StallD, .StallE, .StallM, .FlushD, .FlushE, .FlushM,
    .InstrPageFaultF, .InstrAccessFaultF, .HPTWInstrAccessFaultF, .HPTWInstrPageFaultF, .IllegalIEUFPUInstrD,
    .InstrPageFaultM, .InstrAccessFaultM, .HPTWInstrAccessFaultM, .HPTWInstrPageFaultM, .IllegalIEUFPUInstrM);

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
