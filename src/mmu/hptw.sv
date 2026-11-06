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
// OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
///////////////////////////////////////////

module hptw import cvw::*;  #(parameter cvw_t P) (
  input  logic              clk, reset,
  input  logic [P.XLEN-1:0] SATP_REGW,              // includes SATP.MODE to determine number of levels in page table
  input  logic [P.XLEN-1:0] VSATP_REGW,             // VS-stage translation when V=1 or for HLV/HSV
  input  logic [P.XLEN-1:0] HGATP_REGW,             // G-stage translation when V=1 or for HLV/HSV
  input  logic              VirtModeW,              // current virtualization mode V
  input  logic              MSTATUS_MPV,            // mstatus.MPV: effective V for data accesses when MPRV=1
  input  logic              HLVHSVLegalM,           // HLV/HLVX/HSV access is translated as if V=1
  input  logic [P.XLEN-1:0] PCSpillF,               // addresses to translate
  input  logic [P.XLEN+1:0] IEUAdrExtM,             // addresses to translate
  input  logic [1:0]        MemRWM, AtomicM,
  input  logic              FpLoadStoreM,           // FP load/store in M
  // system status
  input  logic              STATUS_MXR, STATUS_SUM, STATUS_MPRV,
  input  logic [1:0]        STATUS_MPP,
  input  logic              ENVCFG_ADUE,            // HPTW A/D Update enable
  input  logic              ENVCFG_PBMTE,           // Page-based memory types enabled
  input  logic [1:0]        PrivilegeModeW,
  input  logic [P.XLEN-1:0] ReadDataM,              // page table entry from LSU
  input  logic [P.XLEN-1:0] WriteDataM,
  input  logic              DCacheBusStallM,        // stall from LSU
  input  logic              MemAccessInFlightM,     // LSU has started (or performed and is holding) the M-stage memory access; do not pre-empt it
  input  logic              MemAccessDoneM,         // LSU has performed and captured the M-stage memory access; it will not be re-issued
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
  output logic              LSUFpLoadStoreM,        // FpLoadStoreM, cleared for the walker's PTE accesses
  output logic              HPTWFlushW,
  output logic              SelHPTW,
  output logic              HPTWStall,
  input  logic              LSULoadAccessFaultM, LSUStoreAmoAccessFaultM,
  input  logic              LSULoadPageFaultM, LSUStoreAmoPageFaultM,
  output logic              LoadAccessFaultM, StoreAmoAccessFaultM, HPTWInstrAccessFaultF,
  output logic              LoadPageFaultM, StoreAmoPageFaultM, HPTWInstrPageFaultF
);

  typedef enum logic [4:0] {L0_ADR, L0_RD,
          L1_ADR, L1_RD,
          L2_ADR, L2_RD,
          L3_ADR, L3_RD,
          L4_ADR, L4_RD,
          LEAF, IDLE, UPDATE_PTE,
          G0_ADR, G0_RD,
          G1_ADR, G1_RD,
          G2_ADR, G2_RD,
          G3_ADR, G3_RD,
          G4_ADR, G4_RD,
          GLEAF, GUPDATE_PTE,
          FAULT} statetype;

  // Why the G-stage walk was entered, so GLEAF knows where to go next
  typedef enum logic [1:0] {GFINAL,          // translate the final GPA of the access; GLEAF writes the TLB
          GIMPLICIT_RD,                      // translate the GPA of a VS-stage PTE read; GLEAF returns to Lx_RD
          GIMPLICIT_WR} gpurposetype;        // translate the GPA of a VS-stage PTE A/D update; GLEAF goes to UPDATE_PTE

  logic                     DTLBWalk; // current walk is for the DTLB (else ITLB)
  logic                     DTLBWalkPending, ITLBWalkPending; // requests recorded when the walker left IDLE, cleared as each completes
  logic                     DTLBReq, ITLBReq, AcceptReq;
  logic                     WalkDone;
  logic                     TLBWriteNow; // last cycle of a walk that writes the TLB (VS/single-stage LEAF, or final G-stage GLEAF)
  logic [P.PPN_BITS-1:0]    BasePageTablePPN;
  logic [P.PPN_BITS-1:0]    CurrentPPN;
  logic                     Executable, Writable, Readable, Valid, PTE_U;
  logic                     Misaligned, MegapageMisaligned;
  logic                     ValidPTE, LeafPTE, ValidLeafPTE, ValidNonLeafPTE;
  logic                     StartWalk;
  logic                     PRegEn;
  logic [2:0]               LevelPageType;          // page size implied by the level of the PTE being read
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
  logic                     NonLeafReservedFaultM;
  logic                     DAUFaultM;
  logic                     NonLeafPageFaultM;
  logic                     HPTWFaultM;
  gpurposetype              GPurpose, NextGPurpose;

  localparam GPA_BITS = (P.XLEN==32) ? 34 : 64;
  logic [P.PA_BITS-1:0]     Stage1ReadAdr;          // address of the next VS-stage (or single-stage) PTE read
  logic [P.PA_BITS-1:0]     GHPTWReadAdr;           // address of the next G-stage PTE read
  logic [GPA_BITS-1:0]      GPAReg, NextGPA, FinalGPA;
  logic [P.PPN_BITS-1:0]     FinalGPPN;
  logic [P.XLEN-1:0]        effSATP;
  logic [P.SVMODE_BITS-1:0] effSATP_MODE, HGATP_MODE;
  localparam logic [P.SVMODE_BITS-1:0] BARE = P.NO_TRANSLATE[P.SVMODE_BITS-1:0]; // MODE = 0 selects Bare in satp, vsatp, and hgatp
  statetype                 GInitialWalkerState, ReturnState, ReturnStateVal;
  logic                     S1Active, GActive;      // walk the VS/single stage table; walk the G-stage table
  logic                     TwoStage;               // VS-stage and G-stage both active: VS-stage PTEs live at GPAs
  logic                     InGWalk, EnterGWalk;    // walker is in a G-stage state; walker is about to start a G-stage walk
  logic [2:0]               GPageType;              // page size of the G-stage leaf
  logic [P.PPN_BITS-1:0]    SPAPPN;                 // PPN of the supervisor physical address produced by the G-stage
  logic [P.PA_BITS-1:0]     SPA, SPAReg;            // supervisor physical address produced by the G-stage
  logic                     GPAUpperBitsNonzero;    // GPA is wider than the G-stage mode allows: guest-page fault

  // map hptw access faults onto either the original LSU load/store fault or instruction access fault
  assign LSUAccessFaultM         = LSULoadAccessFaultM | LSUStoreAmoAccessFaultM;
  assign NonLeafPageFaultM       = NonLeafReservedFaultM | DAUFaultM;
  assign HPTWFaultM              = LSUAccessFaultM | NonLeafPageFaultM;
  assign HPTWLoadAccessFault     = LSUAccessFaultM & DTLBWalk & MemRWM[1] & ~MemRWM[0];
  assign HPTWStoreAmoAccessFault = LSUAccessFaultM & DTLBWalk & (MemRWM[0] | (|CMOpM));
  assign HPTWInstrAccessFault    = LSUAccessFaultM & ~DTLBWalk;
  assign HPTWLoadPageFault       = NonLeafPageFaultM & DTLBWalk & MemRWM[1] & ~MemRWM[0];
  assign HPTWStoreAmoPageFault   = NonLeafPageFaultM & DTLBWalk & (MemRWM[0] | (|CMOpM));
  assign HPTWInstrPageFault      = NonLeafPageFaultM & ~DTLBWalk;

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

  // Request arbitration and sequencing (issues #1538, #1766)
  // The walker records the translation requests present when it leaves IDLE and serves them in the order
  // DTLB walk, then ITLB walk.  The M-stage memory access itself is performed only after both complete,
  // because nothing but the M->W pipeline register can capture its result.
  //   DTLBReq: the M-stage access needs a DTLB fill or A/D update.  It has not started, so it is pre-empted
  //            (HPTWFlushW) and replayed after the walk(s).
  //   ITLBReq: the F-stage fetch needs an ITLB fill or A update.  It is deferred while the LSU has a memory
  //            access in flight, because an access that has started on the D$ or bus can be neither aborted
  //            (AHB transaction in progress) nor replayed (uncached loads/stores and AMOs are not idempotent).
  //            The IFU stalls the pipeline while its request is outstanding.
  assign DTLBReq   = DTLBMissOrUpdateDAM;
  assign ITLBReq   = ITLBMissOrUpdateAF & ~MemAccessInFlightM;
  assign AcceptReq = (WalkerState == IDLE) & (DTLBReq | ITLBReq);

  // Determine which address to translate
  mux2 #(P.XLEN) vadrmux(PCSpillF, IEUAdrExtM[P.XLEN-1:0], DTLBWalk, TranslationVAdr);
  assign CurrentPPN = PTE[P.PPN_BITS+9:10];

  // State flops
  // Pending-request registers: both requests are captured when the walk starts; each is cleared when its
  // walk completes (final LEAF or FAULT).  A DTLB-walk fault traps, so the ITLB request is dropped too.
  // FlushW (trap) clears both.
  // A two-stage walk ends in GLEAF after the G-stage walk of the final GPA, not in LEAF.
  assign WalkDone = TLBWriteNow | (WalkerState == FAULT);
  always_ff @(posedge clk)
    if (reset | FlushW)       {DTLBWalkPending, ITLBWalkPending} <= 2'b00;
    else if (StartWalk)       {DTLBWalkPending, ITLBWalkPending} <= {DTLBReq, ITLBReq};
    else if (WalkDone)
      if (DTLBWalkPending) begin
        DTLBWalkPending <= 1'b0;
        if (WalkerState == FAULT) ITLBWalkPending <= 1'b0;
      end else                ITLBWalkPending <= 1'b0;
  assign DTLBWalk = DTLBWalkPending; // DTLB walk is served first
  // Capture the PTE from the data cache.  Clear it at the end of every walk (not only on return to IDLE) so a
  // walk chained directly after another never evaluates stale PTE bits.
  assign PRegEn = HPTWRW[1] & ~DCacheBusStallM | UpdatePTE | WalkDone | (NextWalkerState == IDLE);
  assign NextPTE2 = (WalkDone | (NextWalkerState == IDLE)) ? '0 : NextPTE;
  flopenr #(P.XLEN) PTEReg(clk, reset, PRegEn, NextPTE2, PTE); // Capture page table entry from data cache

  // Assign PTE descriptors common across all XLEN values
  // For non-leaf PTEs, D, A, U bits (7:6, 4) are reserved and cause faults while walking the page table.
  // Likewise, N (63), PBMT (62:61), and reserved (60:54) bits must be zero in non-leaf PTEs regardless of
  // whether Svnapot/Svpbmt are supported (privileged spec: "these bits remain reserved and must be zeroed
  // in non-leaf PTEs")
  assign {PTE_U, Executable, Writable, Readable, Valid} = PTE[4:0];
  assign LeafPTE = Executable | Writable | Readable;
  assign ValidPTE = Valid & ~(Writable & ~Readable); // W = 1, R = 0 is a reserved encoding
  assign ValidLeafPTE = ValidPTE & LeafPTE;
  assign ValidNonLeafPTE = Valid & ~LeafPTE;
  if (P.XLEN == 64) assign NonLeafReservedFaultM = ValidNonLeafPTE & (|PTE[63:54]);
  else assign NonLeafReservedFaultM = 1'b0;
  assign DAUFaultM = ValidNonLeafPTE & (|PTE[7:6] | PTE[4]);

  if (P.SVADU_SUPPORTED) begin : hptwwrites
    logic                 ReadAccess, WriteAccess;
    logic                 InvalidRead, InvalidWrite, InvalidOp;
    logic                 OtherPageFault, LeafReservedFault;
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
    assign WriteAccess = MemRWM[0] | CMOpM[3]; // implies | (|AtomicM); cbo.zero needs W and sets D, as in tlbcontrol
    assign SetDirty = ~Dirty & DTLBWalk & WriteAccess;
    assign ReadAccess = MemRWM[1] | (|CMOpM[2:0]); // cbo.clean/flush/inval need R (or X with MXR), as in tlbcontrol

    assign EffectivePrivilegeMode = DTLBWalk ? (STATUS_MPRV ? STATUS_MPP : PrivilegeModeW) : PrivilegeModeW; // DTLB uses MPP mode when MPRV is 1
    // U-mode may only access user pages; S-mode may access user pages only for data with SUM = 1
    assign ImproperPrivilege = ((EffectivePrivilegeMode == P.U_MODE) & ~PTE_U) |
                               ((EffectivePrivilegeMode == P.S_MODE) & PTE_U & (~STATUS_SUM | ~DTLBWalk));

    // Check for page faults.  Non-canonical addresses page fault in the TLB and are never walked.
    assign InvalidRead = ReadAccess & ~Readable & (~STATUS_MXR | ~Executable);
    assign InvalidWrite = WriteAccess & ~Writable;
    assign InvalidOp = DTLBWalk ? (InvalidRead | InvalidWrite) : ~Executable;
    // Reserved bit, PBMT, and NAPOT encodings that tlbcontrol faults on must also block the A/D update
    if (P.XLEN == 64) assign LeafReservedFault = (|PTE[60:54]) |
                        (PTE[62:61] == 2'b11) | ((PTE[62:61] != 2'b00) & ~(P.SVPBMT_SUPPORTED & ENVCFG_PBMTE)) |
                        (PTE[63] & (~P.SVNAPOT_SUPPORTED | (PTE[13:10] != 4'b1000) | (PageType != 3'b000)));
    else              assign LeafReservedFault = 1'b0;
    assign OtherPageFault = ImproperPrivilege | InvalidOp | Misaligned | LeafReservedFault | ~Valid;

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
  assign StartWalk  = AcceptReq;
  assign HPTWRW[1]  = (WalkerState == L4_RD & P.SV57_SUPPORTED) |
                      (WalkerState == L3_RD & P.SV48_SUPPORTED) |
                      (WalkerState == L2_RD & P.SV39_SUPPORTED) |
                      (WalkerState == L1_RD) | (WalkerState == L0_RD) |
                      (WalkerState == G4_RD & P.SV57_SUPPORTED) |
                      (WalkerState == G3_RD & P.SV48_SUPPORTED) |
                      (WalkerState == G2_RD & P.SV39_SUPPORTED) |
                      (WalkerState == G1_RD) | (WalkerState == G0_RD);

  assign TLBWriteNow = GActive ? (WalkerState == GLEAF & GPurpose == GFINAL & ~HPTWUpdateDA)
                               : (WalkerState == LEAF  & ~HPTWUpdateDA);
  assign DTLBWriteM = TLBWriteNow & DTLBWalk;
  assign ITLBWriteF = TLBWriteNow & ~DTLBWalk;

  // Page size implied by the level of the PTE being read, shared by the VS/single stage and the G-stage
  always_comb
    case (WalkerState)
      L4_RD, G4_RD: LevelPageType = 3'b100; // petapage
      L3_RD, G3_RD: LevelPageType = 3'b011; // terapage
      L2_RD, G2_RD: LevelPageType = 3'b010; // gigapage
      L1_RD, G1_RD: LevelPageType = 3'b001; // megapage
      default:      LevelPageType = 3'b000; // kilopage (L0_RD, G0_RD)
    endcase

  // PageType tracks the VS/single-stage leaf size; GPageType tracks the G-stage leaf size.
  // HPTWRW[1] is high only in the _RD states, so each register loads only on reads at its own stage.
  flopenr #(3) PageTypeReg(clk, reset, HPTWRW[1] & ~InGWalk, LevelPageType, PageType);
  flopenr #(3) GPageTypeReg(clk, reset, HPTWRW[1] & InGWalk, LevelPageType, GPageType);

  // HPTWAdr muxing
  if (P.XLEN == 32) begin // RV32
    logic [9:0] VPN;
    logic [P.PPN_BITS-1:0] PPN;
    assign VPN = ((WalkerState == L1_ADR) | (WalkerState == L1_RD)) ? TranslationVAdr[31:22] : TranslationVAdr[21:12]; // select VPN field based on HPTW state
    assign PPN = ((WalkerState == L1_ADR) | (WalkerState == L1_RD)) ? BasePageTablePPN : CurrentPPN;
    assign Stage1ReadAdr = {PPN, VPN, 2'b00};
    assign HPTWSize = 3'b010;
  end else begin // RV64
    logic [8:0] VPN;
    logic [P.PPN_BITS-1:0] PPN;
    always_comb
      case (WalkerState) // select VPN field based on HPTW state
        L4_ADR, L4_RD:  VPN = TranslationVAdr[56:48]; // Extracted top 9 bits for sv57
        L3_ADR, L3_RD:  VPN = TranslationVAdr[47:39];
        L2_ADR, L2_RD:  VPN = TranslationVAdr[38:30];
        L1_ADR, L1_RD:  VPN = TranslationVAdr[29:21];
        default:        VPN = TranslationVAdr[20:12];
      endcase
    assign PPN = ((P.SV57_SUPPORTED & SvMode == P.SV57 & (WalkerState == L4_ADR | WalkerState == L4_RD)) |
                  (P.SV48_SUPPORTED & SvMode == P.SV48 & (WalkerState == L3_ADR | WalkerState == L3_RD)) |
                  (SvMode == P.SV39 & (WalkerState == L2_ADR | WalkerState == L2_RD))) ? BasePageTablePPN : CurrentPPN;
    assign Stage1ReadAdr = {PPN, VPN, 3'b000};
    assign HPTWSize = 3'b011;
  end
  // G-stage states read G-stage PTEs. GLEAF presents the translated address of the VS-stage PTE so it acts as
  // the _ADR cycle for the Lx_RD it returns to; SPAReg then holds that address steady through Lx_RD.
  assign HPTWReadAdr = InGWalk ? ((WalkerState == GLEAF) ? SPA : GHPTWReadAdr) :
                       TwoStage ? SPAReg : Stage1ReadAdr;
  flopenr #(P.PA_BITS) SPARegReg(clk, reset, (WalkerState == GLEAF), SPA, SPAReg);

  // G stage Muxing
  if (P.XLEN == 32) begin
    logic                  GRootLevel;
    logic [P.PPN_BITS-1:0] GBasePageTablePPN;

    assign GBasePageTablePPN = HGATP_REGW[P.PPN_BITS-1:0];
    assign GRootLevel = (WalkerState == G1_ADR) | (WalkerState == G1_RD);

    // Sv32x4: root table is 16 KiB, indexed by 12 bits GPA[33:22]; hgatp.PPN[1:0] are dropped
    // Level 0: normal 4 KiB table, indexed by 10 bits GPA[21:12]
    assign GHPTWReadAdr = GRootLevel ? {GBasePageTablePPN[P.PPN_BITS-1:2], GPAReg[33:22], 2'b00}
                                     : {CurrentPPN,                        GPAReg[21:12], 2'b00};

    // SPA from the G-stage leaf, mixing in low GPA bits for a megapage
    assign SPAPPN = (GPageType == 3'b001) ? {CurrentPPN[P.PPN_BITS-1:10], GPAReg[21:12]} : CurrentPPN;
  end else begin
    logic                  GRootLevel;
    logic [P.PPN_BITS-1:0] GBasePageTablePPN;
    logic [10:0]           GVPN;

    assign GBasePageTablePPN = HGATP_REGW[P.PPN_BITS-1:0];
    assign GRootLevel = (P.SV57_SUPPORTED & HGATP_MODE == P.SV57 & (WalkerState == G4_ADR | WalkerState == G4_RD)) |
                        (P.SV48_SUPPORTED & HGATP_MODE == P.SV48 & (WalkerState == G3_ADR | WalkerState == G3_RD)) |
                        (HGATP_MODE == P.SV39 & (WalkerState == G2_ADR | WalkerState == G2_RD));

    // Sv39x4/Sv48x4/Sv57x4: root table is 16 KiB, indexed by 11 bits; hgatp.PPN[1:0] are dropped
    // Lower levels: normal 4 KiB tables, indexed by 9 bits
    always_comb
      case (WalkerState)
        G4_ADR, G4_RD:  GVPN = GPAReg[58:48];
        G3_ADR, G3_RD:  GVPN = {GRootLevel ? GPAReg[49:48] : 2'b00, GPAReg[47:39]};
        G2_ADR, G2_RD:  GVPN = {GRootLevel ? GPAReg[40:39] : 2'b00, GPAReg[38:30]};
        G1_ADR, G1_RD:  GVPN = {2'b00, GPAReg[29:21]};
        default:        GVPN = {2'b00, GPAReg[20:12]};
      endcase
    assign GHPTWReadAdr = GRootLevel ? {GBasePageTablePPN[P.PPN_BITS-1:2], GVPN,      3'b000}
                                     : {CurrentPPN,                        GVPN[8:0], 3'b000};

    // SPA from the G-stage leaf, mixing in low GPA bits for superpages
    always_comb
      case (GPageType)
        3'b100:  SPAPPN = {CurrentPPN[P.PPN_BITS-1:36], GPAReg[47:12]}; // petapage
        3'b011:  SPAPPN = {CurrentPPN[P.PPN_BITS-1:27], GPAReg[38:12]}; // terapage
        3'b010:  SPAPPN = {CurrentPPN[P.PPN_BITS-1:18], GPAReg[29:12]}; // gigapage
        3'b001:  SPAPPN = {CurrentPPN[P.PPN_BITS-1:9],  GPAReg[20:12]}; // megapage
        default: SPAPPN = CurrentPPN;                                   // kilopage
      endcase
  end
  assign SPA = {SPAPPN, GPAReg[11:0]};

  // Initial state and misalignment for RV32/64
  if (P.XLEN == 32) begin
    assign InitialWalkerState = L1_ADR;
    assign GInitialWalkerState = G1_ADR;
    assign GPAUpperBitsNonzero = 1'b0; // Sv32x4 GPAs are 34 bits, the full width of GPAReg
    assign MegapageMisaligned = |(CurrentPPN[9:0]); // must have zero PPN0
    assign Misaligned = (WalkerState == LEAF) & (PageType == 3'b001) & MegapageMisaligned;
  end else begin
    logic PetapageMisaligned, TerapageMisaligned, GigapageMisaligned;
    assign InitialWalkerState = (P.SV57_SUPPORTED & SvMode == P.SV57) ? L4_ADR :
                                (P.SV48_SUPPORTED & SvMode == P.SV48) ? L3_ADR :
                                                                        L2_ADR;
    assign GInitialWalkerState = (HGATP_MODE == P.SV57) ? G4_ADR :
                   (HGATP_MODE == P.SV48) ? G3_ADR : G2_ADR;
    // The "x4" modes widen the GPA by 2 bits beyond the VA width; all higher GPA bits must be zero
    always_comb
      case (HGATP_MODE)
        P.SV57:  GPAUpperBitsNonzero = |GPAReg[GPA_BITS-1:59]; // Sv57x4: 59-bit GPA
        P.SV48:  GPAUpperBitsNonzero = |GPAReg[GPA_BITS-1:50]; // Sv48x4: 50-bit GPA
        P.SV39:  GPAUpperBitsNonzero = |GPAReg[GPA_BITS-1:41]; // Sv39x4: 41-bit GPA
        default: GPAUpperBitsNonzero = 1'b0;                   // Bare: no G-stage walk
      endcase
    assign PetapageMisaligned = P.SV57_SUPPORTED & |(CurrentPPN[35:0]); // Must have zero PPN3, PPN2, PPN1, PPN0
    assign TerapageMisaligned = P.SV48_SUPPORTED & |(CurrentPPN[26:0]); // Must have zero PPN2, PPN1, PPN0
    assign GigapageMisaligned =                    |(CurrentPPN[17:0]); // Must have zero PPN1 and PPN0
    assign MegapageMisaligned = |(CurrentPPN[8:0]);  // Must have zero PPN0
    assign Misaligned = (WalkerState == LEAF) &
                        ((P.SV57_SUPPORTED & (PageType == 3'b100) & PetapageMisaligned) |
                         (P.SV48_SUPPORTED & (PageType == 3'b011) & TerapageMisaligned) |
                                            ((PageType == 3'b010) & GigapageMisaligned) |
                                            ((PageType == 3'b001) & MegapageMisaligned));
  end

  // Effective translation controls for this walk. Data walks are virtualized when V=1,
  // when mstatus.MPRV=1 with MPV=1, or for HLV/HLVX/HSV; instruction walks follow V.
  if (P.H_SUPPORTED) begin: effvirt
    logic effVirtMode;
    assign effVirtMode = HLVHSVLegalM | (STATUS_MPRV ? MSTATUS_MPV : VirtModeW);
    assign effSATP = effVirtMode ? VSATP_REGW : SATP_REGW;
    assign S1Active = effSATP_MODE != BARE;   // walk the stage 1 table (effSATP)
    assign GActive = effVirtMode & (HGATP_MODE != BARE);   // translate GPA -> SPA (hgatp)
  end else begin: effvirtNoH
    assign effSATP = SATP_REGW;
    assign S1Active = effSATP_MODE != BARE;
    assign GActive = 1'b0;
  end
  assign effSATP_MODE = effSATP[P.XLEN-1:P.XLEN-P.SVMODE_BITS];
  assign HGATP_MODE   = HGATP_REGW[P.XLEN-1:P.XLEN-P.SVMODE_BITS];
  assign TwoStage     = S1Active & GActive;

  if (P.XLEN == 32) begin
    assign FinalGPPN = (PageType == 3'b001) ? {CurrentPPN[P.PPN_BITS-1:10], TranslationVAdr[21:12]} : CurrentPPN;
  end else begin
    always_comb
      case (PageType)
        3'b100:  FinalGPPN = {CurrentPPN[P.PPN_BITS-1:36], TranslationVAdr[47:12]}; // petapage
        3'b011:  FinalGPPN = {CurrentPPN[P.PPN_BITS-1:27], TranslationVAdr[38:12]}; // terapage
        3'b010:  FinalGPPN = {CurrentPPN[P.PPN_BITS-1:18], TranslationVAdr[29:12]}; // gigapage
        3'b001:  FinalGPPN = {CurrentPPN[P.PPN_BITS-1:9],  TranslationVAdr[20:12]}; // megapage
        default: FinalGPPN = CurrentPPN;                                            // kilopage
      endcase
  end
  assign FinalGPA = GPA_BITS'({FinalGPPN, TranslationVAdr[11:0]}); // zero-extend to the GPA width

  always_comb begin
    if (WalkerState == IDLE) begin
      NextGPA = GPA_BITS'(TranslationVAdr);
      NextGPurpose = GFINAL;
    end else if (WalkerState == LEAF) begin
      NextGPA = HPTWUpdateDA ? GPAReg : FinalGPA; // GPAReg still holds the GPA of the VS-stage leaf PTE from its G-stage walk
      NextGPurpose = HPTWUpdateDA ? GIMPLICIT_WR : GFINAL;
    end else if (WalkerState == GLEAF) begin
      NextGPA = GPA_BITS'(PCSpillF); // chained ITLB walk with VS-stage Bare: its GPA is the fetch address
      NextGPurpose = GFINAL;
    end else begin
      NextGPA = GPA_BITS'(Stage1ReadAdr);
      NextGPurpose = GIMPLICIT_RD;
    end
  end

  assign InGWalk = (WalkerState == G0_ADR) | (WalkerState == G0_RD) | (WalkerState == G1_ADR) | (WalkerState == G1_RD) |
                   (WalkerState == G2_ADR) | (WalkerState == G2_RD) | (WalkerState == G3_ADR) | (WalkerState == G3_RD) |
                   (WalkerState == G4_ADR) | (WalkerState == G4_RD) | (WalkerState == GLEAF) | (WalkerState == GUPDATE_PTE);
  assign EnterGWalk = (!InGWalk | WalkerState == GLEAF) & NextWalkerState == GInitialWalkerState; // GLEAF -> G root only when chaining to an ITLB walk

  always_comb
    case (WalkerState)
      L4_ADR:  ReturnStateVal = L4_RD;
      L3_ADR:  ReturnStateVal = L3_RD;
      L2_ADR:  ReturnStateVal = L2_RD;
      L1_ADR:  ReturnStateVal = L1_RD;
      default: ReturnStateVal = L0_RD;
  endcase

  flopenr #(GPA_BITS) GPARegReg(clk, reset, EnterGWalk, NextGPA, GPAReg);
  flopenl #(.TYPE(gpurposetype)) GPurposeReg(clk, reset, EnterGWalk, NextGPurpose, GFINAL, GPurpose);
  flopenl #(.TYPE(statetype)) ReturnStateReg(clk, reset, EnterGWalk, ReturnStateVal, L0_RD, ReturnState);

  // Page Table Walker FSM
  flopenl #(.TYPE(statetype)) WalkerStateReg(clk, reset | FlushW, 1'b1, NextWalkerState, IDLE, WalkerState);
  always_comb
    case (WalkerState)
      IDLE:       if (AcceptReq)                                           NextWalkerState = S1Active ? InitialWalkerState : GInitialWalkerState; // If vsatp bare go straight ot G stage
                  else                                                     NextWalkerState = IDLE;
      L4_ADR:                                                              NextWalkerState = GActive ? GInitialWalkerState : L4_RD; // First access in SV57
      L4_RD:      if (HPTWFaultM)                                          NextWalkerState = FAULT;
                  else if (DCacheBusStallM)                                NextWalkerState = L4_RD;
                  else                                                     NextWalkerState = L3_ADR;   // Transition to level 3
      L3_ADR:     if (HPTWFaultM)                                          NextWalkerState = FAULT;
                  else if (InitialWalkerState == L3_ADR | ValidNonLeafPTE) NextWalkerState = GActive ? GInitialWalkerState : L3_RD; // First access in SV48
                  else                                                     NextWalkerState = LEAF;
      L3_RD:      if (HPTWFaultM)                                          NextWalkerState = FAULT;
                  else if (DCacheBusStallM)                                NextWalkerState = L3_RD;
                  else                                                     NextWalkerState = L2_ADR;
      L2_ADR:     if (HPTWFaultM)                                          NextWalkerState = FAULT;
                  else if (InitialWalkerState == L2_ADR | ValidNonLeafPTE) NextWalkerState = GActive ? GInitialWalkerState : L2_RD; // First access in SV39
                  else                                                     NextWalkerState = LEAF;
      L2_RD:      if (HPTWFaultM)                                          NextWalkerState = FAULT;
                  else if (DCacheBusStallM)                                NextWalkerState = L2_RD;
                  else                                                     NextWalkerState = L1_ADR;
      L1_ADR:     if (HPTWFaultM)                                          NextWalkerState = FAULT;
                  else if (InitialWalkerState == L1_ADR | ValidNonLeafPTE) NextWalkerState = GActive ? GInitialWalkerState : L1_RD; // First access in SV32
                  else                                                     NextWalkerState = LEAF;
      L1_RD:      if (HPTWFaultM)                                          NextWalkerState = FAULT;
                  else if (DCacheBusStallM)                                NextWalkerState = L1_RD;
                  else                                                     NextWalkerState = L0_ADR;
      L0_ADR:     if (HPTWFaultM)                                          NextWalkerState = FAULT;
                  else if (ValidNonLeafPTE)                                NextWalkerState = GActive ? GInitialWalkerState : L0_RD;
                  else                                                     NextWalkerState = LEAF;
      L0_RD:      if (HPTWFaultM)                                          NextWalkerState = FAULT;
                  else if (DCacheBusStallM)                                NextWalkerState = L0_RD;
                  else                                                     NextWalkerState = LEAF;
      LEAF:       if (P.SVADU_SUPPORTED & HPTWUpdateDA)                    NextWalkerState = GActive ? GInitialWalkerState : UPDATE_PTE;
                  else if (GActive)                                        NextWalkerState = GInitialWalkerState;
                  else if (DTLBWalk & ITLBWalkPending)                     NextWalkerState = InitialWalkerState; // DTLB walk done; chain directly to the pending ITLB walk
                  else                                                     NextWalkerState = IDLE;
      UPDATE_PTE: if (HPTWFaultM)                                          NextWalkerState = FAULT;
                  else if (DCacheBusStallM)                                NextWalkerState = UPDATE_PTE;
                  else                                                     NextWalkerState = LEAF;

      G4_ADR:     if (GPAUpperBitsNonzero)                                 NextWalkerState = FAULT;
                  else                                                     NextWalkerState = G4_RD; // First access in SV57
      G4_RD:      if (HPTWFaultM | GPAUpperBitsNonzero)                    NextWalkerState = FAULT;
                  else if (DCacheBusStallM)                                NextWalkerState = G4_RD;
                  else                                                     NextWalkerState = G3_ADR; // First access in SV57
      G3_ADR:     if (HPTWFaultM | GPAUpperBitsNonzero)                    NextWalkerState = FAULT;
                  else if (GInitialWalkerState == G3_ADR | ValidNonLeafPTE) NextWalkerState = G3_RD; // First access in SV48
                  else                                                     NextWalkerState = GLEAF;
      G3_RD:      if (HPTWFaultM | GPAUpperBitsNonzero)                    NextWalkerState = FAULT;
                  else if (DCacheBusStallM)                                NextWalkerState = G3_RD;
                  else                                                     NextWalkerState = G2_ADR;
      G2_ADR:     if (HPTWFaultM | GPAUpperBitsNonzero)                    NextWalkerState = FAULT;
                  else if (GInitialWalkerState == G2_ADR | ValidNonLeafPTE) NextWalkerState = G2_RD; // First access in SV39
                  else                                                     NextWalkerState = GLEAF;
      G2_RD:      if (HPTWFaultM | GPAUpperBitsNonzero)                    NextWalkerState = FAULT;
                  else if (DCacheBusStallM)                                NextWalkerState = G2_RD;
                  else                                                     NextWalkerState = G1_ADR;
      G1_ADR:     if  (HPTWFaultM | GPAUpperBitsNonzero)                   NextWalkerState = FAULT;
                  else if (GInitialWalkerState == G1_ADR | ValidNonLeafPTE) NextWalkerState = G1_RD; // First access in SV32
                  else                                                     NextWalkerState = GLEAF;
      G1_RD:      if (HPTWFaultM | GPAUpperBitsNonzero)                    NextWalkerState = FAULT;
                  else if (DCacheBusStallM)                                NextWalkerState = G1_RD;
                  else                                                     NextWalkerState = G0_ADR;
      G0_ADR:     if (HPTWFaultM | GPAUpperBitsNonzero)                    NextWalkerState = FAULT;
                  else if (ValidNonLeafPTE)                                NextWalkerState = G0_RD;
                  else                                                     NextWalkerState = GLEAF;
      G0_RD:      if (HPTWFaultM | GPAUpperBitsNonzero)                    NextWalkerState = FAULT;
                  else if (DCacheBusStallM)                                NextWalkerState = G0_RD;
                  else                                                     NextWalkerState = GLEAF;
      GLEAF:      if (P.SVADU_SUPPORTED & HPTWUpdateDA)                    NextWalkerState = GUPDATE_PTE;
                  else if (GPurpose == GIMPLICIT_RD)                       NextWalkerState = ReturnState;   // Lx_RD
                  else if (GPurpose == GIMPLICIT_WR)                       NextWalkerState = UPDATE_PTE;
                  else if (DTLBWalk & ITLBWalkPending)                     NextWalkerState = S1Active ? InitialWalkerState : GInitialWalkerState; // GFINAL: DTLB walk done; chain directly to the pending ITLB walk
                  else                                                     NextWalkerState = IDLE; // GPurpose == GFINAL
      GUPDATE_PTE: if (HPTWFaultM)                                         NextWalkerState = FAULT;
                  else if (DCacheBusStallM)                                NextWalkerState = GUPDATE_PTE;
                  else                                                     NextWalkerState = GLEAF;
      FAULT:                                                               NextWalkerState = IDLE;
      default:                                                             NextWalkerState = IDLE; // Should never be reached
    endcase // case (WalkerState)

  // Pre-empt the M-stage memory access when a walk is accepted so it replays after the TLB fill (unless the LSU
  // has already performed and captured it), and squash the walker's own access when it faults.  A walk is only
  // accepted while no access is in flight, so this flush never abandons a bus transaction.
  assign HPTWFlushW = (AcceptReq & ~MemAccessDoneM) | (WalkerState != IDLE & HPTWFaultM);

  assign SelHPTW = WalkerState != IDLE;
  // Stall the pipeline from the cycle a request is accepted until the walker returns to IDLE, including FAULT:
  // while SelHPTW is 1 the LSU datapath belongs to the walker, so the M-stage access must not retire.  A DTLB
  // walk fault traps in FAULT and the trap overrides this stall; an ITLB walk fault is held by the IFU and the
  // M-stage access runs after the walker returns to IDLE.
  assign HPTWStall = (WalkerState != IDLE) | AcceptReq;

  // HPTW address/data/control muxing

  // In the last cycle of a walk (TLB write or FAULT) switch back to the original data virtual address so the
  // data cache reads the tag/data/valid/dirty/LRU state of the M-stage access's set (the set index lies within
  // the page offset) and the access resumes at IDLE with a valid hit/miss decision.
  assign SelHPTWAdr = SelHPTW & ~(DTLBWriteM | ITLBWriteF | (WalkerState == FAULT));

  // multiplex the outputs to LSU
  if (P.XLEN == 64) assign HPTWAdrExt = {{(P.XLEN+2-P.PA_BITS){1'b0}}, HPTWAdr}; // Extend to 66 bits
  else              assign HPTWAdrExt = HPTWAdr;
  mux2 #(2) rwmux(MemRWM, HPTWRW, SelHPTW, PreLSURWM);
  mux2 #(3) sizemux(Funct3M, HPTWSize, SelHPTW, LSUFunct3M);
  mux2 #(7) funct7mux(Funct7M, 7'b0, SelHPTW, LSUFunct7M);
  mux2 #(2) atomicmux(AtomicM, 2'b00, SelHPTW, LSUAtomicM);
  mux2 #(4) cmomux(CMOpM, 4'b0, SelHPTW, LSUCMOpM);
  mux2 #(1) fpmux(FpLoadStoreM, 1'b0, SelHPTW, LSUFpLoadStoreM);
  mux2 #(P.XLEN+2) lsupadrmux(IEUAdrExtM, HPTWAdrExt, SelHPTWAdr, IHAdrM);
  if (P.SVADU_SUPPORTED)
    mux2 #(P.XLEN) lsuwritedatamux(WriteDataM, PTE, SelHPTW, IHWriteDataM);
  else assign IHWriteDataM = WriteDataM;

endmodule
