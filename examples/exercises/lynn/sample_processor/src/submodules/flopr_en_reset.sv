module flopr_en_reset #(parameter WIDTH = 8)
  (input  logic             clk, reset, enable,
                  input  logic [WIDTH-1:0] resetData, d,
                  output logic [WIDTH-1:0] q);

  always_ff @(posedge clk, posedge reset)
    if (reset) q <= resetData;
    else if  (enable)     q <= d;
endmodule
