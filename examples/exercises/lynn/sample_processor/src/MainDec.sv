module MainDec(input  logic [6:0] op,
               input  logic       funct7b25,
               `ifdef DEBUG
                    input  logic [31:0] insn_debug,
               `endif
               output logic [2:0] ResultSrc,
               output logic       MemWrite,
               output logic       Load,
               output logic       Branch, ALUSrc,
               output logic       RegWrite, Jump,
               output logic       CSRWrite,
               output logic [2:0] ImmSrc,
               output logic [1:0] ALUOp);

  logic [14:0] controls;

  assign {RegWrite, ImmSrc, ALUSrc, MemWrite,
          ResultSrc, Branch, ALUOp, Jump, CSRWrite, Load} = controls;

 always_comb
    casez({op, funct7b25})
    // RegWrite_ImmSrc_ALUSrc_MemWrite_ResultSrc_Branch_ALUOp_Jump_CSRWrite_Load
      8'b0000011_?: controls = 15'b1_000_1_0_001_0_00_0_0_1; // lw
      8'b0100011_?: controls = 15'b0_001_1_1_000_0_00_0_0_0; // sw
      8'b0110011_0: controls = 15'b1_xxx_0_0_000_0_10_0_0_0; // R-type
      8'b1100011_?: controls = 15'b0_010_0_0_000_1_01_0_0_0; // branch type
      8'b0010011_?: controls = 15'b1_000_1_0_000_0_10_0_0_0; // I-type ALU
      8'b1101111_?: controls = 15'b1_011_0_0_010_0_00_1_0_0; // jal
      8'b0110111_?: controls = 15'b1_100_x_0_011_0_00_0_0_0; // lui TODO: check resultsrc
      8'b0010111_?: controls = 15'b1_100_x_0_100_0_xx_0_0_0; // auipc TODO: check
      8'b1100111_?: controls = 15'b1_000_1_0_010_0_00_1_0_0; // jalr TODO: check
      8'b0110011_1: controls = 15'b1_xxx_0_0_101_0_xx_0_0_0; // mul/div TODO: check
      8'b1110011_?: controls = 15'b1_101_x_0_110_0_xx_0_1_0; // csr TODO: check --> with i type csr, then ImmSrc shld account for that
      default: begin
                `ifdef DEBUG
                    controls = 15'bx_xxx_x_x_xxx_x_xx_x_x_x; // non-implemented instruction
                    if ((insn_debug !== 'x)) begin
                        $display("Instruction not implemented: %h", insn_debug);
                        $finish(-1);
                    end
                `else
                    controls = 15'b0; // non-implemented instruction
                `endif
            end
    endcase

endmodule
