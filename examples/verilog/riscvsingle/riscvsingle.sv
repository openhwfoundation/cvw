///////////////////////////////////////////
// riscvsingle.sv
//
// Written: David_Harris@hmc.edu 9 January 2021
// Modified:
//
// Purpose: Simplified Single Cycle RISC-V Processor
//          Adapted from DDCA RISC-V Edition
//          Modified to match partitioning in RISC-V SoC Design
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////


// run 210
// Expect simulator to print "Simulation succeeded"
// when the value 25 (0x19) is written to address 100 (0x64)

// Single-cycle implementation of RISC-V (RV32I)
// User-level Instruction Set Architecture V2.2
// Implements a subset of the base integer instructions:
//    lw, sw
//    add, sub, and, or, slt
//    addi, andi, ori, slti
//    beq
//    jal
// Exceptions, traps, and interrupts not implemented
// little-endian memory

// 31 32-bit registers x1-x31, x0 hardwired to 0
// R-Type instructions
//   add, sub, and, or, slt
//   INSTR rd, rs1, rs2
//   Instr[31:25] = funct7 (funct7b5 & opb5 = 1 for sub, 0 for others)
//   Instr[24:20] = rs2
//   Instr[19:15] = rs1
//   Instr[14:12] = funct3
//   Instr[11:7]  = rd
//   Instr[6:0]   = opcode
// I-Type Instructions
//   lw, I-type ALU (addi, andi, ori, slti)
//   lw:         INSTR rd, imm(rs1)
//   I-type ALU: INSTR rd, rs1, imm (12-bit signed)
//   Instr[31:20] = imm[11:0]
//   Instr[24:20] = rs2
//   Instr[19:15] = rs1
//   Instr[14:12] = funct3
//   Instr[11:7]  = rd
//   Instr[6:0]   = opcode
// S-Type Instruction
//   sw rs2, imm(rs1) (store rs2 into address specified by rs1 + immm)
//   Instr[31:25] = imm[11:5] (offset[11:5])
//   Instr[24:20] = rs2 (src)
//   Instr[19:15] = rs1 (base)
//   Instr[14:12] = funct3
//   Instr[11:7]  = imm[4:0]  (offset[4:0])
//   Instr[6:0]   = opcode
// B-Type Instruction
//   beq rs1, rs2, imm (PCTarget = PC + (signed imm x 2))
//   Instr[31:25] = imm[12], imm[10:5]
//   Instr[24:20] = rs2
//   Instr[19:15] = rs1
//   Instr[14:12] = funct3
//   Instr[11:7]  = imm[4:1], imm[11]
//   Instr[6:0]   = opcode
// J-Type Instruction
//   jal rd, imm  (signed imm is multiplied by 2 and added to PC, rd = PC+4)
//   Instr[31:12] = imm[20], imm[10:1], imm[11], imm[19:12]
//   Instr[11:7]  = rd
//   Instr[6:0]   = opcode

//   Instruction  opcode    funct3    funct7
//   add          0110011   000       0000000
//   sub          0110011   000       0100000
//   and          0110011   111       0000000
//   or           0110011   110       0000000
//   slt          0110011   010       0000000
//   addi         0010011   000       immediate
//   andi         0010011   111       immediate
//   ori          0010011   110       immediate
//   slti         0010011   010       immediate
//   beq          1100011   000       immediate
//   lw           0000011   010       immediate
//   sw           0100011   010       immediate
//   jal          1101111   immediate immediate


/* verilator lint_on UNUSED */

/* verilator lint_off COMBDLY */
/* verilator lint_off INITIALDLY */
/* verilator lint_off STMTDLY */

module testbench();
  logic        clk;
  logic        reset;
  logic [31:0] WriteData, IEUAdr;
  logic        MemWrite;

  // instantiate device to be tested
  riscvsinglecore dut(clk, reset, WriteData, IEUAdr, MemWrite);

  // initialize test
  initial begin
      reset <= 1; # 22; reset <= 0;
  end

  // generate clock to sequence tests
  always begin
      clk <= 1; # 5; clk <= 0; # 5;
  end

  // check results
  always @(negedge clk) begin
      if(MemWrite) begin
        if(IEUAdr === 100 & WriteData === 25) begin
          $display("Simulation succeeded");
          $stop;
        end else if (IEUAdr !== 96) begin
          $display("Simulation failed");
          $stop;
        end
      end
  end
endmodule

module riscvsinglecore(
  input  logic        clk, reset,
  output logic [31:0] WriteData, IEUAdr,
  output logic        MemWrite);

  logic [31:0] PC, PCPlus4, Instr, ReadData;
  logic        PCSrc;

  ifu ifu(.clk, .reset, .PCSrc, .IEUAdr, .Instr, .PC, .PCPlus4);
  ieu ieu(.clk, .reset, .Instr, .PC, .PCPlus4, .PCSrc, .MemWrite, .IEUAdr, .WriteData, .ReadData);
  lsu lsu(.clk, .MemWrite, .IEUAdr, .WriteData, .ReadData);
endmodule

module ifu(
  input  logic        clk, reset,
  input  logic        PCSrc,
  input  logic [31:0] IEUAdr,
  output logic [31:0] Instr, PC, PCPlus4);

  logic [31:0] PCNext;

  // next PC logic
  flopr #(32) pcreg(clk, reset, PCNext, PC);
  adder       pcadd4(PC, 32'd4, PCPlus4);
  mux2 #(32)  pcmux(PCPlus4, IEUAdr, PCSrc, PCNext);
  irom        irom(PC, Instr);
endmodule

module irom(input  logic [31:0] a,
            output logic [31:0] rd);

  logic [31:0] RAM[63:0];

  initial
      $readmemh("riscvtest.memfile",RAM);

  assign rd = RAM[a[7:2]]; // word aligned
endmodule

module ieu(
  input  logic        clk, reset,
  input  logic [31:0] Instr,
  input  logic [31:0] PC, PCPlus4,
  output logic        PCSrc, MemWrite,
  output logic [31:0] IEUAdr, WriteData,
  input  logic [31:0] ReadData);

  logic       RegWrite, Jump, Eq, ALUResultSrc, ResultSrc;
  logic [1:0] ALUSrc, ImmSrc;
  logic [1:0] ALUControl;

  controller c(.Op(Instr[6:0]), .Funct3(Instr[14:12]), .Funct7b5(Instr[30]), .Eq,
               .ALUResultSrc, .ResultSrc, .MemWrite, .PCSrc,
               .ALUSrc, .RegWrite, .ImmSrc, .ALUControl);
  datapath dp(.clk, .reset, .Funct3(Instr[14:12]),
              .ALUResultSrc, .ResultSrc, .ALUSrc, .RegWrite, .ImmSrc, .ALUControl, .Eq,
              .PC, .PCPlus4, .Instr, .IEUAdr, .WriteData, .ReadData);
endmodule

module controller(
  input  logic [6:0] Op,
  input  logic       Eq,
  input  logic [2:0] Funct3,
  input  logic       Funct7b5,
  output logic       ALUResultSrc,
  output logic       ResultSrc,
  output logic       MemWrite,
  output logic       PCSrc,
  output logic       RegWrite,
  output logic [1:0] ALUSrc, ImmSrc,
  output logic [1:0] ALUControl);

  logic       Branch, Jump;
  logic       Sub, ALUOp;

  logic [10:0] controls;

  // Main decoder
  always_comb
    case(Op)
    // RegWrite_ImmSrc_ALUSrc_ALUOp_ALUResultSrc_MemWrite_ResultSrc_Branch_Jump
      7'b0000011: controls = 11'b1_00_01_0_0_0_1_0_0; // lw
      7'b0100011: controls = 11'b0_01_01_0_0_1_0_0_0; // sw
      7'b0110011: controls = 11'b1_xx_00_1_0_0_0_0_0; // R-type
      7'b0010011: controls = 11'b1_00_01_1_0_0_0_0_0; // I-type ALU
      7'b1100011: controls = 11'b0_10_11_0_0_0_0_1_0; // beq
      7'b1101111: controls = 11'b1_11_11_0_1_0_0_0_1; // jal
      default:    controls = 11'bx_xx_xx_x_x_x_x_x_x; // non-implemented instruction
    endcase

  assign {RegWrite, ImmSrc, ALUSrc, ALUOp, ALUResultSrc, MemWrite,
          ResultSrc, Branch, Jump} = controls;

  // ALU Control Logic
  assign Sub = ALUOp & ((Funct3 == 3'b000) & Funct7b5 & Op[5] | (Funct3 == 3'b010));  // subtract or SLT
  assign ALUControl = {Sub, ALUOp};

  // PCSrc logic
  assign PCSrc = Branch & Eq | Jump;
endmodule

module datapath(
  input  logic        clk, reset,
  input  logic [2:0]  Funct3,
  input  logic        ALUResultSrc, ResultSrc,
  input  logic [1:0]  ALUSrc,
  input  logic        RegWrite,
  input  logic [1:0]  ImmSrc,
  input  logic [1:0]  ALUControl,
  output logic        Eq,
  input  logic [31:0] PC, PCPlus4,
  input  logic [31:0] Instr,
  output logic [31:0] IEUAdr, WriteData,
  input  logic [31:0] ReadData);

  logic [31:0] ImmExt;
  logic [31:0] R1, R2, SrcA, SrcB;
  logic [31:0] ALUResult, IEUResult, Result;

  // register file logic
  regfile     rf(.clk, .WE3(RegWrite), .A1(Instr[19:15]), .A2(Instr[24:20]),
                 .A3(Instr[11:7]), .WD3(Result), .RD1(R1), .RD2(R2));
  extend      ext(.Instr(Instr[31:7]), .ImmSrc, .ImmExt);

  // ALU logic
  cmp         cmp(.R1, .R2, .Eq);
  mux2 #(32)  srcamux(R1, PC, ALUSrc[1], SrcA);
  mux2 #(32)  srcbmux(R2, ImmExt, ALUSrc[0], SrcB);
  alu         alu(.SrcA, .SrcB, .ALUControl, .Funct3, .ALUResult, .IEUAdr);
  mux2 #(32)  ieuresultmux(ALUResult, PCPlus4, ALUResultSrc, IEUResult);
  mux2 #(32)  resultmux(IEUResult, ReadData, ResultSrc, Result);
  assign WriteData = R2;
endmodule

module regfile(
  input  logic        clk,
  input  logic        WE3,
  input  logic [ 4:0] A1, A2, A3,
  input  logic [31:0] WD3,
  output logic [31:0] RD1, RD2);

  logic [31:0] rf[31:1];

  // three ported register file
  // read two ports combinationally (A1/RD1, A2/RD2)
  // write third port on rising edge of clock (A3/WD3/WE3)
  // register 0 hardwired to 0

  always_ff @(posedge clk)
    if (WE3) rf[A3] <= WD3;

  assign RD1 = (A1 != 0) ? rf[A1] : 0;
  assign RD2 = (A2 != 0) ? rf[A2] : 0;
endmodule

module extend(
  input  logic [31:7] Instr,
  input  logic [1:0]  ImmSrc,
  output logic [31:0] ImmExt);

  always_comb
    case(ImmSrc)
               // I-type
      2'b00:   ImmExt = {{20{Instr[31]}}, Instr[31:20]};
               // S-type (stores)
      2'b01:   ImmExt = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]};
               // B-type (branches)
      2'b10:   ImmExt = {{20{Instr[31]}}, Instr[7], Instr[30:25], Instr[11:8], 1'b0};
               // J-type (jal)
      2'b11:   ImmExt = {{12{Instr[31]}}, Instr[19:12], Instr[20], Instr[30:21], 1'b0};
      default: ImmExt = 32'bx; // undefined
    endcase
endmodule

module cmp(
  input  logic [31:0] R1, R2,
  output logic        Eq
);

   assign Eq = (R1 == R2);
endmodule


module alu(
  input  logic [31:0] SrcA, SrcB,
  input  logic [1:0]  ALUControl,
  input  logic [2:0]  Funct3,
  output logic [31:0] ALUResult, IEUAdr);

  logic [31:0] CondInvb, Sum, SLT;
  logic        ALUOp, Sub, Overflow, Neg, LT;
  logic [2:0]  ALUFunct;

  assign {Sub, ALUOp} = ALUControl;

  // Add or subtract
  assign CondInvb = Sub ? ~SrcB : SrcB;
  assign Sum = SrcA + CondInvb + Sub;
  assign IEUAdr = Sum; // Send this out to IFU and LSU

  // Set less than based on subtraction result
  assign Overflow = (SrcA[31] ^ SrcB[31]) & (SrcA[31] ^ Sum[31]);
  assign Neg  = Sum[31];
  assign LT = Neg ^ Overflow;
  assign SLT = {31'b0, LT};

  assign ALUFunct = Funct3 & {3{ALUOp}}; // Force ALUFunct to 0 to Add when ALUOp = 0
  always_comb
    case (ALUFunct)
      3'b000:  ALUResult = Sum;          // add or sub
      3'b010:  ALUResult = SLT;          // slt
      3'b110:  ALUResult = SrcA | SrcB;  // or
      3'b111:  ALUResult = SrcA & SrcB;  // and
      default: ALUResult = 'x;
    endcase
endmodule

module lsu(
  input  logic        clk, MemWrite,
  input  logic [31:0] IEUAdr, WriteData,
  output logic [31:0] ReadData);

  logic [31:0] RAM[63:0];

  assign ReadData = RAM[IEUAdr[7:2]]; // word aligned

  always_ff @(posedge clk)
    if (MemWrite) RAM[IEUAdr[7:2]] <= WriteData;
endmodule

module flopr #(parameter WIDTH = 8) (
  input  logic             clk, reset,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  always_ff @(posedge clk, posedge reset)
    if (reset) q <= 0;
    else       q <= d;
endmodule

module mux2 #(parameter WIDTH = 8) (
  input  logic [WIDTH-1:0] d0, d1,
  input  logic             s,
  output logic [WIDTH-1:0] y);

  assign y = s ? d1 : d0;
endmodule

module adder(input  [31:0] a, b,
             output [31:0] y);

  assign y = a + b;
endmodule
