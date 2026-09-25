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
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

`include "config.vh"
`include "BranchPredictorType.vh"

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

  string  elfPaths[];    // ELF files run back-to-back in this simulation
  longint elfTohost[];   // address of each ELF's tohost, where the test stores its result (0 if none)
  longint elfBeginSig[]; // address of each ELF's begin_signature (0 if none); used by embench
  string  elfQueue[$];
  longint tohostQueue[$], sigQueue[$];
  string  elfPathLine;
  longint tohostLine, sigLine;
  integer elfListFD;
  int     NumTests;
  logic DCacheFlushDone, DCacheFlushStart;
  logic Validate;
  logic SelectTest;
  logic TestComplete;
  logic TohostWrite;             // the test is storing its result to tohost
  logic TohostStore, TohostHiStore; // a store to tohost / to its upper word (tohost+4)
  logic HtifPutchar;             // the store to tohost is an HTIF console putchar
  logic [31:0] TohostHi;         // upper word of tohost, stored separately on RV32
  logic [63:0] TohostWord;       // the 64-bit tohost value being stored
  logic [31:0] TohostValue;      // value stored to tohost: 1 = pass, (code << 1) | 1 = fail, 0 = never written
  logic PrevPCZero;
  logic RVVIStall;

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

    // Build the list of ELF files to run back-to-back in this simulation.  wsim writes one line per
    // ELF into the ElfList file: the absolute path, then the hex addresses of tohost and
    // begin_signature (0 if the ELF lacks the symbol).  A single ELF may also be named with +ElfFile,
    // in which case no result can be read back.  buildroot and fpga instead load prebuilt memory
    // images, so they have no ELF list.
    if (TEST == "buildroot" | TEST == "fpga") begin
      NumTests = 1;
    end else begin
      if (ElfList != "none") begin
        elfListFD = $fopen(ElfList, "r");
        if (elfListFD == 0) begin
          $display("Error: Could not open ELF list file %s", ElfList);
          $finish;
        end
        while ($fscanf(elfListFD, "%s %h %h", elfPathLine, tohostLine, sigLine) == 3) begin
          elfQueue.push_back(elfPathLine);
          tohostQueue.push_back(tohostLine);
          sigQueue.push_back(sigLine);
        end
        $fclose(elfListFD);
      end else if (ElfFile != "none") begin
        elfQueue.push_back(ElfFile);
        tohostQueue.push_back(0);
        sigQueue.push_back(0);
      end
      elfPaths = new[elfQueue.size()];
      elfTohost = new[elfQueue.size()];
      elfBeginSig = new[elfQueue.size()];
      foreach (elfQueue[elfIdx]) begin
        elfPaths[elfIdx] = elfQueue[elfIdx];
        elfTohost[elfIdx] = tohostQueue[elfIdx];
        elfBeginSig[elfIdx] = sigQueue[elfIdx];
      end
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
                           STATE_COPY_RAM,
                           STATE_CHECK_TEST,
                           STATE_CHECK_TEST_WAIT,
                           STATE_VALIDATE,
                           STATE_INCR_TEST} statetype;
  statetype CurrState, NextState;
  logic        TestBenchReset;
  logic [2:0]  ResetCount, ResetThreshold;
  logic        LoadMem;
  logic        ResetCntEn;
  logic        ResetCntRst;
  logic        CopyRAM;

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
      STATE_RUN_TEST:        if(TestComplete)     NextState = STATE_COPY_RAM;
                             else                 NextState = STATE_RUN_TEST;
      STATE_COPY_RAM:                             NextState = STATE_CHECK_TEST;
      STATE_CHECK_TEST:      if (DCacheFlushDone) NextState = STATE_VALIDATE;
                             else                 NextState = STATE_CHECK_TEST_WAIT;
      STATE_CHECK_TEST_WAIT: if(DCacheFlushDone)  NextState = STATE_VALIDATE;
                             else                 NextState = STATE_CHECK_TEST_WAIT;
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
  assign CopyRAM = TestComplete & CurrState == STATE_RUN_TEST;
  assign DCacheFlushStart = CurrState == STATE_COPY_RAM;

  // fsm reset counter
  counter #(3) RstCounter(clk, ResetCntRst, ResetCntEn, ResetCount);

  ////////////////////////////////////////////////////////////////////////////////
  // Find the test vector files and populate the PC to function label converter
  ////////////////////////////////////////////////////////////////////////////////
  logic [P.XLEN-1:0] testadr;

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
      end
      if (TEST == "buildroot" | TEST == "fpga") begin
        tohost_addr = 0;
        begin_signature_addr = 0;
      end else begin
        tohost_addr = elfTohost[test];
        begin_signature_addr = elfBeginSig[test];
      end
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
        // Writes contents of begin_signature to .sim.output file
        // this contains instret and cycles for start and end of test run, used by embench
        // python speed script to calculate embench speed score.
        // also, begin_signature contains the results of the self checking mechanism,
        // which will be read by the python script for error checking
        $display("Embench Benchmark: %s is done.", elffilename);
        outputfile = {stripElfSuffix(elffilename), ".sim.output"};
        outputFilePointer = $fopen(outputfile, "w");
        i = 0;
        testadr = ($unsigned(begin_signature_addr))/(P.XLEN/8);
        while ($unsigned(i) < $unsigned(5'd5)) begin
          $fdisplayh(outputFilePointer, DCacheFlushFSM.ShadowRAM[testadr+i]);
          i = i + 1;
        end
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

  integer ShadowIndex;
  integer LogXLEN;
  integer StartIndex;
  integer EndIndex;
  integer BaseIndex;
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
    always @(posedge clk) begin
      if (LoadMem) begin
        $readmemh(memfilename, dut.core.ifu.irom.irom.rom.ROM);
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
      if (CopyRAM) begin
        // copy the signature region (read back by the embench flow) into the shadow RAM
        LogXLEN = (1 + P.XLEN/32); // 2 for rv32 and 3 for rv64
        StartIndex = begin_signature_addr >> LogXLEN;
        EndIndex = StartIndex + 15;
        BaseIndex = P.UNCORE_RAM_BASE >> LogXLEN;
        if (begin_signature_addr != 0)
          for(ShadowIndex = StartIndex; ShadowIndex <= EndIndex; ShadowIndex++) begin
            testbench.DCacheFlushFSM.ShadowRAM[ShadowIndex] = dut.uncoregen.uncore.ram.ram.memory.ram.RAM[ShadowIndex - BaseIndex];
          end
      end
    end
  end
  if (P.DTIM_SUPPORTED) begin
    always @(posedge clk) begin
      if (LoadMem) begin
        $readmemh(memfilename, dut.core.lsu.dtim.dtim.ram.ram.RAM);
      end
      if (CopyRAM) begin
        // copy the signature region (read back by the embench flow) into the shadow RAM
        LogXLEN = (1 + P.XLEN/32); // 2 for rv32 and 3 for rv64
        StartIndex = begin_signature_addr >> LogXLEN;
        EndIndex = StartIndex + 15;
        BaseIndex = P.UNCORE_RAM_BASE >> LogXLEN;
        if (begin_signature_addr != 0)
          for(ShadowIndex = StartIndex; ShadowIndex <= EndIndex; ShadowIndex++) begin
            testbench.DCacheFlushFSM.ShadowRAM[ShadowIndex] = dut.core.lsu.dtim.dtim.ram.ram.RAM[ShadowIndex - BaseIndex];
          end
      end
    end
  end

  integer adrindex;
  if (P.UNCORE_RAM_SUPPORTED)
    always @(posedge clk)
      if (ResetMem)  // program memory is sometimes reset (e.g. for CoreMark, which needs zeroed memory)
        for (adrindex=0; adrindex<(P.UNCORE_RAM_RANGE>>1+(P.XLEN/32)); adrindex = adrindex+1)
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

  wallypipelinedsoc  #(P) dut(.clk, .reset_ext, .reset, .ExternalStall(RVVIStall),
    .HRDATAEXT, .HREADYEXT, .HRESPEXT, .HSELEXT,
    .HCLK, .HRESETn, .HADDR, .HWDATA, .HWSTRB, .HWRITE, .HSIZE, .HBURST, .HPROT,
    .HTRANS, .HMASTLOCK, .HREADY, .TIMECLK(1'b0), .GPIOIN, .GPIOOUT, .GPIOEN,
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
    rvvitbwrapper(.clk, .reset, .RVVIStall, .mii_tx_clk(clk), .mii_txd, .mii_tx_en, .mii_tx_er,
                  .mii_rx_clk(clk), .mii_rxd('0), .mii_rx_dv('0), .mii_rx_er('0));
  end else begin
    assign RVVIStall = '0;
  end


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

  // Track names of instructions
  string InstrFName, InstrDName, InstrEName, InstrMName, InstrWName;
  logic [31:0] InstrW;
  flopenr #(32)    InstrWReg(clk, reset, ~dut.core.ieu.dp.StallW,  InstrM, InstrW);
  instrTrackerTB #(P.XLEN) it(clk, reset, dut.core.ieu.dp.FlushE,
                dut.core.ifu.InstrRawF[31:0],
                dut.core.ifu.InstrD, dut.core.ifu.InstrE,
                InstrM,  InstrW,
                InstrFName, InstrDName, InstrEName, InstrMName, InstrWName);

  // watch for problems such as lockup, reading uninitialized memory, bad configs
`ifdef MEMPIPE_PROBE
  `include "mempipeprobe.svh"
`endif
  watchdog #(P.XLEN, 1000000) watchdog(.clk, .reset, .TEST);  // check if PCW is stuck
  ramxdetector #(P.XLEN, P.LLEN) ramxdetector(clk, dut.core.lsu.MemRWM[1], dut.core.lsu.LSULoadAccessFaultM, dut.core.lsu.ReadDataM,
                                      dut.core.ifu.PCM, InstrM, dut.core.lsu.IEUAdrM, dut.core.lsu.StallW, InstrMName);
  riscvassertions       #(P) riscvassertions();     // check assertions for a legal architectural configuration
  riscvassertions_wally #(P) riscvassertions_wally();  // check assertions for a legal microarchitectural configuration
  loggers #(P, PrintHPMCounters, I_CACHE_ADDR_LOGGER, D_CACHE_ADDR_LOGGER, BPRED_LOGGER)
    loggers (clk, reset, DCacheFlushStart, DCacheFlushDone, memfilename, sim_log_prefix, TEST);

  // track the current function or global label
  if (DEBUG > 0 | ((PrintHPMCounters | BPRED_LOGGER) & P.ZICNTR_SUPPORTED)) begin : functionName
    // build the .objdump.addr/.lab label maps from the ELF if they are missing or stale
    always @(posedge clk)
      if (SelectTest & TEST != "buildroot" & TEST != "fpga")
        void'($system({"make -s -f ", WALLY_DIR, "/testbench/Makefile WALLY=", WALLY_DIR, " ", ProgramAddrMapFile}));
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


  logic [P.XLEN-1:0] PCM;
  // PCM is not valid for configurations without ZICSR or branch predictor
  flopenr #(P.XLEN) PCMReg(clk, reset, ~dut.core.StallM, dut.core.PCE, PCM);
  // tohost follows HTIF: a store whose bits 63:48 are device 1, command 1 is a console putchar
  // of bits 7:0, which configurations without a UART use for console output.  Any other store to
  // tohost reports the test result.  RV32 stores the upper word to tohost+4 before the lower word.
  assign TohostStore   = (dut.core.lsu.IEUAdrM == tohost_addr & tohost_addr != 0) & (InstrMName == "SW" | InstrMName == "SD");
  assign TohostHiStore = (dut.core.lsu.IEUAdrM == tohost_addr + 4 & tohost_addr != 0) & (InstrMName == "SW");
  assign TohostWord    = (InstrMName == "SD") ? 64'(dut.core.WriteDataM) : {TohostHi, dut.core.WriteDataM[31:0]};
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

  DCacheFlushFSM #(P) DCacheFlushFSM(.clk, .start(DCacheFlushStart), .done(DCacheFlushDone));

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
  rvviTrace #(.XLEN(P.XLEN), .FLEN(P.FLEN)) rvvi();
  wallyTracer #(P) wallyTracer(rvvi);
`endif

// Functional coverage.  riscv_arch_test comes from riscv-arch-test and samples the generated
// covergroups off the RVVI trace; wally-compile.do supplies it and its include paths with --fcov.
`ifdef FCOV
  // wallyTracer drives every RVVI signal the covergroups read except these, which belong to
  // extensions rv64gc does not implement, so tie them off rather than sampling X.
  assign rvvi.mode_virt[0][0]  = 1'b0; // no hypervisor
  assign rvvi.debug_mode[0][0] = 1'b0; // no debug module
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

`ifdef PMP_COVERAGE
test_pmp_coverage #(P) pmp_inst(clk);
`endif
  /* verilator lint_on WIDTHTRUNC */
  /* verilator lint_on WIDTHEXPAND */

endmodule

/* verilator lint_on STMTDLY */
/* verilator lint_on WIDTH */
