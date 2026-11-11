///////////////////////////////////////////
// testbench.sv
//
// Written: David_Harris@hmc.edu 9 January 2021
//// Modified by sanarayanan@hmc.edu, May 2025
// Modified:
//
// Purpose: Wally Testbench and helper modules
//          Applies test programs from the riscv-arch-test and other custom tests
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

`include "config.vh"

`ifdef USE_IMPERAS_DV
    `include "idv/idv.svh"
`endif

import cvw::*;

module testbench;
  /* verilator lint_off WIDTHTRUNC */
  /* verilator lint_off WIDTHEXPAND */
  parameter DEBUG=0;
  parameter PrintHPMCounters=0;
  parameter BPRED_LOGGER=0;
  parameter I_CACHE_ADDR_LOGGER=0;
  parameter D_CACHE_ADDR_LOGGER=0;
  parameter RVVI_SYNTH_SUPPORTED=0;
  parameter MAKE_VCD=0;

  // TREK Requires a license for the Breker tool. See tests/breker/README.md for details
  `ifdef USE_TREK_DV
    event trek_start;
    always @(testbench.trek_start) begin
      trek_uvm_pkg::trek_uvm_events::do_backdoor_init();
    end
  `endif

  `ifdef USE_IMPERAS_DV
    import idvPkg::*;
    import rvviApiPkg::*;
    import idvApiPkg::*;
    `define ENABLE_RVVI_TRACE
  `endif

  `ifdef FCOV
    `define ENABLE_RVVI_TRACE
  `endif

  `ifdef VERILATOR
      import "DPI-C" function string getenvval(input string env_name);
      string       RISCV_DIR = getenvval("RISCV");
      string       WALLY_DIR = getenvval("WALLY"); // ~/cvw typical
  `elsif VCS
      import "DPI-C" function string getenv(input string env_name);
      string       RISCV_DIR = getenv("RISCV");
      string       WALLY_DIR = getenv("WALLY");
  `else
      string       RISCV_DIR = "$RISCV";
      string       WALLY_DIR = "$WALLY";
  `endif

  `include "parameter-defs.vh"

  logic        clk;
  logic        reset_ext, reset;
  logic        ResetMem;

  // Variables that can be overwritten with $value$plusargs at start of simulation
  string       TEST, ElfFile, ElfList, sim_log_prefix;
  integer      INSTR_LIMIT;
  string       UART_LOG_FILE;
  integer      UART_LOG;

  // DUT signals
  logic [P.AHBW-1:0]    HRDATAEXT;
  logic                 HREADYEXT, HRESPEXT;
  logic [P.PA_BITS-1:0] HADDR;
  logic [P.AHBW-1:0]    HWDATA;
  logic [P.XLEN/8-1:0]  HWSTRB;
  logic                 HWRITE;
  logic [2:0]           HSIZE;
  logic [2:0]           HBURST;
  logic [3:0]           HPROT;
  logic [1:0]           HTRANS;
  logic                 HMASTLOCK;
  logic                 HCLK, HRESETn;

  logic [31:0] GPIOIN, GPIOOUT, GPIOEN;
  logic        UARTSin, UARTSout;
  logic        SPIIn, SPIOut;
  logic [3:0]  SPICS;
  logic        SPICLK;
  logic        SDCCmd;
  logic        SDCIn;
  logic [3:0]  SDCCS;
  logic        SDCCLK;
  logic [3:0]  PWMGPIO;

  logic        HREADY;
  logic        HSELEXT;


  string  ProgramAddrMapFile, ProgramLabelMapFile; // label maps used by functionName for debug tracing

  int test, i, errors, totalerrors;

  string outputfile;
  integer outputFilePointer;

  string  elfPaths[$];   // ELF files run back-to-back in this simulation
  string  elfPathLine;
  integer elfListFD;
  int     NumTests;
  logic EndTest;                 // pulses for one cycle when a test finishes
  logic Validate;
  logic SelectTest;
  logic TestComplete;
  logic TohostWrite;             // the test is storing its result to tohost
  logic TohostStore, TohostHiStore; // a store to tohost / to its upper word (tohost+4)
  logic HtifPutchar;             // the store to tohost is an HTIF console putchar
  logic [31:0] TohostHi;         // upper word of tohost, stored separately on RV32
  logic [63:0] TohostWord;       // the 64-bit tohost value being stored
  logic [31:0] TohostValue;      // value stored to tohost: 1 = pass, (code << 1) | 1 = fail, 0 = never written
  localparam SIG_WORDS = 5;      // words captured from begin_signature (embench's timing and result)
  logic [P.XLEN-1:0] Signature[SIG_WORDS-1:0];
  logic PrevPCZero;
  logic ExternalStall;

  integer elfFD;
  byte header[0:4];
  byte readBytes;

  initial begin
    // look for arguments passed to simulation, or use defaults
    if (!$value$plusargs("TEST=%s", TEST))
      TEST = "none";
    if (!$value$plusargs("ElfFile=%s", ElfFile))
      ElfFile = "none";
    if (!$value$plusargs("INSTR_LIMIT=%d", INSTR_LIMIT))
      INSTR_LIMIT = 0;
    // Check if sim_log_prefix is passed as a command-line argument
    if (!$value$plusargs("sim_log_prefix=%s", sim_log_prefix)) begin
        sim_log_prefix = "";  // Assign default value if not passed
    end
    if (!$value$plusargs("UART_LOG=%d", UART_LOG))
      UART_LOG = (TEST == "buildroot"); // Default to true for buildroot test, false otherwise
    if (!$value$plusargs("UART_LOG_FILE=%s", UART_LOG_FILE))
      UART_LOG_FILE = {"logs/", TEST, "_uart.out"};
    //$display("TEST = %s ElfFile = %s", TEST, ElfFile);

    if (!$value$plusargs("ElfList=%s", ElfList))
      ElfList = "none";

    // Build the list of ELF files to run back-to-back in this simulation.  wsim writes the path of
    // each ELF on its own line of the ElfList file; a single ELF may also be named with +ElfFile.
    // buildroot and fpga instead load prebuilt memory images, so they have no ELF list.
    if (TEST == "buildroot" | TEST == "fpga") begin
      NumTests = 1;
    end else begin
      if (ElfList != "none") begin
        elfListFD = $fopen(ElfList, "r");
        if (elfListFD == 0) begin
          $display("Error: Could not open ELF list file %s", ElfList);
          $finish;
        end
        while ($fscanf(elfListFD, "%s", elfPathLine) == 1)
          elfPaths.push_back(elfPathLine);
        $fclose(elfListFD);
      end else if (ElfFile != "none")
        elfPaths.push_back(ElfFile);
      NumTests = elfPaths.size();
      if (NumTests == 0) begin
        $display("Error: No ELF files to run.  Pass +ElfList=<listfile> or +ElfFile=<elf>.");
        $finish;
      end
      ElfFile = elfPaths[0];  // lockstep reference models load the ELF at time 0; only one is allowed
      $display("Running %0d test%s", NumTests, NumTests == 1 ? "" : "s");

      // Check that every ELF matches the DUT's XLEN before running anything
      foreach (elfPaths[elfIdx]) begin
        elfFD = $fopen(elfPaths[elfIdx], "rb");
        if (elfFD == 0) begin
          $display("Error: Could not open ELF file %s", elfPaths[elfIdx]);
          $finish;
        end
        readBytes = $fread(header, elfFD);
        $fclose(elfFD);
        if (header[4] == 1 & integer'(P.XLEN) == 64) begin
          $display("Error: You can not run a 32 bit elf (%s) on a 64 bit DUT", elfPaths[elfIdx]);
          $finish;
        end else if (header[4] == 2 & integer'(P.XLEN) == 32) begin
          $display("Error: You can not run a 64 bit elf (%s) on a 32 bit DUT", elfPaths[elfIdx]);
          $finish;
        end
      end
    end
    if (MAKE_VCD) begin
      $dumpfile("testbench.vcd");
      $dumpvars;
    end
  end // initial begin

  // Model the testbench as an fsm.
  // Do this in parts so it easier to verify
  // part 1: build a version which echos the same behavior as the below code, but does not drive anything
  // part 2: drive some of the controls
  // part 3: drive all logic and remove old initial and always @ negedge clk block

  typedef enum logic [3:0]{STATE_TESTBENCH_RESET,
                           STATE_INIT_TEST,
                           STATE_RESET_MEMORIES,
                           STATE_RESET_MEMORIES2,
                           STATE_LOAD_MEMORIES,
                           STATE_RESET_TEST,
                           STATE_RUN_TEST,
                           STATE_END_TEST,
                           STATE_VALIDATE,
                           STATE_INCR_TEST} statetype;
  statetype CurrState, NextState;
  logic        TestBenchReset;
  logic [2:0]  ResetCount, ResetThreshold;
  logic        LoadMem;
  logic        ResetCntEn;
  logic        ResetCntRst;

  string  elffilename, memfilename, bootmemfilename, uartoutfilename;
  logic [P.XLEN-1:0] tohost_addr, begin_signature_addr; // for the test being run; 0 if it lacks the symbol
  integer uartoutfile;


  assign ResetThreshold = 3'd5;

  initial begin
    TestBenchReset = 1'b1;
    # 100;
    TestBenchReset = 1'b0;
  end

  always_ff @(posedge clk)
    if (TestBenchReset) CurrState <= STATE_TESTBENCH_RESET;
    else CurrState <= NextState;

  // fsm next state logic
  always_comb begin
    case(CurrState)
      STATE_TESTBENCH_RESET:                      NextState = STATE_INIT_TEST;
      STATE_INIT_TEST:                            NextState = STATE_RESET_MEMORIES;
      STATE_RESET_MEMORIES:                       NextState = STATE_RESET_MEMORIES2;
      STATE_RESET_MEMORIES2:                      NextState = STATE_LOAD_MEMORIES;  // Give the reset enough time to ensure the bus is reset before loading the memories.
      STATE_LOAD_MEMORIES:                        NextState = STATE_RESET_TEST;
      STATE_RESET_TEST:      if(ResetCount < ResetThreshold) NextState = STATE_RESET_TEST;
                             else                 NextState = STATE_RUN_TEST;
      STATE_RUN_TEST:        if(TestComplete)     NextState = STATE_END_TEST;
                             else                 NextState = STATE_RUN_TEST;
      STATE_END_TEST:                             NextState = STATE_VALIDATE;
      STATE_VALIDATE:                             NextState = STATE_INIT_TEST;
      STATE_INCR_TEST:                            NextState = STATE_INIT_TEST;
      default:                                    NextState = STATE_TESTBENCH_RESET;
    endcase
  end // always_comb
  // fsm output control logic
  assign reset_ext = CurrState == STATE_TESTBENCH_RESET | CurrState == STATE_INIT_TEST |
                     CurrState == STATE_RESET_MEMORIES | CurrState == STATE_RESET_MEMORIES2 |
                     CurrState == STATE_LOAD_MEMORIES | CurrState ==STATE_RESET_TEST;
  // this initialization is very expensive, only do it for coremark.
  assign ResetMem = (CurrState == STATE_RESET_MEMORIES | CurrState == STATE_RESET_MEMORIES2) & TEST == "coremark";
  assign LoadMem = CurrState == STATE_LOAD_MEMORIES;
  assign ResetCntRst = CurrState == STATE_INIT_TEST;
  assign ResetCntEn = CurrState == STATE_RESET_TEST;
  assign Validate = CurrState == STATE_VALIDATE;
  assign SelectTest = CurrState == STATE_INIT_TEST;
  assign EndTest = CurrState == STATE_END_TEST;

  // fsm reset counter
  counter #(3) RstCounter(clk, ResetCntRst, ResetCntEn, ResetCount);

  ////////////////////////////////////////////////////////////////////////////////
  // Find the test vector files and populate the PC to function label converter
  ////////////////////////////////////////////////////////////////////////////////

  logic EcallFaultM;
  if (P.ZICSR_SUPPORTED)
    assign EcallFaultM = dut.core.priv.priv.EcallFaultM;
  else
    assign EcallFaultM = 0;

  always @(posedge clk) begin
    ////////////////////////////////////////////////////////////////////////////////
    // Verify the test ran correctly by checking the memory against a known signature.
    ////////////////////////////////////////////////////////////////////////////////
    if(TestBenchReset) test = 0;
    if (P.ZICSR_SUPPORTED & TEST == "coremark")
      if (EcallFaultM) begin
        $display("Benchmark: coremark is done.");
`ifdef QUESTA
        $stop;
`else
        $finish;  // $stop would abort a Verilator run with a nonzero exit code
`endif
      end
    if(SelectTest) begin
      if(TEST == "buildroot") begin
        memfilename = {RISCV_DIR, "/linux-testvectors/ram.bin"};
        elffilename = "buildroot";
        bootmemfilename = {RISCV_DIR, "/linux-testvectors/bootmem.bin"};
        ProgramAddrMapFile = {RISCV_DIR, "/buildroot/output/images/disassembly/vmlinux.objdump.addr"};
        ProgramLabelMapFile = {RISCV_DIR, "/buildroot/output/images/disassembly/vmlinux.objdump.lab"};
      end else if(TEST == "fpga") begin
        bootmemfilename = {WALLY_DIR, "/fpga/src/boot.mem"};
        memfilename = {WALLY_DIR, "/fpga/src/data.mem"};
        ProgramAddrMapFile = {WALLY_DIR, "/fpga/zsbl/bin/boot.objdump.addr"};
        ProgramLabelMapFile = {WALLY_DIR, "/fpga/zsbl/bin/boot.objdump.lab"};
      end else begin
        elffilename = elfPaths[test];
        memfilename = {elffilename, ".memfile"};
        ProgramAddrMapFile = {elffilename, ".objdump.addr"};
        ProgramLabelMapFile = {elffilename, ".objdump.lab"};
        // build the memory image and the label maps from the ELF if they are missing or out of date
        if ($system({"make -s -f ", WALLY_DIR, "/testbench/Makefile WALLY=", WALLY_DIR, " ", memfilename, " ", ProgramAddrMapFile}) != 0)
          $display("Error: Could not build %s and the label maps of %s", memfilename, elffilename);
      end
      if (TEST == "buildroot" | TEST == "fpga") begin
        tohost_addr = 0;
        begin_signature_addr = 0;
      end else
        findSymbols(ProgramAddrMapFile, ProgramLabelMapFile, tohost_addr, begin_signature_addr);
      // Open UART log file if enabled (buildroot defaults to on, override with +UART_LOG=1)
      if (UART_LOG) begin
        uartoutfilename = UART_LOG_FILE;
        uartoutfile = $fopen(uartoutfilename, "w");
      end else
        uartoutfile = 0;
    end
    if(Validate) begin
      if (PrevPCZero) totalerrors = totalerrors + 1; //  error if PC is stuck at zero
      if (uartoutfile)
        $fclose(uartoutfile);
      if (TEST == "embench") begin
        // Writes the words the benchmark stored to begin_signature to the .sim.output file:
        // the cycles and instret at its start and stop triggers, which embench's python speed
        // script uses to calculate the speed score, and the result of its own check.
        $display("Embench Benchmark: %s is done.", elffilename);
        outputfile = {stripElfSuffix(elffilename), ".sim.output"};
        outputFilePointer = $fopen(outputfile, "w");
        for (i = 0; i < SIG_WORDS; i++)
          $fdisplayh(outputFilePointer, Signature[i]);
        $fclose(outputFilePointer);
        $display("Embench Benchmark: created output file: %s", outputfile);
      end else if (TEST == "buildroot" | TEST == "fpga" | TEST == "coremark") begin
        $display("%s is done.", TEST);
      end else begin
        // Every test checks itself and reports the result by storing to tohost: 1 = pass,
        // (exit code << 1) | 1 = fail.  A test that halts without storing to tohost is a failure.
        `ifdef USE_TREK_DV
          $display("Breker test is done.");
        `else
          if (TohostValue == 1) $display("%s succeeded.  Brilliant!!!", elffilename);
          else begin
            if (TohostValue == 0) $display("  Error on test %s: halted without reporting a result to tohost", elffilename);
            else $display("  Error on test %s: tohost = %0d (test exit code %0d)", elffilename, TohostValue, TohostValue >> 1);
            $display("%s failed. :(", elffilename);
            totalerrors = totalerrors + 1;
          end
        `endif
      end
      test = test + 1;
      if (test == NumTests) begin
        if (totalerrors == 0) $display("SUCCESS! All tests ran without failures.");
        else $display("FAIL: %d test programs had errors", totalerrors);
`ifdef QUESTA
        $stop;  // if this is changed to $finish for Questa, wally-batch.do does not go to the next step to run coverage, and wally.do terminates without allowing GUI debug
`else
        $finish;
`endif
      end
    end
  end


  ////////////////////////////////////////////////////////////////////////////////
  // load memories with program image
  ////////////////////////////////////////////////////////////////////////////////

  integer memFile, uncoreMemFile;
  integer readResult;
  if (P.SDC_SUPPORTED) begin
    always @(posedge clk) begin
      if (LoadMem) begin
        string romfilename, sdcfilename;
        romfilename = {"../tests/custom/fpga-test-sdc/bin/fpga-test-sdc.memfile"};
        sdcfilename = {"../testbench/sdc/ramdisk2.hex"};
        //$readmemh(romfilename, dut.uncoregen.uncore.bootrom.bootrom.memory.ROM);
        //$readmemh(sdcfilename, sdcard.sdcard.FLASHmem);
        // shorten sdc timers for simulation
        //dut.uncoregen.uncore.sdc.SDC.LimitTimers = 1;
      end
    end
  end else if (P.IROM_SUPPORTED) begin
    // The memfile holds XLEN-bit words; the IROM is 32 bits wide (irom.sv), so split each into 32-bit words
    localparam IMAGEWORDS = (P.IROM_RANGE+1) >> $clog2(P.XLEN/8);
    localparam ROMWORDS = (P.IROM_RANGE+1) >> 2;
    bit [P.XLEN-1:0] IROMImage [IMAGEWORDS-1:0];
    function automatic bit [31:0] IROMWord(int i);
      return IROMImage[i/(P.XLEN/32)][32*(i%(P.XLEN/32)) +: 32];
    endfunction
    if (P.ZCA_SUPPORTED) begin : iromimage
      // With compressed instructions, the IROM is two banks interleaved by word: bank 0 holds the even words and bank 1 the odd words
      always @(posedge clk) begin
        if (LoadMem) begin
          $readmemh(memfilename, IROMImage);
          for (int i = 0; i < ROMWORDS/2; i++) begin
            dut.core.ifu.irom.irom.banks.bank0.ROM[i] = IROMWord(2*i);
            dut.core.ifu.irom.irom.banks.bank1.ROM[i] = IROMWord(2*i+1);
          end
        end
      end
    end else begin : iromimage
      always @(posedge clk) begin
        if (LoadMem) begin
          $readmemh(memfilename, IROMImage);
          for (int i = 0; i < ROMWORDS; i++)
            dut.core.ifu.irom.irom.bank.rom.ROM[i] = IROMWord(i);
        end
      end
    end
  end else if (P.BUS_SUPPORTED) begin : bus_supported
    always @(posedge clk) begin
      if (LoadMem) begin
        if (TEST == "buildroot") begin
          memFile = $fopen(bootmemfilename, "rb");
          if (memFile == 0) begin
            $display("Error: Could not open file %s", memfilename);
            $finish;
          end
          if (P.BOOTROM_SUPPORTED)
            readResult = $fread(dut.uncoregen.uncore.bootrom.bootrom.memory.ROM, memFile);
          else begin
            $display("Buildroot test requires BOOTROM_SUPPORTED");
            $finish;
          end
          $fclose(memFile);
          memFile = $fopen(memfilename, "rb");
          if (memFile == 0) begin
            $display("Error: Could not open file %s", memfilename);
            $finish;
          end
          readResult = $fread(dut.uncoregen.uncore.ram.ram.memory.ram.RAM, memFile);
          $fclose(memFile);
        end else if (TEST == "fpga") begin
          memFile = $fopen(bootmemfilename, "rb");
          if (memFile == 0) begin
            $display("Error: Could not open file %s", memfilename);
            $finish;
          end
          if (P.BOOTROM_SUPPORTED) begin
            readResult = $fread(dut.uncoregen.uncore.bootrom.bootrom.memory.ROM, memFile);
          end
          $fclose(memFile);
          memFile = $fopen(memfilename, "rb");
          if (memFile == 0) begin
            $display("Error: Could not open file %s", memfilename);
            $finish;
          end
          readResult = $fread(dut.uncoregen.uncore.ram.ram.memory.ram.RAM, memFile);
          $fclose(memFile);
        end else begin
          uncoreMemFile = $fopen(memfilename, "r");  // Is there a better way to test if a file exists?
          if (uncoreMemFile == 0) begin
            $display("Error: Could not open file %s", memfilename);
            $finish;
          end else begin
            $fclose(uncoreMemFile);
            $readmemh(memfilename, dut.uncoregen.uncore.ram.ram.memory.ram.RAM);
            `ifdef USE_TREK_DV
              -> trek_start;
              $display("starting Trek....");
            `endif
          end
        end
        if (TEST == "embench") $display("Read memfile %s", memfilename);
      end
    end
  end
  if (P.DTIM_SUPPORTED) begin
    always @(posedge clk) begin
      if (LoadMem) begin
        $readmemh(memfilename, dut.core.lsu.dtim.dtim.ram.ram.RAM);
      end
    end
  end

  integer adrindex;
  if (P.UNCORE_RAM_SUPPORTED)
    always @(posedge clk)
      if (ResetMem)  // program memory is sometimes reset (e.g. for CoreMark, which needs zeroed memory)
        for (adrindex=0; adrindex<((P.UNCORE_RAM_RANGE+1)>>(1+P.XLEN/32)); adrindex = adrindex+1)
          dut.uncoregen.uncore.ram.ram.memory.ram.RAM[adrindex] = '0;

  ////////////////////////////////////////////////////////////////////////////////
  // Actual hardware
  ////////////////////////////////////////////////////////////////////////////////

  // instantiate device to be tested
  assign GPIOIN = '0;
  assign UARTSin = 1'b1;
  assign SPIIn = 1'b0;

  if(P.EXT_MEM_SUPPORTED) begin
    ram_ahb #(.P(P), .RANGE(P.EXT_MEM_RANGE))
    ram (.HCLK, .HRESETn, .HADDR, .HWRITE, .HTRANS, .HWDATA, .HSELRam(HSELEXT),
      .HREADRam(HRDATAEXT), .HREADYRam(HREADYEXT), .HRESPRam(HRESPEXT), .HREADY, .HWSTRB);
  end else begin
    assign HREADYEXT = 1'b1;
    assign {HRESPEXT, HRDATAEXT} = '0;
  end

  if(P.SDC_SUPPORTED) begin : sdcard
    // JP: Add back sd card when sd card AHB implementation done
    /* -----\/----- EXCLUDED -----\/-----
    sdModel sdcard
      (.sdClk(SDCCLK),
       .cmd(SDCCmd),
       .dat(SDCDat));

    assign SDCCmd = SDCCmdOE ? SDCCmdOut : 1'bz;
    assign SDCCmdIn = SDCCmd;
    assign SDCDat = sd_dat_reg_t ? sd_dat_reg_o : sd_dat_i;
    assign SDCDatIn = SDCDat;
    -----/\----- EXCLUDED -----/\----- */
  end else begin
    assign SDCIn = 1'b1;

  end

  wallypipelinedsoc  #(P) dut(.clk, .reset_ext, .reset, .ExternalStall,
    .HRDATAEXT, .HREADYEXT, .HRESPEXT, .HSELEXT,
    .HCLK, .HRESETn, .HADDR, .HWDATA, .HWSTRB, .HWRITE, .HSIZE, .HBURST, .HPROT,
    .HTRANS, .HMASTLOCK, .HREADY, .GPIOIN, .GPIOOUT, .GPIOEN,
    .UARTSin, .UARTSout, .SPIIn, .SPIOut, .SPICS, .SPICLK, .SDCIn, .SDCCmd, .SDCCS, .SDCCLK, .PWMGPIO);

  // generate clock to sequence tests
  always begin
    clk = 1'b1; # 5; clk = 1'b0; # 5;
  end

  if(RVVI_SYNTH_SUPPORTED) begin : rvvi_synth
    localparam MAX_CSRS = 5;
    localparam logic [31:0] RVVI_INIT_TIME_OUT = 32'd4;
    localparam logic [31:0] RVVI_PACKET_DELAY = 32'd2;

    logic [3:0]                                       mii_txd;
    logic                                             mii_tx_en, mii_tx_er;

    rvvitbwrapper #(P, MAX_CSRS, RVVI_INIT_TIME_OUT, RVVI_PACKET_DELAY)
    rvvitbwrapper(.clk, .reset, .RVVIStall(ExternalStall), .mii_tx_clk(clk), .mii_txd, .mii_tx_en, .mii_tx_er,
                  .mii_rx_clk(clk), .mii_rxd('0), .mii_rx_dv('0), .mii_rx_er('0));
  end // otherwise ExternalStall comes from stallinjector below


  /*
  // Print key info  each cycle for debugging
  always @(posedge clk) begin
    #2;
    $display("PCM: %x  InstrM: %x (%5s) WriteDataM: %x  IEUResultM: %x",
         dut.core.PCM, dut.core.InstrM, InstrMName, dut.core.WriteDataM, dut.core.ieu.dp.IEUResultM);
  end
  */

  ////////////////////////////////////////////////////////////////////////////////
  // Support logic
  ////////////////////////////////////////////////////////////////////////////////

  // Duplicate copy of pipeline registers that are optimized out of some configurations
  logic [31:0] NextInstrE, InstrM;
  mux2    #(32)     FlushInstrMMux(dut.core.ifu.InstrE, dut.core.ifu.nop, dut.core.ifu.FlushM, NextInstrE);
  flopenr #(32)     InstrMReg(clk, reset, ~dut.core.ifu.StallM, NextInstrE, InstrM);

  // Optional ExternalStall injector for directed tests of stall/flush interactions.  Inactive unless the
  // program retires the custom-use HINT slti x0, x0, imm with imm = {length[5:0], delay[5:0]}: delay cycles
  // later, ExternalStall is held for length cycles.
  if (!RVVI_SYNTH_SUPPORTED) begin : stallinjector
    logic [5:0] StallDelay, StallLength;
    always_ff @(posedge clk)
      if (reset) {StallLength, StallDelay} <= '0;
      else if (dut.core.InstrValidM & ~dut.core.StallW & ~dut.core.FlushW & InstrM[19:0] == 20'h02013)
                                 {StallLength, StallDelay} <= InstrM[31:20];
      else if (StallDelay != 0)  StallDelay <= StallDelay - 1;
      else if (StallLength != 0) StallLength <= StallLength - 1;
    assign ExternalStall = (StallDelay == 0) & (StallLength != 0);
  end

  // Track names of instructions
  string InstrFName, InstrDName, InstrEName, InstrMName, InstrWName;
  logic [31:0] InstrW;
  flopenr #(32)    InstrWReg(clk, reset, ~dut.core.ieu.dp.StallW,  InstrM, InstrW);
  instrTrackerTB #(P.XLEN) it(clk, reset, dut.core.ieu.dp.FlushE,
                dut.core.ifu.InstrRawF[31:0],
                dut.core.ifu.InstrD, dut.core.ifu.InstrE,
                InstrM,  InstrW,
                InstrFName, InstrDName, InstrEName, InstrMName, InstrWName);

  // Superscalar: the front end decodes two instruction slots but issues only slot 0.  Nothing downstream
  // consumes slot 1 yet, so check it here.  Whenever Decode advances and execution is sequential, the
  // instruction that just arrived in Decode (slot 0) must be exactly what the previous Decode held in
  // slot 1: same PC, same raw and decompressed bits, and the same decode results (source registers,
  // immediate, register-file reads, branch/jump/illegal flags).
  // Remove this block once slot 1 issues: slot 1 then no longer reappears as the next slot 0.
  // instrfields reads slot 1's register fields in Fetch from raw bytes, duplicating knowledge that
  // decompress.sv also holds.  Duplication is only acceptable if a divergence is detected rather
  // than silent -- a wrong Rd would let issue.sv permit a dependent pair, which corrupts data with
  // no fault to catch it.  So compare the Fetch-stage fields against the Decode-stage decompressed
  // instruction, which is the authority, every time slot 1 actually issues.
  if (P.ICACHE_SUPPORTED & P.SUPERSCALAR_SUPPORTED) begin : fieldscheck
    logic [4:0] Rd1F, Rs1_1F, Rs2_1F;
    logic [1:0] MemRW1F;
    logic       Recognized1F;
    integer     FieldChecks = 0;
    // These must mirror Instr1RawD's register exactly, which is a flopenl whose load ignores en:
    // on a simultaneous flush and stall the instruction becomes a nop while Issue1D, a flopenrc
    // whose clear requires en, keeps its old value.  Clearing Recognized1F on flush suppresses the check for
    // a slot that Fetch never examined.
    always_ff @(posedge clk)
      if (reset | dut.core.ifu.FlushD) Recognized1F <= 1'b0;
      else if (~dut.core.ifu.StallD) begin
        Rd1F  <= dut.core.ifu.dualissue.issue.Rd1F;
        Rs1_1F <= dut.core.ifu.dualissue.issue.Rs1_1F;
        Rs2_1F   <= dut.core.ifu.dualissue.issue.Rs2_1F;
        MemRW1F <= dut.core.ifu.dualissue.issue.MemRW1F;
        Recognized1F   <= dut.core.ifu.dualissue.issue.Recognized1F;
      end
    always_ff @(posedge clk)
      // Only compare when the decompressor actually recognised the instruction.  For a reserved or
      // HINT encoding -- c.slli with a zero shift amount, c.lwsp with rd = x0 -- it emits a default
      // rather than a decode, so there is nothing meaningful to compare against.  Those encodings
      // are handled instead by IllegalComp1M, which replays slot 1 so it traps as an unpaired
      // instruction; instrfields deliberately does not try to enumerate the HINT rules.
      if (~reset & dut.core.ifu.Issue1D & Recognized1F & ~dut.core.ifu.IllegalCompInstr1D) begin
        FieldChecks <= FieldChecks + 1;
        // The property that matters is one-sided.  Naming a register the instruction does not touch
        // only makes issue.sv's dependency check refuse a pair it could have taken -- harmless.  *Missing* one
        // permits a dependent pair, which corrupts data silently.  So a nonzero register in the
        // decompressed form must be reported exactly; x0 means no dependency and anything is safe.
        // This also accommodates the HINT encodings, which decompress.sv turns into a nop (see its
        // line 156): instrfields names their registers, the nop touches none.
        // A branch's or store's [11:7] are immediate bits: c.beqz and c.sw report no rd, while their expansions put offset bits there.
        if (~(dut.core.ifu.Instr1D[6:0] inside {7'b1100011, 7'b0100011}) & (dut.core.ifu.Instr1D[11:7] !== 5'b0) & (Rd1F !== dut.core.ifu.Instr1D[11:7]))
          $fatal(1, "fieldscheck: Rd under-reported at PC %h: Fetch said x%0d, decompressed writes x%0d (raw %h)",
                 dut.core.ifu.Instr1PCD, Rd1F, dut.core.ifu.Instr1D[11:7], dut.core.ifu.Instr1RawD);
        // Only compare rs1 for formats that have one.  LUI, AUIPC and JAL are U- and J-type, so
        // their [19:15] bits are immediate, not a register number -- c.lui decompresses to lui and
        // those bits can be any value.  Likewise [24:20] is rs2 only for R-type, already gated below.
        if (~(dut.core.ifu.Instr1D[6:0] inside {7'b0110111, 7'b0010111, 7'b1101111})
            & (dut.core.ifu.Instr1D[19:15] !== 5'b0) & (Rs1_1F !== dut.core.ifu.Instr1D[19:15]))
          $fatal(1, "fieldscheck: Rs1 under-reported at PC %h: Fetch said x%0d, decompressed reads x%0d (raw %h)",
                 dut.core.ifu.Instr1PCD, Rs1_1F, dut.core.ifu.Instr1D[19:15], dut.core.ifu.Instr1RawD);
        // Rs2 only exists as a register in the R-type, branch and store expansions; for an OP-IMM
        // expansion those bits are immediate, so comparing them would be meaningless.
        if ((dut.core.ifu.Instr1D[6:0] inside {7'b0110011, 7'b1100011, 7'b0100011}) & (dut.core.ifu.Instr1D[24:20] !== 5'b0)
            & (Rs2_1F !== dut.core.ifu.Instr1D[24:20]))
          $fatal(1, "fieldscheck: Rs2 under-reported at PC %h: Fetch said x%0d, decompressed reads x%0d (raw %h)",
                 dut.core.ifu.Instr1PCD, Rs2_1F, dut.core.ifu.Instr1D[24:20], dut.core.ifu.Instr1RawD);
        // Memory-ness matters as much as the registers: OneMemOpF is the only thing keeping two
        // accesses off the single load/store unit, so a compressed load that Fetch failed to
        // recognise as memory would let a pair through that the LSU cannot serve.
        if (MemRW1F !== {dut.core.ifu.Instr1D[6:0] == 7'b0000011, dut.core.ifu.Instr1D[6:0] == 7'b0100011})
          $fatal(1, "fieldscheck: MemRW mismatch at PC %h: Fetch said %b, decompressed opcode %h (raw %h)",
                 dut.core.ifu.Instr1PCD, MemRW1F, dut.core.ifu.Instr1D[6:0], dut.core.ifu.Instr1RawD);
      end
    final $display("fieldscheck: %0d slot-1 field extractions verified against the decompressor", FieldChecks);
  end

  if (P.ICACHE_SUPPORTED & P.SUPERSCALAR_SUPPORTED) begin : decode1check
    logic              AdvanceD;              // Decode is loading a new instruction this cycle
    logic              CheckPending;          // Decode advanced last cycle, so compare now
    logic              Instr1ValidPrev;
    logic [P.XLEN-1:0] Instr1PCPrev, ImmExt1Prev, R1_1Prev, R2_1Prev;
    logic [31:0]       Instr1RawPrev, Instr1Prev;
    logic [4:0]        Rs1_1Prev, Rs2_1Prev;
    logic [2:0]        ImmSrc1Prev;
    logic              Branch1Prev, Jump1Prev, Illegal1Prev;
    logic              CompressedNow, Slot0Squashed, R1Written, R2Written;
    integer            ChecksDone = 0;

    assign AdvanceD = ~reset & ~dut.core.ifu.StallD & ~dut.core.ifu.FlushD;
    always_ff @(posedge clk) begin
      if (AdvanceD) begin                                       // remember slot 1 as Decode is replaced
        Instr1ValidPrev <= dut.core.ifu.Instr1ValidD;
        Instr1PCPrev    <= dut.core.ifu.Instr1PCD;
        Instr1RawPrev   <= dut.core.ifu.Instr1RawD;
        Instr1Prev      <= dut.core.ifu.Instr1D;
        Rs1_1Prev       <= dut.core.ieu.Rs1_1D;
        Rs2_1Prev       <= dut.core.ieu.Rs2_1D;
        ImmSrc1Prev     <= dut.core.ieu.ImmSrc1D;
        ImmExt1Prev     <= dut.core.ieu.dp.ImmExt1D;
        R1_1Prev        <= dut.core.ieu.dp.R1_1D;
        R2_1Prev        <= dut.core.ieu.dp.R2_1D;
        Branch1Prev     <= dut.core.ieu.Branch1D;
        Jump1Prev       <= dut.core.ieu.Jump1D;
        Illegal1Prev    <= dut.core.ieu.IllegalBaseInstr1D;
        CheckPending    <= 1'b1;
      end else CheckPending <= 1'b0;
      // fence.i / I$ invalidate: memory may have changed, so the remembered slot 1 is stale
      if (dut.core.ifu.CSRWriteFenceM | dut.core.ifu.InvalidateICacheM) Instr1ValidPrev <= 1'b0;
    end

    assign CompressedNow = ~&dut.core.ifu.InstrRawD[1:0];
    assign Slot0Squashed = dut.core.ifu.IllegalIEUFPUInstrD;    // slot 0's controls are zeroed for an illegal instruction; slot 1's are not
    // a writeback in between the two reads changes the register file, so skip that operand
    assign R1Written = ((dut.core.ieu.RegWriteW  & (dut.core.ieu.RdW  == Rs1_1Prev)) |
                        (dut.core.ieu.RegWrite1W & (dut.core.ieu.Rd1W == Rs1_1Prev))) & (Rs1_1Prev != 0);
    assign R2Written = ((dut.core.ieu.RegWriteW  & (dut.core.ieu.RdW  == Rs2_1Prev)) |
                        (dut.core.ieu.RegWrite1W & (dut.core.ieu.Rd1W == Rs2_1Prev))) & (Rs2_1Prev != 0);

    always_ff @(posedge clk)
      if (CheckPending & Instr1ValidPrev & (dut.core.ifu.PCD == Instr1PCPrev)) begin
        ChecksDone <= ChecksDone + 1;
        if (CompressedNow ? (Instr1RawPrev[15:0] != dut.core.ifu.InstrRawD[15:0]) : (Instr1RawPrev != dut.core.ifu.InstrRawD))
          $fatal(1, "decode1check: raw mismatch at PC %h: slot 1 %h, slot 0 %h", dut.core.ifu.PCD, Instr1RawPrev, dut.core.ifu.InstrRawD);
        if (Instr1Prev != dut.core.ifu.InstrD)
          $fatal(1, "decode1check: decompressed mismatch at PC %h: slot 1 %h, slot 0 %h", dut.core.ifu.PCD, Instr1Prev, dut.core.ifu.InstrD);
        if ({Rs1_1Prev, Rs2_1Prev} != {dut.core.ieu.Rs1D, dut.core.ieu.Rs2D})
          $fatal(1, "decode1check: Rs1/Rs2 mismatch at PC %h: slot 1 x%0d/x%0d, slot 0 x%0d/x%0d", dut.core.ifu.PCD, Rs1_1Prev, Rs2_1Prev, dut.core.ieu.Rs1D, dut.core.ieu.Rs2D);
        if ({Branch1Prev, Jump1Prev, Illegal1Prev} != {dut.core.ieu.BranchD, dut.core.ieu.JumpD, dut.core.ieu.IllegalBaseInstrD})
          $fatal(1, "decode1check: branch/jump/illegal mismatch at PC %h: slot 1 %b, slot 0 %b", dut.core.ifu.PCD, {Branch1Prev, Jump1Prev, Illegal1Prev}, {dut.core.ieu.BranchD, dut.core.ieu.JumpD, dut.core.ieu.IllegalBaseInstrD});
        if (~Slot0Squashed & ({ImmSrc1Prev, ImmExt1Prev} != {dut.core.ieu.ImmSrcD, dut.core.ieu.dp.ImmExtD}))
          $fatal(1, "decode1check: immediate mismatch at PC %h: slot 1 src %b ext %h, slot 0 src %b ext %h", dut.core.ifu.PCD, ImmSrc1Prev, ImmExt1Prev, dut.core.ieu.ImmSrcD, dut.core.ieu.dp.ImmExtD);
        if (~R1Written & (R1_1Prev != dut.core.ieu.dp.R1D))
          $fatal(1, "decode1check: R1 mismatch at PC %h (x%0d): slot 1 %h, slot 0 %h", dut.core.ifu.PCD, Rs1_1Prev, R1_1Prev, dut.core.ieu.dp.R1D);
        if (~R2Written & (R2_1Prev != dut.core.ieu.dp.R2D))
          $fatal(1, "decode1check: R2 mismatch at PC %h (x%0d): slot 1 %h, slot 0 %h", dut.core.ifu.PCD, Rs2_1Prev, R2_1Prev, dut.core.ieu.dp.R2D);
      end

    // FP decode: slot 1's fctrl outputs and FP register-file reads must match slot 0's the next cycle
    if (P.F_SUPPORTED) begin : fpcheck
      logic [4:0]        FAdr1_1Prev, FAdr2_1Prev, FAdr3_1Prev;
      logic              XEn1Prev, YEn1Prev, ZEn1Prev, FIllegal1Prev;
      logic [P.FLEN-1:0] FRD1_1Prev, FRD2_1Prev, FRD3_1Prev;
      logic              F1Written, F2Written, F3Written;
      always_ff @(posedge clk)
        if (AdvanceD) begin
          {FAdr1_1Prev, FAdr2_1Prev, FAdr3_1Prev} <= {dut.core.fpu.fpu.Adr1_1D, dut.core.fpu.fpu.Adr2_1D, dut.core.fpu.fpu.Adr3_1D};
          {XEn1Prev, YEn1Prev, ZEn1Prev}          <= {dut.core.fpu.fpu.XEn1D, dut.core.fpu.fpu.YEn1D, dut.core.fpu.fpu.ZEn1D};
          FIllegal1Prev                           <= dut.core.fpu.fpu.IllegalFPUInstr1D;
          {FRD1_1Prev, FRD2_1Prev, FRD3_1Prev}    <= {dut.core.fpu.fpu.FRD1_1D, dut.core.fpu.fpu.FRD2_1D, dut.core.fpu.fpu.FRD3_1D};
        end
      // an FP writeback in between the two reads changes the register file, so skip that operand
      assign F1Written = dut.core.fpu.fpu.FRegWriteW & (dut.core.fpu.fpu.RdW == FAdr1_1Prev);
      assign F2Written = dut.core.fpu.fpu.FRegWriteW & (dut.core.fpu.fpu.RdW == FAdr2_1Prev);
      assign F3Written = dut.core.fpu.fpu.FRegWriteW & (dut.core.fpu.fpu.RdW == FAdr3_1Prev);
      always_ff @(posedge clk)
        if (CheckPending & Instr1ValidPrev & (dut.core.ifu.PCD == Instr1PCPrev)) begin
          if ({FAdr1_1Prev, FAdr2_1Prev, FAdr3_1Prev} != {dut.core.fpu.fpu.Adr1D, dut.core.fpu.fpu.Adr2D, dut.core.fpu.fpu.Adr3D})
            $fatal(1, "decode1check: FP Adr mismatch at PC %h: slot 1 f%0d/f%0d/f%0d, slot 0 f%0d/f%0d/f%0d", dut.core.ifu.PCD,
                   FAdr1_1Prev, FAdr2_1Prev, FAdr3_1Prev, dut.core.fpu.fpu.Adr1D, dut.core.fpu.fpu.Adr2D, dut.core.fpu.fpu.Adr3D);
          if ({XEn1Prev, YEn1Prev, ZEn1Prev, FIllegal1Prev} != {dut.core.fpu.fpu.XEnD, dut.core.fpu.fpu.YEnD, dut.core.fpu.fpu.ZEnD, dut.core.fpu.fpu.IllegalFPUInstrD})
            $fatal(1, "decode1check: FP XYZEn/illegal mismatch at PC %h: slot 1 %b, slot 0 %b", dut.core.ifu.PCD,
                   {XEn1Prev, YEn1Prev, ZEn1Prev, FIllegal1Prev}, {dut.core.fpu.fpu.XEnD, dut.core.fpu.fpu.YEnD, dut.core.fpu.fpu.ZEnD, dut.core.fpu.fpu.IllegalFPUInstrD});
          if (~F1Written & (FRD1_1Prev != dut.core.fpu.fpu.FRD1D))
            $fatal(1, "decode1check: FRD1 mismatch at PC %h (f%0d): slot 1 %h, slot 0 %h", dut.core.ifu.PCD, FAdr1_1Prev, FRD1_1Prev, dut.core.fpu.fpu.FRD1D);
          if (~F2Written & (FRD2_1Prev != dut.core.fpu.fpu.FRD2D))
            $fatal(1, "decode1check: FRD2 mismatch at PC %h (f%0d): slot 1 %h, slot 0 %h", dut.core.ifu.PCD, FAdr2_1Prev, FRD2_1Prev, dut.core.fpu.fpu.FRD2D);
          if (~F3Written & (FRD3_1Prev != dut.core.fpu.fpu.FRD3D))
            $fatal(1, "decode1check: FRD3 mismatch at PC %h (f%0d): slot 1 %h, slot 0 %h", dut.core.ifu.PCD, FAdr3_1Prev, FRD3_1Prev, dut.core.fpu.fpu.FRD3D);
        end
    end
    final $display("decode1check: %0d slot-1 decodes verified against slot 0", ChecksDone);
  end

  // Report how often the two slots actually issue together.  This is the headline number for the
  // superscalar work: it bounds the speedup the issue rules currently allow.
  if (P.ICACHE_SUPPORTED) begin : issuerate
    integer Retired = 0, RetiredPaired = 0;
    always_ff @(posedge clk)
      if (~reset & dut.core.ieu.c.InstrValidM & ~dut.core.ifu.StallW & ~dut.core.ifu.FlushW) begin
        Retired <= Retired + 1;
        // Not Issue1M alone: a replayed slot 1 is still in Memory but has not retired, and will be
        // counted when it runs again on its own.
        if (dut.core.ifu.Issue1M & ~dut.core.Replay1M) RetiredPaired <= RetiredPaired + 1;
      end
    final
      if (Retired > 0)
        $display("issuerate: %0d instructions retired, %0d of them paired (%0d%% of cycles dual-issued)",
                 Retired + RetiredPaired, RetiredPaired, (100 * RetiredPaired) / Retired);
  end

  // Cycles that issue nothing are either stalls or flushes.  Attribute them to a cause so a change
  // that pairs more instructions but runs slower can be diagnosed rather than guessed at.
  if (P.ICACHE_SUPPORTED & P.SUPERSCALAR_SUPPORTED) begin : overhead
    integer Cycles = 0, StallSlot0 = 0, StallSlot1 = 0, StallOther = 0, FlushMispredict = 0, Kills = 0;
    integer Replays = 0, Mem1 = 0;   // slot 1 memory operations, and how many had to be replayed
    integer LoadUse1 = 0, BundleStore = 0;  // the two bundle-level memory hazards, to confirm they fire
    integer Replay1Ld = 0, Replay1St = 0;   // which kind of slot 1 memory operation had to be replayed
    integer BrWithMem1 = 0;                 // taken branch in slot 0 alongside a memory operation in slot 1
    integer ReplayStoreLeak = 0;            // a replayed slot 1 store that the LSU was not told to cancel

    // Why a pair was refused.  Each counter records cycles where one term of Issue1F was the ONLY
    // thing holding the pair back, so it reads as the marginal headroom of fixing that term alone
    // rather than as a raw tally of a term that was one blocker among several.
    integer PairOpportunity = 0;            // slot 1 held a complete instruction but the pair was refused
    integer BlockBranch1 = 0;               // ... solely because slot 1 was a branch or jump
    integer BlockBranch1Aligned = 0;        // ... and the bundle was 8-byte aligned, so a block-indexed BTB would see it
    integer BlockCompressed = 0;            // ... solely because either slot was compressed
    integer BlockDep = 0;                   // ... solely because slot 1 depended on slot 0
    integer BlockSlot0 = 0;                 // ... solely because of slot 0 (predicted taken, jump, SYSTEM, fence)
    integer BlockOneMem = 0;                // ... solely because both slots wanted the load/store unit
    integer AnyCompressed = 0;              // ... compressed was A blocker, not necessarily the only one
    integer AnyDep = 0;                     // ... likewise for the dependency check
    integer BlockJump1 = 0;                 // ... solely because slot 1 was a jal/jalr (out of scope: the RAS)
    integer BlockMDU1 = 0;                  // ... solely because slot 1 was a divide (slot 1 has no divider)
    integer BlockOneMdu = 0;                // ... solely because both slots wanted the multiply/divide unit
    integer Mul1 = 0;                       // slot 1 multiplies that committed
    integer Div1 = 0;                       // slot 1 divides that committed
    integer KilledDiv1 = 0;                 // slot 1 divides in Execute beside a taken branch (must be 0)
    integer MulUse1 = 0;                    // cycles stalled because a slot 1 multiply's product was not ready
    integer DepSlot1Load = 0, DepSameRdOnly = 0, DepSameRd = 0, DepSlot0Late = 0, DepSlot1Op = 0; // dependency blocks: same rd, slot 0 result late, slot 1 not a late-ALU op
    integer LateBr = 0, LateBrWrong = 0;   // branches resolved in Memory, and how many fetch got wrong
    integer Late1 = 0;                      // bundles whose slot 1 executed on the late ALU
    integer Fused = 0, Unfused = 0;         // indexed-load fusions retired / replayed unfused after a fault
    integer FusedBr = 0;                    // ALU op + branch fusions leaving Execute
    integer LateUse1 = 0;                   // cycles stalled because a late slot 1's result was not ready
    integer BlockUnrec0 = 0;                // ... solely because SLOT 0's encoding is not in instrfields
    integer BlockUnrec1 = 0;                // ... solely because SLOT 1's is
    logic Cfi1F, Br1F, Jmp1F, Refused;
    assign Br1F    = (dut.core.ifu.dualissue.issue.Op1F == 7'b1100011);   // branch
    assign Jmp1F   = (dut.core.ifu.dualissue.issue.Op1F == 7'b1101111)    // jal
                   | (dut.core.ifu.dualissue.issue.Op1F == 7'b1100111);   // jalr
    assign Cfi1F   = Br1F | Jmp1F;
    assign Refused = dut.core.ifu.dualissue.issue.Instr1ValidF & ~dut.core.ifu.Issue1F;

    logic Slot1Stall;
    // The slot 1 hazard only costs anything when slot 0 was not already stalling for its own reasons
    assign Slot1Stall = dut.core.ieu.Issue1D & dut.core.ieu.StructuralStall1D
                        & ~dut.core.ieu.StructuralStall0D;
    always_ff @(posedge clk)
      if (~reset) begin
        Cycles <= Cycles + 1;
        if (dut.core.StallD) begin
          if (dut.core.ieu.StructuralStall0D) StallSlot0 <= StallSlot0 + 1;
          else if (Slot1Stall)                StallSlot1 <= StallSlot1 + 1;
          else                                StallOther <= StallOther + 1;
        end
        // "Solely" means every other term of Issue1F was satisfied, so this one term is what cost
        // the pair.  A cycle blocked by two terms is counted in neither, which is the point: fixing
        // one of them would not have paired it.
        if (Refused) begin
          PairOpportunity <= PairOpportunity + 1;
          if (~dut.core.ifu.dualissue.issue.Slot1CanPairF & Cfi1F
              & dut.core.ifu.dualissue.issue.BothRecognizedF & dut.core.ifu.dualissue.issue.Slot0CanPairF
              & dut.core.ifu.dualissue.issue.DependencyOKF    & dut.core.ifu.dualissue.issue.OneMemOpF & dut.core.ifu.dualissue.issue.OneMduOpF) begin
            if (Br1F) begin
              BlockBranch1 <= BlockBranch1 + 1;
              if (~dut.core.ifu.PCF[2]) BlockBranch1Aligned <= BlockBranch1Aligned + 1;
            end else BlockJump1 <= BlockJump1 + 1;
          end
          // A slot 1 divide is refused by ~MExtF inside Slot1CanPairF, so it needs its own attribution:
          // it is not a branch, a jump, compressed, a dependency or a memory clash.  Multiplies pair, so
          // since slot 1 multiplies were admitted this counts divides only.
          if (~dut.core.ifu.dualissue.issue.Slot1CanPairF & dut.core.ifu.dualissue.issue.MExtF & ~Cfi1F
              & dut.core.ifu.dualissue.issue.BothRecognizedF & dut.core.ifu.dualissue.issue.Slot0CanPairF
              & dut.core.ifu.dualissue.issue.DependencyOKF   & dut.core.ifu.dualissue.issue.OneMemOpF & dut.core.ifu.dualissue.issue.OneMduOpF)
            BlockMDU1 <= BlockMDU1 + 1;
          if (~dut.core.ifu.dualissue.issue.OneMduOpF
              & dut.core.ifu.dualissue.issue.BothRecognizedF & dut.core.ifu.dualissue.issue.Slot0CanPairF
              & dut.core.ifu.dualissue.issue.Slot1CanPairF     & dut.core.ifu.dualissue.issue.DependencyOKF & dut.core.ifu.dualissue.issue.OneMemOpF)
            BlockOneMdu <= BlockOneMdu + 1;
          if (~dut.core.ifu.dualissue.issue.BothRecognizedF) AnyCompressed <= AnyCompressed + 1;
          if (~dut.core.ifu.dualissue.issue.DependencyOKF)      AnyDep        <= AnyDep + 1;
          if (~dut.core.ifu.dualissue.issue.BothRecognizedF
              & dut.core.ifu.dualissue.issue.Slot0CanPairF & dut.core.ifu.dualissue.issue.Slot1CanPairF
              & dut.core.ifu.dualissue.issue.DependencyOKF & dut.core.ifu.dualissue.issue.OneMemOpF & dut.core.ifu.dualissue.issue.OneMduOpF) begin
            BlockCompressed <= BlockCompressed + 1;
            // Which slot's encoding instrfields failed to recognise.  A gap in slot 0 is pure
            // conservatism -- slot 0 executes everything it always did -- so it bounds what the
            // class-split change would recover without any datapath work.
            if (~dut.core.ifu.dualissue.issue.Recognized0F) BlockUnrec0 <= BlockUnrec0 + 1;
            if (~dut.core.ifu.dualissue.issue.Recognized1F) BlockUnrec1 <= BlockUnrec1 + 1;
          end
          if (~dut.core.ifu.dualissue.issue.DependencyOKF
              & dut.core.ifu.dualissue.issue.BothRecognizedF & dut.core.ifu.dualissue.issue.Slot0CanPairF
              & dut.core.ifu.dualissue.issue.Slot1CanPairF    & dut.core.ifu.dualissue.issue.OneMemOpF & dut.core.ifu.dualissue.issue.OneMduOpF)
          begin
            BlockDep <= BlockDep + 1;
            // Why the late ALU could not take it.  Not exclusive: a pair can fail several ways.
            if (dut.core.ifu.dualissue.issue.SameRdF)                                  DepSameRd   <= DepSameRd + 1;
            // ... and how many of those were refused only for the shared destination
            if (dut.core.ifu.dualissue.issue.SameRdF & (~dut.core.ifu.dualissue.issue.SrcDepF |
                (dut.core.ifu.dualissue.issue.Slot0EarlyF & dut.core.ifu.dualissue.issue.Slot1LateOKF))) DepSameRdOnly <= DepSameRdOnly + 1;
            if (dut.core.ifu.dualissue.issue.SrcDepF & ~dut.core.ifu.dualissue.issue.Slot0EarlyF)  DepSlot0Late <= DepSlot0Late + 1;
            if (dut.core.ifu.dualissue.issue.SrcDepF & ~dut.core.ifu.dualissue.issue.Slot1LateOKF) DepSlot1Op  <= DepSlot1Op + 1;
            // ... of which a slot 1 load whose address comes from a slot 0 ALU result: what a late
            // address into the LSU could take
            if (dut.core.ifu.dualissue.issue.SrcDepF & ~dut.core.ifu.dualissue.issue.SameRdF & dut.core.ifu.dualissue.issue.Slot0EarlyF
                & dut.core.ifu.dualissue.issue.MemRW1F[1])                                DepSlot1Load <= DepSlot1Load + 1;
          end
          if (~dut.core.ifu.dualissue.issue.Slot0CanPairF
              & dut.core.ifu.dualissue.issue.BothRecognizedF & dut.core.ifu.dualissue.issue.Slot1CanPairF
              & dut.core.ifu.dualissue.issue.DependencyOKF     & dut.core.ifu.dualissue.issue.OneMemOpF & dut.core.ifu.dualissue.issue.OneMduOpF)
            BlockSlot0 <= BlockSlot0 + 1;
          if (~dut.core.ifu.dualissue.issue.OneMemOpF
              & dut.core.ifu.dualissue.issue.BothRecognizedF & dut.core.ifu.dualissue.issue.Slot0CanPairF
              & dut.core.ifu.dualissue.issue.Slot1CanPairF     & dut.core.ifu.dualissue.issue.DependencyOKF & dut.core.ifu.dualissue.issue.OneMduOpF)
            BlockOneMem <= BlockOneMem + 1;
        end
        if (dut.core.ifu.BPWrongE)                             FlushMispredict <= FlushMispredict + 1;
        if (dut.core.ifu.Kill1E & dut.core.ifu.Issue1E)         Kills <= Kills + 1;
        if (dut.core.Mem1M & ~dut.core.StallM)                  Mem1 <= Mem1 + 1;
        if (dut.core.Replay1M & ~dut.core.StallM)               Replays <= Replays + 1;
        if (dut.core.ieu.LoadStall1D       & ~dut.core.StallE)  LoadUse1    <= LoadUse1 + 1;
        if (dut.core.ieu.MDUStall1D        & ~dut.core.StallE)  MulUse1     <= MulUse1 + 1;
        if (dut.core.ieu.LateStall1D       & ~dut.core.StallE)  LateUse1    <= LateUse1 + 1;
        if (dut.core.LateBrM & ~dut.core.StallM & ~dut.core.FlushW) begin
          LateBr <= LateBr + 1;
          if (dut.core.LateBrWrongM) LateBrWrong <= LateBrWrong + 1;
        end
        if (dut.core.ieu.dp.Late1M & dut.core.ifu.Issue1M & ~dut.core.StallM & ~dut.core.FlushM) Late1 <= Late1 + 1;
        // A replay flushes Memory itself, so it is counted without the ~FlushM qualifier.
        if (dut.core.FuseM & ~dut.core.StallM & dut.core.Replay1M)              Unfused <= Unfused + 1;
        else if (dut.core.FuseM & ~dut.core.StallM & ~dut.core.FlushM)          Fused   <= Fused + 1;
        if ((dut.core.ieu.FuseBrA1E | dut.core.ieu.FuseBrB1E) & ~dut.core.StallE) FusedBr <= FusedBr + 1;
        if (dut.core.ieu.Mdu1M & dut.core.ifu.Issue1M & ~dut.core.StallM & ~dut.core.FlushM) begin
          if (dut.core.ieu.MDUFunct3M[2]) Div1 <= Div1 + 1;
          else                            Mul1 <= Mul1 + 1;
        end
        // The divider acts as soon as it starts, so a slot 1 divide must never share Execute with a
        // slot 0 branch that resolves taken: the divide would run for an instruction that is then
        // squashed.  issue.sv refuses that pair; this catches anyone relaxing the rule.
        if (dut.core.ieu.Mdu1E & dut.core.ieu.IntDiv1E & dut.core.PCSrcE) begin
          KilledDiv1 <= KilledDiv1 + 1;
          $error("slot 1 divide in Execute beside a taken slot 0 branch");
        end
        if (dut.core.ieu.BundleStoreStallD & ~dut.core.StallE)  BundleStore <= BundleStore + 1;
        if (dut.core.Replay1M & ~dut.core.StallM & dut.core.ieu.MemRW1M[1]) Replay1Ld <= Replay1Ld + 1;
        if (dut.core.Replay1M & ~dut.core.StallM & dut.core.ieu.MemRW1M[0]) Replay1St <= Replay1St + 1;
        if (dut.core.PCSrcE & (|dut.core.ieu.MemRW1E) & ~dut.core.StallE)   BrWithMem1 <= BrWithMem1 + 1;
        // A replayed slot 1 store must never reach memory: the instruction is about to be refetched and
        // trap, so the handler has to find state unmodified.  A replay withholds FlushW so slot 0 can
        // commit; the LSU cancels the write itself instead, because the store's own fault drives
        // LSUFlushW (SelfFaultM in lsu.sv).  This must never fire.
        if (dut.core.Replay1M & dut.core.Mem1M & dut.core.ieu.MemRW1M[0] & ~dut.core.lsu.LSUFlushW) begin
          ReplayStoreLeak <= ReplayStoreLeak + 1;
          $error("replayed slot 1 store was not cancelled at the LSU: the write will reach memory");
        end
      end
    // Brainstorming breakdowns (measurement only).
    integer Slot0Jump = 0, Slot0PredTaken = 0, Slot0System = 0, Slot0Fence = 0;   // why slot 0 could not carry a partner
    integer DepSlot1Mul = 0, DepSlot1Other = 0;                              // dependent slot 1 the late ALU lacks
    integer LateUseSlot0 = 0, LateUseSlot1Only = 0, LateUseSlot1OnlyAlu = 0;    // late-use stall: who consumed
    integer LoadUseSlot0 = 0, LoadUseSlot1Only = 0, LoadUseSlot1OnlyAlu = 0;    // load-use stall: who consumed
    logic [6:0] Op1D; logic [6:0] F7_1D; logic Slot1BaseAluD;
    logic Slot0LoadUseD, Slot1LoadUseD, Slot0LateUseD, Slot1LateUseD;
    assign Op1D  = dut.core.ieu.Instr1D[6:0];
    assign F7_1D = dut.core.ieu.Instr1D[31:25];
    // Slot 1 in Decode is an operation a late ALU could do (approximate: base OP/OP-IMM forms)
    assign Slot1BaseAluD = (Op1D == 7'b0010011) | (Op1D == 7'b0011011) |
                        (((Op1D == 7'b0110011) | (Op1D == 7'b0111011)) & ((F7_1D == 7'b0) | (F7_1D == 7'b0100000)));
    assign Slot0LoadUseD = (dut.core.ieu.c.MemReadE & (dut.core.ieu.RdE != 0) &
                         ((dut.core.ieu.Rs1D == dut.core.ieu.RdE) | (dut.core.ieu.Rs2D == dut.core.ieu.RdE))) |
                        (dut.core.ieu.MemRW1E[1] & (dut.core.ieu.Rd1E != 0) &
                         ((dut.core.ieu.Rs1D == dut.core.ieu.Rd1E) | (dut.core.ieu.Rs2D == dut.core.ieu.Rd1E)));
    assign Slot1LoadUseD = dut.core.ieu.Issue1D &
                        ((dut.core.ieu.c.MemReadE & (dut.core.ieu.RdE != 0) &
                          ((dut.core.ieu.Rs1_1D == dut.core.ieu.RdE) | (dut.core.ieu.Rs2_1D == dut.core.ieu.RdE))) |
                         (dut.core.ieu.MemRW1E[1] & (dut.core.ieu.Rd1E != 0) &
                          ((dut.core.ieu.Rs1_1D == dut.core.ieu.Rd1E) | (dut.core.ieu.Rs2_1D == dut.core.ieu.Rd1E))));
    assign Slot0LateUseD = dut.core.ieu.Late1E & (dut.core.ieu.Rd1E != 0) &
                        ((dut.core.ieu.Rs1D == dut.core.ieu.Rd1E) | (dut.core.ieu.Rs2D == dut.core.ieu.Rd1E));
    assign Slot1LateUseD = dut.core.ieu.Late1E & dut.core.ieu.Issue1D & (dut.core.ieu.Rd1E != 0) &
                        ((dut.core.ieu.Rs1_1D == dut.core.ieu.Rd1E) | (dut.core.ieu.Rs2_1D == dut.core.ieu.Rd1E));
    always_ff @(posedge clk)
      if (~reset) begin
        if (Refused & ~dut.core.ifu.dualissue.issue.Slot0CanPairF
            & dut.core.ifu.dualissue.issue.BothRecognizedF & dut.core.ifu.dualissue.issue.Slot1CanPairF
            & dut.core.ifu.dualissue.issue.DependencyOKF & dut.core.ifu.dualissue.issue.OneMemOpF & dut.core.ifu.dualissue.issue.OneMduOpF) begin
          if ((dut.core.ifu.dualissue.issue.Op0F == 7'b1101111) | (dut.core.ifu.dualissue.issue.Op0F == 7'b1100111)) Slot0Jump <= Slot0Jump + 1;
          else if (dut.core.ifu.dualissue.issue.BPPCSrcF)                                                  Slot0PredTaken <= Slot0PredTaken + 1;
          else if (dut.core.ifu.dualissue.issue.Op0F == 7'b1110011)                                         Slot0System <= Slot0System + 1;
          else                                                                                    Slot0Fence <= Slot0Fence + 1;
        end
        if (Refused & ~dut.core.ifu.dualissue.issue.DependencyOKF & dut.core.ifu.dualissue.issue.BothRecognizedF
            & dut.core.ifu.dualissue.issue.Slot0CanPairF & dut.core.ifu.dualissue.issue.Slot1CanPairF
            & dut.core.ifu.dualissue.issue.OneMemOpF & dut.core.ifu.dualissue.issue.OneMduOpF
            & dut.core.ifu.dualissue.issue.SrcDepF & ~dut.core.ifu.dualissue.issue.SameRdF & dut.core.ifu.dualissue.issue.Slot0EarlyF
            & ~dut.core.ifu.dualissue.issue.Slot1LateOKF & ~dut.core.ifu.dualissue.issue.MemRW1F[1]) begin
          if (dut.core.ifu.dualissue.issue.MExtF) DepSlot1Mul <= DepSlot1Mul + 1;
          else                          DepSlot1Other <= DepSlot1Other + 1;
        end
        if (dut.core.StallD & ~dut.core.StallE & ~dut.core.FlushD) begin
          if (Slot0LoadUseD) LoadUseSlot0 <= LoadUseSlot0 + 1;
          else if (Slot1LoadUseD) begin
            LoadUseSlot1Only <= LoadUseSlot1Only + 1;
            if (Slot1BaseAluD) LoadUseSlot1OnlyAlu <= LoadUseSlot1OnlyAlu + 1;
          end
          if (Slot0LateUseD) LateUseSlot0 <= LateUseSlot0 + 1;
          else if (Slot1LateUseD) begin
            LateUseSlot1Only <= LateUseSlot1Only + 1;
            if (Slot1BaseAluD) LateUseSlot1OnlyAlu <= LateUseSlot1OnlyAlu + 1;
          end
        end
      end
    final
      $display("brainstorm: slot0-unpairable jump=%0d predtaken=%0d system=%0d fence=%0d | dep slot1 not late: mul=%0d other(bitmanip)=%0d | loaduse consumer slot0=%0d slot1only=%0d (base ALU %0d) | lateuse consumer slot0=%0d slot1only=%0d (base ALU %0d)",
               Slot0Jump, Slot0PredTaken, Slot0System, Slot0Fence, DepSlot1Mul, DepSlot1Other, LoadUseSlot0, LoadUseSlot1Only, LoadUseSlot1OnlyAlu, LateUseSlot0, LateUseSlot1Only, LateUseSlot1OnlyAlu);

    // Could slot 0's load-use consumer have used a shared late ALU?  Upper bounds, per stall cycle.
    integer Slot0LU_Alu = 0, Slot0LU_AluConflict = 0, Slot0LU_StoreData = 0, Slot0LU_Branch = 0, Slot0LU_Other = 0;
    logic [6:0] Op0D; logic [6:0] F7_0D; logic Slot0BaseAluD, LdRs1, LdRs2, Slot1WantsLate;
    logic [4:0] Rs1_0D, Rs2_0D;
    assign Op0D  = dut.core.ieu.InstrD[6:0];
    assign F7_0D = dut.core.ieu.InstrD[31:25];
    assign Rs1_0D = dut.core.ieu.Rs1D;
    assign Rs2_0D = dut.core.ieu.Rs2D;
    assign Slot0BaseAluD = (Op0D == 7'b0010011) | (Op0D == 7'b0011011) |
                        (((Op0D == 7'b0110011) | (Op0D == 7'b0111011)) & ((F7_0D == 7'b0) | (F7_0D == 7'b0100000)));
    // Which of slot 0's sources are a load's destination in Execute (either slot)
    assign LdRs1 = (dut.core.ieu.c.MemReadE & (dut.core.ieu.RdE != 0) & (Rs1_0D == dut.core.ieu.RdE)) |
                   (dut.core.ieu.MemRW1E[1] & (dut.core.ieu.Rd1E != 0) & (Rs1_0D == dut.core.ieu.Rd1E));
    assign LdRs2 = (dut.core.ieu.c.MemReadE & (dut.core.ieu.RdE != 0) & (Rs2_0D == dut.core.ieu.RdE)) |
                   (dut.core.ieu.MemRW1E[1] & (dut.core.ieu.Rd1E != 0) & (Rs2_0D == dut.core.ieu.Rd1E));
    // Slot 1 of the same bundle also needs the one late ALU: it reads slot 0, or it is a load-use consumer itself
    assign Slot1WantsLate = dut.core.ieu.Issue1D & (dut.core.ieu.LateA1D | dut.core.ieu.LateB1D | Slot1LoadUseD);
    always_ff @(posedge clk)
      if (~reset & dut.core.StallD & ~dut.core.StallE & ~dut.core.FlushD & Slot0LoadUseD) begin
        if (Slot0BaseAluD) begin
          if (Slot1WantsLate) Slot0LU_AluConflict <= Slot0LU_AluConflict + 1;
          else             Slot0LU_Alu <= Slot0LU_Alu + 1;
        end
        else if ((Op0D == 7'b0100011) & LdRs2 & ~LdRs1) Slot0LU_StoreData <= Slot0LU_StoreData + 1;
        else if (Op0D == 7'b1100011)                    Slot0LU_Branch <= Slot0LU_Branch + 1;
        else                                            Slot0LU_Other <= Slot0LU_Other + 1;
      end
    // Of those, how often the next bundle reads the ALU op's result: a shared late ALU would only move
    // that stall one bundle later.
    integer Slot0LU_NextDep = 0, Slot0LU_Seen = 0;
    logic Cand, CandLeft; logic [4:0] CandRd;
    always_ff @(posedge clk)
      if (reset) begin Cand <= 0; CandLeft <= 0; end
      else begin
        if (dut.core.StallD & ~dut.core.StallE & ~dut.core.FlushD & Slot0LoadUseD & Slot0BaseAluD & ~Slot1WantsLate) begin
          Cand <= 1; CandRd <= dut.core.ieu.InstrD[11:7];
        end else if (Cand & ~dut.core.StallD) begin Cand <= 0; CandLeft <= 1; end
        if (CandLeft & ~dut.core.FlushD & dut.core.ifu.InstrValidD) begin
          CandLeft <= 0; Slot0LU_Seen <= Slot0LU_Seen + 1;
          if ((CandRd != 0) & ((dut.core.ieu.Rs1D == CandRd) | (dut.core.ieu.Rs2D == CandRd) |
              (dut.core.ieu.Issue1D & ((dut.core.ieu.Rs1_1D == CandRd) | (dut.core.ieu.Rs2_1D == CandRd)))))
            Slot0LU_NextDep <= Slot0LU_NextDep + 1;
        end else if (CandLeft & dut.core.FlushD) CandLeft <= 0;
      end
    // Load-dependent branches: how many were mispredicted anyway.  Resolving these in Memory from the
    // load data would remove the stall for the rest, at one extra cycle on each of these.
    integer LdBrSeen = 0, LdBrWrong = 0;
    logic BrCand, BrInE;
    always_ff @(posedge clk)
      if (reset) begin BrCand <= 0; BrInE <= 0; end
      else begin
        BrInE <= 0;
        if (dut.core.StallD & ~dut.core.StallE & ~dut.core.FlushD & Slot0LoadUseD & (Op0D == 7'b1100011)) BrCand <= 1;
        else if (BrCand & ~dut.core.StallD) begin BrCand <= 0; BrInE <= ~dut.core.FlushD; end
        if (BrInE & ~dut.core.StallE) begin
          LdBrSeen <= LdBrSeen + 1;
          if (dut.core.ifu.BPWrongE) LdBrWrong <= LdBrWrong + 1;
        end
      end
    final $display("load-dependent branches: %0d reached Execute, %0d mispredicted", LdBrSeen, LdBrWrong);
    final $display("slot0 load-use ALU candidates: next bundle reads its result in %0d of %0d", Slot0LU_NextDep, Slot0LU_Seen);
    final
      $display("slot0 load-use: base ALU=%0d (+%0d where slot 1 also needs the late ALU) | store data only=%0d | branch=%0d | other (load/store address, jalr, ...)=%0d",
               Slot0LU_Alu, Slot0LU_AluConflict, Slot0LU_StoreData, Slot0LU_Branch, Slot0LU_Other);

    // minstret must equal the number of instructions actually committed.  Both count from reset and
    // use the same condition, so any difference is the counter being wrong -- which matters because
    // a slot 1 abandoned in Execute must not be counted as retired.
    integer Committed = 0;
    always_ff @(posedge clk)
      if (~reset & dut.core.ieu.c.InstrValidM & ~dut.core.StallW & ~dut.core.FlushW)
        Committed <= Committed + 1 + ((dut.core.ifu.Issue1M & ~dut.core.Replay1M & ~dut.core.LateBrWrongM) ? 1 : 0);

    final begin
      $display("overhead: %0d cycles | stall slot0=%0d slot1=%0d other=%0d | mispredict=%0d | slot1 kills=%0d | slot1 mem=%0d replays=%0d | slot1 mul=%0d div=%0d | hazards: loaduse1=%0d muluse1=%0d bundlestore=%0d | replay ld=%0d st=%0d | branch+slot1mem=%0d | replay store leaks=%0d (must be 0) | killed slot1 divs=%0d (must be 0)",
               Cycles, StallSlot0, StallSlot1, StallOther, FlushMispredict, Kills, Mem1, Replays, Mul1, Div1, LoadUse1, MulUse1, BundleStore, Replay1Ld, Replay1St, BrWithMem1, ReplayStoreLeak, KilledDiv1);
      $display("pairing refused: %0d opportunities | sole cause: branch in slot1=%0d (8B-aligned=%0d) jump in slot1=%0d div in slot1=%0d compressed=%0d dependency=%0d slot0=%0d onemem=%0d onemdu=%0d (unrec slot0=%0d slot1=%0d) | any-cause: compressed=%0d dependency=%0d",
               PairOpportunity, BlockBranch1, BlockBranch1Aligned, BlockJump1, BlockMDU1, BlockCompressed, BlockDep, BlockSlot0, BlockOneMem, BlockOneMdu, BlockUnrec0, BlockUnrec1, AnyCompressed, AnyDep);
      $display("late branch: resolved in Memory=%0d, of which fetch went the wrong way=%0d", LateBr, LateBrWrong);
      $display("late ALU: slot1 late=%0d | lateuse1 stalls=%0d | dependency still refused: same rd=%0d (only cause %0d) slot0 not ALU=%0d slot1 not late op=%0d (dependent load after ALU op=%0d)",
               Late1, LateUse1, DepSameRd, DepSameRdOnly, DepSlot0Late, DepSlot1Op, DepSlot1Load);
      $display("fusion: indexed loads fused=%0d, replayed unfused after a fault=%0d | ALU+branch fused=%0d", Fused, Unfused, FusedBr);
      if (P.ZICSR_SUPPORTED)
        $display("minstret check: committed=%0d minstret=%0d %s", Committed,
                 dut.core.priv.priv.csr.counters.HPMCOUNTER_REGW[2],
                 (Committed == dut.core.priv.priv.csr.counters.HPMCOUNTER_REGW[2]) ? "MATCH" : "*** MISMATCH ***");
    end
  end



  // watch for problems such as lockup, reading uninitialized memory, bad configs
`ifdef MEMPIPE_PROBE
  `include "mempipeprobe.svh"
`endif
  watchdog #(P.XLEN, 1000000) watchdog(.clk, .reset, .TEST);  // check if PCW is stuck
  ramxdetector #(P.XLEN, P.LLEN) ramxdetector(clk, dut.core.lsu.MemRWM[1], dut.core.TrapM, dut.core.lsu.ReadDataM,
                                      dut.core.ifu.PCM, InstrM, dut.core.lsu.IEUAdrM, dut.core.lsu.StallW, InstrMName);
  riscvassertions       #(P) riscvassertions();     // check assertions for a legal architectural configuration
  riscvassertions_wally #(P) riscvassertions_wally();  // check assertions for a legal microarchitectural configuration
  loggers #(P, PrintHPMCounters, I_CACHE_ADDR_LOGGER, D_CACHE_ADDR_LOGGER, BPRED_LOGGER)
    loggers (clk, reset, EndTest, memfilename, sim_log_prefix, TEST);

  // track the current function or global label
  if (DEBUG > 0 | ((PrintHPMCounters | BPRED_LOGGER) & P.ZICNTR_SUPPORTED)) begin : functionName
    functionName #(P) functionName(.reset(reset_ext | TestBenchReset),
            .clk(clk), .ProgramAddrMapFile(ProgramAddrMapFile), .ProgramLabelMapFile(ProgramLabelMapFile));
  end

  // Optionally log UART output to file (always on for buildroot, enable with +UART_LOG=1)
  if (P.UART_SUPPORTED) begin: uart_logger
    always @(posedge clk) begin
      if (uartoutfile) begin
        if (~dut.uncoregen.uncore.uartgen.uart.MEMWb & dut.uncoregen.uncore.uartgen.uart.uartPC.A == 3'b000 & ~dut.uncoregen.uncore.uartgen.uart.uartPC.DLAB) begin
          $fwrite(uartoutfile, "%c", dut.uncoregen.uncore.uartgen.uart.uartPC.Din); // append characters one at a time so we see a consistent log appearing during the run
          $fflush(uartoutfile);
        end
      end
    end
  end

  // Termination condition
  // Terminate on
  // 1. jump to self loop (0x0000006f)
  // 2. a store word writes a test result (not an HTIF console putchar) to the address "tohost"
  // 3. or PC is stuck at 0


  logic              StoreSWM, StoreSDM;   // a word / doubleword store is in Memory, from either slot
  logic [P.XLEN-1:0] PCM;
  // PCM is not valid for configurations without ZICSR or branch predictor
  flopenr #(P.XLEN) PCMReg(clk, reset, ~dut.core.StallM, dut.core.PCE, PCM);
  // tohost follows HTIF: a store whose bits 63:48 are device 1, command 1 is a console putchar
  // of bits 7:0, which configurations without a UART use for console output.  Any other store to
  // tohost reports the test result.  RV32 stores the upper word to tohost+4 before the lower word.
  // A superscalar slot 1 store has no InstrMName to recognise it by, so its width comes from the
  // control the LSU acts on.  Mem1M says the bundle's memory operation is slot 1's, and the LSU's
  // address, data and funct3 are then all slot 1's.  Funct3 is unambiguous because the issue rules
  // keep AMOs and store-conditional in slot 0.
  assign StoreSWM = dut.core.Mem1M ? (dut.core.MemRWM[0] & (dut.core.MemFunct3M == 3'b010)) : (InstrMName == "SW");
  assign StoreSDM = dut.core.Mem1M ? (dut.core.MemRWM[0] & (dut.core.MemFunct3M == 3'b011)) : (InstrMName == "SD");
  assign TohostStore   = (dut.core.lsu.IEUAdrM == tohost_addr & tohost_addr != 0) & (StoreSWM | StoreSDM);
  assign TohostHiStore = (dut.core.lsu.IEUAdrM == tohost_addr + 4 & tohost_addr != 0) & StoreSWM;
  assign TohostWord    = StoreSDM ? 64'(dut.core.WriteDataM) : {TohostHi, dut.core.WriteDataM[31:0]};
  assign HtifPutchar   = TohostStore & (TohostWord[63:48] == 16'h0101);
  assign TohostWrite   = TohostStore & ~HtifPutchar;
  always @(posedge clk) begin
    if (SelectTest) TohostHi <= '0;
    else if (TohostHiStore & dut.core.InstrValidM & ~dut.core.StallM) TohostHi <= dut.core.WriteDataM[31:0];
    if (HtifPutchar & dut.core.InstrValidM & ~dut.core.StallM) begin
      $write("%c", TohostWord[7:0]);
      if (uartoutfile) begin
        $fwrite(uartoutfile, "%c", TohostWord[7:0]);
        $fflush(uartoutfile);
      end
    end
  end
  always @(posedge clk) begin
    TestComplete <= ((InstrM == 32'h6f) & dut.core.InstrValidM ) | TohostWrite; // |
    // Capture the result as it is stored, so the check does not depend on the store reaching memory
    if (SelectTest) TohostValue <= 0;
    else if (TohostWrite) TohostValue <= dut.core.WriteDataM[31:0];
    //   (functionName.PCM == 0 & dut.core.ifu.InstrM == 0 & dut.core.InstrValidM & PrevPCZero));
    if (reset) PrevPCZero <= 0;
    else if (dut.core.InstrValidM) PrevPCZero <= (PCM == 0 & dut.core.ifu.InstrM == 0);
    if (PCM == 0 & dut.core.ifu.InstrM == 0 & dut.core.InstrValidM & PrevPCZero) begin
      $error("Program fetched illegal instruction 0x00000000 from address 0x00000000 twice in a row.  Usually due to fault with no fault handler.");
      $fatal(1);
    end
  end

  // Capture the words a test stores to begin_signature (embench's timing and result) as they are stored,
  // like the tohost value, so the result does not depend on the stores reaching memory
  logic [P.XLEN-1:0] SigOffset;
  assign SigOffset = dut.core.lsu.IEUAdrM - begin_signature_addr;
  always @(posedge clk)
    if (SelectTest) Signature <= '{default: '0};
    else if (begin_signature_addr != 0 & SigOffset < SIG_WORDS*P.XLEN/8 & dut.core.InstrValidM & ~dut.core.StallM) begin
      if (InstrMName == "SD") Signature[SigOffset/(P.XLEN/8)] <= dut.core.WriteDataM;
      else if (InstrMName == "SW") Signature[SigOffset/(P.XLEN/8)][32*SigOffset[2]*(P.XLEN/64) +: 32] <= dut.core.WriteDataM[31:0];
    end

  // The privileged unit, and with it minstret, only exists when ZICSR is supported
  if (P.ZICSR_SUPPORTED) begin : instrlimit
    logic [P.XLEN-1:0] Minstret;
    assign Minstret = testbench.dut.core.priv.priv.csr.counters.HPMCOUNTER_REGW[2];
    always @(negedge clk) begin
      if (INSTR_LIMIT > 0) begin
        if((Minstret != 0) & (Minstret % 'd100000 == 0)) $display("Reached %d instructions", Minstret);
        if((Minstret == INSTR_LIMIT) & (INSTR_LIMIT!=0)) begin $finish; end
      end
    end
  end

// RVVI trace for functional coverage and lockstep
`ifdef ENABLE_RVVI_TRACE
  // RETIRE=2: the superscalar core can retire two instructions in one cycle, and each needs its own
  // RVVI record or the reference model falls a instruction behind and never catches up.
  rvviTrace #(.XLEN(P.XLEN), .FLEN(P.FLEN), .RETIRE(2)) rvvi();
  wallyTracer #(P) wallyTracer(rvvi);
`endif

// Functional coverage.  riscv_arch_test comes from riscv-arch-test and samples the generated
// covergroups off the RVVI trace; each simulator's compile script supplies it and its include paths with --fcov.
`ifdef FCOV
  riscv_arch_test riscv_arch_test(rvvi);
`endif

  ////////////////////////////////////////////////////////////////////////////////
  // ImperasDV Co-simulator hooks
  ////////////////////////////////////////////////////////////////////////////////
`ifdef USE_IMPERAS_DV

  // enabling of comparison types
  trace2api #(.CMP_PC      (1),
              .CMP_INS     (1),
              .CMP_GPR     (1),
              .CMP_FPR     (P.F_SUPPORTED),
              .CMP_VR      (0),
              .CMP_CSR     (P.ZICSR_SUPPORTED)
              ) idv_trace2api(rvvi);
  trace2log idv_trace2log(rvvi); // enable Imperas tracer

  string filename;
  initial begin
    // imperasDV requires the elffile be defined at the beginning of the simulation.
    int iter;
    longint x64;
    int     x32[2];
    longint index;
    string  memfilenameImperasDV, bootmemfilenameImperasDV;
    #1;
    IDV_MAX_ERRORS = 3;
    elffilename = ElfFile;

    // Initialize REF (do this before initializing the DUT)
    if (!rvviVersionCheck(RVVI_API_VERSION)) begin
      $display($sformatf("%m @ t=%0t: Expecting RVVI API version %0d.", $time, RVVI_API_VERSION));
      $fatal;
    end

    void'(rvviRefConfigSetString(IDV_CONFIG_MODEL_VENDOR,            "riscv.ovpworld.org"));
    void'(rvviRefConfigSetString(IDV_CONFIG_MODEL_NAME,              "riscv"));
    void'(rvviRefConfigSetString(IDV_CONFIG_MODEL_VARIANT,           "RV64GCK"));
    void'(rvviRefConfigSetInt(IDV_CONFIG_MODEL_ADDRESS_BUS_WIDTH,     XLEN==64 ? 56 : 34));
    void'(rvviRefConfigSetInt(IDV_CONFIG_MAX_NET_LATENCY_RETIREMENTS, 6));

    if(elffilename == "buildroot") filename = "";
    else filename = elffilename;

    // use the ImperasDV rvviRefInit to load the reference model with an elf file
    if(elffilename != "none") begin
      if (!rvviRefInit(filename)) begin
        $display($sformatf("%m @ t=%0t: rvviRefInit failed", $time));
        $fatal;
      end
    end else begin // for buildroot use the binary instead to load the reference model.
      if (!rvviRefInit("")) begin // still have to call with nothing
        $display($sformatf("%m @ t=%0t: rvviRefInit failed", $time));
        $fatal;
      end

      memfilenameImperasDV = {RISCV_DIR, "/linux-testvectors/ram.bin"};
      bootmemfilenameImperasDV = {RISCV_DIR, "/linux-testvectors/bootmem.bin"};

      $display("RVVI Loading bootmem.bin");
      memFile = $fopen(bootmemfilenameImperasDV, "rb");
      index = 'h1000 - 8;
      while(!$feof(memFile)) begin
        index+=8;
        readResult = $fread(x64, memFile);
        if (x64 == 0) continue;
        x32[0] = x64 & 'hffffffff;
        x32[1] = x64 >> 32;
        rvviRefMemoryWrite(0, index+0, x32[0], 4);
        rvviRefMemoryWrite(0, index+4, x32[1], 4);
        //$display("boot %08X x32[0]=%08X x32[1]=%08X", index, x32[0], x32[1]);
      end
      $fclose(memFile);

      $display("RVVI Loading ram.bin");
      memFile = $fopen(memfilenameImperasDV, "rb");
      index = 'h80000000 - 8;
      while(!$feof(memFile)) begin
        index+=8;
        readResult = $fread(x64, memFile);
        if (x64 == 0) continue;
        x32[0] = x64 & 'hffffffff;
        x32[1] = x64 >> 32;
        rvviRefMemoryWrite(0, index+0, x32[0], 4);
        rvviRefMemoryWrite(0, index+4, x32[1], 4);
        //$display("ram  %08X x32[0]=%08X x32[1]=%08X", index, x32[0], x32[1]);
      end
      $fclose(memFile);

      $display("RVVI Loading Complete");

      void'(rvviRefPcSet(0, P.RESET_VECTOR)); // set BOOTROM address
    end

    // Volatile CSRs
    // Counter CSRs
    if (P.ZICNTR_SUPPORTED) begin
      void'(rvviRefCsrSetVolatile(0, 32'hC00));   // CYCLE
      void'(rvviRefCsrSetVolatile(0, 32'hB00));   // MCYCLE
      void'(rvviRefCsrSetVolatile(0, 32'hC02));   // INSTRET
      void'(rvviRefCsrSetVolatile(0, 32'hB02));   // MINSTRET
      void'(rvviRefCsrSetVolatile(0, 32'hC01));   // TIME
      if (P.XLEN == 32) begin
        void'(rvviRefCsrSetVolatile(0, 32'hC80));   // CYCLEH
        void'(rvviRefCsrSetVolatile(0, 32'hB80));   // MCYCLEH
        void'(rvviRefCsrSetVolatile(0, 32'hC82));   // INSTRETH
        void'(rvviRefCsrSetVolatile(0, 32'hB82));   // MINSTRETH
        void'(rvviRefCsrSetVolatile(0, 32'hC81));   // TIMEH
      end
      // HPM counters
      if (P.ZIHPM_SUPPORTED) begin
        // User HPMCOUNTER3 - HPMCOUNTER31
        if (P.U_SUPPORTED) begin
          for (iter='hC03; iter<='hC1F; iter++) begin
            void'(rvviRefCsrSetVolatile(0, iter));   // HPMCOUNTERx
            if (P.XLEN == 32)
              void'(rvviRefCsrSetVolatile(0, iter+128));   // HPMCOUNTERxH
          end
        end

        // Machine MHPMCOUNTER3 - MHPMCOUNTER31
        for (iter='hB03; iter<='hB1F; iter++) begin
          void'(rvviRefCsrSetVolatile(0, iter));   // MHPMCOUNTERx
          if (P.XLEN == 32)
            void'(rvviRefCsrSetVolatile(0, iter+128));   // MHPMCOUNTERxH
        end
      end
    end

    // cannot predict this register due to latency between
    // pending and taken
    void'(rvviRefCsrSetVolatile(0, 32'h344));   // MIP
    if (P.S_SUPPORTED) begin
      void'(rvviRefCsrSetVolatile(0, 32'h144));   // SIP
    end

    // Privileges for PMA are set in the imperas.ic
    // volatile (IO) regions are defined here
    // only real ROM/RAM areas are BOOTROM and UNCORE_RAM
    if (P.CLINT_SUPPORTED) begin
      void'(rvviRefMemorySetVolatile(P.CLINT_BASE, (P.CLINT_BASE + P.CLINT_RANGE)));
    end
    if (P.GPIO_SUPPORTED) begin
      void'(rvviRefMemorySetVolatile(P.GPIO_BASE, (P.GPIO_BASE + P.GPIO_RANGE)));
    end
    if (P.UART_SUPPORTED) begin
      void'(rvviRefMemorySetVolatile(P.UART_BASE, (P.UART_BASE + P.UART_RANGE)));
    end
    if (P.PLIC_SUPPORTED) begin
      void'(rvviRefMemorySetVolatile(P.PLIC_BASE, (P.PLIC_BASE + P.PLIC_RANGE)));
    end
    if (P.SDC_SUPPORTED) begin
      void'(rvviRefMemorySetVolatile(P.SDC_BASE, (P.SDC_BASE + P.SDC_RANGE)));
    end
    if (P.SPI_SUPPORTED) begin
      void'(rvviRefMemorySetVolatile(P.SPI_BASE, (P.SPI_BASE + P.SPI_RANGE)));
    end
    if (P.PWM_SUPPORTED) begin
      void'(rvviRefMemorySetVolatile(P.PWM_BASE, (P.PWM_BASE + P.PWM_RANGE)));
    end
  end

  if (P.ZICSR_SUPPORTED) begin
    always @(dut.core.priv.priv.csr.csri.MIP_REGW[7])   void'(rvvi.net_push("MTimerInterrupt",    dut.core.priv.priv.csr.csri.MIP_REGW[7]));
    always @(dut.core.priv.priv.csr.csri.MIP_REGW[11])  void'(rvvi.net_push("MExternalInterrupt", dut.core.priv.priv.csr.csri.MIP_REGW[11]));
    always @(dut.core.priv.priv.csr.csri.MIP_REGW[3])   void'(rvvi.net_push("MSWInterrupt",       dut.core.priv.priv.csr.csri.MIP_REGW[3]));
    if (P.S_SUPPORTED) begin
      always @(dut.core.priv.priv.csr.csri.MIP_REGW[5])   void'(rvvi.net_push("STimerInterrupt",    dut.core.priv.priv.csr.csri.MIP_REGW[5]));
      always @(dut.core.priv.priv.csr.csri.MIP_REGW[9])   void'(rvvi.net_push("SExternalInterrupt", dut.core.priv.priv.csr.csri.MIP_REGW[9]));
      // when ImperasDV is updated, restore the MIP-based logic commented out below and remove the ValidIntsM-based logic
      // See Fixed https://github.com/openhwfoundation/cvw-arch-verif/issues/670
      //always @(dut.core.priv.priv.csr.csri.MIP_REGW[1])   void'(rvvi.net_push("SSWInterrupt",       dut.core.priv.priv.csr.csri.MIP_REGW[1]));
      always @(dut.core.priv.priv.trap.ValidIntsM[1])   void'(rvvi.net_push("SSWInterrupt",       dut.core.priv.priv.trap.ValidIntsM[1])); // dh 6/29/25 temporarily use ValidInts until Synopsys fixes level sensitive  https://github.com/openhwfoundation/cvw-arch-verif/issues/670
    end
  end

  final begin
    void'(rvviRefShutdown());
  end

`endif
  ////////////////////////////////////////////////////////////////////////////////
  // END of ImperasDV Co-simulator hooks
  ////////////////////////////////////////////////////////////////////////////////

  // Strip a trailing ".elf" from a file name, if present
  function automatic string stripElfSuffix(input string name);
    if (name.len() > 4 && name.substr(name.len()-4, name.len()-1) == ".elf")
      return name.substr(0, name.len()-5);
    else
      return name;
  endfunction

  // Look up, in the label maps built from an ELF's symbol table, where the test reports its result
  // (tohost) and where its signature starts (begin_signature, used by embench); 0 if the ELF lacks one
  task automatic findSymbols(input string addrFile, labFile, output logic [P.XLEN-1:0] tohost, beginSig);
    integer addrFD, labFD;
    longint adr;
    string  label;
    tohost = 0;
    beginSig = 0;
    addrFD = $fopen(addrFile, "r");
    labFD = $fopen(labFile, "r");
    if (addrFD == 0 | labFD == 0)
      $display("Error: Could not open the label maps %s and %s", addrFile, labFile);
    else
      while ($fscanf(addrFD, "%h", adr) == 1 && $fscanf(labFD, "%s", label) == 1)
        if (label == "tohost") tohost = adr[P.XLEN-1:0];
        else if (label == "begin_signature") beginSig = adr[P.XLEN-1:0];
    if (addrFD != 0) $fclose(addrFD);
    if (labFD != 0) $fclose(labFD);
  endtask

  /* verilator lint_on WIDTHTRUNC */
  /* verilator lint_on WIDTHEXPAND */

endmodule

/* verilator lint_on STMTDLY */
/* verilator lint_on WIDTH */
