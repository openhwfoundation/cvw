module mux6 #(parameter WIDTH = 8)
  (input  logic [WIDTH-1:0] d0, d1, d2, d3, d4, d5,
   input  logic [2:0]       s,
   output logic [WIDTH-1:0] y);

  always_comb
    case(s)
      3'b000: y = d0;
      3'b001: y = d1;
      3'b010: y = d2;
      3'b011: y = d3;
      3'b100: y = d4;
      3'b101: y = d5;
      default: y = d0;
    endcase
endmodule
