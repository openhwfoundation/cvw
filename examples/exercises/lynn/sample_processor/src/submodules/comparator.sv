// This comparator is best - adapated it from wally
module comparator #(parameter WIDTH=32) (
  input  logic [WIDTH-1:0] a, b,    // Operands
  output logic [2:0]       flags);  // Output flags: {eq, lt}

  logic eq_E, lt_signed_E, lt_unsig_E;
  assign eq_E        = (a == b);
  assign lt_signed_E = ($signed(a) < $signed(b));
  assign lt_unsig_E  = (a < b);
  assign flags = {eq_E, lt_signed_E, lt_unsig_E};
endmodule
