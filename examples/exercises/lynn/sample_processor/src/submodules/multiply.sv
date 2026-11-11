// multiply.sv
// RISC-V pipelined processor
// sanarayanan@hmc.edu, sgopalakrishnan@hmc.edu 2026

module multiply(
    input  logic [31:0] SrcAE, SrcBE,
    input  logic [1:0]  ALUFunctb01E,
    output logic signed [17:0] P00, P01, P02, P03,
                               P10, P11, P12, P13,
                               P20, P21, P22, P23,
                               P30, P31, P32, P33
);

    // 9-bit signed chunks: [sign_bit | 8 data bits]
    // A0 = SrcAE[7:0],   A1 = SrcAE[15:8],
    // A2 = SrcAE[23:16], A3 = SrcAE[31:24]  (MSB chunk — signed only when needed)
    // Same layout for B.
    logic signed [8:0] A0, A1, A2, A3;
    logic signed [8:0] B0, B1, B2, B3;

    logic AHmsb, BHmsb;

    // Lower three chunks always zero-extended (unsigned magnitude)
    assign A0 = {1'b0,              SrcAE[7:0]};
    assign A1 = {1'b0,              SrcAE[15:8]};
    assign A2 = {1'b0,              SrcAE[23:16]};
    assign A3 = {AHmsb & SrcAE[31], SrcAE[31:24]};  // MSB chunk: sign only if signed op

    assign B0 = {1'b0,              SrcBE[7:0]};
    assign B1 = {1'b0,              SrcBE[15:8]};
    assign B2 = {1'b0,              SrcBE[23:16]};
    assign B3 = {BHmsb & SrcBE[31], SrcBE[31:24]};  // MSB chunk: sign only if signed op

    // 4x4 grid of 9x9 signed partial products → 18-bit signed results
    // Pij contributes at bit position (i+j)*8 in the final 64-bit product
    assign P00 = A0 * B0;   // shift:  0
    assign P01 = A0 * B1;   // shift:  8
    assign P02 = A0 * B2;   // shift: 16
    assign P03 = A0 * B3;   // shift: 24

    assign P10 = A1 * B0;   // shift:  8
    assign P11 = A1 * B1;   // shift: 16
    assign P12 = A1 * B2;   // shift: 24
    assign P13 = A1 * B3;   // shift: 32

    assign P20 = A2 * B0;   // shift: 16
    assign P21 = A2 * B1;   // shift: 24
    assign P22 = A2 * B2;   // shift: 32
    assign P23 = A2 * B3;   // shift: 40

    assign P30 = A3 * B0;   // shift: 24
    assign P31 = A3 * B1;   // shift: 32
    assign P32 = A3 * B2;   // shift: 40
    assign P33 = A3 * B3;   // shift: 48

    always_comb begin
        case (ALUFunctb01E)
            2'b11: begin   // MULHU: unsigned x unsigned
                AHmsb = 1'b0;
                BHmsb = 1'b0;
            end
            2'b10: begin   // MULHSU: signed x unsigned
                AHmsb = 1'b1;
                BHmsb = 1'b0;
            end
            default: begin // MUL, MULH: signed x signed
                AHmsb = 1'b1;
                BHmsb = 1'b1;
            end
        endcase
    end

endmodule
