module csrData #(parameter WIDTH = 8)
  (input  logic [WIDTH-1:0] csr, rs1,
   input  logic [2:0]       funct3,
   output logic [WIDTH-1:0] y);

  always_comb
    case(funct3)
      3'b001: y = rs1;
      3'b010: y = (csr | rs1);
      3'b011: y = (csr & ~rs1);
      3'b101: y = rs1;           // CSRRWI
      3'b110: y = (csr | rs1);   // CSRRSI
      3'b111: y = (csr & ~rs1);  // CSRRCI
      default: y = csr;
    endcase
endmodule
