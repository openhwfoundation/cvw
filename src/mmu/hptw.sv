///////////////////////////////////////////
// hptw.sv
//
// Written: tfleming@hmc.edu 2 March 2021
// Modified:  david_harris@hmc.edu 18 July 2021 cleanup and simplification
//            kmacsaigoren@hmc.edu 1 June 2021
//            implemented SV48 on top of SV39. This included, adding a level of the FSM for the extra page number segment
//            adding support for terapage encoding, and for setting the HPTWAdr using the new level,
//            adding the internal SvMode signal
//
//            implemented SV57 on top of SV48, SV39. This included, adding a level of the FSM for the extra page number segment
//            adding support for petapage encoding, and for setting the HPTWAdr using the new level,
//            adding the internal SvMode signal
// Purpose: Hardware Page Table Walker
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
// OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
///////////////////////////////////////////

module hptw import cvw::*;  #(parameter cvw_t P) (
  input  logic              clk, reset,
  input  logic [P.XLEN-1:0] SATP_REGW,              // includes SATP.MODE to determine number of levels in page table
  input  logic [P.XLEN-1:0] PCSpillF,               // addresses to translate
  input  logic [P.XLEN+1:0] IEUAdrExtM,             // addresses to translate
  input  logic [1:0]        MemRWM, AtomicM,
  // system status
  input  logic              STATUS_MXR, STATUS_SUM, STATUS_MPRV,
  input  logic [1:0]        STATUS_MPP,
  input  logic              ENVCFG_ADUE,            // HPTW A/D Update enable
  input  logic [1:0]        PrivilegeModeW,
  input  logic [P.XLEN-1:0] ReadDataM,              // page table entry from LSU
  input  logic [P.XLEN-1:0] WriteDataM,
  input  logic              DCacheBusStallM,           // stall from LSU
  input  logic [2:0]        Funct3M,
  input  logic [6:0]        Funct7M,
  input  logic              ITLBMissOrUpdateAF,
  input  logic              DTLBMissOrUpdateDAM,
  input  logic              FlushW,
  input  logic [3:0]        CMOpM,
  output logic [P.XLEN-1:0] PTE,                    // page table entry to TLBs
  output logic [2:0]        PageType,               // page type to TLBs
  output logic              ITLBWriteF, DTLBWriteM, // write TLB with new entry
  output logic [1:0]        PreLSURWM,
  output logic [P.XLEN+1:0] IHAdrM,
  output logic [P.XLEN-1:0] IHWriteDataM,
  output logic [1:0]        LSUAtomicM,
  output logic [2:0]        LSUFunct3M,
  output logic [6:0]        LSUFunct7M,
  output logic [3:0]        LSUCMOpM,
  output logic              HPTWFlushW,
  output logic              SelHPTW,
  output logic              HPTWStall,
  input  logic              LSULoadAccessFaultM, LSUStoreAmoAccessFaultM,
  input  logic              LSULoadPageFaultM, LSUStoreAmoPageFaultM,
  output logic              LoadAccessFaultM, StoreAmoAccessFaultM, HPTWInstrAccessFaultF,
  output logic              LoadPageFaultM, StoreAmoPageFaultM, HPTWInstrPageFaultF
);

  typedef enum logic [3:0] {L0_ADR, L0_RD,
          L1_ADR, L1_RD,
          L2_ADR, L2_RD,
          L3_ADR, L3_RD,
          L4_ADR, L4_RD,
          LEAF, IDLE, UPDATE_PTE,
          FAULT} statetype;

  logic                     DTLBWalk; // register TLBs translation miss requests
  logic [P.PPN_BITS-1:0]    BasePageTablePPN;
  logic [P.PPN_BITS-1:0]    CurrentPPN;
  logic                     Executable, Writable, Readable, Valid, PTE_U;
  logic                     Misaligned, MegapageMisaligned;
  logic                     ValidPTE, LeafPTE, ValidLeafPTE, ValidNonLeafPTE;
  logic                     StartWalk;
  logic                     TLBMissOrUpdateDA;
  logic                     PRegEn;
  logic [2:0]               NextPageType;
  logic [P.SVMODE_BITS-1:0] SvMode;
  logic [P.XLEN-1:0]        TranslationVAdr;
  logic [P.XLEN-1:0]        NextPTE, NextPTE2;
  logic                     UpdatePTE;
  logic                     HPTWUpdateDA;
  logic [P.PA_BITS-1:0]     HPTWReadAdr;
  logic                     SelHPTWAdr;
  logic [P.XLEN+1:0]        HPTWAdrExt;
  logic                     LSUAccessFaultM;
  logic [P.PA_BITS-1:0]     HPTWAdr;
  logic [1:0]               HPTWRW;
  logic [2:0]               HPTWSize; // 32 or 64 bit access
  statetype                 WalkerState, NextWalkerState, InitialWalkerState;
  logic                     HPTWLoadAccessFault, HPTWStoreAmoAccessFault, HPTWInstrAccessFault;
  logic                     HPTWLoadAccessFaultDelay, HPTWStoreAmoAccessFaultDelay, HPTWInstrAccessFaultDelay;
  logic                     HPTWLoadPageFault, HPTWStoreAmoPageFault, HPTWInstrPageFault;
  logic                     HPTWLoadPageFaultDelay, HPTWStoreAmoPageFaultDelay, HPTWInstrPageFaultDelay;
  logic                     HPTWAccessFaultDelay;
  logic                     TakeHPTWFault;
  logic                     PBMTFaultM;
  logic                     DAUFaultM;
  logic                     PBMTOrDAUFaultM;
  logic                     HPTWFaultM;

  // map hptw access faults onto either the original LSU load/store fault or instruction access fault
  assign LSUAccessFaultM         = LSULoadAccessFaultM | LSUStoreAmoAccessFaultM;
  assign PBMTOrDAUFaultM         = PBMTFaultM | DAUFaultM;
  assign HPTWFaultM              = LSUAccessFaultM | PBMTOrDAUFaultM;
  assign HPTWLoadAccessFault     = LSUAccessFaultM & DTLBWalk & MemRWM[1] & ~MemRWM[0];
  assign HPTWStoreAmoAccessFault = LSUAccessFaultM & DTLBWalk & (MemRWM[0] | (|CMOpM));
  assign HPTWInstrAccessFault    = LSUAccessFaultM & ~DTLBWalk;
  assign HPTWLoadPageFault       = PBMTOrDAUFaultM & DTLBWalk & MemRWM[1] & ~MemRWM[0];
  assign HPTWStoreAmoPageFault   = PBMTOrDAUFaultM & DTLBWalk & (MemRWM[0] | (|CMOpM));
  assign HPTWInstrPageFault      = PBMTOrDAUFaultM & ~DTLBWalk;

  flopr #(6) HPTWAccesFaultReg(clk, reset, {HPTWLoadAccessFault, HPTWStoreAmoAccessFault, HPTWInstrAccessFault,
                                            HPTWLoadPageFault, HPTWStoreAmoPageFault, HPTWInstrPageFault},
                               {HPTWLoadAccessFaultDelay, HPTWStoreAmoAccessFaultDelay, HPTWInstrAccessFaultDelay,
                                HPTWLoadPageFaultDelay, HPTWStoreAmoPageFaultDelay, HPTWInstrPageFaultDelay});

  assign TakeHPTWFault = WalkerState != IDLE;

  // Improve timing by taking HPTW faults off critical path because these are multicycle operations anyway
  assign LoadAccessFaultM      = TakeHPTWFault ? HPTWLoadAccessFaultDelay : LSULoadAccessFaultM;
  assign StoreAmoAccessFaultM  = TakeHPTWFault ? HPTWStoreAmoAccessFaultDelay : LSUStoreAmoAccessFaultM;
  assign HPTWInstrAccessFaultF = TakeHPTWFault ? HPTWInstrAccessFaultDelay : 1'b0;
  assign LoadPageFaultM        = TakeHPTWFault ? HPTWLoadPageFaultDelay : LSULoadPageFaultM;
  assign StoreAmoPageFaultM    = TakeHPTWFault ? HPTWStoreAmoPageFaultDelay : LSUStoreAmoPageFaultM;
  assign HPTWInstrPageFaultF   = TakeHPTWFault ? HPTWInstrPageFaultDelay : 1'b0;

  // Extract bits from CSRs and inputs
  assign SvMode = SATP_REGW[P.XLEN-1:P.XLEN-P.SVMODE_BITS];
  assign BasePageTablePPN = SATP_REGW[P.PPN_BITS-1:0];
  assign TLBMissOrUpdateDA = DTLBMissOrUpdateDAM | ITLBMissOrUpdateAF;

  // Determine which address to translate
  mux2 #(P.XLEN) vadrmux(PCSpillF, IEUAdrExtM[P.XLEN-1:0], DTLBWalk, TranslationVAdr);
  assign CurrentPPN = PTE[P.PPN_BITS+9:10];

  // State flops
  flopenr #(1) TLBMissMReg(clk, reset, StartWalk, DTLBMissOrUpdateDAM, DTLBWalk); // when walk begins, record whether it was for DTLB (or record 0 for ITLB)
  assign PRegEn = HPTWRW[1] & ~DCacheBusStallM | UpdatePTE | (NextWalkerState == IDLE);
  assign NextPTE2 = (NextWalkerState == IDLE) ? '0 : NextPTE;
  flopenr #(P.XLEN) PTEReg(clk, reset, PRegEn, NextPTE2, PTE); // Capture page table entry from data cache

  // Assign PTE descriptors common across all XLEN values
  // For non-leaf PTEs, D, A, U bits are reserved and ignored.  They do not cause faults while walking the page table
  assign {PTE_U, Executable, Writable, Readable, Valid} = PTE[4:0];
  assign LeafPTE = Executable | Writable | Readable;
  assign ValidPTE = Valid & ~(Writable & ~Readable);
  assign ValidLeafPTE = ValidPTE & LeafPTE;
  assign ValidNonLeafPTE = Valid & ~LeafPTE;
  if(P.XLEN == 64) assign PBMTFaultM = ValidNonLeafPTE & (|PTE[62:61]);
  else assign PBMTFaultM = 1'b0;
  assign DAUFaultM = ValidNonLeafPTE & (|PTE[7:6] | PTE[4]);

  if(P.SVADU_SUPPORTED) begin : hptwwrites
    logic                 ReadAccess, WriteAccess;
    logic                 InvalidRead, InvalidWrite, InvalidOp;
    logic                 UpperBitsUnequal, UpperBitsUnequalD;
    logic                 OtherPageFault;
    logic [1:0]           EffectivePrivilegeMode;
    logic                 ImproperPrivilege;
    logic                 SaveHPTWAdr, SelHPTWWriteAdr;
    logic [P.PA_BITS-1:0] HPTWWriteAdr;
    logic                 SetDirty;
    logic                 Dirty, Accessed;
    logic [P.XLEN-1:0]    AccessedPTE;

    assign AccessedPTE = {PTE[P.XLEN-1:8], (SetDirty | PTE[7]), 1'b1, PTE[5:0]}; // set accessed bit, conditionally set dirty bit
    mux2 #(P.XLEN) NextPTEMux(ReadDataM, AccessedPTE, UpdatePTE, NextPTE); // NextPTE = ReadDataM when ADUE = 0 because UpdatePTE = 0
    flopenr #(P.PA_BITS) HPTWAdrWriteReg(clk, reset, SaveHPTWAdr, HPTWReadAdr, HPTWWriteAdr);

    assign SaveHPTWAdr = (NextWalkerState == L0_RD | NextWalkerState == L1_RD | NextWalkerState == L2_RD | NextWalkerState == L3_RD | NextWalkerState == L4_RD); // save the HPTWAdr when the walker is about to read the PTE at any level; the last level read is the one to write during UpdatePTE
    assign SelHPTWWriteAdr = UpdatePTE | HPTWRW[0];
    mux2 #(P.PA_BITS) HPTWWriteAdrMux(HPTWReadAdr, HPTWWriteAdr, SelHPTWWriteAdr, HPTWAdr);

    assign {Dirty, Accessed} = PTE[7:6];
    assign WriteAccess = MemRWM[0]; // implies | (|AtomicM);
    assign SetDirty = ~Dirty & DTLBWalk & (WriteAccess | CMOpM[3]);
    assign ReadAccess = MemRWM[1];

    assign EffectivePrivilegeMode = DTLBWalk ? (STATUS_MPRV ? STATUS_MPP : PrivilegeModeW) : PrivilegeModeW; // DTLB uses MPP mode when MPRV is 1
    assign ImproperPrivilege = ((EffectivePrivilegeMode == P.U_MODE) & ~PTE_U) |
                               ((EffectivePrivilegeMode == P.S_MODE) & PTE_U & (~STATUS_SUM & DTLBWalk));

    // Check for page faults
    vm64check #(P) vm64check(.SATP_MODE(SATP_REGW[P.XLEN-1:P.XLEN-P.SVMODE_BITS]), .VAdr(TranslationVAdr),
      .SV39Mode(), .SV48Mode(), .UpperBitsUnequal);
    // This register is not functionally necessary, but improves the critical path.
    flopr #(1) upperbitsunequalreg(clk, reset, UpperBitsUnequal, UpperBitsUnequalD);
    assign InvalidRead = ReadAccess & ~Readable & (~STATUS_MXR | ~Executable);
    assign InvalidWrite = WriteAccess & ~Writable;
    assign InvalidOp = DTLBWalk ? (InvalidRead | InvalidWrite) : ~Executable;
    assign OtherPageFault = ImproperPrivilege | InvalidOp | UpperBitsUnequalD | Misaligned | ~Valid;

    // hptw needs to know if there is a Dirty or Access fault occurring on this
    // memory access.  If there is the PTE needs to be updated setting Access
    // and possibly also Dirty.  Dirty is set if the operation is a store/amo.
    // However any other fault should not cause the update, and updates are in software when ENVCFG_ADUE = 0
    assign HPTWUpdateDA = ValidLeafPTE & (~Accessed | SetDirty) & ENVCFG_ADUE & ~OtherPageFault;

    assign HPTWRW[0] = (WalkerState == UPDATE_PTE);           // HPTWRW[0] will always be 0 if ADUE = 0 because HPTWUpdateDA will be 0 so WalkerState never is UPDATE_PTE
    assign UpdatePTE = (WalkerState == LEAF) & HPTWUpdateDA;  // UpdatePTE will always be 0 if ADUE = 0 because HPTWUpdateDA will be 0

  end else begin // block: hptwwrites
    assign NextPTE = ReadDataM;
    assign HPTWAdr = HPTWReadAdr;
    assign HPTWUpdateDA = 1'b0;
    assign UpdatePTE = 1'b0;
    assign HPTWRW[0] = 1'b0;
  end

  // Enable and select signals based on states
  assign StartWalk  = (WalkerState == IDLE) & TLBMissOrUpdateDA;
  assign HPTWRW[1]  = (WalkerState == L4_RD & P.SV57_SUPPORTED) |
                      (WalkerState == L3_RD & P.SV48_SUPPORTED) |
                      (WalkerState == L2_RD & P.SV39_SUPPORTED) |
                      (WalkerState == L1_RD) | (WalkerState == L0_RD);
  assign DTLBWriteM = (WalkerState == LEAF & ~HPTWUpdateDA) & DTLBWalk;
  assign ITLBWriteF = (WalkerState == LEAF & ~HPTWUpdateDA) & ~DTLBWalk;

  // FSM to track PageType based on the levels of the page table traversed
  flopr #(3) PageTypeReg(clk, reset, NextPageType, PageType);
  always_comb
    case (WalkerState)
      L4_RD:  NextPageType = 3'b100; // petapage
      L3_RD:  NextPageType = 3'b011; // terapage
      L2_RD:  NextPageType = 3'b010; // gigapage
      L1_RD:  NextPageType = 3'b001; // megapage
      L0_RD:  NextPageType = 3'b000; // kilopage
      default: NextPageType = PageType;
    endcase

  // HPTWAdr muxing
  if (P.XLEN==32) begin // RV32
    logic [9:0] VPN;
    logic [P.PPN_BITS-1:0] PPN;
    assign VPN = ((WalkerState == L1_ADR) | (WalkerState == L1_RD)) ? TranslationVAdr[31:22] : TranslationVAdr[21:12]; // select VPN field based on HPTW state
    assign PPN = ((WalkerState == L1_ADR) | (WalkerState == L1_RD)) ? BasePageTablePPN : CurrentPPN;
    assign HPTWReadAdr = {PPN, VPN, 2'b00};
    assign HPTWSize = 3'b010;
  end else begin // RV64
    logic [8:0] VPN;
    logic [P.PPN_BITS-1:0] PPN;
    always_comb
      case (WalkerState) // select VPN field based on HPTW state
        L4_ADR, L4_RD:  VPN = TranslationVAdr[56:48]; // Extracted top 9 bits for sv57
        L3_ADR, L3_RD:  VPN = TranslationVAdr[47:39];
        L2_ADR, L2_RD:  VPN = TranslationVAdr[38:30];
        L1_ADR, L1_RD:   VPN = TranslationVAdr[29:21];
        default:    VPN = TranslationVAdr[20:12];
      endcase
      assign PPN = ((P.SV57_SUPPORTED & SvMode == P.SV57 & (WalkerState == L4_ADR | WalkerState == L4_RD)) |
                    (P.SV48_SUPPORTED & SvMode == P.SV48 & (WalkerState == L3_ADR | WalkerState == L3_RD)) |
                    (SvMode == P.SV39 & (WalkerState == L2_ADR | WalkerState == L2_RD)) ) ? BasePageTablePPN : CurrentPPN;
    assign HPTWReadAdr = {PPN, VPN, 3'b000};
    assign HPTWSize = 3'b011;
  end

  // Initial state and misalignment for RV32/64
  if (P.XLEN == 32) begin
    assign InitialWalkerState = L1_ADR;
    assign MegapageMisaligned = |(CurrentPPN[9:0]); // must have zero PPN0
    assign Misaligned = ((WalkerState == L0_ADR) & MegapageMisaligned);
  end else begin
    logic  PetapageMisaligned, GigapageMisaligned, TerapageMisaligned;
    assign InitialWalkerState = (P.SV57_SUPPORTED & SvMode == P.SV57) ? L4_ADR :
                                (P.SV48_SUPPORTED & SvMode == P.SV48) ? L3_ADR :
                                                                        L2_ADR ;
    assign PetapageMisaligned = P.SV57_SUPPORTED & |(CurrentPPN[35:0]); // Must have zero PPN3, PPN2, PPN1, PPN0
    assign TerapageMisaligned = P.SV48_SUPPORTED & |(CurrentPPN[26:0]); // Must have zero PPN2, PPN1, PPN0
    assign GigapageMisaligned =                    |(CurrentPPN[17:0]); // Must have zero PPN1 and PPN0
    assign MegapageMisaligned = |(CurrentPPN[8:0]);  // Must have zero PPN0
    assign Misaligned = (P.SV57_SUPPORTED & (WalkerState == L3_ADR) & PetapageMisaligned) |
                        (P.SV48_SUPPORTED & (WalkerState == L2_ADR) & TerapageMisaligned) |
                                           ((WalkerState == L1_ADR) & GigapageMisaligned) |
                                           ((WalkerState == L0_ADR) & MegapageMisaligned);
  end

  // Page Table Walker FSM
  flopenl #(.TYPE(statetype)) WalkerStateReg(clk, reset | FlushW, 1'b1, NextWalkerState, IDLE, WalkerState);
  always_comb
    case (WalkerState)
      IDLE:       if (TLBMissOrUpdateDA)                              NextWalkerState = InitialWalkerState;
                  else                                                NextWalkerState = IDLE;
      L4_ADR:                                                         NextWalkerState = L4_RD; // First access in SV57
      L4_RD:      if (HPTWFaultM)                                     NextWalkerState = FAULT;
                  else if (DCacheBusStallM)                           NextWalkerState = L4_RD;
                  else                                                NextWalkerState = L3_ADR;   // Transition to level 3
      L3_ADR:     if (HPTWFaultM)                                     NextWalkerState = FAULT;
                  else if (InitialWalkerState == L3_ADR | ValidNonLeafPTE) NextWalkerState = L3_RD; // First access in SV48
                  else                                                NextWalkerState = LEAF;
      L3_RD:      if (HPTWFaultM)                                     NextWalkerState = FAULT;
                  else if (DCacheBusStallM)                           NextWalkerState = L3_RD;
                  else                                                NextWalkerState = L2_ADR;
      L2_ADR:     if (HPTWFaultM)                                     NextWalkerState = FAULT;
                  else if (InitialWalkerState == L2_ADR | ValidNonLeafPTE) NextWalkerState = L2_RD; // First access in SV39
                  else                                                NextWalkerState = LEAF;
      L2_RD:      if (HPTWFaultM)                                     NextWalkerState = FAULT;
                  else if (DCacheBusStallM)                           NextWalkerState = L2_RD;
                  else                                                NextWalkerState = L1_ADR;
      L1_ADR:     if  (HPTWFaultM)                                     NextWalkerState = FAULT;
                  else if (InitialWalkerState == L1_ADR | ValidNonLeafPTE) NextWalkerState = L1_RD; // First access in SV32
                  else                                                NextWalkerState = LEAF;
      L1_RD:      if (HPTWFaultM)                                     NextWalkerState = FAULT;
                  else if (DCacheBusStallM)                           NextWalkerState = L1_RD;
                  else                                                NextWalkerState = L0_ADR;
      L0_ADR:     if (HPTWFaultM)                                     NextWalkerState = FAULT;
                  else if (ValidNonLeafPTE)                           NextWalkerState = L0_RD;
                  else                                                NextWalkerState = LEAF;
      L0_RD:      if (HPTWFaultM)                                     NextWalkerState = FAULT;
                  else if (DCacheBusStallM)                           NextWalkerState = L0_RD;
                  else                                                NextWalkerState = LEAF;
      LEAF:       if (P.SVADU_SUPPORTED & HPTWUpdateDA)               NextWalkerState = UPDATE_PTE;
                  else                                                NextWalkerState = IDLE;
      UPDATE_PTE: if (HPTWFaultM)                                     NextWalkerState = FAULT;
                  else if (DCacheBusStallM)                           NextWalkerState = UPDATE_PTE;
                  else                                                NextWalkerState = LEAF;
      FAULT:                                                          NextWalkerState = IDLE;
      default:                                                        NextWalkerState = IDLE; // Should never be reached
    endcase // case (WalkerState)

  assign HPTWFlushW = (WalkerState == IDLE & TLBMissOrUpdateDA) | (WalkerState != IDLE & HPTWFaultM);

  assign SelHPTW = WalkerState != IDLE;
  assign HPTWStall = (WalkerState != IDLE & WalkerState != FAULT) | (WalkerState == IDLE & TLBMissOrUpdateDA);

  // HTPW address/data/control muxing

  // Once the walk is done and it is time to update the TLB we need to switch back
  // to the original data virtual address.
  assign SelHPTWAdr = SelHPTW & ~(DTLBWriteM | ITLBWriteF);

  // multiplex the outputs to LSU
  if (P.XLEN == 64) assign HPTWAdrExt = {{(P.XLEN+2-P.PA_BITS){1'b0}}, HPTWAdr}; // Extend to 66 bits
  else              assign HPTWAdrExt = HPTWAdr;
  mux2 #(2) rwmux(MemRWM, HPTWRW, SelHPTW, PreLSURWM);
  mux2 #(3) sizemux(Funct3M, HPTWSize, SelHPTW, LSUFunct3M);
  mux2 #(7) funct7mux(Funct7M, 7'b0, SelHPTW, LSUFunct7M);
  mux2 #(2) atomicmux(AtomicM, 2'b00, SelHPTW, LSUAtomicM);
  mux2 #(4) cmomux(CMOpM, 4'b0, SelHPTW, LSUCMOpM);
  mux2 #(P.XLEN+2) lsupadrmux(IEUAdrExtM, HPTWAdrExt, SelHPTWAdr, IHAdrM);
  if (P.SVADU_SUPPORTED)
    mux2 #(P.XLEN) lsuwritedatamux(WriteDataM, PTE, SelHPTW, IHWriteDataM);
  else assign IHWriteDataM = WriteDataM;

endmodule
