module aludec(input  logic       f7b5, op5,
              input  logic [2:0] funct3,
              input  logic [1:0] aluop,
              output logic [3:0] alucontrol);

  logic addSubType;
  assign addSubType = op5 ? (f7b5 & op5) : (f7b5 & (funct3 == 3'b101));
  always_comb
    case(aluop)
      2'b00: alucontrol = 4'b0000;  // add
      2'b01: alucontrol = 4'b0001;  // sub
      default: case({addSubType, funct3})        // R- or I-type
          4'b0000: alucontrol = 4'b0000; // ADD
          4'b1000: alucontrol = 4'b0001; // SUB
          4'b0111: alucontrol = 4'b0010; // AND
          4'b0110: alucontrol = 4'b0011; // OR
          4'b0010: alucontrol = 4'b0101; // SLT
          4'b0100: alucontrol = 4'b0100; // XOR
          4'b0001: alucontrol = 4'b0111; // SLL
          4'b0101: alucontrol = 4'b1000; // SRL
          4'b1101: alucontrol = 4'b1001; // SRA
          4'b0011: alucontrol = 4'b0110; // SLTU
          default: alucontrol = 4'bxxxx; // ???
        endcase
    endcase
endmodule
