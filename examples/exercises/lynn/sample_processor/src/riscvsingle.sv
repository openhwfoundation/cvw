// riscvsingle.sv
// Superscalar in-order 2-wide RISC-V processor top level
// Dual-issue: I0 at PC, I1 at PC+4.
// Controllers see decode-stage instructions (fed back from datapath);
// their output control signals are pipelined by the datapath at the ID→EX boundary.

`include "parameters.svh"

module riscvsingle(
    input  logic        clk,
    input  logic        reset,

    // Instruction memory interface
    output logic [31:0] PC,
    input  logic [63:0] Instr,       // [63:32] = I0@PC, [31:0] = I1@PC+4

    // Data memory interface
    output logic [31:0] IEUAdr,
    input  logic [31:0] ReadData,
    output logic [31:0] WriteData,
    output logic        MemEn,
    output logic        WriteEn,
    output logic [3:0]  WriteByteEn
);

    // Decode-stage instructions (datapath outputs, fed back to controllers)
    logic [31:0] InstrD_I0, InstrD_I1;

    // I0 controller outputs
    logic [2:0]  ResultSrc_I0;
    logic        MemWrite_I0, Load_I0, ALUSrc_I0, RegWrite_I0;
    logic        Jump_I0, Branch_I0, CSRWrite_I0;
    logic [2:0]  ImmSrc_I0;
    logic [3:0]  ALUControl_I0;

    // I1 controller outputs
    logic [2:0]  ResultSrc_I1;
    logic        MemWrite_I1, Load_I1, ALUSrc_I1, RegWrite_I1;
    logic        Jump_I1, Branch_I1, CSRWrite_I1;
    logic [2:0]  ImmSrc_I1;
    logic [3:0]  ALUControl_I1;

    // Datapath memory-stage outputs
    logic [31:0] ALUResultDP, WriteDataDP;
    logic        MemWriteDP, LoadDP;
    logic [2:0]  Funct3DP;

    // ---- Dual controllers ----
    controller c0(
        .funct7b5  (InstrD_I0[30]),
        .funct7b25 (InstrD_I0[25]),
        .funct3    (InstrD_I0[14:12]),
        .op        (InstrD_I0[6:0]),
        .ResultSrc (ResultSrc_I0),
        .MemWrite  (MemWrite_I0),
        .Load      (Load_I0),
        .ALUSrc    (ALUSrc_I0),
        .RegWrite  (RegWrite_I0),
        .Jump      (Jump_I0),
        .Branch    (Branch_I0),
        .CSRWrite  (CSRWrite_I0),
        .ImmSrc    (ImmSrc_I0),
        .ALUControl(ALUControl_I0)
    );

    controller c1(
        .funct7b5  (InstrD_I1[30]),
        .funct7b25 (InstrD_I1[25]),
        .funct3    (InstrD_I1[14:12]),
        .op        (InstrD_I1[6:0]),
        .ResultSrc (ResultSrc_I1),
        .MemWrite  (MemWrite_I1),
        .Load      (Load_I1),
        .ALUSrc    (ALUSrc_I1),
        .RegWrite  (RegWrite_I1),
        .Jump      (Jump_I1),
        .Branch    (Branch_I1),
        .CSRWrite  (CSRWrite_I1),
        .ImmSrc    (ImmSrc_I1),
        .ALUControl(ALUControl_I1)
    );

    // ---- Datapath ----
    datapath dp(
        .clk            (clk),
        .reset          (reset),

        // I0 decode-stage control (pipelined to EX inside datapath)
        .ResultSrcD_I0  (ResultSrc_I0),
        .MemWriteD_I0   (MemWrite_I0),
        .ALUSrcD_I0     (ALUSrc_I0),
        .RegWriteD_I0   (RegWrite_I0),
        .ImmSrcD_I0     (ImmSrc_I0),
        .ALUControlD_I0 ({1'b0, ALUControl_I0}),  // zero-extend 4→5 bits
        .CSRWriteD_I0   (CSRWrite_I0),
        .JumpD_I0       (Jump_I0),
        .BranchD_I0     (Branch_I0),

        // I1 decode-stage control
        .ResultSrcD_I1  (ResultSrc_I1),
        .MemWriteD_I1   (MemWrite_I1),
        .ALUSrcD_I1     (ALUSrc_I1),
        .RegWriteD_I1   (RegWrite_I1),
        .ImmSrcD_I1     (ImmSrc_I1),
        .ALUControlD_I1 ({1'b0, ALUControl_I1}),  // zero-extend 4→5 bits
        .CSRWriteD_I1   (CSRWrite_I1),
        .JumpD_I1       (Jump_I1),
        .BranchD_I1     (Branch_I1),

        // Fetch
        .PC             (PC),
        .Instr          (Instr),

        // Memory interface
        .ALUResult      (ALUResultDP),
        .WriteData      (WriteDataDP),
        .MemWriteOut    (MemWriteDP),
        .LoadOut        (LoadDP),
        .Funct3Out      (Funct3DP),
        .ReadData       (ReadData),

        // Decode-stage instruction feedback to controllers
        .InstrD_I0      (InstrD_I0),
        .InstrD_I1      (InstrD_I1)
    );

    // ---- Store unit: byte/halfword enables ----
    storeUnit su(
        .funct3      (Funct3DP),
        .addr_low    (ALUResultDP[1:0]),
        .MemWrite    (MemWriteDP),
        .WriteByteEn (WriteByteEn),
        .WriteDataIn (WriteDataDP),
        .WriteDataOut(WriteData)
    );

    assign IEUAdr  = ALUResultDP;
    assign MemEn   = MemWriteDP | LoadDP;
    assign WriteEn = MemWriteDP;

endmodule
