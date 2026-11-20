// NOTE: if we did everything without PCSrcE can we eliminate it from everywhere else? bc it will eliminate the circular loop we
// curently havinh

module datapath(
   input  logic        clk, reset,


   // Control signals for I0 (from controller, decode stage)
   input  logic [2:0]  ResultSrcD_I0,
   input  logic        MemWriteD_I0,
   input  logic        ALUSrcD_I0,
   input  logic        RegWriteD_I0,
   input  logic [2:0]  ImmSrcD_I0,
   input  logic [4:0]  ALUControlD_I0,
   input  logic        CSRWriteD_I0,
   input  logic        JumpD_I0,
   input  logic        BranchD_I0,


   // Control signals for I1 (from controller, decode stage)
   input  logic [2:0]  ResultSrcD_I1,
   input  logic        MemWriteD_I1,
   input  logic        ALUSrcD_I1,
   input  logic        RegWriteD_I1,
   input  logic [2:0]  ImmSrcD_I1,
   input  logic [4:0]  ALUControlD_I1,
   input  logic        CSRWriteD_I1,
   input  logic        JumpD_I1,
   input  logic        BranchD_I1,


   // Fetch interface
   output logic [31:0] PC,
   input  logic [63:0] Instr,          // 64-bit fetch (2 instructions)


   // Memory interface (single-ported)
   output logic [31:0] ALUResult,      // Data address
   output logic [31:0] WriteData,      // Data to write
   output logic        MemWriteOut,    // Write enable
   output logic        LoadOut,        // Load enable
   output logic [2:0]  Funct3Out,      // For byte/halfword/word ops
   input  logic [31:0] ReadData,       // Data from memory


   // Decode stage outputs (for controller)
   output logic [31:0] InstrD_I0,
   output logic [31:0] InstrD_I1
);


   // ============================================================
   // SIGNAL DECLARATIONS  (single unified block — no duplicates)
   // ============================================================

   // Branch Prediction
   // 128-entry gshare PHT with 7-bit GHR.
   logic [7:0] GHR;
   logic [7:0] GHR_snapD;
   logic [7:0] GHR_snapE;
   logic [1:0] PHT [255:0];  // 128-entry PHT, indexed by PC[8:2]^GHR


   // ------------------------------------------------------------
   // Fetch Stage
   // ------------------------------------------------------------
   logic buffer_stale;

   logic [31:0] PCF, PCNextF, PCPlus4F, PCPlus8F;
   logic [31:0] InstrF_0, InstrF_1;            // split from 64-bit fetch


   // 4-entry instruction buffer (circular)
   logic [31:0] InstrBuffer [3:0];
   logic [31:0] PCBuffer    [3:0];
   logic [1:0]  ReadPtr, WritePtr;


   logic [1:0] ReadPtr_next;
   logic [1:0] ReadPtr_next_p1_fast;
   logic d2_valid;

   logic PC_redirected;


   // Buffer-output branch signals (pre-IF/ID register; used for fetch-stage redirect)
   logic [31:0] InstrToDecodeI0, InstrToDecodeI1;
   logic [31:0] PCToDecodeI0,    PCToDecodeI1;
   logic        isBranchF_I0;
   logic [7:0]  BranchIndex_I0;
   logic        PredictedTakenF_I0;


   // JAL decode-stage prediction signals
   logic        isJALD_I0;           // instruction in decode is JAL
   logic [31:0] JALTargetD_I0;       // JAL target = PCD + ImmExtD
   logic        JALPredictD_I0;      // asserted when we redirect PC for JAL at decode
   logic        JALPredictE_I0;      // pipelined to execute for mispredict check

   // I1 branch decode-stage prediction signals
   // (I1 branch redirect is deferred to Decode so IssueI1 is known before redirecting)
   logic [31:0] BranchTargetD_I1;        // branch target = PCD_I1 + ImmExtD_I1
   logic        BranchPredictTakenD_I1;  // redirect PC for I1 predicted-taken branch at decode
   // FlushD augmented with the I1 branch prediction redirect;
   // kept separate from FlushD so IssueI1 (which checks !FlushD) has no combinatorial loop
   logic        FlushD_full;


   // PC steering
   logic [31:0] PCMux3In;


   // ------------------------------------------------------------
   // Decode Stage
   // ------------------------------------------------------------
   logic [31:0] PCD_I0,      PCD_I1;
   logic [31:0] PCPlus4D_I0, PCPlus4D_I1;
   logic        PredictedTakenD_I0, PredictedTakenD_I1;


   logic [4:0]  Rs1D_I0, Rs2D_I0, RdD_I0;
   logic [4:0]  Rs1D_I1, Rs2D_I1, RdD_I1;
   logic [2:0]  funct3D_I0, funct3D_I1;
   logic [11:0] CSRAddrD_I0, CSRAddrD_I1;
   logic [6:0]  OpcodeD_I0,  OpcodeD_I1;


   logic [31:0] RD1D_I0, RD2D_I0;
   logic [31:0] RD1D_I1, RD2D_I1;
   logic [31:0] ImmExtD_I0,    ImmExtD_I1;
   logic [31:0] CSRSrcDataD_I0, CSRSrcDataD_I1;


   logic        LoadD_I0, LoadD_I1;


   // Intra-pair hazard / issue decision
   logic IntraPairRAW, BothBranches, I0_PredictedTakenBranch;
   logic BothMemOps, I0_IsJump, AnyCSR;
   logic IssueI1;


   // ------------------------------------------------------------
   // Hazard / Stall / Flush
   // ------------------------------------------------------------
   // Per-lane outputs from HazardUnit insntances
   logic StallF_I0_hz, StallF_I1_hz;
   logic StallD_I0_hz, StallD_I1_hz;
   logic FlushD_I0_hz, FlushD_I1_hz; // wired but FlushD computed directly
   logic FlushE_I0_hz, FlushE_I1_hz;
   logic FlushD_ifid;


   // Combined pipeline control
   logic StallF, StallD, FlushD, FlushE;
   logic StallD_hz;          // raw stall from hazard units, no PCSrcE masking — for PCMux3In
   logic IssueI1_noflushd;   // IssueI1 without !FlushD — for PCMux3In timing
   logic BranchPredictTakenD_I1_fast; // no PCSrcE/comparator dependency — for PCMux3In

   // Fetch-stage fast signals: use ReadPtr_next_fast (no PCSrcE) for PCMux3In to avoid
   // false timing path: comparator→PCSrcE→{StallD,FlushE}→ReadPtr_next→BranchTargetF_I0→pcmux d0
   logic [1:0]  ReadPtr_next_fast;
   logic [31:0] BranchTargetF_I0_fast;
   logic        isBranchF_I0_fast, PredictedTakenF_I0_fast;
   logic        PredictedTakenF_I1_fast;
   // Precomputed branch info for every buffer slot (constant index → no dynamic mux in computation).
   logic [31:0] BranchTarget_buf [3:0];
   logic        isBranch_buf     [3:0];
   logic        predTaken_buf    [3:0];

   // Fast buffer write-enable signals: no PCSrcE dependency.
   // Used in PCBuffer/InstrBuffer write enable to break the false path:
   //   comparator→PCSrcE→StallF/FlushD_full(many gates)→PCBuffer write enable→PCBuffer D
   logic        branch_predicted_fetch_fast; // fetch-stage branch pred using fast signals
   logic        value_fast;                  // buffer-full stall, no PCSrcE
   logic        StallF_fast;                 // stall from hazard units + value, no PCSrcE
   logic        FlushD_full_fast;            // JAL + I1-branch pred, no PCSrcE
   logic        PCBuffer_write_en;           // combined write enable for InstrBuffer/PCBuffer


   // Forwarding selects from HazardUnit (3-bit: encodes same-lane and cross-lane sources)
   // 3'b000=reg file  3'b001=same-lane W  3'b010=same-lane M
   // 3'b011=cross-lane W  3'b100=cross-lane M
   logic [2:0] ForwardAE_I0, ForwardBE_I0;
   logic [2:0] ForwardAE_I1, ForwardBE_I1;


   // PCSrcE (from execute branch unit)
   logic [1:0]  PCSrcE;


   // ------------------------------------------------------------
   // Execute Stage — I0
   // ------------------------------------------------------------
   logic [31:0] PCE_I0, PCPlus4E_I0;
   logic [31:0] RD1E_I0, RD2E_I0;
   logic [4:0]  Rs1E_I0, Rs2E_I0, RdE_I0;
   logic [2:0]  funct3E_I0;
   logic [11:0] CSRAddrE_I0;
   logic [31:0] ImmExtE_I0;
   logic [31:0] CSRSrcDataE_I0;
   logic        PredictedTakenE_I0;
   logic        RegWriteE_I0, ALUSrcE_I0, MemWriteE_I0;
   logic        CSRWriteE_I0, BranchE_I0, JumpE_I0;
   logic [2:0]  ResultSrcE_I0;
   logic [4:0]  ALUControlE_I0;
   logic        LoadE_I0;


   logic [31:0] SrcAE_I0, SrcBE_I0, SrcBEIntermediate_I0;
   logic [31:0] ALUResultE_I0, ALUResultPipeE_I0, WriteDataE_I0;
   logic [31:0] PCTargetE_I0;
   logic        eq_E_I0, lt_signed_E_I0, lt_unsig_E_I0, take_branchE_I0;


   // ------------------------------------------------------------
   // Execute Stage — I1
   // ------------------------------------------------------------
   logic [31:0] PCE_I1, PCPlus4E_I1;
   logic [31:0] RD1E_I1, RD2E_I1;
   logic [4:0]  Rs1E_I1, Rs2E_I1, RdE_I1;
   logic [2:0]  funct3E_I1;
   logic [11:0] CSRAddrE_I1;
   logic [31:0] ImmExtE_I1;
   logic [31:0] CSRSrcDataE_I1;
   logic        PredictedTakenE_I1;
   logic        RegWriteE_I1, ALUSrcE_I1, MemWriteE_I1;
   logic        CSRWriteE_I1, BranchE_I1, JumpE_I1;
   logic [2:0]  ResultSrcE_I1;
   logic [4:0]  ALUControlE_I1;
   logic        LoadE_I1;


   logic [31:0] SrcAE_I1, SrcBE_I1, SrcBEIntermediate_I1;
   logic [31:0] ALUResultE_I1, ALUResultPipeE_I1, WriteDataE_I1;
   logic [31:0] PCTargetE_I1;
   logic        eq_E_I1, lt_signed_E_I1, lt_unsig_E_I1, take_branchE_I1;


   // Execute Branch/Jump shared
   logic        UseBranchI0;
   logic [2:0]  funct3E_branch;
   logic        BranchE_branch, JumpE_branch, ALUSrcE_branch, PredictedTakenE_branch;
   logic        take_branchE_branch;
   logic [31:0] PCE_branch, PCPlus4E, PCTargetE, ALUResultE;
   logic        BranchTakenE, BranchMispredictE;
   logic [7:0]  indexE;


   // ------------------------------------------------------------
   // Memory Stage — I0
   // ------------------------------------------------------------
   logic [31:0] PCPlus4M_I0;
   logic [31:0] ALUResultM_I0, WriteDataM_I0;
   logic [4:0]  RdM_I0;
   logic [2:0]  funct3M_I0;
   logic [11:0] CSRAddrM_I0;
   logic [31:0] CSRSrcDataM_I0;
   logic [4:0]  ALUControlM_I0;
   logic        RegWriteM_I0, MemWriteM_I0, CSRWriteM_I0, LoadM_I0;
   logic [2:0]  ResultSrcM_I0;
   logic [31:0] oldCSRReadDataM_I0, newCSRWriteDataM_I0;
   logic [31:0] ResultM_I0;
   // Partial products registered at EX/MEM boundary: computed in EX, accumulated in MEM.
   logic signed [17:0] P00_M, P01_M, P02_M, P03_M;
   logic signed [17:0] P10_M, P11_M, P12_M, P13_M;
   logic signed [17:0] P20_M, P21_M, P22_M, P23_M;
   logic signed [17:0] P30_M, P31_M, P32_M, P33_M;


   // ------------------------------------------------------------
   // Memory Stage — I1
   // ------------------------------------------------------------
   logic [31:0] PCPlus4M_I1;
   logic [31:0] ALUResultM_I1, WriteDataM_I1;
   logic [4:0]  RdM_I1;
   logic [2:0]  funct3M_I1;
   logic [11:0] CSRAddrM_I1;
   logic [31:0] CSRSrcDataM_I1;
   logic [4:0]  ALUControlM_I1;
   logic        RegWriteM_I1, MemWriteM_I1, CSRWriteM_I1, LoadM_I1;
   logic [2:0]  ResultSrcM_I1;
   logic [31:0] ResultM_I1;
   // I1 uses the same MEM-computed partial products (P00_M..P33_M) as I0.




   // Memory arbitration
   logic        UseMemI0;
   logic [31:0] ReadDataM;


   // ------------------------------------------------------------
   // Writeback Stage — I0
   // ------------------------------------------------------------
   logic [31:0] PCPlus4W_I0;
   logic [31:0] ALUResultW_I0, productW_I0;
   logic [31:0] oldCSRReadDataW_I0, newCSRWriteDataW_I0;
   logic [31:0] ReadDataW_I0;
   logic [31:0] ALUResultForAddrW_I0;
   logic [2:0]  funct3W_I0;
   logic [4:0]  RdW_I0;
   logic [11:0] CSRAddrW_I0;
   logic        RegWriteW_I0, CSRWriteW_I0;
   logic [2:0]  ResultSrcW_I0;
   logic [31:0] AdjustedReadDataW_I0, ResultW_I0;


   // ------------------------------------------------------------
   // Writeback Stage — I1
   // ------------------------------------------------------------
   logic [31:0] PCPlus4W_I1;
   logic [31:0] ALUResultW_I1, productW_I1;
   logic [31:0] ReadDataW_I1;
   logic [31:0] ALUResultForAddrW_I1;
   logic [2:0]  funct3W_I1;
   logic [4:0]  RdW_I1;
   logic        RegWriteW_I1;
   logic [2:0]  ResultSrcW_I1;
   logic [31:0] AdjustedReadDataW_I1, ResultW_I1;


   // ------------------------------------------------------------
   // CSR performance counter signals
   // ------------------------------------------------------------
   logic IncrementInstret, IncrementAdd, IncrementBranch, IncrementBranchTaken;
   logic IncrementLoads, IncrementStores, IncrementStalls, IncrementFlushes;
   logic BranchMisPrediction;


   // ============================================================
   // HAZARD UNITS (one per lane)
   // ============================================================


   HazardUnit hazardunit_I0(
       .Rs1D          (Rs1D_I0),
       .Rs2D          (Rs2D_I0),
       .Rs1E          (Rs1E_I0),
       .Rs2E          (Rs2E_I0),
       .RdE           (RdE_I0),
       .ResultSrcE_b0 (ResultSrcE_I0[0]),
       .Load           (LoadE_I0),
       .RegWriteE     (RegWriteE_I0),
    //    .PCSrcE        (PCSrcE),
    //    .BranchMispredictE(BranchMispredictE),
       .RdM           (RdM_I0),   .RegWriteM     (RegWriteM_I0),
       .RdW           (RdW_I0),   .RegWriteW     (RegWriteW_I0),
       .RdE_other     (RdE_I1),
       .RdM_other     (RdM_I1),   .RegWriteM_other(RegWriteM_I1),
       .RdW_other     (RdW_I1),   .RegWriteW_other(RegWriteW_I1),
       .Rs1D_other    (Rs1D_I1),  .Rs2D_other    (Rs2D_I1),
       .isMulE        (ResultSrcE_I0 == 3'b101),
       .isMulE_other  (ResultSrcE_I1 == 3'b101),
       .StallF        (StallF_I0_hz),
       .StallD        (StallD_I0_hz),
       .FlushD        (FlushD_I0_hz),
    //    .FlushE        (FlushE_I0_hz),
       .ForwardAE     (ForwardAE_I0),
       .ForwardBE     (ForwardBE_I0)
   );


   HazardUnit hazardunit_I1(
       .Rs1D          (Rs1D_I1),
       .Rs2D          (Rs2D_I1),
       .Rs1E          (Rs1E_I1),
       .Rs2E          (Rs2E_I1),
       .RdE           (RdE_I1),
       .ResultSrcE_b0 (ResultSrcE_I1[0]),
       .Load           (LoadE_I1),
       .RegWriteE     (RegWriteE_I1),
    //    .PCSrcE        (PCSrcE),
    //    .BranchMispredictE(BranchMispredictE),
       .RdM           (RdM_I1),   .RegWriteM     (RegWriteM_I1),
       .RdW           (RdW_I1),   .RegWriteW     (RegWriteW_I1),
       .RdE_other     (RdE_I0),
       .RdM_other     (RdM_I0),   .RegWriteM_other(RegWriteM_I0),
       .RdW_other     (RdW_I0),   .RegWriteW_other(RegWriteW_I0),
       .Rs1D_other    (Rs1D_I0),  .Rs2D_other    (Rs2D_I0),
       .isMulE        (ResultSrcE_I1 == 3'b101),
       .isMulE_other  (ResultSrcE_I0 == 3'b101),
       .StallF        (StallF_I1_hz),
       .StallD        (StallD_I1_hz),
       .FlushD        (FlushD_I1_hz),
    //    .FlushE        (FlushE_I1_hz),
       .ForwardAE     (ForwardAE_I1),
       .ForwardBE     (ForwardBE_I1)
   );


   // ============================================================
    // BUFFER MANAGEMENT
    // ============================================================

    // Free slots calculation
    logic [2:0] free_slots;
    always_comb begin
        if (WritePtr >= ReadPtr)
            free_slots
             = 4 - (WritePtr - ReadPtr);
        else
            free_slots = ReadPtr - WritePtr;
    end

    // Buffer overflow detection
    logic value;
    logic branch_predicted_fetch;
    assign value = ((ReadPtr_next == WritePtr) && (IssueI1 == 0) && // todo added flushE here
                    (buffer_stale == 0 || (BranchD_I1 && PredictedTakenD_I1) || FlushE) && // or if the buffer is stale, then it was due to a branch predicted in I1
                    (PCSrcE == 2'b00));
    // TODO: should what is above be BranchPredictTakenD_I1 instead of PredictedTakenD_I1

    // Combined stall/flush signals
    // assign StallF = StallF_I0_hz | StallF_I1_hz | (value & ~((JALPredictD_I0 & ~StallD) | branch_predicted_fetch));
    // assign StallD = StallD_I0_hz | StallD_I1_hz;
    // assign FlushE = FlushE_I0_hz | FlushE_I1_hz;
    // assign FlushD = (PCSrcE != 2'b00) | (JALPredictD_I0 & ~StallD);
    // FlushE for load/mul stalls (from hazard units)
    logic FlushE_stall;
    assign FlushE_stall = FlushD_I0_hz | FlushD_I1_hz;  // HazardUnit outputs FlushD for stalls

    // FlushE for branch misprediction (simple logic, no dependency checking needed)
    logic FlushE_branch;
    assign FlushE_branch = (PCSrcE != 2'b00);

    // Combined FlushE
    assign FlushE = FlushE_stall | FlushE_branch;

    // Combined stalls - coordinate with branch resolution
    // Don't stall when taking a branch (the branch flush overrides the stall)
    assign StallF = (StallF_I0_hz | StallF_I1_hz | (value & ~((JALPredictD_I0 & ~StallD) | branch_predicted_fetch))) & (PCSrcE == 2'b00);
    assign StallD = (StallD_I0_hz | StallD_I1_hz) & (PCSrcE == 2'b00);

    // FlushD combines hazard unit flushes with branch/JAL redirects
    assign FlushD = (PCSrcE != 2'b00) | (JALPredictD_I0 & ~StallD);

    // Raw stall from hazard units only — no PCSrcE masking.
    // Used in PCMux3In to avoid false timing path: comparator→PCSrcE→StallD→PCMux3In.
    assign StallD_hz = StallD_I0_hz | StallD_I1_hz;


    // ============================================================
    // FETCH STAGE
    // ============================================================

    logic [31:0] entry_addr;
    initial begin
        entry_addr = '0;
        void'($value$plusargs("ENTRY_ADDR=%h", entry_addr));
        $display("[TB] ENTRY_ADDR = 0x%h", entry_addr);
    end

    // pcreg enable: use !StallF_fast | FlushE_branch rather than !StallF
    // to avoid the long comparator→PCSrcE→StallF (23-gate) enable path.
    // FlushE_branch = PCSrcE[0]|PCSrcE[1] (1 gate from PCSrcE; arrives at ~3.1 ns)
    // !StallF_fast = precomputed from hazard units (arrives well before comparator finishes)
    // Equivalent to !StallF: when PCSrcE==00, StallF_fast==StallF; when PCSrcE!=00, both =1.
    logic pcreg_en;
    assign pcreg_en = !StallF_fast | FlushE_branch;
    flopr_en_reset #(32) pcreg(clk, reset, pcreg_en, entry_addr, PCNextF, PCF);
    adder pcadd4 (PCF, 32'd4, PCPlus4F);
    adder pcadd8 (PCF, 32'd8, PCPlus8F);

    // Split 64-bit fetch
    assign InstrF_0 = Instr[63:32];
    assign InstrF_1 = Instr[31:0];

    // Write fetched pair into circular instruction buffer.
    // PCBuffer_write_en uses FlushE_branch (1 gate from PCSrcE) rather than the long
    // StallF/FlushD_full chain, to keep the comparator→PCBuffer write path short.
    always_ff @(posedge clk) begin
        if (PCBuffer_write_en) begin
            InstrBuffer[WritePtr]     <= InstrF_0;
            PCBuffer[WritePtr]        <= PCF;
            InstrBuffer[WritePtr + 1] <= InstrF_1;
            PCBuffer[WritePtr + 1]    <= PCPlus4F;
        end
    end


    // ============================================================
    // BUFFER READ LOGIC
    // ============================================================

    // Gate ReadPtr advance: only trust IssueI1 once D2 has non-flushed instructions
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            d2_valid <= 1'b0;
        end else begin
            if (FlushD_full) begin
                d2_valid <= 1'b0;
            end else if (!StallD) begin
                d2_valid <= !buffer_stale;
            end
        end
    end

    assign ReadPtr_next    = (d2_valid && !StallD && !FlushE && !FlushD_full && free_slots >= 1 && !buffer_stale) ? // todo updated here flushe
                            ReadPtr + (IssueI1 ? 2 : 1) : ReadPtr;

    // ReadPtr_next_fast: no PCSrcE or StallD_hz dependency.
    // "Wrong" during stalls is harmless: pcreg and IF/ID registers are gated, so no state is captured.
    assign ReadPtr_next_fast = (d2_valid && !FlushE_stall &&
                                !(JALPredictD_I0 | BranchPredictTakenD_I1_fast) &&
                                free_slots >= 1 && !buffer_stale) ?
                               ReadPtr + (IssueI1_noflushd ? 2 : 1) : ReadPtr;
    assign ReadPtr_next_p1_fast = ReadPtr_next_fast + 2'd1;

    assign InstrToDecodeI0 = InstrBuffer[ReadPtr_next_fast];
    assign PCToDecodeI0    = PCBuffer[ReadPtr_next_fast];
    assign InstrToDecodeI1 = InstrBuffer[ReadPtr_next_p1_fast];
    assign PCToDecodeI1    = PCBuffer[ReadPtr_next_p1_fast];


    // ============================================================
    // BRANCH PREDICTION
    // ============================================================

    // Branch detection (I0 only; I1 uses fast version)
    assign isBranchF_I0 = (InstrToDecodeI0[6:0] == 7'b1100011);

    // PHT indexing (I0 only; I1 and IF/ID register use fast versions)
    assign BranchIndex_I0     = PCToDecodeI0[9:2] ^ GHR;
    assign PredictedTakenF_I0 = PHT[BranchIndex_I0][1];

    // Precompute branch info for ALL 4 buffer entries in parallel using constant slot indices.
    // Each slot's computation starts from registered InstrBuffer[k]/PCBuffer[k] values, so no
    // dynamic mux is needed in the hot path.  The only dynamic mux is the cheap final select
    // driven by ReadPtr_next_fast (2-bit, just select delay — no adder on the critical path).
    genvar k;
    generate
        for (k = 0; k < 4; k++) begin : gen_bp_pre
            assign isBranch_buf[k]     = (InstrBuffer[k][6:0] == 7'b1100011);
            assign predTaken_buf[k]    = PHT[PCBuffer[k][9:2] ^ GHR][1];
            assign BranchTarget_buf[k] = PCBuffer[k] + {{20{InstrBuffer[k][31]}},
                                                         InstrBuffer[k][7],
                                                         InstrBuffer[k][30:25],
                                                         InstrBuffer[k][11:8], 1'b0};
        end
    endgenerate

    assign isBranchF_I0_fast       = isBranch_buf[ReadPtr_next_fast];
    assign PredictedTakenF_I0_fast = predTaken_buf[ReadPtr_next_fast];
    assign BranchTargetF_I0_fast   = BranchTarget_buf[ReadPtr_next_fast];
    assign PredictedTakenF_I1_fast = predTaken_buf[ReadPtr_next_p1_fast];

    // Branch prediction signals
    logic branch_predicted_decode;
    assign branch_predicted_fetch  = (isBranchF_I0 & PredictedTakenF_I0 & ~StallD & ~buffer_stale);
    assign branch_predicted_decode = (BranchD_I1 & PredictedTakenD_I1 & ~StallD & (IssueI1 == 0));

    // Fast (no PCSrcE) versions for PCBuffer/InstrBuffer write enable.
    assign branch_predicted_fetch_fast = isBranchF_I0_fast & PredictedTakenF_I0_fast & ~buffer_stale;
    assign FlushD_full_fast            = JALPredictD_I0 | BranchPredictTakenD_I1_fast;
    assign value_fast                  = ((ReadPtr_next_fast == WritePtr) && !IssueI1_noflushd &&
                                          (!buffer_stale || (BranchD_I1 && PredictedTakenD_I1) || FlushE_stall));
    assign StallF_fast                 = StallF_I0_hz | StallF_I1_hz |
                                         (value_fast & ~(branch_predicted_fetch_fast | JALPredictD_I0));
    // PCBuffer_write_en: uses FlushE_branch as the sole PCSrcE-dependent term (1 gate from PCSrcE),
    // avoiding the long StallF/FlushD_full path from the comparator.
    assign PCBuffer_write_en = !FlushE_branch && !StallF_fast && !FlushD_full_fast;


    // ============================================================
    // BUFFER POINTER MANAGEMENT
    // ============================================================

    logic reset_pointers;
    assign reset_pointers = FlushD_full | branch_predicted_fetch;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            WritePtr <= 2'b00;
            ReadPtr  <= 2'b00;
        end else if (reset_pointers) begin
            WritePtr <= 2'b00;
            ReadPtr  <= 2'b00;
        end else begin
            ReadPtr <= ReadPtr_next;
            if (!StallF_fast) WritePtr <= WritePtr + 2;
        end
    end


    // ============================================================
    // BUFFER STALENESS TRACKING
    // ============================================================

    assign PC_redirected = ((PCSrcE != 2'b00) |
                            (JALPredictD_I0 & ~StallD) |
                            (branch_predicted_fetch) |
                            BranchPredictTakenD_I1); // i am predicting branch of i1 in decode now bc of issue checks

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            buffer_stale <= 1'b1;
        end else begin
            if (PC_redirected) begin
                buffer_stale <= 1'b1;
            end else if (!StallF) begin
                buffer_stale <= 1'b0;
            end
        end
    end

    // Soft flush (buffer_stale) must be gated by !StallD.
    // When a load-use stall coincides with buffer_stale (e.g. branch predicted at fetch
    // followed by a stall cycle), the IF/ID registers hold the valid pre-branch instructions.
    // flopr_en_flush gives flush priority over enable, so without the !StallD gate the flush
    // would win and wipe out the correct instructions even while the stall is active.
    // The hard flush (FlushD_full: mispredicts, JAL, I1-branch-at-decode) still fires
    // unconditionally — those cases genuinely need to override a stall.
    assign FlushD_ifid = (FlushD_full | (!StallD && buffer_stale));


    // ============================================================
    // PC SELECTION MUX
    // ============================================================

    // PCMux3In: prediction-only default next-PC (no PCSrcE/comparator dependency).
    // All signals use "fast" variants to eliminate false timing paths from comparator through PCSrcE.
    always_comb
        if      (JALPredictD_I0)                                               PCMux3In = JALTargetD_I0;
        else if (BranchPredictTakenD_I1_fast)                                  PCMux3In = BranchTargetD_I1;
        else if (isBranchF_I0_fast & PredictedTakenF_I0_fast & ~buffer_stale) PCMux3In = BranchTargetF_I0_fast;
        else                                                                    PCMux3In = PCPlus8F;

    // Use PCSrcE directly as the pcmux select — no PCSelect layer needed.
    // pcmux encoding mirrors PCSrcE:
    //   2'b00 → PCMux3In  (prediction target or PCPlus8F, fast; PCSrcE==0 means no EX redirect)
    //   2'b01 → PCTargetE (taken-branch correction or unpredicted JAL)
    //   2'b10 → ALUResultE (JALR)
    //   2'b11 → PCPlus4E  (not-taken correction; PCPlus4E is fast, no PCMux3In indirection)
    mux4 #(32) pcmux(PCMux3In, PCTargetE, {ALUResultE[31:1], 1'b0}, PCPlus4E,
                    PCSrcE, PCNextF);


   // ============================================================
   // IF → ID Pipeline Registers
   // ============================================================
   flopr_en_flush #(32) IF_ID_PC_I0        (clk, reset, ~StallD, FlushD_ifid, PCToDecodeI0,      PCD_I0);
   flopr_en_flush #(32) IF_ID_PC_I1        (clk, reset, ~StallD, FlushD_ifid, PCToDecodeI1,      PCD_I1);
   flopr_en_flush #(32) IF_ID_Instr_I0     (clk, reset, ~StallD, FlushD_ifid, InstrToDecodeI0,   InstrD_I0);
   flopr_en_flush #(32) IF_ID_Instr_I1     (clk, reset, ~StallD, FlushD_ifid, InstrToDecodeI1,   InstrD_I1);
   flopr_en_flush #(1)  IF_ID_BranchPred_I0(clk, reset, ~StallD, FlushD_ifid, PredictedTakenF_I0_fast, PredictedTakenD_I0);
   flopr_en_flush #(1)  IF_ID_BranchPred_I1(clk, reset, ~StallD, FlushD_ifid, PredictedTakenF_I1_fast, PredictedTakenD_I1);
   flopr_en_flush #(8)  IF_ID_GHR          (clk, reset, ~StallD, FlushD_ifid, GHR,               GHR_snapD);


   // ============================================================
   // DECODE
   // ============================================================
   assign PCPlus4D_I0 = PCD_I0 + 32'd4;
   assign PCPlus4D_I1 = PCD_I1 + 32'd4;


   // I0 field extraction
   assign Rs1D_I0    = InstrD_I0[19:15];
   assign Rs2D_I0    = InstrD_I0[24:20];
   assign RdD_I0     = InstrD_I0[11:7];
   assign funct3D_I0  = InstrD_I0[14:12];
   assign CSRAddrD_I0 = InstrD_I0[31:20];
   assign OpcodeD_I0  = InstrD_I0[6:0];


   // I1 field extraction
   assign Rs1D_I1    = InstrD_I1[19:15];
   assign Rs2D_I1    = InstrD_I1[24:20];
   assign RdD_I1     = InstrD_I1[11:7];
   assign funct3D_I1  = InstrD_I1[14:12];
   assign CSRAddrD_I1 = InstrD_I1[31:20];
   assign OpcodeD_I1  = InstrD_I1[6:0];


   assign LoadD_I0 = (OpcodeD_I0 == 7'b0000011);
   assign LoadD_I1 = (OpcodeD_I1 == 7'b0000011);


   // Intra-pair dependency / issue checks
   // Rs1 is NOT a real source for JAL (J-type imm overlaps rs1 field),
   // LUI, or AUIPC (no register sources at all).
   logic Rs1UsedD_I1;
   assign Rs1UsedD_I1 = (OpcodeD_I1 != 7'b1101111) &&  // not JAL
                        (OpcodeD_I1 != 7'b0110111) &&  // not LUI
                        (OpcodeD_I1 != 7'b0010111);    // not AUIPC


   // Rs2 is only a real source for R-type (0110011), Store (0100011), Branch (1100011).
   // All other opcodes embed rs2 bits in the immediate — checking them causes false stalls.
   logic Rs2UsedD_I1;
   assign Rs2UsedD_I1 = (OpcodeD_I1 == 7'b0110011) ||  // R-type
                        (OpcodeD_I1 == 7'b0100011) ||  // Store
                        (OpcodeD_I1 == 7'b1100011);    // Branch


   assign IntraPairRAW = RegWriteD_I0 && (RdD_I0 != 5'b0) &&
                         ((Rs1UsedD_I1 && RdD_I0 == Rs1D_I1) ||
                          (Rs2UsedD_I1 && RdD_I0 == Rs2D_I1));


   // Multiply detection (opcode=0110011, funct7=0000001)
   logic isMulD_I0, isMulD_I1, BothMuls;
   assign isMulD_I0 = (OpcodeD_I0 == 7'b0110011) && (InstrD_I0[31:25] == 7'b0000001);
   assign isMulD_I1 = (OpcodeD_I1 == 7'b0110011) && (InstrD_I1[31:25] == 7'b0000001);
   assign BothMuls  = isMulD_I0 && isMulD_I1;


   assign BothBranches            = BranchD_I0 && BranchD_I1;
   assign I0_PredictedTakenBranch = BranchD_I0 && PredictedTakenD_I0;
   assign BothMemOps              = (MemWriteD_I0 || LoadD_I0) &&
                                    (MemWriteD_I1 || LoadD_I1);
   assign I0_IsJump               = JumpD_I0;
   assign AnyCSR                  = CSRWriteD_I0 || CSRWriteD_I1;


   // WAW: both lanes would write the same non-zero register — stall I1
   logic WAW;
   assign WAW     = RegWriteD_I0 && RegWriteD_I1 &&
                    (RdD_I0 == RdD_I1) && (RdD_I0 != 5'b0);


   assign IssueI1 = (!IntraPairRAW            &&
                    !BothBranches            &&
                    !I0_PredictedTakenBranch &&
                    !(BranchD_I0 && JumpD_I1) &&
                    !BothMemOps              &&
                    !I0_IsJump               &&
                    !AnyCSR                  &&
                    !WAW                     &&
                    !BothMuls                &&
                    (free_slots >= 3'd2)     &&
                    !StallD && !FlushD && !buffer_stale); //todo added 0 clause always allow I1 if it's the first instruction (PC=0) to get the pipeline going

   // IssueI1 without PCSrcE-dependent terms (!StallD, !FlushD) — for PCMux3In fast path.
   // When PCSrcE==00: IssueI1_noflushd == IssueI1 (since !I0_IsJump implies !JALPredictD_I0,
   // so FlushD==0 and StallD==StallD_hz in that case).
   // When PCSrcE!=00: PCMux3In is not selected by pcmux anyway (false path).
   // StallD_hz removed: downstream registers (pcreg, IF/ID) are gated during stalls,
   // so a "wrong" value here during a stall cycle causes no state corruption.
   assign IssueI1_noflushd = (!IntraPairRAW            &&
                               !BothBranches            &&
                               !I0_PredictedTakenBranch &&
                               !(BranchD_I0 && JumpD_I1) &&
                               !BothMemOps              &&
                               !I0_IsJump               &&
                               !AnyCSR                  &&
                               !WAW                     &&
                               !BothMuls                &&
                               (free_slots >= 3'd2)     &&
                               !buffer_stale);
   assign BranchPredictTakenD_I1_fast = BranchD_I1 & PredictedTakenD_I1 & IssueI1_noflushd & (~(BranchD_I0 & PredictedTakenD_I0));


   // Register file (4-read, 2-write)
   RegFile RF(
       .clk    (clk),
       .WE_I0  (RegWriteW_I0), .A_WR_I0(RdW_I0),  .WD_I0(ResultW_I0),
       .WE_I1  (RegWriteW_I1), .A_WR_I1(RdW_I1),  .WD_I1(ResultW_I1),
       .A_RD0  (Rs1D_I0), .RD0(RD1D_I0),
       .A_RD1  (Rs2D_I0), .RD1(RD2D_I0),
       .A_RD2  (Rs1D_I1), .RD2(RD1D_I1),
       .A_RD3  (Rs2D_I1), .RD3(RD2D_I1)
   );


   Extend Ext_I0(InstrD_I0[31:7], ImmSrcD_I0, ImmExtD_I0);
   Extend Ext_I1(InstrD_I1[31:7], ImmSrcD_I1, ImmExtD_I1);


   // JAL detection and target computation at decode
   // need to distinguish JAL from JALR (ALUSrc=1)
   assign isJALD_I0    = JumpD_I0 & ~ALUSrcD_I0;
   assign JALTargetD_I0 = PCD_I0 + ImmExtD_I0;
   // Predict JAL at decode; pcmux input already handles priority via PCSrcE select.
   assign JALPredictD_I0 = isJALD_I0;

   // I1 branch decode-stage prediction:
    // Redirect at Decode (not Fetch) so IssueI1 is already known — avoids the problem
    // where a Fetch-stage redirect sets buffer_stale=1, causing IssueI1=0 next cycle
    // and the branch never reaching Execute for resolution.
    // IssueI1 does NOT check FlushD_full (no combinatorial loop).
    assign BranchTargetD_I1    = PCD_I1 + ImmExtD_I1;
    assign BranchPredictTakenD_I1 = BranchD_I1 & PredictedTakenD_I1 & IssueI1 & (~(BranchD_I0 & PredictedTakenD_I0));
    // FlushD_full: includes I1 branch prediction on top of the base FlushD.
    // Used for buffer management (write guard, pointer reset, d2_valid, FlushD_ifid).
    // Kept separate from FlushD to avoid a loop through IssueI1.
    assign FlushD_full = FlushD | BranchPredictTakenD_I1;


   // CSR source mux: rs1 or zero-extended immediate (bit 14 of funct3 selects)
   mux2 #(32) CSRSrcMux_I0(RD1D_I0, ImmExtD_I0, InstrD_I0[14], CSRSrcDataD_I0);
   mux2 #(32) CSRSrcMux_I1(RD1D_I1, ImmExtD_I1, InstrD_I1[14], CSRSrcDataD_I1);


   // ============================================================
   // ID → EX Pipeline Registers
   // ============================================================


   // I0: always propagated (may be NOPped by FlushE)
   flopr_en_flush #(32) ID_EX_PC_I0       (clk, reset, 1'b1, FlushE, PCD_I0,         PCE_I0);
   flopr_en_flush #(32) ID_EX_RD1_I0      (clk, reset, 1'b1, FlushE, RD1D_I0,        RD1E_I0);
   flopr_en_flush #(32) ID_EX_RD2_I0      (clk, reset, 1'b1, FlushE, RD2D_I0,        RD2E_I0);
   flopr_en_flush #(5)  ID_EX_Rs1_I0      (clk, reset, 1'b1, FlushE, Rs1D_I0,        Rs1E_I0);
   flopr_en_flush #(5)  ID_EX_Rs2_I0      (clk, reset, 1'b1, FlushE, Rs2D_I0,        Rs2E_I0);
   flopr_en_flush #(5)  ID_EX_Rd_I0       (clk, reset, 1'b1, FlushE, RdD_I0,         RdE_I0);
   flopr_en_flush #(3)  ID_EX_funct3_I0   (clk, reset, 1'b1, FlushE, funct3D_I0,     funct3E_I0);
   flopr_en_flush #(12) ID_EX_CSRAddr_I0  (clk, reset, 1'b1, FlushE, CSRAddrD_I0,    CSRAddrE_I0);
   flopr_en_flush #(32) ID_EX_ImmExt_I0   (clk, reset, 1'b1, FlushE, ImmExtD_I0,     ImmExtE_I0);
   flopr_en_flush #(32) ID_EX_PCPlus4_I0  (clk, reset, 1'b1, FlushE, PCPlus4D_I0,    PCPlus4E_I0);
   flopr_en_flush #(32) ID_EX_PCTarget_I0 (clk, reset, 1'b1, FlushE, JALTargetD_I0,  PCTargetE_I0);
   flopr_en_flush #(32) ID_EX_CSRSrc_I0   (clk, reset, 1'b1, FlushE, CSRSrcDataD_I0, CSRSrcDataE_I0);
   flopr_en_flush #(1)  ID_EX_BrPred_I0   (clk, reset, 1'b1, FlushE, PredictedTakenD_I0, PredictedTakenE_I0);
   flopr_en_flush #(1)  ID_EX_JALPredict_I0(clk, reset, 1'b1, FlushE, JALPredictD_I0,   JALPredictE_I0);
   flopr_en_flush #(8)  ID_EX_GHR         (clk, reset, 1'b1, FlushE, GHR_snapD,         GHR_snapE);
   flopr_en_flush #(1)  ID_EX_RegWrite_I0 (clk, reset, 1'b1, FlushE, RegWriteD_I0,   RegWriteE_I0);
   flopr_en_flush #(1)  ID_EX_ALUSrc_I0   (clk, reset, 1'b1, FlushE, ALUSrcD_I0,     ALUSrcE_I0);
   flopr_en_flush #(1)  ID_EX_MemWrite_I0 (clk, reset, 1'b1, FlushE, MemWriteD_I0,   MemWriteE_I0);
   flopr_en_flush #(1)  ID_EX_CSRWrite_I0 (clk, reset, 1'b1, FlushE, CSRWriteD_I0,   CSRWriteE_I0);
   flopr_en_flush #(1)  ID_EX_Branch_I0   (clk, reset, 1'b1, FlushE, BranchD_I0,     BranchE_I0);
   flopr_en_flush #(1)  ID_EX_Jump_I0     (clk, reset, 1'b1, FlushE, JumpD_I0,       JumpE_I0);
   flopr_en_flush #(3)  ID_EX_ResultSrc_I0(clk, reset, 1'b1, FlushE, ResultSrcD_I0,  ResultSrcE_I0);
   flopr_en_flush #(5)  ID_EX_ALUCtrl_I0  (clk, reset, 1'b1, FlushE, ALUControlD_I0, ALUControlE_I0);
   flopr_en_flush #(1)  ID_EX_Load_I0     (clk, reset, 1'b1, FlushE, LoadD_I0,       LoadE_I0);


   // I1: additionally flushed when not issued (becomes NOP)
   logic FlushE_I1;
   assign FlushE_I1 = FlushE | ~IssueI1;


   flopr_en_flush #(32) ID_EX_PC_I1       (clk, reset, 1'b1, FlushE_I1, PCD_I1,         PCE_I1);
   flopr_en_flush #(32) ID_EX_RD1_I1      (clk, reset, 1'b1, FlushE_I1, RD1D_I1,        RD1E_I1);
   flopr_en_flush #(32) ID_EX_RD2_I1      (clk, reset, 1'b1, FlushE_I1, RD2D_I1,        RD2E_I1);
   flopr_en_flush #(5)  ID_EX_Rs1_I1      (clk, reset, 1'b1, FlushE_I1, Rs1D_I1,        Rs1E_I1);
   flopr_en_flush #(5)  ID_EX_Rs2_I1      (clk, reset, 1'b1, FlushE_I1, Rs2D_I1,        Rs2E_I1);
   flopr_en_flush #(5)  ID_EX_Rd_I1       (clk, reset, 1'b1, FlushE_I1, RdD_I1,         RdE_I1);
   flopr_en_flush #(3)  ID_EX_funct3_I1   (clk, reset, 1'b1, FlushE_I1, funct3D_I1,     funct3E_I1);
   flopr_en_flush #(12) ID_EX_CSRAddr_I1  (clk, reset, 1'b1, FlushE_I1, CSRAddrD_I1,    CSRAddrE_I1);
   flopr_en_flush #(32) ID_EX_ImmExt_I1   (clk, reset, 1'b1, FlushE_I1, ImmExtD_I1,     ImmExtE_I1);
   flopr_en_flush #(32) ID_EX_PCPlus4_I1  (clk, reset, 1'b1, FlushE_I1, PCPlus4D_I1,    PCPlus4E_I1);
   flopr_en_flush #(32) ID_EX_PCTarget_I1 (clk, reset, 1'b1, FlushE_I1, BranchTargetD_I1, PCTargetE_I1);
   flopr_en_flush #(32) ID_EX_CSRSrc_I1   (clk, reset, 1'b1, FlushE_I1, CSRSrcDataD_I1, CSRSrcDataE_I1);
   flopr_en_flush #(1)  ID_EX_BrPred_I1   (clk, reset, 1'b1, FlushE_I1, PredictedTakenD_I1, PredictedTakenE_I1);
   flopr_en_flush #(1)  ID_EX_RegWrite_I1 (clk, reset, 1'b1, FlushE_I1, RegWriteD_I1,   RegWriteE_I1);
   flopr_en_flush #(1)  ID_EX_ALUSrc_I1   (clk, reset, 1'b1, FlushE_I1, ALUSrcD_I1,     ALUSrcE_I1);
   flopr_en_flush #(1)  ID_EX_MemWrite_I1 (clk, reset, 1'b1, FlushE_I1, MemWriteD_I1,   MemWriteE_I1);
   flopr_en_flush #(1)  ID_EX_CSRWrite_I1 (clk, reset, 1'b1, FlushE_I1, CSRWriteD_I1,   CSRWriteE_I1);
   flopr_en_flush #(1)  ID_EX_Branch_I1   (clk, reset, 1'b1, FlushE_I1, BranchD_I1,     BranchE_I1);
   flopr_en_flush #(1)  ID_EX_Jump_I1     (clk, reset, 1'b1, FlushE_I1, JumpD_I1,       JumpE_I1);
   flopr_en_flush #(3)  ID_EX_ResultSrc_I1(clk, reset, 1'b1, FlushE_I1, ResultSrcD_I1,  ResultSrcE_I1);
   flopr_en_flush #(5)  ID_EX_ALUCtrl_I1  (clk, reset, 1'b1, FlushE_I1, ALUControlD_I1, ALUControlE_I1);
   flopr_en_flush #(1)  ID_EX_Load_I1     (clk, reset, 1'b1, FlushE_I1, LoadD_I1,       LoadE_I1);


   // ============================================================
   // EXECUTE
   // ============================================================


   // ---- I0 Execute datapath ----
   // PCTargetE_I0 comes from ID_EX_PCTarget_I0 (pre-computed at decode as JALTargetD_I0)

   // Forwarding mux for I0 SrcA — 5 sources, select from HazardUnit
   always_comb begin
       case (ForwardAE_I0)
           3'b010:  SrcAE_I0 = ResultM_I0;  // same-lane  M
           3'b100:  SrcAE_I0 = ResultM_I1;  // cross-lane M
           3'b001:  SrcAE_I0 = ResultW_I0;  // same-lane  W
           3'b011:  SrcAE_I0 = ResultW_I1;  // cross-lane W
           default: SrcAE_I0 = RD1E_I0;     // register file
       endcase
   end


   // Forwarding mux for I0 SrcB (pre-ALUSrc)
   always_comb begin
       case (ForwardBE_I0)
           3'b010:  SrcBEIntermediate_I0 = ResultM_I0;
           3'b100:  SrcBEIntermediate_I0 = ResultM_I1;
           3'b001:  SrcBEIntermediate_I0 = ResultW_I0;
           3'b011:  SrcBEIntermediate_I0 = ResultW_I1;
           default: SrcBEIntermediate_I0 = RD2E_I0;
       endcase
   end


   mux2 #(32) SrcBmux_I0(SrcBEIntermediate_I0, ImmExtE_I0, ALUSrcE_I0, SrcBE_I0);


   alu        ALU_I0        (SrcAE_I0, SrcBE_I0, ALUControlE_I0[3:0], ALUResultE_I0);
   comparator comp_I0       (SrcAE_I0, SrcBE_I0, {eq_E_I0, lt_signed_E_I0, lt_unsig_E_I0});

   // Single shared multiply unit — mux I0's operands if I0 is the multiply, else I1's
   logic        useMulI0;
   logic [31:0] SrcA_mul, SrcB_mul;
   logic [2:0]  funct3_mul;
   assign useMulI0   = (ResultSrcE_I0 == 3'b101);
   assign SrcA_mul   = useMulI0 ? SrcAE_I0  : SrcAE_I1;
   assign SrcB_mul   = useMulI0 ? SrcBE_I0  : SrcBE_I1;
   assign funct3_mul = useMulI0 ? funct3E_I0 : funct3E_I1;

   // Compute all 16 partial products in EX (after forwarding mux settles).
   // Registered at EX/MEM boundary; MEM only needs the accumulation.
   logic signed [17:0] P00_E, P01_E, P02_E, P03_E;
   logic signed [17:0] P10_E, P11_E, P12_E, P13_E;
   logic signed [17:0] P20_E, P21_E, P22_E, P23_E;
   logic signed [17:0] P30_E, P31_E, P32_E, P33_E;
   multiply multiply_ex(SrcA_mul, SrcB_mul, funct3_mul[1:0],
                        P00_E, P01_E, P02_E, P03_E,
                        P10_E, P11_E, P12_E, P13_E,
                        P20_E, P21_E, P22_E, P23_E,
                        P30_E, P31_E, P32_E, P33_E);



   always_comb begin
       case (ResultSrcE_I0)
           3'b100:  ALUResultPipeE_I0 = PCTargetE_I0;  // AUIPC
           3'b011:  ALUResultPipeE_I0 = ImmExtE_I0;    // LUI
           default: ALUResultPipeE_I0 = ALUResultE_I0;
       endcase
   end


   always_comb begin
       case (funct3E_I0)
           3'b000: take_branchE_I0 = eq_E_I0;
           3'b001: take_branchE_I0 = ~eq_E_I0;
           3'b100: take_branchE_I0 = lt_signed_E_I0;
           3'b101: take_branchE_I0 = ~lt_signed_E_I0;
           3'b110: take_branchE_I0 = lt_unsig_E_I0;
           3'b111: take_branchE_I0 = ~lt_unsig_E_I0;
           default: take_branchE_I0 = 1'b0;
       endcase
   end


   assign WriteDataE_I0 = SrcBEIntermediate_I0;


   // ---- I1 Execute datapath ----
   // PCTargetE_I1 comes from ID_EX_PCTarget_I1 (pre-computed at decode as BranchTargetD_I1)


   // Forwarding mux for I1 SrcA
   always_comb begin
       case (ForwardAE_I1)
           3'b010:  SrcAE_I1 = ResultM_I1;  // same-lane  M
           3'b100:  SrcAE_I1 = ResultM_I0;  // cross-lane M
           3'b001:  SrcAE_I1 = ResultW_I1;  // same-lane  W
           3'b011:  SrcAE_I1 = ResultW_I0;  // cross-lane W
           default: SrcAE_I1 = RD1E_I1;
       endcase
   end


   // Forwarding mux for I1 SrcB (pre-ALUSrc)
   always_comb begin
       case (ForwardBE_I1)
           3'b010:  SrcBEIntermediate_I1 = ResultM_I1;
           3'b100:  SrcBEIntermediate_I1 = ResultM_I0;
           3'b001:  SrcBEIntermediate_I1 = ResultW_I1;
           3'b011:  SrcBEIntermediate_I1 = ResultW_I0;
           default: SrcBEIntermediate_I1 = RD2E_I1;
       endcase
   end


   mux2 #(32) SrcBmux_I1(SrcBEIntermediate_I1, ImmExtE_I1, ALUSrcE_I1, SrcBE_I1);


   alu        ALU_I1        (SrcAE_I1, SrcBE_I1, ALUControlE_I1[3:0], ALUResultE_I1);
   comparator comp_I1       (SrcAE_I1, SrcBE_I1, {eq_E_I1, lt_signed_E_I1, lt_unsig_E_I1});



   always_comb begin
       case (ResultSrcE_I1)
           3'b100:  ALUResultPipeE_I1 = PCTargetE_I1;
           3'b011:  ALUResultPipeE_I1 = ImmExtE_I1;
           default: ALUResultPipeE_I1 = ALUResultE_I1;
       endcase
   end


   always_comb begin
       case (funct3E_I1)
           3'b000: take_branchE_I1 = eq_E_I1;
           3'b001: take_branchE_I1 = ~eq_E_I1;
           3'b100: take_branchE_I1 = lt_signed_E_I1;
           3'b101: take_branchE_I1 = ~lt_signed_E_I1;
           3'b110: take_branchE_I1 = lt_unsig_E_I1;
           3'b111: take_branchE_I1 = ~lt_unsig_E_I1;
           default: take_branchE_I1 = 1'b0;
       endcase
   end


   assign WriteDataE_I1 = SrcBEIntermediate_I1;


   // ---- Branch/Jump resolution ----
   // I0 always wins if it's a branch or jump.
   // I1 can never be a jump when I0 is a branch (blocked at issue), so no take_branch
   // dependency needed here — keeps take_branchE_I0 off the PCTargetE mux select.
   assign UseBranchI0 = JumpE_I0 || BranchE_I0;

   // Gate JAL-already-predicted on which lane's jump is actually being used:
    logic JALPredictE_branch;
    assign JALPredictE_branch = UseBranchI0 ? JALPredictE_I0 : 1'b0; // I1 JAL never pre-predicted


   assign BranchE_branch         = UseBranchI0 ? BranchE_I0         : BranchE_I1;
   assign JumpE_branch           = UseBranchI0 ? JumpE_I0           : JumpE_I1;
   assign ALUSrcE_branch         = UseBranchI0 ? ALUSrcE_I0         : ALUSrcE_I1;
   assign PredictedTakenE_branch = UseBranchI0 ? PredictedTakenE_I0 : PredictedTakenE_I1;
   assign take_branchE_branch    = UseBranchI0 ? take_branchE_I0    : take_branchE_I1;
   assign PCE_branch             = UseBranchI0 ? PCE_I0             : PCE_I1;
   assign PCPlus4E               = UseBranchI0 ? PCPlus4E_I0        : PCPlus4E_I1;
   assign PCTargetE              = UseBranchI0 ? PCTargetE_I0       : PCTargetE_I1;
   assign ALUResultE             = UseBranchI0 ? ALUResultE_I0      : ALUResultE_I1;


   assign BranchTakenE     = BranchE_branch & take_branchE_branch;
   assign BranchMispredictE = BranchE_branch &&
                              (PredictedTakenE_branch != BranchTakenE);


   // BranchTakenE and BranchMispredictE are the only comparator-dependent signals.
   // PCSrcE is derived directly from them — no further nesting on the critical path.
   always_comb begin
       PCSrcE = 2'b00;
       if (BranchMispredictE)
           PCSrcE = BranchTakenE ? 2'b01 : 2'b11; // correction: taken→PCTargetE, NT→PCPlus4E
       else if (JumpE_branch && ~ALUSrcE_branch && ~JALPredictE_branch)
           PCSrcE = 2'b01; // JAL not yet predicted at decode
       else if (JumpE_branch && ALUSrcE_branch)
           PCSrcE = 2'b10; // JALR
   end


   // GHR update (shift in outcome on every resolved branch)
   flopr_en #(8) ghr_update(clk, reset, BranchE_branch,
                             {GHR[6:0], BranchTakenE}, GHR);


   // PHT update (saturating 2-bit counter)
   assign indexE = PCE_branch[9:2] ^ GHR_snapE;
   always_ff @(posedge clk, posedge reset) begin
       if (reset) begin
           for (int i = 0; i < 256; i++)
               PHT[i] <= 2'b01;           // reset to weakly not-taken
       end else if (BranchE_branch) begin
           if (BranchTakenE) begin
               if (PHT[indexE] != 2'b11) PHT[indexE] <= PHT[indexE] + 1;
           end else begin
               if (PHT[indexE] != 2'b00) PHT[indexE] <= PHT[indexE] - 1;
           end
       end
   end


   // ============================================================
   // EX → MEM Pipeline Registers
   // ============================================================


   // I0
   flopr_en #(32) EX_MEM_PCPlus4_I0  (clk, reset, 1'b1, PCPlus4E_I0,       PCPlus4M_I0);
   flopr_en #(32) EX_MEM_ALUResult_I0 (clk, reset, 1'b1, ALUResultPipeE_I0, ALUResultM_I0);
   // Register partial products at EX/MEM — MEM only needs to accumulate
   flopr_en #(18) EX_MEM_P00(clk, reset, 1'b1, P00_E, P00_M);
   flopr_en #(18) EX_MEM_P01(clk, reset, 1'b1, P01_E, P01_M);
   flopr_en #(18) EX_MEM_P02(clk, reset, 1'b1, P02_E, P02_M);
   flopr_en #(18) EX_MEM_P03(clk, reset, 1'b1, P03_E, P03_M);
   flopr_en #(18) EX_MEM_P10(clk, reset, 1'b1, P10_E, P10_M);
   flopr_en #(18) EX_MEM_P11(clk, reset, 1'b1, P11_E, P11_M);
   flopr_en #(18) EX_MEM_P12(clk, reset, 1'b1, P12_E, P12_M);
   flopr_en #(18) EX_MEM_P13(clk, reset, 1'b1, P13_E, P13_M);
   flopr_en #(18) EX_MEM_P20(clk, reset, 1'b1, P20_E, P20_M);
   flopr_en #(18) EX_MEM_P21(clk, reset, 1'b1, P21_E, P21_M);
   flopr_en #(18) EX_MEM_P22(clk, reset, 1'b1, P22_E, P22_M);
   flopr_en #(18) EX_MEM_P23(clk, reset, 1'b1, P23_E, P23_M);
   flopr_en #(18) EX_MEM_P30(clk, reset, 1'b1, P30_E, P30_M);
   flopr_en #(18) EX_MEM_P31(clk, reset, 1'b1, P31_E, P31_M);
   flopr_en #(18) EX_MEM_P32(clk, reset, 1'b1, P32_E, P32_M);
   flopr_en #(18) EX_MEM_P33(clk, reset, 1'b1, P33_E, P33_M);
   flopr_en #(32) EX_MEM_WriteData_I0 (clk, reset, 1'b1, WriteDataE_I0,     WriteDataM_I0);
   flopr_en #(5)  EX_MEM_Rd_I0        (clk, reset, 1'b1, RdE_I0,            RdM_I0);
   flopr_en #(3)  EX_MEM_funct3_I0    (clk, reset, 1'b1, funct3E_I0,        funct3M_I0);
   flopr_en #(12) EX_MEM_CSRAddr_I0   (clk, reset, 1'b1, CSRAddrE_I0,       CSRAddrM_I0);
   flopr_en #(32) EX_MEM_CSRSrc_I0    (clk, reset, 1'b1, CSRSrcDataE_I0,    CSRSrcDataM_I0);
   flopr_en #(1)  EX_MEM_RegWrite_I0  (clk, reset, 1'b1, RegWriteE_I0,      RegWriteM_I0);
   flopr_en #(1)  EX_MEM_Load_I0      (clk, reset, 1'b1, LoadE_I0,          LoadM_I0);
   flopr_en #(1)  EX_MEM_MemWrite_I0  (clk, reset, 1'b1, MemWriteE_I0,      MemWriteM_I0);
   flopr_en #(1)  EX_MEM_CSRWrite_I0  (clk, reset, 1'b1, CSRWriteE_I0,      CSRWriteM_I0);
   flopr_en #(3)  EX_MEM_ResultSrc_I0 (clk, reset, 1'b1, ResultSrcE_I0,     ResultSrcM_I0);
   flopr_en #(5)  EX_MEM_ALUCtrl_I0   (clk, reset, 1'b1, ALUControlE_I0,    ALUControlM_I0);


   // I1 TODO: check if flush logic is correct
   flopr_en_flush #(32) EX_MEM_PCPlus4_I1  (clk, reset, 1'b1, UseBranchI0 & (PCSrcE != 2'b00), PCPlus4E_I1,       PCPlus4M_I1);
   flopr_en_flush #(32) EX_MEM_ALUResult_I1 (clk, reset, 1'b1, UseBranchI0 & (PCSrcE != 2'b00), ALUResultPipeE_I1, ALUResultM_I1);
   // I1 mul registers: flopr_en (no flush gate on data path); correctness maintained by
   // RegWriteM_I1=0 when I1 is flushed, so stale values are never written to the register file.
   flopr_en_flush #(32) EX_MEM_WriteData_I1 (clk, reset, 1'b1, UseBranchI0 & (PCSrcE != 2'b00), WriteDataE_I1,     WriteDataM_I1);
   flopr_en_flush #(5)  EX_MEM_Rd_I1        (clk, reset, 1'b1, UseBranchI0 & (PCSrcE != 2'b00), RdE_I1,            RdM_I1);
   flopr_en_flush #(3)  EX_MEM_funct3_I1    (clk, reset, 1'b1, UseBranchI0 & (PCSrcE != 2'b00), funct3E_I1,        funct3M_I1);
   flopr_en_flush #(12) EX_MEM_CSRAddr_I1   (clk, reset, 1'b1, UseBranchI0 & (PCSrcE != 2'b00), CSRAddrE_I1,       CSRAddrM_I1);
   flopr_en_flush #(32) EX_MEM_CSRSrc_I1    (clk, reset, 1'b1, UseBranchI0 & (PCSrcE != 2'b00), CSRSrcDataE_I1,    CSRSrcDataM_I1);
   flopr_en_flush #(1)  EX_MEM_RegWrite_I1  (clk, reset, 1'b1, UseBranchI0 & (PCSrcE != 2'b00), RegWriteE_I1,      RegWriteM_I1);
   flopr_en_flush #(1)  EX_MEM_Load_I1      (clk, reset, 1'b1, UseBranchI0 & (PCSrcE != 2'b00), LoadE_I1,          LoadM_I1);
   flopr_en_flush #(1)  EX_MEM_MemWrite_I1  (clk, reset, 1'b1, UseBranchI0 & (PCSrcE != 2'b00), MemWriteE_I1,      MemWriteM_I1);
   flopr_en_flush #(1)  EX_MEM_CSRWrite_I1  (clk, reset, 1'b1, UseBranchI0 & (PCSrcE != 2'b00), CSRWriteE_I1,      CSRWriteM_I1);
   flopr_en_flush #(3)  EX_MEM_ResultSrc_I1 (clk, reset, 1'b1, UseBranchI0 & (PCSrcE != 2'b00), ResultSrcE_I1,     ResultSrcM_I1);
   flopr_en_flush #(5)  EX_MEM_ALUCtrl_I1   (clk, reset, 1'b1, UseBranchI0 & (PCSrcE != 2'b00), ALUControlE_I1,    ALUControlM_I1);


   // ============================================================
   // MEMORY STAGE
   // ============================================================


   // Single-ported memory arbitration: I0 has priority
   assign UseMemI0    = MemWriteM_I0 || LoadM_I0;
   assign ALUResult   = UseMemI0 ? ALUResultM_I0 : ALUResultM_I1;
   assign WriteData   = UseMemI0 ? WriteDataM_I0 : WriteDataM_I1;
   assign MemWriteOut = UseMemI0 ? MemWriteM_I0  : MemWriteM_I1;
   assign LoadOut     = UseMemI0 ? LoadM_I0       : LoadM_I1;
   assign Funct3Out   = UseMemI0 ? funct3M_I0     : funct3M_I1;


   assign ReadDataM = ReadData;


   // Performance counters
   assign IncrementInstret     = (RegWriteM_I0 | MemWriteM_I0 | LoadM_I0) +
                                 (RegWriteM_I1 | MemWriteM_I1 | LoadM_I1);
   assign IncrementAdd         = ((ALUControlM_I0 == 5'b00000) & RegWriteM_I0) +
                                 ((ALUControlM_I1 == 5'b00000) & RegWriteM_I1);
   assign IncrementBranch      = BranchE_branch;
   assign IncrementBranchTaken = BranchE_branch & BranchTakenE;
   assign BranchMisPrediction  = BranchMispredictE;
   assign IncrementLoads       = LoadM_I0 + LoadM_I1;
   assign IncrementStores      = MemWriteM_I0 + MemWriteM_I1;
   assign IncrementStalls      = StallD;
   assign IncrementFlushes     = FlushE;


   // CSR file — I0 only
   csrfile csrfile(
       .clk                 (clk),
       .reset               (reset),
       .WE3                 (CSRWriteW_I0),
       .A1                  (CSRAddrM_I0),
       .A2                  (CSRAddrW_I0),
       .WD3                 (newCSRWriteDataW_I0),
       .RD1                 (oldCSRReadDataM_I0),
       .IncrementCycle      (1'b1),
       .IncrementInstret    (IncrementInstret),
       .IncrementAdd        (IncrementAdd),
       .IncrementBranch     (IncrementBranch),
       .IncrementBranchTaken(IncrementBranchTaken),
       .BranchMisPrediction (BranchMisPrediction),
       .IncrementLoads      (IncrementLoads),
       .IncrementStores     (IncrementStores),
       .IncrementStalls     (IncrementStalls),
       .IncrementFlushes    (IncrementFlushes)
   );


   csrData #(32) csrData_I0(oldCSRReadDataM_I0, CSRSrcDataM_I0,
                             funct3M_I0, newCSRWriteDataM_I0);


    // Accumulate 16 registered partial products into 64-bit product (EX computed, MEM accumulates).
    logic [63:0] origProductM_0;
    assign origProductM_0 =
        {{46{P00_M[17]}}, P00_M}        +  // shift  0
        {{38{P01_M[17]}}, P01_M, 8'b0}  +  // shift  8
        {{38{P10_M[17]}}, P10_M, 8'b0}  +  // shift  8
        {{30{P02_M[17]}}, P02_M, 16'b0} +  // shift 16
        {{30{P11_M[17]}}, P11_M, 16'b0} +  // shift 16
        {{30{P20_M[17]}}, P20_M, 16'b0} +  // shift 16
        {{22{P03_M[17]}}, P03_M, 24'b0} +  // shift 24
        {{22{P12_M[17]}}, P12_M, 24'b0} +  // shift 24
        {{22{P21_M[17]}}, P21_M, 24'b0} +  // shift 24
        {{22{P30_M[17]}}, P30_M, 24'b0} +  // shift 24
        {{14{P13_M[17]}}, P13_M, 32'b0} +  // shift 32
        {{14{P22_M[17]}}, P22_M, 32'b0} +  // shift 32
        {{14{P31_M[17]}}, P31_M, 32'b0} +  // shift 32
        {{ 6{P23_M[17]}}, P23_M, 40'b0} +  // shift 40
        {{ 6{P32_M[17]}}, P32_M, 40'b0} +  // shift 40
        {P33_M[15:0], 48'b0};               // shift 48

    logic [31:0] productM_0;
    always_comb begin
        case (funct3M_I0)
            3'b000: productM_0 = origProductM_0[31:0];
            default: productM_0 = origProductM_0[63:32];
        endcase
    end

    logic [63:0] origProductM_1;
    assign origProductM_1 = origProductM_0;  // I0 and I1 share the same multiply unit

    logic [31:0] productM_1;
    always_comb begin
        case (funct3M_I1)
            3'b000: productM_1 = origProductM_1[31:0];
            default: productM_1 = origProductM_1[63:32];
        endcase
    end


   // M-stage result muxes (forwarding sources for EX stage next cycle)
   mux7 #(32) ResultMmux_I0(
       ALUResultM_I0,   // 000 ALU
       ReadDataM,       // 001 load (raw; adjustment in WB)
       PCPlus4M_I0,     // 010 return address
       ALUResultM_I0,   // 011 LUI  (folded)
       ALUResultM_I0,   // 100 AUIPC(folded)
       32'h0,   // 101 ALUResultM_I0
       oldCSRReadDataM_I0,           // 110 CSR  (block; forward from WB instead)
       ResultSrcM_I0,
       ResultM_I0
   );


   mux7 #(32) ResultMmux_I1(
       ALUResultM_I1,   // 000
       ReadDataM,       // 001
       PCPlus4M_I1,     // 010
       ALUResultM_I1,   // 011
       ALUResultM_I1,   // 100
       32'h0,   // 101 ALUResultM_I1
       32'h0,           // 110 (I1 never does CSR)
       ResultSrcM_I1,
       ResultM_I1
   );


   // ============================================================
   // MEM → WB Pipeline Registers
   // ============================================================


   // I0
   flopr_en #(32) MEM_WB_PCPlus4_I0   (clk, reset, 1'b1, PCPlus4M_I0,        PCPlus4W_I0);
   flopr_en #(32) MEM_WB_ALUResult_I0  (clk, reset, 1'b1, ALUResultM_I0,      ALUResultW_I0);
   flopr_en #(32) MEM_WB_product_I0  (clk, reset, 1'b1, productM_0,      productW_I0);
   flopr_en #(32) MEM_WB_oldCSR_I0     (clk, reset, 1'b1, oldCSRReadDataM_I0, oldCSRReadDataW_I0);
   flopr_en #(32) MEM_WB_newCSR_I0     (clk, reset, 1'b1, newCSRWriteDataM_I0, newCSRWriteDataW_I0);
   flopr_en #(32) MEM_WB_ReadData_I0   (clk, reset, 1'b1, ReadDataM,           ReadDataW_I0);
   flopr_en #(3)  MEM_WB_funct3_I0     (clk, reset, 1'b1, funct3M_I0,         funct3W_I0);
   flopr_en #(5)  MEM_WB_Rd_I0         (clk, reset, 1'b1, RdM_I0,             RdW_I0);
   flopr_en #(12) MEM_WB_CSRAddr_I0    (clk, reset, 1'b1, CSRAddrM_I0,        CSRAddrW_I0);
   flopr_en #(32) MEM_WB_ALUForAddr_I0 (clk, reset, 1'b1, ALUResultM_I0,      ALUResultForAddrW_I0);
   flopr_en #(1)  MEM_WB_RegWrite_I0   (clk, reset, 1'b1, RegWriteM_I0,       RegWriteW_I0);
   flopr_en #(1)  MEM_WB_CSRWrite_I0   (clk, reset, 1'b1, CSRWriteM_I0,       CSRWriteW_I0);
   flopr_en #(3)  MEM_WB_ResultSrc_I0  (clk, reset, 1'b1, ResultSrcM_I0,      ResultSrcW_I0);


   // I1
   flopr_en #(32) MEM_WB_PCPlus4_I1   (clk, reset, 1'b1, PCPlus4M_I1,        PCPlus4W_I1);
   flopr_en #(32) MEM_WB_ALUResult_I1  (clk, reset, 1'b1, ALUResultM_I1,      ALUResultW_I1);
   flopr_en #(32) MEM_WB_product_I1  (clk, reset, 1'b1, productM_1,      productW_I1);
   flopr_en #(32) MEM_WB_ReadData_I1   (clk, reset, 1'b1, ReadDataM,           ReadDataW_I1);
   flopr_en #(3)  MEM_WB_funct3_I1     (clk, reset, 1'b1, funct3M_I1,         funct3W_I1);
   flopr_en #(5)  MEM_WB_Rd_I1         (clk, reset, 1'b1, RdM_I1,             RdW_I1);
   flopr_en #(32) MEM_WB_ALUForAddr_I1 (clk, reset, 1'b1, ALUResultM_I1,      ALUResultForAddrW_I1);
   flopr_en #(1)  MEM_WB_RegWrite_I1   (clk, reset, 1'b1, RegWriteM_I1,       RegWriteW_I1);
   flopr_en #(3)  MEM_WB_ResultSrc_I1  (clk, reset, 1'b1, ResultSrcM_I1,      ResultSrcW_I1);


   // ============================================================
   // WRITEBACK STAGE
   // LoadUnit placed here (not MEM) to break the ReadData→adjust
   // combinational path off the critical timing cycle.
   // ============================================================


   loadUnit #(32) loadUnit_I0(ReadDataW_I0, ALUResultForAddrW_I0[1:0],
                              funct3W_I0, AdjustedReadDataW_I0);
   loadUnit #(32) loadUnit_I1(ReadDataW_I1, ALUResultForAddrW_I1[1:0],
                              funct3W_I1, AdjustedReadDataW_I1);


   mux7 #(32) Resultmux_I0(
       ALUResultW_I0,        // 000 ALU
       AdjustedReadDataW_I0, // 001 load (byte/hw/word adjusted)
       PCPlus4W_I0,          // 010 return address
       ALUResultW_I0,        // 011 LUI
       ALUResultW_I0,        // 100 AUIPC
       productW_I0,        // 101
       oldCSRReadDataW_I0,   // 110 CSR read value
       ResultSrcW_I0,
       ResultW_I0
   );


   mux7 #(32) Resultmux_I1(
       ALUResultW_I1,        // 000
       AdjustedReadDataW_I1, // 001
       PCPlus4W_I1,          // 010
       ALUResultW_I1,        // 011
       ALUResultW_I1,        // 100
       productW_I1,        // 101
       32'h0,                // 110 (I1 has no CSR access)
       ResultSrcW_I1,
       ResultW_I1
   );


   // ============================================================
   // OUTPUTS
   // ============================================================
   assign PC = PCF;


endmodule
