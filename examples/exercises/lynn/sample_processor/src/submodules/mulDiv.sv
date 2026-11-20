// module mulDiv(
//     input  logic [31:0] a, b,
//     input  logic [2:0]  funct3,
//     output logic [31:0] result
// );

//     logic signed [63:0] product;
//     logic signed [32:0] a_ext, b_ext;

//     always_comb begin
//         // Sign extension based on funct3
//         case(funct3)
//             3'b000, 3'b001: begin  // MUL, MULH - both signed
//                 a_ext = {a[31], a};
//                 b_ext = {b[31], b};
//             end
//             3'b010: begin  // MULHSU - A signed, B unsigned
//                 a_ext = {a[31], a};
//                 b_ext = {1'b0, b};
//             end
//             3'b011: begin  // MULHU - both unsigned
//                 a_ext = {1'b0, a};
//                 b_ext = {1'b0, b};
//             end
//             default: begin
//                 a_ext = {a[31], a};
//                 b_ext = {b[31], b};
//             end
//         endcase

//         // Single multiply
//         product = a_ext * b_ext;

//         // Output selection
//         case(funct3)
//             3'b000: result = product[31:0];   // MUL - lower 32 bits
//             3'b001: result = product[63:32];  // MULH - upper 32 bits
//             3'b010: result = product[63:32];  // MULHSU - upper 32 bits
//             3'b011: result = product[63:32];  // MULHU - upper 32 bits
//             default: result = 32'h0;
//         endcase
//     end

// endmodule
module mulDiv(
        input logic [31:0] SrcAE, SrcBE,
        input logic [2:0] funct3,
        output logic signed [33:0] P0, P1, P2, P3
);


        // logic signed [33:0] P0, P1, P2, P3;
        logic signed [63:0] origProduct;
        logic signed [16:0] AH, AL, BH, BL;

        logic sign;

        logic ALmsb, BLmsb, AHmsb, BHmsb;

        logic [31:0] SrcA, SrcB;


        // Low halves always unsigned (zero-extend to 17 bits)
        assign AL = {1'b0, SrcAE[15:0]};
        assign BL = {1'b0, SrcBE[15:0]};

        // High halves: sign bit only set if this operation treats it as signed
        assign AH = {AHmsb & SrcAE[31], SrcAE[31:16]};
        assign BH = {BHmsb & SrcBE[31], SrcBE[31:16]};

        assign P0 = AH * BH;
        assign P1 = AH * BL;
        assign P2 = AL * BH;
        assign P3 = AL * BL;


        always_comb begin
            case (funct3)
                3'b011: begin  // MULHU: unsigned × unsigned
                    AHmsb = 1'b0;
                    BHmsb = 1'b0;

                end
                3'b010: begin  // MULHSU: signed × unsigned
                    AHmsb = 1'b1;
                    BHmsb = 1'b0;
                end
                3'b000, 3'b001: begin // MUL, MULH: signed × signed
                    AHmsb = 1'b1;
                    BHmsb = 1'b1;
                end
                default: begin
                    AHmsb = 1'b0;
                    BHmsb = 1'b0;
                end
            endcase
        end

        // // assign origProduct = (P0 << 32) + (P1 << 16) + (P2 << 16) + P3;
        // assign origProduct = ({{32{P0[33]}}, P0} << 32) +
        //                  ({{32{P1[33]}}, P1} << 16) +
        //                  ({{32{P2[33]}}, P2} << 16) +
        //                   {{32{P3[33]}}, P3};

        // always_comb begin
        //     case (ALUFunctb01E)
        //         2'b00: productE = origProduct[31:0]; // MUL {$signed(SrcAE) * $signed(SrcBE)}[31:0];
        //         default:  // MULH, MULHU, MULHSU
        //             begin
        //                 productE = origProduct[63:32]; // productE = ($signed(SrcAE) * $signed(SrcBE)) >>> 32; // origProduct[63:32];
        //             end
        //     endcase
        // end
endmodule
