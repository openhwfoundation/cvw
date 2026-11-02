// Top level testbench for the CV32E40S
// Adapted for cv32e40s-tb from cv32e40x-dv 93ce70f tb/core/tb_top.sv.
//
// Copyright 2026 Eclipse Foundation
// SPDX-License-Identifier: Apache-2.0 WITH SHL-0.51
//
// Copyright 2017 Embecosm Limited <www.embecosm.com>
// Copyright 2018 Robert Balas <balasr@student.ethz.ch>
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Top level wrapper for a RI5CY testbench
// Contributor: Robert Balas <balasr@student.ethz.ch>
//              Jeremy Bennett <jeremy.bennett@embecosm.com>

`define TB_CORE

module tb_top
    #(parameter INSTR_RDATA_WIDTH = 32,
      parameter RAM_ADDR_WIDTH = 22,
      parameter BOOT_ADDR  = 'h80);

    // comment to record execution trace
    //`define TRACE_EXECUTION

    // Integer delays; one tb_top for all simulators (Verilator built --timing).
    const int CLK_PHASE_HI        = 5;
    const int CLK_PHASE_LO        = 5;
    const int CLK2NRESET_DELAY    = 1;
    const int RESET_ASSERT_CYCLES = 4;


    // clock and reset for tb
    logic                   core_clk;
    logic                   iss_clk;
    logic                   core_rst_n;

    // cycle counter
    int unsigned            cycle_cnt_q;

    // testbench result
    logic                   tests_passed;
    logic                   tests_failed;
    logic                   exit_valid;
    logic [31:0]            exit_value;

    // signals for ri5cy
    logic                   fetch_enable;

    // make the core start fetching instruction immediately
    assign fetch_enable = '1;

    // Boot address: defaults to module parameter, overridden by ELF entry point
    // (from +elf_file=) or by an explicit +boot_addr=<hex> plusarg.
    logic [31:0]            boot_addr;
    initial boot_addr = BOOT_ADDR;

    // allow vcd dump
    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("riscy_tb.vcd");
            $dumpvars(0, tb_top);
        end
    end

    // Program loading. Supported plusargs (first matched wins):
    //   +elf_file=<path>    Read the ELF32 header, extract e_entry as boot_addr,
    //                       then $readmemh "<path-without-ext>.hex" into memory.
    //                       Used by `make gen-certify` (ACT4 produces ELF+hex).
    //   +firmware=<path>    Legacy: $readmemh <path> directly; boot_addr stays
    //                       at BOOT_ADDR unless +boot_addr=<hex> is also passed.
    initial begin: load_prog
        automatic string      elf_file;
        automatic string      hex_file;
        automatic string      firmware;
        automatic logic [7:0] ehdr [0:51];   // ELF32 file header is 52 bytes
        automatic integer     elf_fd;
        automatic int         last_dot;

        if ($value$plusargs("elf_file=%s", elf_file)) begin
            elf_fd = $fopen(elf_file, "rb");
            if (elf_fd == 0)
                $fatal(1, "[TESTBENCH] Cannot open ELF file: %s", elf_file);
            void'($fread(ehdr, elf_fd));
            $fclose(elf_fd);
            // e_entry is at byte offset 24, little-endian
            boot_addr = {ehdr[27], ehdr[26], ehdr[25], ehdr[24]};

            last_dot = -1;
            for (int i = elf_file.len() - 1; i >= 0; i--) begin
                if (elf_file.getc(i) == 8'h2e && last_dot == -1)
                    last_dot = i;
            end
            hex_file = (last_dot >= 0) ? {elf_file.substr(0, last_dot - 1), ".hex"}
                                       : {elf_file, ".hex"};

            if ($test$plusargs("verbose"))
                $display("[TESTBENCH] @ t=%0t: loading ELF %0s, boot_addr=0x%08h, hex=%0s",
                         $time, elf_file, boot_addr, hex_file);
            $readmemh(hex_file, cv32e40s_tb_wrapper_i.ram_i.dp_ram_i.mem);

        end else if ($value$plusargs("firmware=%s", firmware)) begin
            void'($value$plusargs("boot_addr=%h", boot_addr));
            if ($test$plusargs("verbose"))
                $display("[TESTBENCH] @ t=%0t: loading firmware %0s, boot_addr=0x%08h",
                         $time, firmware, boot_addr);
            $readmemh(firmware, cv32e40s_tb_wrapper_i.ram_i.dp_ram_i.mem);

        end else begin
            $display("[TESTBENCH] No +elf_file or +firmware specified");
            $finish;
        end
    end

    initial begin: clock_gen
        core_clk = 1'b1;
        // Bounded repeat: Verilator's --timing scheduler hangs on a forever
        // clock; 400M periods exceed any +maxcycles-bounded test (CoreMark needs a few M).
        repeat (400_000_000) begin
            #CLK_PHASE_HI core_clk = 1'b0;
            #CLK_PHASE_LO core_clk = 1'b1;
        end
    end: clock_gen


    // Deterministic reset: init high, sync-assert on negedge, hold, deassert.
    // Avoids any X on core_rst_n so Verilator (no X-prop) behaves like four-state sims.
    initial begin
        $timeformat(-9, 0, "ns", 9);
        core_rst_n = 1'b1;

        @(negedge core_clk) core_rst_n = 1'b0;
        repeat (RESET_ASSERT_CYCLES) @(posedge core_clk);
        #CLK2NRESET_DELAY core_rst_n = 1'b1;
        core_rst_n = 1'b1;

        if($test$plusargs("verbose")) begin
            $display("[TESTBENCH] @ t=%0t: reset deasserted", $time);
        end

        if ( !( (INSTR_RDATA_WIDTH == 128) || (INSTR_RDATA_WIDTH == 32) ) ) begin
         $fatal(2, "invalid INSTR_RDATA_WIDTH, choose 32 or 128");
        end
    end

    // abort after n cycles, if we want to (plusarg read once, not every cycle)
    int unsigned maxcycles;
    bit          maxcycles_en;
    initial maxcycles_en = $value$plusargs("maxcycles=%d", maxcycles);
    always_ff @(posedge core_clk, negedge core_rst_n) begin
        if (~core_rst_n) begin
            cycle_cnt_q <= 0;
        end else begin
            cycle_cnt_q     <= cycle_cnt_q + 1;
            if (maxcycles_en && cycle_cnt_q >= maxcycles) begin
                $fatal(2, "Simulation aborted due to maximum cycle limit");
            end
        end
    end

    // check if we succeded
    always_ff @(posedge core_clk, negedge core_rst_n) begin
        if (tests_passed) begin
            $display("ALL TESTS PASSED (%0d cycles after reset)", cycle_cnt_q);
            $finish;
        end
        if (tests_failed) begin
            $display("TEST(S) FAILED! (%0d cycles after reset)", cycle_cnt_q);
            $fatal(1, "RVMODEL_HALT_FAIL");
        end
        if (exit_valid) begin
            if (exit_value == 0)
                $display("%m @ %0t: EXIT SUCCESS", $time);
            else
                $display("%m @ %0t: EXIT FAILURE: %d", exit_value, $time);
            $finish;
        end
    end

    // wrapper for CV32E40S, the memory system and stdout peripheral
    cv32e40s_tb_wrapper
        #(
          .INSTR_RDATA_WIDTH (INSTR_RDATA_WIDTH),
          .RAM_ADDR_WIDTH    (RAM_ADDR_WIDTH)
         )
    cv32e40s_tb_wrapper_i
        (
         .clk_i          ( core_clk     ),
         .rst_ni         ( core_rst_n   ),
         .boot_addr_i    ( boot_addr    ),
         .fetch_enable_i ( fetch_enable ),
         .tests_passed_o ( tests_passed ),
         .tests_failed_o ( tests_failed ),
         .exit_valid_o   ( exit_valid   ),
         .exit_value_o   ( exit_value   )
        );

endmodule // tb_top
