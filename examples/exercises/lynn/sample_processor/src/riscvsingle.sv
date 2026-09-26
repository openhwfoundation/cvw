// riscvsingle.sv
// RISC-V single-cycle processor
// David_Harris@hmc.edu 2020 kacassidy@hmc.edu 2025

`include "parameters.svh"

module riscvsingle (
        input   logic           clk,
        input   logic           reset,

        output  logic [31:0]    PC,  // instruction memory target address
        input   logic [31:0]    Instr, // instruction memory read data

        output  logic [31:0]    IEUAdr,  // data memory target address
        input   logic [31:0]    ReadData, // data memory read data
        output  logic [31:0]    WriteData, // data memory write data

        output  logic           MemEn,
        output  logic           WriteEn,
        output  logic [3:0]     WriteByteEn  // strobes, 1 hot stating weather a byte should be written on a store
    );

    logic [31:0] PCPlus4;
    logic PCSrc;
    logic Load;

    ifu ifu(.clk, .reset, .PCSrc, .IEUAdr, .PC, .PCPlus4);
    ieu ieu(.clk, .reset, .Instr, .PC, .PCPlus4, .PCSrc, .WriteByteEn,
            .IEUAdr, .WriteData, .ReadData, .MemEn
        );

    assign WriteEn = |WriteByteEn;
endmodule
