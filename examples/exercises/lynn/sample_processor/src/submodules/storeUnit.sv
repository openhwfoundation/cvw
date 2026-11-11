module storeUnit(
    input  logic [2:0]  funct3,
    input  logic [1:0]  addr_low,
    input  logic        MemWrite,
    output logic [3:0]  WriteByteEn,
    input  logic [31:0] WriteDataIn,
    output logic [31:0] WriteDataOut
);

    logic [31:0] byteMask, byteData;
    logic [31:0] halfMask, halfwordData;
    logic [1:0]  ByteAdr;

    assign ByteAdr = addr_low;

    always_comb begin
        byteData = WriteDataIn;
        byteMask = 32'b0;

        case (ByteAdr)
            2'b00: begin
                byteData = {24'b0, WriteDataIn[7:0]};
                byteMask = 32'h000000FF;
            end
            2'b01: begin
                byteData = {16'b0, WriteDataIn[7:0], 8'b0};
                byteMask = 32'h0000FF00;
            end
            2'b10: begin
                byteData = {8'b0, WriteDataIn[7:0], 16'b0};
                byteMask = 32'h00FF0000;
            end
            2'b11: begin
                byteData = {WriteDataIn[7:0], 24'b0};
                byteMask = 32'hFF000000;
            end
        endcase
    end

    always_comb begin
        halfwordData = WriteDataIn;
        halfMask     = 32'b0;

        case (ByteAdr[1])
            1'b0: begin
                halfwordData = {16'b0, WriteDataIn[15:0]};
                halfMask     = 32'h0000FFFF;
            end
            1'b1: begin
                halfwordData = {WriteDataIn[15:0], 16'b0};
                halfMask     = 32'hFFFF0000;
            end
        endcase
    end

    always_comb begin
        WriteByteEn = 4'b0000;
        WriteDataOut = WriteDataIn;

        if (MemWrite) begin
            case(funct3)
                3'b000: begin  // SB
                    WriteDataOut = byteData;
                    WriteByteEn = {byteMask[31:24] != 0, byteMask[23:16] != 0,
                                   byteMask[15:8] != 0, byteMask[7:0] != 0};
                end
                3'b001: begin  // SH
                    WriteDataOut = halfwordData;
                    WriteByteEn = {halfMask[31:24] != 0, halfMask[23:16] != 0,
                                   halfMask[15:8] != 0, halfMask[7:0] != 0};
                end
                3'b010: begin  // SW
                    WriteDataOut = WriteDataIn;
                    WriteByteEn = 4'b1111;
                end
                default: begin
                    WriteDataOut = WriteDataIn;
                    WriteByteEn = 4'b0000;
                end
            endcase
        end
    end

endmodule
