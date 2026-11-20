module loadUnit #(parameter WIDTH = 8)
  (input  logic [WIDTH-1:0] ReadData,
   input  logic [1:0]        ByteAdr,
   input  logic [2:0]       funct3,
   output logic [WIDTH-1:0] AdjustedReadData);

  logic [7:0]  byteData;
  logic [15:0] halfwordData;

  always_comb
    case(ByteAdr)
      2'b00: byteData = ReadData[7:0];
      2'b01: byteData = ReadData[15:8];
      2'b10: byteData = ReadData[23:16];
      2'b11: byteData = ReadData[31:24];
      default: byteData = ReadData[7:0];
    endcase

  always_comb
    case(ByteAdr[1])
      1'b0: halfwordData = ReadData[15:0];
      1'b1: halfwordData = ReadData[31:16];
      default: halfwordData = ReadData[15:0];
    endcase

  always_comb
    case(funct3)
      3'b000: AdjustedReadData = {{24{byteData[7]}}, byteData};
      3'b001: AdjustedReadData = {{16{halfwordData[15]}}, halfwordData};
      3'b010: AdjustedReadData = ReadData;
      3'b100: AdjustedReadData = {24'b0, byteData};
      3'b101: AdjustedReadData = {16'b0, halfwordData};
      default: AdjustedReadData = ReadData;
    endcase
endmodule
