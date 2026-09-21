// riscvsingle.sv
// RISC-V single-cycle processor
// David_Harris@hmc.edu 2020

module alu(
        input   logic [31:0]    SrcA, SrcB,
        input   logic [1:0]     ALUControl,
        input   logic [2:0]     Funct3,
        output  logic [31:0]    ALUResult, IEUAdr
    );

    logic [31:0] CondInvb, Sum, SLT;
    logic ALUOp, Sub, Overflow, Neg, LT;
    logic [2:0] ALUFunct;

    assign {Sub, ALUOp} = ALUControl;

    // Add or subtract
    assign CondInvb = Sub ? ~SrcB : SrcB;
    assign Sum = SrcA + CondInvb + {{(31){1'b0}}, Sub};
    assign IEUAdr = Sum; // Send this out to IFU and LSU

    // Set less than based on subtraction result
    assign Overflow = (SrcA[31] ^ SrcB[31]) & (SrcA[31] ^ Sum[31]);
    assign Neg = Sum[31];
    assign LT = Neg ^ Overflow;
    assign SLT = {31'b0, LT};
    assign ALUFunct = Funct3 & {3{ALUOp}}; // Force ALUFunct to 0 to Add when ALUOp = 0

    always_comb begin
        case (ALUFunct)
            3'b000: ALUResult = Sum; // add or sub
            3'b010: ALUResult = SLT; // slt
            3'b110: ALUResult = SrcA | SrcB; // or
            3'b111: ALUResult = SrcA & SrcB; // and
            default: ALUResult = 'x;
        endcase
    end
endmodule
