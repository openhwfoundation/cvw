// cvw_ppa.sv
// Teo Ene & David_Harris@hmc.edu 11 May 2022
// & mmasserfrye@hmc.edu
// Measure PPA of various building blocks

module cvw_ppa_comparator_8 #(parameter WIDTH=8) (
  input  logic [WIDTH-1:0] a, b,
  input  logic             sgnd,
  output logic [1:0]       flags);

  cvw_ppa_comparator #(WIDTH) comp (.*);
endmodule

module cvw_ppa_comparator_16 #(parameter WIDTH=16) (
  input  logic [WIDTH-1:0] a, b,
  input  logic             sgnd,
  output logic [1:0]       flags);

  cvw_ppa_comparator #(WIDTH) comp (.*);
endmodule

module cvw_ppa_comparator_32 #(parameter WIDTH=32) (
  input  logic [WIDTH-1:0] a, b,
  input  logic             sgnd,
  output logic [1:0]       flags);

  cvw_ppa_comparator #(WIDTH) comp (.*);
endmodule

module cvw_ppa_comparator_64 #(parameter WIDTH=64) (
  input  logic [WIDTH-1:0] a, b,
  input  logic             sgnd,
  output logic [1:0]       flags);

  cvw_ppa_comparator #(WIDTH) comp (.*);
endmodule

module cvw_ppa_comparator_128 #(parameter WIDTH=128) (
  input  logic [WIDTH-1:0] a, b,
  input  logic             sgnd,
  output logic [1:0]       flags);

  cvw_ppa_comparator #(WIDTH) comp (.*);
endmodule

module cvw_ppa_comparator #(parameter WIDTH=16) (
  input  logic [WIDTH-1:0] a, b,
  input  logic             sgnd,
  output logic [1:0]       flags);

  logic eq, lt, ltu;
  logic [WIDTH-1:0] af, bf;

  // For signed numbers, flip most significant bit
  assign af = {a[WIDTH-1] ^ sgnd, a[WIDTH-2:0]};
  assign bf = {b[WIDTH-1] ^ sgnd, b[WIDTH-2:0]};

  // behavioral description gives best results
  assign eq = (af == bf);
  assign lt = (af < bf);
  assign flags = {eq, lt};
endmodule

module cvw_ppa_add_8 #(parameter WIDTH=8) (
    input logic [WIDTH-1:0] a, b,
    output logic [WIDTH-1:0] y);

   assign y = a + b;
endmodule

module cvw_ppa_add_16 #(parameter WIDTH=16) (
    input logic [WIDTH-1:0] a, b,
    output logic [WIDTH-1:0] y);

   assign y = a + b;
endmodule

module cvw_ppa_add_32 #(parameter WIDTH=32) (
    input logic [WIDTH-1:0] a, b,
    output logic [WIDTH-1:0] y);

   assign y = a + b;
endmodule

module cvw_ppa_add_64 #(parameter WIDTH=64) (
    input logic [WIDTH-1:0] a, b,
    output logic [WIDTH-1:0] y);

   assign y = a + b;
endmodule

module cvw_ppa_add_128 #(parameter WIDTH=128) (
    input logic [WIDTH-1:0] a, b,
    output logic [WIDTH-1:0] y);

   assign y = a + b;
endmodule

module cvw_ppa_mult_8 #(parameter WIDTH=8) (
  input logic [WIDTH-1:0] a, b,
  output logic [WIDTH*2-1:0] y); //is this right width
  assign y = a * b;
endmodule

module cvw_ppa_mult_16 #(parameter WIDTH=16) (
  input logic [WIDTH-1:0] a, b,
  output logic [WIDTH*2-1:0] y); //is this right width
  assign y = a * b;
endmodule

module cvw_ppa_mult_32 #(parameter WIDTH=32) (
  input logic [WIDTH-1:0] a, b,
  output logic [WIDTH*2-1:0] y); //is this right width
  assign y = a * b;
endmodule

module cvw_ppa_mult_64 #(parameter WIDTH=64) (
  input logic [WIDTH-1:0] a, b,
  output logic [WIDTH*2-1:0] y); //is this right width
  assign y = a * b;
endmodule

module cvw_ppa_mult_128 #(parameter WIDTH=128) (
  input logic [WIDTH-1:0] a, b,
  output logic [WIDTH*2-1:0] y); //is this right width
  assign y = a * b;
endmodule

module cvw_ppa_alu_8 #(parameter WIDTH=8) (
  input  logic [WIDTH-1:0] A, B,
  input  logic [2:0]       ALUControl,
  input  logic [2:0]       Funct3,
  output logic [WIDTH-1:0] Result,
  output logic [WIDTH-1:0] Sum);

  cvw_ppa_alu #(WIDTH) alu (.*);
endmodule

module cvw_ppa_alu_16 #(parameter WIDTH=16) (
  input  logic [WIDTH-1:0] A, B,
  input  logic [2:0]       ALUControl,
  input  logic [2:0]       Funct3,
  output logic [WIDTH-1:0] Result,
  output logic [WIDTH-1:0] Sum);

  cvw_ppa_alu #(WIDTH) alu (.*);
endmodule

module cvw_ppa_alu_32 #(parameter WIDTH=32) (
  input  logic [WIDTH-1:0] A, B,
  input  logic [2:0]       ALUControl,
  input  logic [2:0]       Funct3,
  output logic [WIDTH-1:0] Result,
  output logic [WIDTH-1:0] Sum);

  cvw_ppa_alu #(WIDTH) alu (.*);
endmodule

module cvw_ppa_alu_64 #(parameter WIDTH=64) (
  input  logic [WIDTH-1:0] A, B,
  input  logic [2:0]       ALUControl,
  input  logic [2:0]       Funct3,
  output logic [WIDTH-1:0] Result,
  output logic [WIDTH-1:0] Sum);

  cvw_ppa_alu #(WIDTH) alu (.*);
endmodule

module cvw_ppa_alu_128 #(parameter WIDTH=128) (
  input  logic [WIDTH-1:0] A, B,
  input  logic [2:0]       ALUControl,
  input  logic [2:0]       Funct3,
  output logic [WIDTH-1:0] Result,
  output logic [WIDTH-1:0] Sum);

  cvw_ppa_alu #(WIDTH) alu (.*);
endmodule

module cvw_ppa_alu #(parameter WIDTH=32) (
  input  logic [WIDTH-1:0] A, B,
  input  logic [2:0]       ALUControl,
  input  logic [2:0]       Funct3,
  output logic [WIDTH-1:0] Result,
  output logic [WIDTH-1:0] Sum);

  logic [WIDTH-1:0] CondInvB, Shift, SLT, SLTU, FullResult;
  logic        Carry, Neg;
  logic        LT, LTU;
  logic        W64, SubArith, ALUOp;
  logic [2:0]  ALUFunct;
  logic        Asign, Bsign;

  // Extract control signals
  // W64 indicates RV64 W-suffix instructions acting on lower 32-bit word
  // SubArith indicates subtraction
  // ALUOp = 0 for address generation addition or 1 for regular ALU
  assign {W64, SubArith, ALUOp} = ALUControl;

  // addition
  assign CondInvB = SubArith ? ~B : B;
  assign {Carry, Sum} = A + CondInvB + {{(WIDTH-1){1'b0}}, SubArith};

  // Shifts
  cvw_ppa_shifter #(WIDTH) sh(.A, .Amt(B[$clog2(WIDTH)-1:0]), .Right(Funct3[2]), .Arith(SubArith), .W64, .Y(Shift));

  // condition code flags based on subtract output Sum = A-B
  // Overflow occurs when the numbers being subtracted have the opposite sign
  // and the result has the opposite sign of A
  assign Neg  = Sum[WIDTH-1];
  assign Asign = A[WIDTH-1];
  assign Bsign = B[WIDTH-1];
  assign LT = Asign & ~Bsign | Asign & Neg | ~Bsign & Neg; // simplified from Overflow = Asign & Bsign & Asign & Neg; LT = Neg ^ Overflow
  assign LTU = ~Carry;

  // SLT
  assign SLT = {{(WIDTH-1){1'b0}}, LT};
  assign SLTU = {{(WIDTH-1){1'b0}}, LTU};

  // Select appropriate ALU Result
  assign ALUFunct = Funct3 & {3{ALUOp}}; // Force ALUFunct to 0 to Add when ALUOp = 0
  always_comb
    casez (ALUFunct)
      3'b000: FullResult = Sum;       // add or sub
      3'b?01: FullResult = Shift;     // sll, sra, or srl
      3'b010: FullResult = SLT;       // slt
      3'b011: FullResult = SLTU;      // sltu
      3'b100: FullResult = A ^ B;     // xor
      3'b110: FullResult = A | B;     // or
      3'b111: FullResult = A & B;     // and
    endcase

  assign Result = FullResult;
  // not using W64 so it has the same architecture regardless of width
  // // support W-type RV64I ADDW/SUBW/ADDIW/Shifts that sign-extend 32-bit result to 64 bits
  // if (WIDTH==64)  assign Result = W64 ? {{32{FullResult[31]}}, FullResult[31:0]} : FullResult;
  // else            assign Result = FullResult;
endmodule

module cvw_ppa_shiftleft_8 #(parameter WIDTH=8) (
  input logic [WIDTH-1:0] a,
  input logic [$clog2(WIDTH)-1:0] amt,
  output logic [WIDTH-1:0] y);

  assign y = a << amt;
endmodule

module cvw_ppa_shiftleft_16 #(parameter WIDTH=16) (
  input logic [WIDTH-1:0] a,
  input logic [$clog2(WIDTH)-1:0] amt,
  output logic [WIDTH-1:0] y);

  assign y = a << amt;
endmodule

module cvw_ppa_shiftleft_32 #(parameter WIDTH=32) (
  input logic [WIDTH-1:0] a,
  input logic [$clog2(WIDTH)-1:0] amt,
  output logic [WIDTH-1:0] y);

  assign y = a << amt;
endmodule

module cvw_ppa_shiftleft_64 #(parameter WIDTH=64) (
  input logic [WIDTH-1:0] a,
  input logic [$clog2(WIDTH)-1:0] amt,
  output logic [WIDTH-1:0] y);

  assign y = a << amt;
endmodule

module cvw_ppa_shiftleft_128 #(parameter WIDTH=128) (
  input logic [WIDTH-1:0] a,
  input logic [$clog2(WIDTH)-1:0] amt,
  output logic [WIDTH-1:0] y);

  assign y = a << amt;
endmodule

module cvw_ppa_shifter #(parameter WIDTH=32) (
  input  logic [WIDTH-1:0]     A,
  input  logic [$clog2(WIDTH)-1:0] Amt,
  input  logic                 Right, Arith, W64,
  output logic [WIDTH-1:0]     Y);

  logic [2*WIDTH-2:0]      z, zshift;
  logic [$clog2(WIDTH)-1:0]    amttrunc, offset;

  // Handle left and right shifts with a funnel shifter.
  // For RV32, only 32-bit shifts are needed.
  // For RV64, 32 and 64-bit shifts are needed, with sign extension.

  // funnel shifter input (see CMOS VLSI Design 4e Section 11.8.1, note Table 11.11 shift types wrong)
  // if (WIDTH == 64 | WIDTH ==128) begin:shifter  // RV64 or 128
  //   always_comb  // funnel mux
  //     if (W64) begin // 32-bit shifts
  //       if (Right)
  //         if (Arith) z = {{WIDTH{1'b0}}, {WIDTH/2 -1{A[WIDTH/2 -1]}}, A[WIDTH/2 -1:0]};
  //         else       z = {{WIDTH*3/2-1{1'b0}}, A[WIDTH/2 -1:0]};
  //       else         z = {{WIDTH/2{1'b0}}, A[WIDTH/2 -1:0], {WIDTH-1{1'b0}}};
  //     end else begin
  //       if (Right)
  //         if (Arith) z = {{WIDTH-1{A[WIDTH-1]}}, A};
  //         else       z = {{WIDTH-1{1'b0}}, A};
  //       else         z = {A, {WIDTH-1{1'b0}}};
  //     end
  //     assign amttrunc = W64  ? {1'b0, Amt[$clog2(WIDTH)-2:0]} : Amt; // 32 or 64-bit shift
  // end else begin:shifter // RV32 or less
  //   always_comb  // funnel mux
  //     if (Right)
  //       if (Arith) z = {{WIDTH-1{A[WIDTH-1]}}, A};
  //       else       z = {{WIDTH-1{1'b0}}, A};
  //     else         z = {A, {WIDTH-1{1'b0}}};
  //   assign amttrunc = Amt; // shift amount
  // end

  always_comb  // funnel mux
      if (Right)
        if (Arith) z = {{WIDTH-1{A[WIDTH-1]}}, A};
        else       z = {{WIDTH-1{1'b0}}, A};
      else         z = {A, {WIDTH-1{1'b0}}};
    assign amttrunc = Amt; // shift amount

  // opposite offset for right shifts
  assign offset = Right ? amttrunc : ~amttrunc;

  // funnel operation
  assign zshift = z >> offset;
  assign Y = zshift[WIDTH-1:0];
endmodule

  //   module ppa_shifter_8 #(parameter WIDTH=8) (
  //   input  logic [WIDTH-1:0]     A,
  //   input  logic [$clog2(WIDTH)-1:0] Amt,
  //   input  logic                 Right, Arith, W64,
  //   output logic [WIDTH-1:0]     Y);

  //   ppa_shifter #(WIDTH) sh (.*);
  // endmodule

  // module ppa_shifter_16 #(parameter WIDTH=16) (
  //   input  logic [WIDTH-1:0]     A,
  //   input  logic [$clog2(WIDTH)-1:0] Amt,
  //   input  logic                 Right, Arith, W64,
  //   output logic [WIDTH-1:0]     Y);

  //   ppa_shifter #(WIDTH) sh (.*);
  // endmodule

  // module ppa_shifter_32 #(parameter WIDTH=32) (
  //   input  logic [WIDTH-1:0]     A,
  //   input  logic [$clog2(WIDTH)-1:0] Amt,
  //   input  logic                 Right, Arith, W64,
  //   output logic [WIDTH-1:0]     Y);

  //   ppa_shifter #(WIDTH) sh (.*);
  // endmodule

  // module ppa_shifter_64 #(parameter WIDTH=64) (
  //   input  logic [WIDTH-1:0]     A,
  //   input  logic [$clog2(WIDTH)-1:0] Amt,
  //   input  logic                 Right, Arith, W64,
  //   output logic [WIDTH-1:0]     Y);

  //   ppa_shifter #(WIDTH) sh (.*);
  // endmodule

  // module ppa_shifter_128 #(parameter WIDTH=128) (
  //   input  logic [WIDTH-1:0]     A,
  //   input  logic [$clog2(WIDTH)-1:0] Amt,
  //   input  logic                 Right, Arith, W64,
  //   output logic [WIDTH-1:0]     Y);

  //   ppa_shifter #(WIDTH) sh (.*);
  // endmodule

module cvw_ppa_prioritythermometer #(parameter N = 8) (
  input  logic  [N-1:0] a,
  output logic  [N-1:0] y);

  // Carefully crafted so design compiler will synthesize into a fast tree structure
  //  Rather than linear.

  // create thermometer code mask
  genvar i;
  assign y[0] = ~a[0];
  for (i=1; i<N; i++) begin:therm
    assign y[i] = y[i-1] & ~a[i];
  end
endmodule

module cvw_ppa_priorityonehot #(parameter WIDTH = 8) (
  input  logic  [WIDTH-1:0] a,
  output logic  [WIDTH-1:0] y);
  logic [WIDTH-1:0] nolower;

  // create thermometer code mask
  cvw_ppa_prioritythermometer #(WIDTH) maskgen(.a({a[WIDTH-2:0], 1'b0}), .y(nolower));
  assign y = a & nolower;
endmodule

module cvw_ppa_priorityonehot_8 #(parameter WIDTH = 8) (
  input  logic  [WIDTH-1:0] a,
  output logic  [WIDTH-1:0] y);
  logic [WIDTH-1:0] nolower;

  // create thermometer code mask
  cvw_ppa_priorityonehot #(WIDTH) poh (.*);
endmodule

module cvw_ppa_priorityonehot_16 #(parameter WIDTH = 16) (
  input  logic  [WIDTH-1:0] a,
  output logic  [WIDTH-1:0] y);
  logic [WIDTH-1:0] nolower;

  // create thermometer code mask
  cvw_ppa_priorityonehot #(WIDTH) poh (.*);
endmodule

module cvw_ppa_priorityonehot_32 #(parameter WIDTH = 32) (
  input  logic  [WIDTH-1:0] a,
  output logic  [WIDTH-1:0] y);
  logic [WIDTH-1:0] nolower;

  // create thermometer code mask
  cvw_ppa_priorityonehot #(WIDTH) poh (.*);
endmodule

module cvw_ppa_priorityonehot_64 #(parameter WIDTH = 64) (
  input  logic  [WIDTH-1:0] a,
  output logic  [WIDTH-1:0] y);
  logic [WIDTH-1:0] nolower;

  // create thermometer code mask
  cvw_ppa_priorityonehot #(WIDTH) poh (.*);
endmodule

module cvw_ppa_priorityonehot_128 #(parameter WIDTH = 128) (
  input  logic  [WIDTH-1:0] a,
  output logic  [WIDTH-1:0] y);
  logic [WIDTH-1:0] nolower;

  // create thermometer code mask
  cvw_ppa_priorityonehot #(WIDTH) poh (.*);
endmodule

module cvw_ppa_priorityencoder_8 #(parameter WIDTH = 8) (
  input  logic  [WIDTH-1:0] a,
  output logic  [$clog2(WIDTH)-1:0] y);
  cvw_ppa_priorityencoder #(WIDTH) pe (.*);
endmodule

module cvw_ppa_priorityencoder_16 #(parameter WIDTH = 16) (
  input  logic  [WIDTH-1:0] a,
  output logic  [$clog2(WIDTH)-1:0] y);
  cvw_ppa_priorityencoder #(WIDTH) pe (.*);
endmodule

module cvw_ppa_priorityencoder_32 #(parameter WIDTH = 32) (
  input  logic  [WIDTH-1:0] a,
  output logic  [$clog2(WIDTH)-1:0] y);
  cvw_ppa_priorityencoder #(WIDTH) pe (.*);
endmodule

module cvw_ppa_priorityencoder_64 #(parameter WIDTH = 64) (
  input  logic  [WIDTH-1:0] a,
  output logic  [$clog2(WIDTH)-1:0] y);
  cvw_ppa_priorityencoder #(WIDTH) pe (.*);
endmodule

module cvw_ppa_priorityencoder_128 #(parameter WIDTH = 128) (
  input  logic  [WIDTH-1:0] a,
  output logic  [$clog2(WIDTH)-1:0] y);
  cvw_ppa_priorityencoder #(WIDTH) pe (.*);
endmodule

module cvw_ppa_priorityencoder #(parameter WIDTH = 8) (
  input  logic  [WIDTH-1:0] a,
  output logic  [$clog2(WIDTH)-1:0] y);

  int i;
  always_comb begin
    y = 0;
    for (i=0; i<WIDTH; i++) begin:pri
      if (a[i]) y= i;
    end
  end
endmodule

module cvw_ppa_decoder_8 #(parameter WIDTH = 8) (
  input  logic  [$clog2(WIDTH)-1:0] a,
  output logic  [WIDTH-1:0] y);
  cvw_ppa_decoder #(WIDTH) dec (.*);
endmodule

module cvw_ppa_decoder_16 #(parameter WIDTH = 16) (
  input  logic  [$clog2(WIDTH)-1:0] a,
  output logic  [WIDTH-1:0] y);
  cvw_ppa_decoder #(WIDTH) dec (.*);
endmodule

module cvw_ppa_decoder_32 #(parameter WIDTH = 32) (
  input  logic  [$clog2(WIDTH)-1:0] a,
  output logic  [WIDTH-1:0] y);
  cvw_ppa_decoder #(WIDTH) dec (.*);
endmodule

module cvw_ppa_decoder_64 #(parameter WIDTH = 64) (
  input  logic  [$clog2(WIDTH)-1:0] a,
  output logic  [WIDTH-1:0] y);
  cvw_ppa_decoder #(WIDTH) dec (.*);
endmodule

module cvw_ppa_decoder_128 #(parameter WIDTH = 128) (
  input  logic  [$clog2(WIDTH)-1:0] a,
  output logic  [WIDTH-1:0] y);
  cvw_ppa_decoder #(WIDTH) dec (.*);
endmodule

module cvw_ppa_decoder #(parameter WIDTH = 8) (
  input  logic  [$clog2(WIDTH)-1:0] a,
  output logic  [WIDTH-1:0] y);
  always_comb begin
    y = 0;
    y[a] = 1;
  end
endmodule

module cvw_ppa_mux2d_1 #(parameter WIDTH = 1) (
  input  logic [WIDTH-1:0] d0, d1,
  input  logic             s,
  output logic [WIDTH-1:0] y);

  assign y = s ? d1 : d0;
endmodule

module cvw_ppa_mux4d_1 #(parameter WIDTH = 1) (
  input  logic [WIDTH-1:0] d0, d1, d2, d3,
  input  logic [1:0]       s,
  output logic [WIDTH-1:0] y);

  assign y = s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0);
endmodule

module cvw_ppa_mux8d_1 #(parameter WIDTH = 1) (
  input  logic [WIDTH-1:0] d0, d1, d2, d3, d4, d5, d6, d7,
  input  logic [2:0]       s,
  output logic [WIDTH-1:0] y);

  assign y = s[2] ? (s[1] ? (s[0] ? d5 : d4) : (s[0] ? d6 : d7)) : (s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0));
endmodule

module cvw_ppa_mux2_1 #(parameter WIDTH = 1) (
  input  logic [WIDTH-1:0] d0, d1,
  input  logic             s,
  output logic [WIDTH-1:0] y);

  assign y = s ? d1 : d0;
endmodule

module cvw_ppa_mux4_1 #(parameter WIDTH = 1) (
  input  logic [WIDTH-1:0] d0, d1, d2, d3,
  input  logic [1:0]       s,
  output logic [WIDTH-1:0] y);

  assign y = s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0);
endmodule

module cvw_ppa_mux8_1 #(parameter WIDTH = 1) (
  input  logic [WIDTH-1:0] d0, d1, d2, d3, d4, d5, d6, d7,
  input  logic [2:0]       s,
  output logic [WIDTH-1:0] y);

  assign y = s[2] ? (s[1] ? (s[0] ? d5 : d4) : (s[0] ? d6 : d7)) : (s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0));
endmodule

module cvw_ppa_mux2_8 #(parameter WIDTH = 8) (
  input  logic [WIDTH-1:0] d0, d1,
  input  logic             s,
  output logic [WIDTH-1:0] y);

  assign y = s ? d1 : d0;
endmodule

module cvw_ppa_mux4_8 #(parameter WIDTH = 8) (
  input  logic [WIDTH-1:0] d0, d1, d2, d3,
  input  logic [1:0]       s,
  output logic [WIDTH-1:0] y);

  assign y = s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0);
endmodule

module cvw_ppa_mux8_8 #(parameter WIDTH = 8) (
  input  logic [WIDTH-1:0] d0, d1, d2, d3, d4, d5, d6, d7,
  input  logic [2:0]       s,
  output logic [WIDTH-1:0] y);

  assign y = s[2] ? (s[1] ? (s[0] ? d5 : d4) : (s[0] ? d6 : d7)) : (s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0));
endmodule

module cvw_ppa_mux2_16 #(parameter WIDTH = 16) (
  input  logic [WIDTH-1:0] d0, d1,
  input  logic             s,
  output logic [WIDTH-1:0] y);

  assign y = s ? d1 : d0;
endmodule

module cvw_ppa_mux4_16 #(parameter WIDTH = 16) (
  input  logic [WIDTH-1:0] d0, d1, d2, d3,
  input  logic [1:0]       s,
  output logic [WIDTH-1:0] y);

  assign y = s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0);
endmodule

module cvw_ppa_mux8_16 #(parameter WIDTH = 16) (
  input  logic [WIDTH-1:0] d0, d1, d2, d3, d4, d5, d6, d7,
  input  logic [2:0]       s,
  output logic [WIDTH-1:0] y);

  assign y = s[2] ? (s[1] ? (s[0] ? d5 : d4) : (s[0] ? d6 : d7)) : (s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0));
endmodule

module cvw_ppa_mux2_32 #(parameter WIDTH = 32) (
  input  logic [WIDTH-1:0] d0, d1,
  input  logic             s,
  output logic [WIDTH-1:0] y);

  assign y = s ? d1 : d0;
endmodule

module cvw_ppa_mux4_32 #(parameter WIDTH = 32) (
  input  logic [WIDTH-1:0] d0, d1, d2, d3,
  input  logic [1:0]       s,
  output logic [WIDTH-1:0] y);

  assign y = s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0);
endmodule

module cvw_ppa_mux8_32 #(parameter WIDTH = 32) (
  input  logic [WIDTH-1:0] d0, d1, d2, d3, d4, d5, d6, d7,
  input  logic [2:0]       s,
  output logic [WIDTH-1:0] y);

  assign y = s[2] ? (s[1] ? (s[0] ? d5 : d4) : (s[0] ? d6 : d7)) : (s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0));
endmodule

module cvw_ppa_mux2_64 #(parameter WIDTH = 64) (
  input  logic [WIDTH-1:0] d0, d1,
  input  logic             s,
  output logic [WIDTH-1:0] y);

  assign y = s ? d1 : d0;
endmodule

module cvw_ppa_mux4_64 #(parameter WIDTH = 64) (
  input  logic [WIDTH-1:0] d0, d1, d2, d3,
  input  logic [1:0]       s,
  output logic [WIDTH-1:0] y);

  assign y = s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0);
endmodule

module cvw_ppa_mux8_64 #(parameter WIDTH = 64) (
  input  logic [WIDTH-1:0] d0, d1, d2, d3, d4, d5, d6, d7,
  input  logic [2:0]       s,
  output logic [WIDTH-1:0] y);

  assign y = s[2] ? (s[1] ? (s[0] ? d5 : d4) : (s[0] ? d6 : d7)) : (s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0));
endmodule

module cvw_ppa_mux2_128 #(parameter WIDTH = 128) (
  input  logic [WIDTH-1:0] d0, d1,
  input  logic             s,
  output logic [WIDTH-1:0] y);

  assign y = s ? d1 : d0;
endmodule

module cvw_ppa_mux4_128 #(parameter WIDTH = 128) (
  input  logic [WIDTH-1:0] d0, d1, d2, d3,
  input  logic [1:0]       s,
  output logic [WIDTH-1:0] y);

  assign y = s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0);
endmodule

module cvw_ppa_mux8_128 #(parameter WIDTH = 128) (
  input  logic [WIDTH-1:0] d0, d1, d2, d3, d4, d5, d6, d7,
  input  logic [2:0]       s,
  output logic [WIDTH-1:0] y);

  assign y = s[2] ? (s[1] ? (s[0] ? d5 : d4) : (s[0] ? d6 : d7)) : (s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0));
endmodule

module cvw_ppa_flop #(parameter WIDTH = 8) (
  input  logic             clk,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  always_ff @(posedge clk)
    q <= #1 d;
endmodule

module cvw_ppa_flop_8 #(parameter WIDTH = 8) (
  input  logic             clk,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  logic [WIDTH-1:0] q1;

  cvw_ppa_flop #(WIDTH) f1(clk, d, q1);
  cvw_ppa_flop #(WIDTH) f2(clk, q1, q);
endmodule

module cvw_ppa_flop_16 #(parameter WIDTH = 16) (
  input  logic             clk,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  logic [WIDTH-1:0] q1;

  cvw_ppa_flop #(WIDTH) f1(clk, d, q1);
  cvw_ppa_flop #(WIDTH) f2(clk, q1, q);
endmodule

module cvw_ppa_flop_32 #(parameter WIDTH = 32) (
  input  logic             clk,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  logic [WIDTH-1:0] q1;

  cvw_ppa_flop #(WIDTH) f1(clk, d, q1);
  cvw_ppa_flop #(WIDTH) f2(clk, q1, q);
endmodule

module cvw_ppa_flop_64 #(parameter WIDTH = 64) (
  input  logic             clk,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  logic [WIDTH-1:0] q1;

  cvw_ppa_flop #(WIDTH) f1(clk, d, q1);
  cvw_ppa_flop #(WIDTH) f2(clk, q1, q);
endmodule

module cvw_ppa_flop_128 #(parameter WIDTH = 128) (
  input  logic             clk,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  logic [WIDTH-1:0] q1;

  cvw_ppa_flop #(WIDTH) f1(clk, d, q1);
  cvw_ppa_flop #(WIDTH) f2(clk, q1, q);
endmodule

module cvw_ppa_flopr #(parameter WIDTH = 8) (
  input  logic             clk, reset,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  always_ff @(posedge clk)
    if (reset) q <= #1 0;
    else       q <= #1 d;
endmodule

module cvw_ppa_flopr_8 #(parameter WIDTH = 8) (
  input  logic             clk, reset,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  logic [WIDTH-1:0] q1;

  cvw_ppa_flopr #(WIDTH) f1(clk, reset, d, q1);
  cvw_ppa_flopr #(WIDTH) f2(clk, reset, q1, q);
endmodule

module cvw_ppa_flopr_16 #(parameter WIDTH = 16) (
  input  logic             clk, reset,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  logic [WIDTH-1:0] q1;

  cvw_ppa_flopr #(WIDTH) f1(clk, reset, d, q1);
  cvw_ppa_flopr #(WIDTH) f2(clk, reset, q1, q);
endmodule

module cvw_ppa_flopr_32 #(parameter WIDTH = 32) (
  input  logic             clk, reset,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  logic [WIDTH-1:0] q1;

  cvw_ppa_flopr #(WIDTH) f1(clk, reset, d, q1);
  cvw_ppa_flopr #(WIDTH) f2(clk, reset, q1, q);
endmodule

module cvw_ppa_flopr_64 #(parameter WIDTH = 64) (
  input  logic             clk, reset,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  logic [WIDTH-1:0] q1;

  cvw_ppa_flopr #(WIDTH) f1(clk, reset, d, q1);
  cvw_ppa_flopr #(WIDTH) f2(clk, reset, q1, q);
endmodule

module cvw_ppa_flopr_128 #(parameter WIDTH = 128) (
  input  logic             clk, reset,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  logic [WIDTH-1:0] q1;

  cvw_ppa_flopr #(WIDTH) f1(clk, reset, d, q1);
  cvw_ppa_flopr #(WIDTH) f2(clk, reset, q1, q);
endmodule

module cvw_ppa_floprasync #(parameter WIDTH = 8) (
  input  logic             clk, reset,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  always_ff @(posedge clk or posedge reset)
    if (reset) q <= #1 0;
    else       q <= #1 d;
endmodule

module cvw_ppa_floprasync_8 #(parameter WIDTH = 8) (
  input  logic             clk, reset,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  logic [WIDTH-1:0] q1;

  cvw_ppa_floprasync #(WIDTH) f1(clk, reset, d, q1);
  cvw_ppa_floprasync #(WIDTH) f2(clk, reset, q1, q);
endmodule

module cvw_ppa_floprasync_16 #(parameter WIDTH = 16) (
  input  logic             clk, reset,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  logic [WIDTH-1:0] q1;

  cvw_ppa_floprasync #(WIDTH) f1(clk, reset, d, q1);
  cvw_ppa_floprasync #(WIDTH) f2(clk, reset, q1, q);
endmodule

module cvw_ppa_floprasync_32 #(parameter WIDTH = 32) (
  input  logic             clk, reset,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  logic [WIDTH-1:0] q1;

  cvw_ppa_floprasync #(WIDTH) f1(clk, reset, d, q1);
  cvw_ppa_floprasync #(WIDTH) f2(clk, reset, q1, q);
endmodule

module cvw_ppa_floprasync_64 #(parameter WIDTH = 64) (
  input  logic             clk, reset,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  logic [WIDTH-1:0] q1;

  cvw_ppa_floprasync #(WIDTH) f1(clk, reset, d, q1);
  cvw_ppa_floprasync #(WIDTH) f2(clk, reset, q1, q);
endmodule

module cvw_ppa_floprasync_128 #(parameter WIDTH = 128) (
  input  logic             clk, reset,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  logic [WIDTH-1:0] q1;

  cvw_ppa_floprasync #(WIDTH) f1(clk, reset, d, q1);
  cvw_ppa_floprasync #(WIDTH) f2(clk, reset, q1, q);
endmodule

module cvw_ppa_flopenr #(parameter WIDTH = 8) (
  input  logic             clk, reset, en,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  always_ff @(posedge clk)
    if (reset)   q <= #1 0;
    else if (en) q <= #1 d;
endmodule

module cvw_ppa_flopenr_8 #(parameter WIDTH = 8) (
  input  logic             clk, reset, en,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  logic [WIDTH-1:0] q1;

  cvw_ppa_flopenr #(WIDTH) f1(clk, reset, en, d, q1);
  cvw_ppa_flopenr #(WIDTH) f2(clk, reset, en, q1, q);
endmodule

module cvw_ppa_flopenr_16 #(parameter WIDTH = 16) (
  input  logic             clk, reset, en,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  logic [WIDTH-1:0] q1;

  cvw_ppa_flopenr #(WIDTH) f1(clk, reset, en, d, q1);
  cvw_ppa_flopenr #(WIDTH) f2(clk, reset, en, q1, q);
endmodule

module cvw_ppa_flopenr_32 #(parameter WIDTH = 32) (
  input  logic             clk, reset, en,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  logic [WIDTH-1:0] q1;

  cvw_ppa_flopenr #(WIDTH) f1(clk, reset, en, d, q1);
  cvw_ppa_flopenr #(WIDTH) f2(clk, reset, en, q1, q);
endmodule

module cvw_ppa_flopenr_64 #(parameter WIDTH = 64) (
  input  logic             clk, reset, en,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  logic [WIDTH-1:0] q1;

  cvw_ppa_flopenr #(WIDTH) f1(clk, reset, en, d, q1);
  cvw_ppa_flopenr #(WIDTH) f2(clk, reset, en, q1, q);
endmodule

module cvw_ppa_flopenr_128 #(parameter WIDTH = 128) (
  input  logic             clk, reset, en,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

  logic [WIDTH-1:0] q1;

  cvw_ppa_flopenr #(WIDTH) f1(clk, reset, en, d, q1);
  cvw_ppa_flopenr #(WIDTH) f2(clk, reset, en, q1, q);
endmodule

module cvw_ppa_csa_8 #(parameter WIDTH = 8) (
  input logic [WIDTH-1:0] a, b, c,
  output logic [WIDTH-1:0] sum, carry);

  assign sum = a ^ b ^ c;
  assign carry = (a & (b | c)) | (b & c);

endmodule

module cvw_ppa_csa_16 #(parameter WIDTH = 16) (
  input logic [WIDTH-1:0] a, b, c,
  output logic [WIDTH-1:0] sum, carry);

  assign sum = a ^ b ^ c;
  assign carry = (a & (b | c)) | (b & c);

endmodule

module cvw_ppa_csa_32 #(parameter WIDTH = 32) (
  input logic [WIDTH-1:0] a, b, c,
  output logic [WIDTH-1:0] sum, carry);

  assign sum = a ^ b ^ c;
  assign carry = (a & (b | c)) | (b & c);

endmodule

module cvw_ppa_csa_64 #(parameter WIDTH = 64) (
  input logic [WIDTH-1:0] a, b, c,
  output logic [WIDTH-1:0] sum, carry);

  assign sum = a ^ b ^ c;
  assign carry = (a & (b | c)) | (b & c);

endmodule

module cvw_ppa_csa_128 #(parameter WIDTH = 128) (
  input logic [WIDTH-1:0] a, b, c,
  output logic [WIDTH-1:0] sum, carry);

  assign sum = a ^ b ^ c;
  assign carry = (a & (b | c)) | (b & c);

endmodule

module cvw_ppa_inv_1 #(parameter WIDTH = 1) (
  input logic [WIDTH-1:0] a,
  output logic [WIDTH-1:0] y);

  assign y = ~a;
endmodule
