// Sadhvi Narayanan

`timescale 1ns/1ps

`include "parameters.svh"

// If DUT_MODULE isn't defined on the vlog command line,
// fall back to a default name.
`define INSTR_BITS 64

`define ELF_BASE_ADR (`XLEN'h8000_0000)
`define IMEM_BASE_ADR (`ELF_BASE_ADR)
`define DMEM_BASE_ADR (`ELF_BASE_ADR)

`define MaxInstrSizeWords 1048576
// 16384
`define MaxDataSizeWords 2097152

`define MTIME_POINTER (`XLEN'h0200bff8)

`define STDOUT (`XLEN'h8000_0001)


module testbench;

  logic clk;
  logic reset;

  // 100 MHz clock: 10 ns period (change as needed)
  initial clk = 0;
  always #5 clk = ~clk;

  // Simple reset sequence
  initial begin
    reset = 1;
    #10;         // hold reset for a bit
    reset = 0;   // release reset
  end

  // Instruction side interface (byte addresses)
  logic [`XLEN-1:0]               PC;
  logic [`INSTR_BITS-1:0]         Instr;   // [63:32]=I0@PC, [31:0]=I1@PC+4

  // Two-word fetch: I0 at PC, I1 at PC+4 (both 32-bit reads, single-cycle)
  logic [`XLEN-1:0]               PC_p4;
  logic [31:0]                    InstrWord_I0, InstrWord_I1;
  assign PC_p4 = PC + `XLEN'd4;
  assign Instr = {InstrWord_I0, InstrWord_I1}; // datapath: [63:32]=I0@PC, [31:0]=I1@PC+4

  // Data side interface (byte addresses)
  logic [`XLEN-1:0]               DataAdr;
  logic [`XLEN-1:0]               ReadData, MemReadData, TestbenchRequestReadData;
  logic [`XLEN-1:0]               WriteData, IMEM_WriteData;
  logic                           WriteEn;
  logic                           MemEn;
  logic [`XLEN/8-1:0]             WriteByteEn;   // byte enables, one per 8 bits

/* ------- DEBUG PRINTS ------- */

  always @(negedge clk) begin
    int i;
    #1;

    if (~reset) begin

      // // ---------- Fetch stage ----------
      // $display("[F ] PC=%h  I0=%h  I1=%h isBranchF_I0=%b PredictedTakenF_I0=%b isBranchF_I1=%b PredictedTakenF_I1=%b, BranchTargetF_I0=%h BranchTargetF_I1=%h",
      //          PC, InstrWord_I0, InstrWord_I1, dut.dp.isBranchF_I0, dut.dp.PredictedTakenF_I0, dut.dp.isBranchF_I1, dut.dp.PredictedTakenF_I1, dut.dp.BranchTargetF_I0, dut.dp.BranchTargetF_I1);

      // // ---------- Issue decision ----------
      // // $display("[D ] I0=%h (PC=%h)  IssueI1=%b  I1=%h (PC=%h)",
      // //          dut.dp.InstrD_I0, dut.dp.PCD_I0, dut.dp.IssueI1,
      // //          dut.dp.InstrD_I1, dut.dp.PCD_I1);

      // // ---------- Pipeline hazards ----------
      // $display("[HZ] StallF=%b StallD=%b StallD_I0_hz=%b StallD_I1_hz=%b FlushD=%b FlushD_ifid=%b FlushE=%b  PCSrcE=%b  Mispredict=%b JALPredictD_I0=%b BranchD_I0=%b PredictedTakenD_I0=%b BranchD_I1=%b PredictedTakenD_I1=%b",
      //          dut.dp.StallF, dut.dp.StallD, dut.dp.StallD_I0_hz, dut.dp.StallD_I1_hz, dut.dp.FlushD, dut.dp.FlushD_ifid, dut.dp.FlushE,
      //          dut.dp.PCSrcE, dut.dp.BranchMispredictE, dut.dp.JALPredictD_I0, dut.dp.BranchD_I0, dut.dp.PredictedTakenD_I0, dut.dp.BranchD_I1, dut.dp.PredictedTakenD_I1);

      // // ---------- Forwarding selects ----------
      // // $display("[FW] I0: FwdA=%b FwdB=%b   I1: FwdA=%b FwdB=%b",
      // //          dut.dp.ForwardAE_I0, dut.dp.ForwardBE_I0,
      // //          dut.dp.ForwardAE_I1, dut.dp.ForwardBE_I1);

      // // ========== PIPELINE STAGE PROPAGATION ==========
      // // Each line shows what one instruction slot holds in that stage.
      // // PC is shown wherever it exists; memory stage keeps only PC+4 (return addr).
      // // FwdA/B: 000=regfile 001=same-W 010=same-M 011=cross-W 100=cross-M

      // // Instruction buffer: 4-entry circular buffer between Fetch and Decode.
      // // WritePtr always +2/cycle; ReadPtr +1 (IssueI1=0) or +2 (IssueI1=1).
      // // WARNING: if IssueI1=0 for 2+ consecutive cycles WritePtr can lap ReadPtr.
      // $display("[BUF] rdPtr=%0d wrPtr=%0d  stale=%b free_slots=%0d, value=%b",
      //          dut.dp.ReadPtr_next, dut.dp.WritePtr, dut.dp.buffer_stale, dut.dp.free_slots, dut.dp.value);
      // $display("[BUF] [0]=%h(pc=%h)  [1]=%h(pc=%h)  [2]=%h(pc=%h)  [3]=%h(pc=%h)",
      //          dut.dp.InstrBuffer[0], dut.dp.PCBuffer[0],
      //          dut.dp.InstrBuffer[1], dut.dp.PCBuffer[1],
      //          dut.dp.InstrBuffer[2], dut.dp.PCBuffer[2],
      //          dut.dp.InstrBuffer[3], dut.dp.PCBuffer[3]);
      // $display("[BUF] ->I0: insn=%h pc=%h   ->I1: insn=%h pc=%h",
      //          dut.dp.InstrToDecodeI0, dut.dp.PCToDecodeI0,
      //          dut.dp.InstrToDecodeI1, dut.dp.PCToDecodeI1);

      // // [F] already printed above (PC, raw instruction words, stall, pcsrc)

      // // [D] already printed above — adding register-file read values, imm, and ResultSrc here:
      // $display("[D2] I0: pc=%h insn=%h  rs1=x%02d(%h) rs2=x%02d(%h) rd=x%02d  immSrc=%b imm=%h  regWr=%b memWr=%b br=%b jmp=%b  resultSrc=%b",
      //          dut.dp.PCD_I0, dut.dp.InstrD_I0,
      //          dut.dp.Rs1D_I0, dut.dp.RD1D_I0, dut.dp.Rs2D_I0, dut.dp.RD2D_I0, dut.dp.RdD_I0,
      //          dut.dp.ImmSrcD_I0, dut.dp.ImmExtD_I0,
      //          dut.dp.RegWriteD_I0, dut.dp.MemWriteD_I0, dut.dp.BranchD_I0, dut.dp.JumpD_I0,
      //          dut.dp.ResultSrcD_I0);
      // $display("[D2] I1: pc=%h insn=%h  rs1=x%02d(%h) rs2=x%02d(%h) rd=x%02d  immSrc=%b imm=%h  regWr=%b memWr=%b br=%b jmp=%b  resultSrc=%b  issue=%b",
      //          dut.dp.PCD_I1, dut.dp.InstrD_I1,
      //          dut.dp.Rs1D_I1, dut.dp.RD1D_I1, dut.dp.Rs2D_I1, dut.dp.RD2D_I1, dut.dp.RdD_I1,
      //          dut.dp.ImmSrcD_I1, dut.dp.ImmExtD_I1,
      //          dut.dp.RegWriteD_I1, dut.dp.MemWriteD_I1, dut.dp.BranchD_I1, dut.dp.JumpD_I1,
      //          dut.dp.ResultSrcD_I1, dut.dp.IssueI1);
      // $display("[D2] JAL: isJALD_I0=%b  jalTarget=%h  jalPredict=%b",
      //          dut.dp.isJALD_I0, dut.dp.JALTargetD_I0, dut.dp.JALPredictD_I0);
      // $display("[ISS] IssueI1=%b  (RAW=%b bothBr=%b predTknBr=%b bothMem=%b I0jmp=%b CSR=%b WAW=%b stallD=%b flushD=%b stale=%b)",
      //          dut.dp.IssueI1,
      //          dut.dp.IntraPairRAW,
      //          dut.dp.BothBranches,
      //          dut.dp.I0_PredictedTakenBranch,
      //          dut.dp.BothMemOps,
      //          dut.dp.I0_IsJump,
      //          dut.dp.AnyCSR,
      //          dut.dp.WAW,
      //          dut.dp.StallD,
      //          dut.dp.FlushD,
      //          dut.dp.buffer_stale);

      // // Execute: post-forwarding ALU inputs/output, branch/jump resolution, ResultSrc
      // $display("[E ] I0: pc=%h rd=x%02d  srcA=%h srcB=%h alu=%h  fwdA=%b fwdB=%b  regWr=%b memWr=%b load=%b  resultSrc=%b",
      //          dut.dp.PCE_I0, dut.dp.RdE_I0,
      //          dut.dp.SrcAE_I0, dut.dp.SrcBE_I0, dut.dp.ALUResultE_I0,
      //          dut.dp.ForwardAE_I0, dut.dp.ForwardBE_I0,
      //          dut.dp.RegWriteE_I0, dut.dp.MemWriteE_I0, dut.dp.LoadE_I0,
      //          dut.dp.ResultSrcE_I0);
      // $display("[E ] I1: pc=%h rd=x%02d  srcA=%h srcB=%h alu=%h  fwdA=%b fwdB=%b  regWr=%b memWr=%b load=%b  resultSrc=%b  pcsrc=%b mispredict=%b BranchE=%b takeBranchE=%b PredictedTakenE=%b",
      //          dut.dp.PCE_I1, dut.dp.RdE_I1,
      //          dut.dp.SrcAE_I1, dut.dp.SrcBE_I1, dut.dp.ALUResultE_I1,
      //          dut.dp.ForwardAE_I1, dut.dp.ForwardBE_I1,
      //          dut.dp.RegWriteE_I1, dut.dp.MemWriteE_I1, dut.dp.LoadE_I1,
      //          dut.dp.ResultSrcE_I1, dut.dp.PCSrcE, dut.dp.BranchMispredictE,
      //          dut.dp.BranchE_branch, dut.dp.take_branchE_branch, dut.dp.PredictedTakenE_branch);

      // // Memory: ALU result is the data address; UseMemI0 shows which lane owns the port; ResultSrc
      // $display("[M ] I0: pc+4=%h rd=x%02d  adr=%h wdata=%h  regWr=%b memWr=%b load=%b  resultSrc=%b  useI0=%b",
      //          dut.dp.PCPlus4M_I0, dut.dp.RdM_I0,
      //          dut.dp.ALUResultM_I0, dut.dp.WriteDataM_I0,
      //          dut.dp.RegWriteM_I0, dut.dp.MemWriteM_I0, dut.dp.LoadM_I0,
      //          dut.dp.ResultSrcM_I0, dut.dp.UseMemI0);
      // $display("[M ] I1: pc+4=%h rd=x%02d  adr=%h wdata=%h  regWr=%b memWr=%b load=%b  resultSrc=%b",
      //          dut.dp.PCPlus4M_I1, dut.dp.RdM_I1,
      //          dut.dp.ALUResultM_I1, dut.dp.WriteDataM_I1,
      //          dut.dp.RegWriteM_I1, dut.dp.MemWriteM_I1, dut.dp.LoadM_I1,
      //          dut.dp.ResultSrcM_I1);
      // $display("[M ] mem: en=%b wrEn=%b  adr=%h wdata=%h rdata=%h byteEn=%b",
      //          MemEn, WriteEn, DataAdr, WriteData, ReadData, WriteByteEn);

      // // Writeback: final result committed to register file, ResultSrc selects which mux output
      // $display("[WB] I0: pc+4=%h rd=x%02d  val=%h  regWr=%b  resultSrc=%b",
      //          dut.dp.PCPlus4W_I0, dut.dp.RdW_I0, dut.dp.ResultW_I0,
      //          dut.dp.RegWriteW_I0, dut.dp.ResultSrcW_I0);
      // $display("[WB] I1: pc+4=%h rd=x%02d  val=%h  regWr=%b  resultSrc=%b \n",
      //          dut.dp.PCPlus4W_I1, dut.dp.RdW_I1, dut.dp.ResultW_I1,
      //          dut.dp.RegWriteW_I1, dut.dp.ResultSrcW_I1);

      // // ---------- Memory access ----------
      // // $display("[M ] MemEn=%b WrEn=%b Addr=%h WrData=%h RdData=%h ByteEn=%b",
      // //          MemEn, WriteEn, DataAdr, WriteData, ReadData, WriteByteEn);

      // // ---------- Writeback (original compact form) ----------
      // // $display("[WB] I0: RegWr=%b rd=x%0d val=%h   I1: RegWr=%b rd=x%0d val=%h",
      // //          dut.dp.RegWriteW_I0, dut.dp.RdW_I0, dut.dp.ResultW_I0,
      // //          dut.dp.RegWriteW_I1, dut.dp.RdW_I1, dut.dp.ResultW_I1);

      // // ---------- Register file snapshot (common regs) ----------
      // // $display("[RF] ra=%h sp=%h gp=%h tp=%h t0=%h t1=%h t2=%h s0=%h",
      // //          dut.dp.RF.rf[1],  dut.dp.RF.rf[2],  dut.dp.RF.rf[3],
      // //          dut.dp.RF.rf[4],  dut.dp.RF.rf[5],  dut.dp.RF.rf[6],
      // //          dut.dp.RF.rf[7],  dut.dp.RF.rf[8]);

      // // ---------- Branch predictor state ----------
      // // $display("[BP] GHR=%b  BranchE=%b TakenE=%b  PHT[0]=%b PHT[1]=%b",
      // //          dut.dp.GHR, dut.dp.BranchTakenE, dut.dp.BranchTakenE,
      // //          dut.dp.PHT[0], dut.dp.PHT[1]);

      // // terminate program as it exited program space
      // // Check I0 only — I1 can legitimately be x at the final instruction.
      // if (InstrWord_I0 === 'x) begin
      //   $display("Instruction data x (PC: %h)", PC);
      //   $finish(-1);
      // end

    end

  end

  /* ------- PROCESSOR Instantiation ------- */

  // Two 32-bit instruction memory banks loaded from the same file.
  // I0: reads instruction at PC.  I1: reads instruction at PC+4.
  // Together they supply the 64-bit Instr word the superscalar datapath needs.
  // I1 has one extra entry so it never fires an out-of-range error on the last instruction.
  ram1p1rwb #(
    .MEMORY_NAME              ("Instruction Memory I0"),
    .ADDRESS_BITS             (`XLEN),
    .DATA_BITS                (32),
    .MEMORY_SIZE_ENTRIES      (`MaxInstrSizeWords),
    .MEMORY_FILE_BASE_ADDRESS (`ELF_BASE_ADR),
    .MEMORY_ADR_OFFSET        (`IMEM_BASE_ADR),
    .MEMFILE_PLUS_ARG         ("MEMFILE")
  ) InstructionMemory_I0 (.clk, .reset, .En(1'b1), .WriteEn(1'b0), .WriteByteEn(4'b0),
                           .MemoryAddress(PC),    .WriteData(IMEM_WriteData), .ReadData(InstrWord_I0));

  ram1p1rwb #(
    .MEMORY_NAME              ("Instruction Memory I1"),
    .ADDRESS_BITS             (`XLEN),
    .DATA_BITS                (32),
    .MEMORY_SIZE_ENTRIES      (`MaxInstrSizeWords + 1),  // +1 avoids out-of-range on last fetch
    .MEMORY_FILE_BASE_ADDRESS (`ELF_BASE_ADR),
    .MEMORY_ADR_OFFSET        (`IMEM_BASE_ADR),
    .MEMFILE_PLUS_ARG         ("MEMFILE")
  ) InstructionMemory_I1 (.clk, .reset, .En(1'b1), .WriteEn(1'b0), .WriteByteEn(4'b0),
                           .MemoryAddress(PC_p4), .WriteData(IMEM_WriteData), .ReadData(InstrWord_I1));

  ram1p1rwb #(
    .MEMORY_NAME              ("Data Memory"),
    .ADDRESS_BITS             (`XLEN),
    .DATA_BITS                (`XLEN),
    .MEMORY_SIZE_ENTRIES      ((`MaxInstrSizeWords + `MaxDataSizeWords)),
    .MEMORY_FILE_BASE_ADDRESS (`ELF_BASE_ADR),
    .MEMORY_ADR_OFFSET        (`DMEM_BASE_ADR),
    .MEMFILE_PLUS_ARG         ("MEMFILE")
  ) DataMemory (.clk, .reset, .En(MemEn & ~TestbenchRequest), .WriteEn, .WriteByteEn, .MemoryAddress(DataAdr), .WriteData, .ReadData(MemReadData));

  assign ReadData = TestbenchRequest ? TestbenchRequestReadData : MemReadData;

  // ------------------------------------------------------------
  // DUT instantiation
  // ------------------------------------------------------------

  `PROCESSOR_TOP dut (
    .clk            (clk),
    .reset          (reset),

    // Instruction memory interface (byte address)
    .PC             (PC),
    .Instr          (Instr),

    // Data memory interface (byte address + strobes)
    .IEUAdr         (DataAdr),
    .ReadData       (ReadData),
    .WriteData      (WriteData),
    .MemEn          (MemEn),
    .WriteEn        (WriteEn),
    .WriteByteEn    (WriteByteEn)
  );

/* ------- TOHOST Handling ------- */

/*
  Host Target Interface (HTIF) semihosting based on 8 byte value at TOHOST label
  0x00000000_00000001: terminate successfully
  0x00000000_xxxxxxx0: terminate with failure code xxxxxxx
  0x01010000_000000ch: writes the byte ch to the console as ASCII
*/

logic [`XLEN-1:0] TO_HOST_ADR;
logic [31:0] tohost_lo, tohost_hi, payload;

always @(negedge clk) begin
  byte ch;

  #1;
  `ifdef XLEN32
  tohost_lo = DataMemory.Memory[(TO_HOST_ADR-`DMEM_BASE_ADR)>>2];
  tohost_hi = DataMemory.Memory[((TO_HOST_ADR-`DMEM_BASE_ADR)>>2) + 1];
  `endif
  `ifdef XLEN64
  {tohost_hi, tohost_lo} = DataMemory.Memory[(TO_HOST_ADR-`DMEM_BASE_ADR)>>2];
  `endif

  //$display("TOHOST DATA: %h%h, Addr %h, base %h", tohost_hi, tohost_lo, TO_HOST_ADR, `DMEM_BASE_ADR);

  if (MemEn && WriteEn && DataAdr == TO_HOST_ADR`ifdef XLEN32 + 4`endif) begin
    payload = tohost_lo;
    if (tohost_hi == 32'h0 & payload[0]) begin

      if (~(|(payload >> 1))) begin
        $display("INFO: Test Completed!");
      end else begin
        $display("ERROR: Test Failed (code=%d)", (payload >> 1));
      end

      $display("[%0t] INFO: Program Finished! Ending simulation.", $time);
      $finish;

    // Check top bits for "print char" command
    end else if (tohost_hi == 32'h01010000) begin
      ch = tohost_lo[7:0];
      $write("%c", ch);
      if (ch == "\n") $fflush(`STDOUT);
    end

    // clear tohost to be 0
    DataMemory.Memory[(TO_HOST_ADR-`DMEM_BASE_ADR)>>2] = '0;
    `ifdef XLEN32
    DataMemory.Memory[((TO_HOST_ADR-`DMEM_BASE_ADR)>>2) + 1] = '0;
    `endif
  end
end

initial begin

    TO_HOST_ADR = '0; // default
    void'($value$plusargs("TOHOST_ADDR=%h", TO_HOST_ADR)); // override if provided
    $display("[TB] TOHOST_ADDR = 0x%h", TO_HOST_ADR);

    // Wait until reset deasserts
    @(negedge reset);
    $display("[%0t] INFO: Starting simulation.", $time);

end

/* ------- Safety jump-to-self exit ------- */

logic[3:0]       jump_to_self_count;

always_ff @(posedge clk) begin
  if (reset)                                                                       jump_to_self_count <= '0;
  else if (InstrWord_I0 == 32'h0000006f || InstrWord_I1 == 32'h0000006f) jump_to_self_count <= jump_to_self_count + 1;
end

always @(negedge clk) begin
  if (!reset && ((&jump_to_self_count))) begin
      $display("ERROR: Program stuck in infinite loop at address %h", PC);
      $finish(-1);
  end
end

/* ------- MTIME DATA REQUEST ------- */

assign TestbenchRequest = (DataAdr == `MTIME_POINTER) | (DataAdr == `MTIME_POINTER + 4);

logic [63:0] cycle_count;

always_ff @(posedge clk) begin
  if (reset) cycle_count <= 0;
  else       cycle_count <= cycle_count + 1;
end

// Only respond to mtime reads
always_ff @(negedge clk) begin
  TestbenchRequestReadData = 'x;
  if (TestbenchRequest && MemEn && !WriteEn) begin
    if (DataAdr == `MTIME_POINTER)      TestbenchRequestReadData = cycle_count[31:0];
    if (DataAdr == `MTIME_POINTER + 4)  TestbenchRequestReadData = cycle_count[63:32];
  end
end


endmodule
