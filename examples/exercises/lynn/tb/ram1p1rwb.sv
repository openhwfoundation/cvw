//James Kaden Cassidy jkc.cassidy@gmail.com 12/20/2024

module ram1p1rwb #(
    parameter MEMORY_NAME,
    parameter ADDRESS_BITS,
    parameter DATA_BITS,
    parameter MEMORY_SIZE_ENTRIES,
    parameter MEMORY_FILE_BASE_ADDRESS  = 0,
    parameter MEMORY_ADR_OFFSET         = 0,
    parameter MEMORY_FILE_PATH          = "",
    parameter MEMFILE_PLUS_ARG          = ""
) (
    input   logic                       clk,
    input   logic                       reset,

    input   logic                       En,
    input   logic                       WriteEn,
    input   logic[(DATA_BITS/8)-1:0]    WriteByteEn,

    input   logic[ADDRESS_BITS-1:0]     MemoryAddress,
    input   logic[DATA_BITS-1:0]        WriteData,

    output  logic[DATA_BITS-1:0]        ReadData
);

    // allows memory to be loaded from arbitrary position within InitMem rather than just from the beginning
    localparam [`XLEN-1:0] EXTRA_ENTRIES = (MEMORY_ADR_OFFSET - MEMORY_FILE_BASE_ADDRESS) / (DATA_BITS/8);
    logic[DATA_BITS-1:0] InitMem [MEMORY_SIZE_ENTRIES - 1 + EXTRA_ENTRIES : 0];

    logic[DATA_BITS-1:0] Memory[MEMORY_SIZE_ENTRIES-1:0];

    assign ReadData = En ? Memory[(MemoryAddress-MEMORY_ADR_OFFSET)>>2] : 'x;

    always_ff @(negedge clk) begin
        //$display("%s En: %h WriteEn: %h Addr: %h ReadData: %h", MEMORY_NAME, En, WriteEn, MemoryAddress, ReadData);
        if (reset) begin
            int i;
            logic[DATA_BITS-1:0] memory_entry;
            for (i = 0; i < MEMORY_SIZE_ENTRIES; i++) begin
                memory_entry = InitMem [EXTRA_ENTRIES + i];
                if (memory_entry === 'x)    Memory[i] <= '0;
                else                        Memory[i] <= memory_entry;
                // Memory[i] <= memory_entry;
            end
        end else if (En && ((unsigned'(MemoryAddress) < unsigned'(MEMORY_ADR_OFFSET)) ||
                    (unsigned'(MemoryAddress) > unsigned'(MEMORY_ADR_OFFSET + (MEMORY_SIZE_ENTRIES-1) * (DATA_BITS/8))))) begin
            $display("ERROR: %s memory out-of-range addr %h", MEMORY_NAME, MemoryAddress);
            $display("DEBUG: MEM_ADR_OFFSET(%h) MEMORY_SIZE_ENTRIES(%h) DATA_BITS(%h) TOP(%h)", MEMORY_ADR_OFFSET, MEMORY_SIZE_ENTRIES, DATA_BITS, (MEMORY_ADR_OFFSET + (MEMORY_SIZE_ENTRIES-1) * DATA_BITS/8));
            $finish(-1);

        end else if (En & ~WriteEn & ReadData === 'x) begin
            // TODO Not sure why not working for counters array in coremark
            // $display("ERROR: %s attempting to read uninitialized memory: %h", MEMORY_NAME, MemoryAddress);
            // $finish(-1);

        end else if (WriteEn && En) begin
            logic[DATA_BITS-1:0] LocalReadData;

            LocalReadData = Memory[(MemoryAddress-MEMORY_ADR_OFFSET)>>2];

            //$display("%s Writing to local adr: %h, Write Data: %h, byte en: %b", MEMORY_NAME, (MemoryAddress-MEMORY_ADR_OFFSET)>>2, WriteData, WriteByteEn);

            for (int i = 0; i < (DATA_BITS/8); i++) begin
                if (WriteByteEn[i]) begin
                    LocalReadData[((i+1)*8-1) -: 8] = WriteData[((i+1)*8-1) -: 8];
                end
            end

            Memory[(MemoryAddress-MEMORY_ADR_OFFSET)>>2] <= LocalReadData;
        end
    end

    initial begin
        string memfile;
        int i;

        if (MEMORY_FILE_PATH !== "") begin
            $display("%s Loading Memory: " + MEMORY_FILE_PATH, MEMORY_NAME);
            $readmemh(MEMORY_FILE_PATH, InitMem);
        end else if (MEMFILE_PLUS_ARG !== "") begin
            // Try to read +MEMFILE=<path> from vsim command line
            if (!$value$plusargs({MEMFILE_PLUS_ARG,"=%s"},  memfile)) begin
                $display("ERROR: %s +%s not supplied",MEMORY_NAME, MEMFILE_PLUS_ARG);
                $finish(-1);
            end else begin
                $display("INFO: %s Using MEMFILE = '%s'", MEMORY_NAME, memfile);
            end
            $readmemh(memfile, InitMem);
        end else begin
            for (i = 0; i < MEMORY_SIZE_ENTRIES + EXTRA_ENTRIES; i++) begin
                InitMem [i] = 'x;
            end
        end

    end

    initial begin
        if (MEMORY_ADR_OFFSET < MEMORY_FILE_BASE_ADDRESS) begin
            $display("ERROR: MEMORY_ADR_OFFSET < MEMORY_FILE_BASE_ADDRESS");
            $fatal(-1);
        end
    end


endmodule
