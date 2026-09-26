// riscvsingle.sv
// RISC-V single-cycle processor
// David_Harris@hmc.edu 2020

`include "parameters.svh"

module ieu(
        input   logic           clk, reset,
        input   logic [31:0]    Instr,
        input   logic [31:0]    PC, PCPlus4,
        output  logic           PCSrc,
        output  logic [3:0]     WriteByteEn,
        output  logic [31:0]    IEUAdr, WriteData,
        input   logic [31:0]    ReadData,
        output  logic           MemEn
    );

    logic RegWrite, Jump, Eq, ALUResultSrc, ResultSrc;
    logic [1:0] ALUSrc, ImmSrc;
    logic [1:0] ALUControl;

    controller c(.Op(Instr[6:0]), .Funct3(Instr[14:12]), .Funct7b5(Instr[30]), .Eq,
        .ALUResultSrc, .ResultSrc, .WriteByteEn, .PCSrc,
        .ALUSrc, .RegWrite, .ImmSrc, .ALUControl, .MemEn
    `ifdef DEBUG
        , .insn_debug(Instr)
    `endif
    );

    datapath dp(.clk, .reset, .Funct3(Instr[14:12]),
        .ALUResultSrc, .ResultSrc, .ALUSrc, .RegWrite, .ImmSrc, .ALUControl, .Eq,
        .PC, .PCPlus4, .Instr, .IEUAdr, .WriteData, .ReadData);
endmodule
