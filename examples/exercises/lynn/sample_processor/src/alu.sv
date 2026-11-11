module alu(input  logic [31:0] a, b,
input  logic [3:0]  alucontrol,
output logic [31:0] result);
// output logic zero,
// output logic negative,
// output logic overflow,
// output logic carry);

  logic [31:0] condinvb, sum;
  logic [32:0] sum_extend;
  logic        sub;

  assign sub = (alucontrol[1:0] == 2'b01);
  assign condinvb = sub ? ~b : b; // for subtraction or slt
  assign sum_extend = a + condinvb + {31'b0, sub};
  assign sum = sum_extend[31:0];

  always_comb
    case (alucontrol)
      4'b0000: result = sum;              // ADD
      4'b0001: result = sum;              // SUB
      4'b0010: result = a & b;            // AND
      4'b0011: result = a | b;            // OR
      4'b0100: result = a ^ b;            // XOR
      4'b0101: result = {31'b0, $signed(a) < $signed(b)}; // SLT (signed)
      4'b0110: result = {31'b0, a < b};   // SLTU (unsigned)
      4'b0111: result = a << b[4:0];      // SLL (shift left logical)
      4'b1000: result = a >> b[4:0];      // SRL (shift right logical)
      4'b1001: result = $signed(a) >>> b[4:0]; // SRA (shift right arithmetic)
      default: result = 0;
    endcase

  // assign zero = (result == 32'b0);
  // assign negative = (result[31] == 1);
  // assign overflow = (a[31] == condinvb[31]) && (sum[31] != a[31]);
  // assign carry = (sum_extend[32] == 1);

endmodule
