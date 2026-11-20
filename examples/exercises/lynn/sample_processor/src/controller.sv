// riscvsingle.sv
// RISC-V single-cycle processor
// David_Harris@hmc.edu 2020

`include "parameters.svh"

module controller(input  logic       funct7b5,
        input  logic       funct7b25,
        input  logic [2:0] funct3,
        input  logic [6:0] op,
        output logic [2:0] ResultSrc,
        output logic       MemWrite,
        output logic       Load,
        output logic       ALUSrc,
        output logic       RegWrite, Jump, Branch,
        output logic       CSRWrite,
        output logic [2:0] ImmSrc,
        output logic [3:0] ALUControl
        // output  logic [3:0]   WriteByteEn,
        `ifdef DEBUG
            input   logic [31:0]  insn_debug
        `endif
        );

  logic [1:0] ALUOp;

  // Use named connections to avoid width/order errors
  MainDec md(
      .op(op),
      .funct7b25(funct7b25),
      `ifdef DEBUG
          .insn_debug(insn_debug),
      `endif
      .ResultSrc(ResultSrc),
      .MemWrite(MemWrite),
      .Load(Load),
      .Branch(Branch),
      .ALUSrc(ALUSrc),
      .RegWrite(RegWrite),
      .Jump(Jump),
      .CSRWrite(CSRWrite),
      .ImmSrc(ImmSrc),
      .ALUOp(ALUOp)
  );



  aludec  ad(funct7b5, op[5], funct3, ALUOp, ALUControl);

  // assign PCSrc = (Branch & take_branch) | Jump;
  // assign WriteByteEn = {(4){MemWrite}}; // currently assigns all 4 bytes to MemWrite
endmodule


// module controller(
//         input   logic [6:0]   Op,
//         input   logic         Eq,
//         input   logic [2:0]   Funct3,
//         input   logic         Funct7b5,
//         output  logic         ALUResultSrc,
//         output  logic         ResultSrc,
//         output  logic [3:0]   WriteByteEn,
//         output  logic         PCSrc,
//         output  logic         RegWrite,
//         output  logic [1:0]   ALUSrc, ImmSrc,
//         output  logic [1:0]   ALUControl,
//         output  logic         MemEn
//     `ifdef DEBUG
//         , input   logic [31:0]  insn_debug
//     `endif
//     );

//     logic Branch, Jump;
//     logic Sub, ALUOp;
//     logic MemWrite;
//     logic [11:0] controls;

//     // Main decoder
//     always_comb
//         case(Op)
//             // RegWrite_ImmSrc_ALUSrc_ALUOp_ALUResultSrc_MemWrite_ResultSrc_Branch_Jump_Load
//             7'b0000011: controls = 12'b1_00_01_0_0_0_1_0_0_1; // lw
//             7'b0100011: controls = 12'b0_01_01_0_0_1_0_0_0_1; // sw
//             7'b0110011: controls = 12'b1_xx_00_1_0_0_0_0_0_0; // R-type
//             7'b0010011: controls = 12'b1_00_01_1_0_0_0_0_0_0; // I-type ALU
//             7'b1100011: controls = 12'b0_10_11_0_0_0_0_1_0_0; // beq
//             7'b1101111: controls = 12'b1_11_11_0_1_0_0_0_1_0; // jal
//             default: begin
//                 `ifdef DEBUG
//                     controls = 12'bx_xx_xx_x_x_x_x_x_x_x; // non-implemented instruction
//                     if ((insn_debug !== 'x)) begin
//                         $display("Instruction not implemented: %h", insn_debug);
//                         $finish(-1);
//                     end
//                 `else
//                     controls = 12'b0; // non-implemented instruction
//                 `endif
//             end
//         endcase

//     assign {RegWrite, ImmSrc, ALUSrc, ALUOp, ALUResultSrc, MemWrite,
//         ResultSrc, Branch, Jump, MemEn} = controls;

//     // ALU Control Logic
//     assign Sub = ALUOp & ((Funct3 == 3'b000) & Funct7b5 & Op[5] | (Funct3 == 3'b010)); // subtract or SLT
//     assign ALUControl = {Sub, ALUOp};

//     // PCSrc logic
//     assign PCSrc = Branch & Eq | Jump;

//     // MemWrite logic
//     assign WriteByteEn = {(4){MemWrite}}; // currently assigns all 4 bytes to MemWrite
// endmodule
