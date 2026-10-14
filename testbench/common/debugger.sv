///////////////////////////////////////////
// debugger.sv
//
// Written: Jacob Pease jacob.pease@okstate.edu, James Stine james.stine@okstate.edu
// Modified:
//
// Purpose:
//   Testbench JTAG driver that emulates a RISC-V debugger to exercise the
//   Debug Transport/Module (DTM/DM) via IR/DR scans and DMI transactions.
// Key functions:
//   - Bit-bangs JTAG (TCK/TMS/TDI) and samples TDO with a programmable TCK period.
//   - write_instr(): shifts JTAG instructions (IR) into the DTM.
//   - JTAG_DR class: generic DR read/write (parameterized width).
//   - DMI class (41-bit): convenience tasks to read/write DM registers
//       (dmcontrol, dmstatus, abstractcs, command, data0).
//   - Debugger class: higher-level flows to initialize DTM, enable DM,
//       halt/resume the hart, issue abstract commands, read GPRs/CSRs,
//       and print/verify results.
//   - Testvector harness: parses vectors from a file, drives DMI sequences,
//       and checks responses against expected (pass/fail reporting).
// Operation:
//   On reset deassertion, initializes JTAG/DTM, then runs the testvectors
//   in a loop, comparing FPGA/simulation results and reporting mismatches.
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2025 Harvey Mudd College & Oklahoma State University
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

module debugger import cvw::*;  #(parameter cvw_t P)(
  input  logic clk, reset,
  output logic tck, tms, tdi,
  input  logic tdo,
  input string filename
);
  localparam int tcktime = 52;

  // ANSII color codes
  string red     = "\033[1;31m"; // Red text
  string green   = "\033[1;32m"; // Green text
  string yellow  = "\033[1;33m"; // Yellow text
  string normal  = "\033[0m";    // Reset to default
  string bold    = "\033[1m";

  //enum logic {RUN, WAIT} debugger_state;

  // ----------------------------------------------------------------
  //  Write instruction task.
  // ----------------------------------------------------------------

  // Changing the instructions happens so infrequently that we need
  // only make a single task for this. The only time we may need to
  // revisit this after initializing is if we need to set DMIReset if
  // we encounter the sticky error in the DMI.

  // Task for writing instructions to the DTM
  task write_instr(input logic [4:0] INST);
    logic [11:0] tms_seq;
    logic [11:0] tdi_seq;
    begin
      tms_seq = {4'b0110, 5'b0, 3'b110};
      // Reverse instruction so LSB is first
      tdi_seq = {5'b0, {<<{INST}}, 2'b0};

      // Clock should be idling high, TMS should be low keeping
      // us in the Run-test/Idle state and the input should not
      // be driven.
      tck = 1;
      tms = 0;
      tdi = 0;

      // SelectIR -> CaptureIR -> ShiftIR
      for (int i = 11; i >= 0; i--) begin
        #(tcktime) tck = ~tck; // low
        tms = tms_seq[i];
        tdi = tdi_seq[i];
        #(tcktime) tck = ~tck; // high
      end
    end
  endtask // instr

  // ----------------------------------------------------------------
  // Classes
  // ----------------------------------------------------------------

  // This task must be outside the classes for Verilator. Verilator
  // can't resolve the port scope from inside class tasks.
  task automatic jtag_cycle(input logic tms_i, input logic tdi_i, output logic tdo_o);
    #(tcktime) tck = ~tck;          // go low
    tms = tms_i;
    tdi = tdi_i;
    tdo_o = tdo;
    #(tcktime) tck = ~tck;          // go high
  endtask

  // JTAG_DR Class that generalizes the task of reading and writing
  // to the Test Data Regisers.
  class JTAG_DR #(parameter WIDTH = 32);
    logic [WIDTH-1:0] result;

    task read();
      logic [5 + WIDTH + 2 - 1:0] tms_seq = {5'b01000, {(WIDTH-1){1'b0}}, 1'b1, 2'b10};
      logic sampled_tdo;
      for (int i = 5 + WIDTH + 2 - 1; i >= 0; i--) begin
        jtag_cycle(tms_seq[i], 1'b0, sampled_tdo);
        if ((i < WIDTH + 2) && (i >= 2)) begin
          this.result[WIDTH - i + 2 - 1] = sampled_tdo;
        end
      end
    endtask

    task write(input logic [WIDTH-1:0] val);
      logic [5 + WIDTH + 2 - 1:0] tms_seq = {5'b01000, {(WIDTH-1){1'b0}}, 1'b1, 2'b10};
      logic sampled_tdo;
      for (int i = 5 + WIDTH + 2 - 1; i >= 0; i--) begin
        logic tdi_bit = ((i < WIDTH + 2) && (i >= 2)) ? val[WIDTH - i + 2 - 1] : 1'b0;
        jtag_cycle(tms_seq[i], tdi_bit, sampled_tdo);
        this.result[WIDTH - i + 2 - 1] = sampled_tdo;
      end
    endtask
  endclass

  // Debug Module Interface Abstraction.
  class DMI #(parameter WIDTH = 41);
    logic [WIDTH-1:0] result;

    task read();
      logic [5 + WIDTH + 2 - 1:0] tms_seq = {5'b01000, {(WIDTH-1){1'b0}}, 1'b1, 2'b10};
      logic sampled_tdo;
      for (int i = 5 + WIDTH + 2 - 1; i >= 0; i--) begin
        jtag_cycle(tms_seq[i], 1'b0, sampled_tdo);
        if ((i < WIDTH + 2) && (i >= 2)) begin
          this.result[WIDTH - i + 2 - 1] = sampled_tdo;
        end
      end
    endtask

    task write(input logic [WIDTH-1:0] val);
      logic [5 + WIDTH + 2 - 1:0] tms_seq = {5'b01000, {(WIDTH-1){1'b0}}, 1'b1, 2'b10};
      logic sampled_tdo;
      for (int i = 5 + WIDTH + 2 - 1; i >= 0; i--) begin
        logic tdi_bit = ((i < WIDTH + 2) && (i >= 2)) ? val[WIDTH - i + 2 - 1] : 1'b0;
        jtag_cycle(tms_seq[i], tdi_bit, sampled_tdo);
        this.result[WIDTH - i + 2 - 1] = sampled_tdo;
      end
    endtask

    task read_dmcontrol();
      this.write({7'h10, 32'h0000_0000, 2'b01});
      this.write({7'h10, 32'h0000_0000, 2'b00});
    endtask

    task write_dmcontrol(input logic [31:0] data);
      this.write({7'h10, data, 2'b10});
    endtask

    // DMStatus = 0x11
    task read_dmstatus();
      this.write({7'h11, 32'h0000_0000, 2'b01});
      this.write({7'h11, 32'h0000_0000, 2'b00});
    endtask

    // Command = 0x17
    task read_command();
      this.write({7'h17, 32'h0000_0000, 2'b01});
    endtask

    task write_command(input logic [31:0] data);
      this.write({7'h17, data, 2'b10});
    endtask

    // AbstractCS = 0x16
    task read_abstractcs();
      this.write({7'h16, 32'h0000_0000, 2'b01});
      this.write({7'h16, 32'h0000_0000, 2'b00});
    endtask

    task write_abstractcs(input logic [31:0] data);
      this.write({7'h16, data, 2'b10});
    endtask

    // DATA0 = 0x04
    task read_data0();
      this.write({7'h04, 32'h0000_0000, 2'b01});
      this.write({7'h04, 32'h0000_0000, 2'b00});
    endtask

    task write_data0(input logic [31:0] data);
      this.write({7'h04, data, 2'b10});
    endtask
  endclass

  // Debugger Class

  /* This class is special. It simulates what the debugger is
   * supposed to do as outlined in the RISC-V Debug Specification.
   *
   * - Debugger.initialize():
   *   This initializes the Debug Module by setting DMActive high
   *   then polling for the the setting to take effect.
   *
   * - Debugger.halt():
   *   This sets haltreq high and polls for the halting to have taken
   *   effect in DMStatus before deasserting haltreq.
   *
   * - Debugger.resume():
   *   Sets resumereq high and polls DMStatus for when the processor
   *   resumes.
   *
   * - Debugger.readreg(regno):
   *   Reads a GPR of the user's choice
   *
   * - Debugger.readcsr():
   *   Performs an Abstract Access Register read of a CSR.
   *
   * - Debugger.get_testvectors(filename);
   */

  class Debugger;
    // Primary JTAG Registers
    JTAG_DR #(32) idcode;
    JTAG_DR #(32) dtmcs;
    JTAG_DR #(32) bypass;
    DMI #(41) dmireg;

    // state enum
    typedef enum {IDLE, DMREG_READ, DMREG_WRITE, ABSTRACT_READ, ABSTRACT_WRITE, DATA0_READ, DATA1_READ} debugger_state;
    debugger_state state;

    // Need to store these to allow exceptions for certain values during assertions
    logic [6:0] last_addr;
    logic [15:0] last_abstract_reg;
    logic [2:0]  last_aarsize;

    // For running testvectors instead of the encapsulated tests.
    logic [40:0] testvectors[$];
    logic [40:0] expected_outputs[$];

    // Error tracking
    int          error_locations[$];

    // Get the last resume for triggering error read out.
    int          endIndex;

    function new();
      state = IDLE;
      idcode = new();
      dtmcs = new();
      dmireg = new();
      bypass = new();
    endfunction

    // Confirm the DTM is working
    task initialize();
      this.bypass.write(32'hffffffff);

      write_instr(5'b00001);
      this.idcode.read();
      assert(this.idcode.result == 32'h1002AC05)
      else $display("IDCODE was corrupted: 0x%0h", this.idcode.result);

      // Reading DTMCS value
      write_instr(5'b10000);
      this.dtmcs.read();
      assert(this.dtmcs.result == 32'h00100071)
      else $display("Something is wrong with DTMCS on reset and capture: dtmcs = 0x%0h", this.dtmcs.result);

      // Set instruction DMI
      write_instr(5'b10001);
    endtask

    task init_dm();
      // Set DMActive
      this.dmireg.write_dmcontrol(32'h0000_0001);
      this.dmireg.read_dmcontrol();
      assert(this.dmireg.result[33:2] == 32'h0000_0001) $display("DMActive was set");
      else $display("Failed to write to DMActive");

      // Read DMControl
      this.dmireg.read_dmcontrol();
      assert(this.dmireg.result[33:2] == 32'h0000_0001) $display("DMControl: 0x%8h, CORRECT", this.dmireg.result[33:2]);
      else $display("DMControl = 0x%8h, FAILED", this.dmireg.result[33:2]);

      // Read AbstractCS
      this.dmireg.read_abstractcs();
      assert(this.dmireg.result[33:2] == 32'h0000_0001) $display("AbstractCS: 0x%8h, CORRECT", this.dmireg.result[33:2]);
      else $display("AbstractCS: 0x%8h, FAILED", this.dmireg.result[33:2]);
    endtask

    // Halt the processor, and confirm halted
    task halt();
      this.dmireg.read_dmcontrol();
      this.dmireg.write_dmcontrol(32'h8000_0000 | this.dmireg.result[33:2]);
      this.dmireg.read_dmstatus();

      assert(|(this.dmireg.result[33:2] & 32'h0000_0300)) $display("Hart Halted. DMStatus = 0x%8h, CORRECT", this.dmireg.result[33:2]);
      else $display("Hart not halted. DMStatus = 0x%8h, FAILED", this.dmireg.result[33:2]);

      this.dmireg.read_dmcontrol();
      this.dmireg.write_dmcontrol(32'h7fff_ffff & this.dmireg.result[33:2]);
      this.dmireg.read_dmcontrol();

      assert(|(this.dmireg.result[33:2] & 32'h8000_0000) == 0) $display("Haltreq de-asserted. DMControl = 0x%8h, CORRECT", this.dmireg.result[33:2]);
      else $display("Haltreq NOT de-asserted. DMControl = 0x%8h, FAILED", this.dmireg.result[33:2]);
    endtask

    // Resume the processor, and confirm resume
    task resume();
      this.dmireg.read_dmcontrol();
      this.dmireg.write_dmcontrol(32'h4000_0000 | this.dmireg.result[33:2]);

      this.dmireg.read_dmstatus();
      assert(|(this.dmireg.result[33:2] & 32'h0000_0c00)) $display("Hart resumed! DMStatus = 0x%8h, CORRECT", this.dmireg.result[33:2]);
      else $display("Hart not resumed. DMStatus = 0x%8h, FAILED", this.dmireg.result[33:2]);

      this.dmireg.read_dmcontrol();
      this.dmireg.write_dmcontrol(32'hbfff_ffff & this.dmireg.result[33:2]);
      this.dmireg.read_dmcontrol();

      assert(|(this.dmireg.result[33:2] & 32'h4000_0000) == 0) $display("Resumereq de-asserted. DMControl = 0x%8h, CORRECT", this.dmireg.result[33:2]);
      else $display("Resumereq NOT de-asserted. DMControl = 0x%8h, FAILED", this.dmireg.result[33:2]);
    endtask

    task command(input logic [31:0] cmd);
      this.dmireg.write_command(cmd);
      this.dmireg.read_data0();
      $display("COMMAND: Data0:\n  op: 0b%2b,\n  data: 0x%8h,\n  addr: 0x%2h", this.dmireg.result[1:0], this.dmireg.result[33:2], this.dmireg.result[40:34]);
    endtask

    task read_abstractcs();
      this.dmireg.read_abstractcs();
      $display("AbstractCS: op: 0b%2b, data: 0x%8h, addr: 0x%2h", this.dmireg.result[1:0], this.dmireg.result[33:2], this.dmireg.result[40:34]);
    endtask

    task readreg(input logic [4:0] regno);
      // 32'h0020_0301
      this.dmireg.write_command({16'h0022, 11'b0001_0000_000, regno});
      this.dmireg.read_data0();
      $display("GPR: Data0:\n  op: 0b%2b,\n  data: 0x%8h,\n  addr: 0x%2h", this.dmireg.result[1:0], this.dmireg.result[33:2], this.dmireg.result[40:34]);
    endtask

    task readcsr(input logic [11:0] regno);
      this.dmireg.write_command({16'h0022, 4'b0, regno});
      this.read_abstractcs();
      this.dmireg.read_data0();
      $display("CSR: Data0 =\n  op: 0b%2b,\n  data: 0x%8h,\n  addr: 0x%2h\n", this.dmireg.result[1:0], this.dmireg.result[33:2], this.dmireg.result[40:34]);
    endtask

    // TESTVECTOR READING. Reading testvectors grabbed from openocd.log
    function void get_testvectors(string filename);
      string line;
      string items[$];
      int    file = $fopen(filename, "r");

      if (file == 0) begin
        $display("Debugger file is not a valid file descriptor: %s.", filename);
        $fatal;
      end

      testvectors = {};
      expected_outputs = {};
      while (!$feof(file)) begin
        if ($fgets(line, file) != 0) begin
          // Allow comments and whitespace
          if (line[0] == "#" | line[0] == " " | line[0] == "\n") begin
            continue;
          end

          // Split needs to be a function with side effects apparently
          // because the old way of returning a Queue was not
          // compatible with Verilator.
          split(line, " ", items);

          // These values must be converted to the write bit widths
          // for Verilator.
          this.testvectors.push_back(
            {7'(items[2].substr(1, 2).atohex()),
            32'(items[1].atohex()),
            op_decode(items[0], 0)}
          );

          this.expected_outputs.push_back(
            {7'(items[6].substr(1, 2).atohex()),
            32'(items[5].atohex()),
            op_decode(items[4], 1)}
          );
        end
      end

      $fclose(file);

      // foreach (this.testvectors[i]) begin
      //    $display("testvector[%0d]:\n  addr: %2h, data: %8h, op: %2b", i, this.testvectors[i][40:34], this.testvectors[i][33:2], this.testvectors[i][1:0]);
      // end
    endfunction

    function void changeState(logic [40:0] testvector);
      logic [6:0]  addr;
      logic [31:0] data;
      logic [1:0]  op;
      addr = testvector[40:34];
      data = testvector[33:2];
      op = testvector[1:0];
      case (state)
        IDLE: if (addr == 7'h17) begin
          // Currently only support Abstract Register Commands, so no
          // check for Abstract command type is present.
          if (data[16]) begin // Checking for WRITE signal
            state = IDLE;
          end else begin
            state = ABSTRACT_READ;
          end
        end else if (addr != 7'h00 & op == 2'b01) begin
          state = DMREG_READ;
        end else begin
          state = IDLE;
        end

        ABSTRACT_READ: begin
          if (addr == 7'h04 & op == 2'b01) begin
            state = DATA0_READ;
          end else if (addr == 7'h05 & op == 2'b01) begin
            state = DATA1_READ;
          end else begin
            state = ABSTRACT_READ;
          end
        end

        DATA0_READ: begin
          if (addr == 7'h00 & op == 2'b00) begin
            state = IDLE;
          end else if (addr == 7'h05 & op == 2'b01) begin
            state = DATA1_READ;
          end else begin
            state = DATA0_READ;
          end
        end

        DATA1_READ: begin
          if (addr == 7'h00 & op == 2'b00) begin
            state = IDLE;
          end else begin
            state = DATA1_READ;
          end
        end

        DMREG_READ: begin
          if (addr == 7'h00 & op == 2'b00) begin
            state = IDLE;
          end else begin
            // This should never happen. Immediately upon issuing a
            // read the data should be fed out of the JTAG interface
            // immediately before doing anything else. If this state
            // is reached, it means we'll be stuck here.
            state = DMREG_READ;
          end
        end

        default: state = IDLE;
      endcase
    endfunction

    /*
     knownExceptions

     Checks the results of Debug Module register and Abstract Register
     Reads. If any difference is a known and acceptable difference
     between Spike and Wally, it allows the assertion to pass.
     */
    function logic knownExceptions(logic [40:0] expected, logic [40:0] actual);
      logic result;
      // $display("last_addr = %2h", last_addr);
      if (state == DATA0_READ | state == DATA1_READ) begin
        case (last_abstract_reg)
          16'h7b0: begin
            // Do not check any unimplemented features for now
            if ((expected[33:2] & 32'hF000_01E3) == (actual[33:2] & 32'hF000_01E3)) begin
              result = 1;
            end else begin
              result = 0;
            end
          end

          // Ignoring trigger module read differences for now.

          //tdata
          16'h7a1: begin
            result = 1;
          end

          // tselect
          16'h7a0: begin
            result = 1;
          end

          16'h7a4: begin
            result = 1;
          end

          default:  begin
            result = 0;
          end
        endcase

      end else if (state == DMREG_READ | state == ABSTRACT_READ) begin
        case (last_addr)
          7'h11: begin
            if (expected[33:8] == actual[33:8] & expected[6] == expected[6]) begin
              // Ignore hasresethaltreq differences. Spike doesn't seem to implement it.
              result = 1;
            end else begin
              // case(last_abstract_reg)
              //   // Ignore fails in DMSTATUS when trying to read
              //   // Trigger Module registers, as this is a known
              //   // difference until Trigger Modules are implemented.
              //   16'h7a0: begin
              //     result = 1;
              //   end
              //   16'h7a1: result = 1;
              //   default: result = 0;
              result = 0;
              // endcase
            end
          end

          7'h12: begin
            result = 1; // This is not implemented yet, so forgive it for now.
          end

          // The case where the AbstractCS register is read during the
          // Abstract Register Read process. Spike actually asserts
          // the busy signal for a regular Abstract Access Register
          // GPR read for some reason.
          7'h16: begin
            // $display("HERE");
            if ((expected[14] != actual[14]) | (expected[17] != actual[17])) begin
              result = 1;
            end else if (last_aarsize == 3'd3 & P.XLEN == 32 & (expected[12:10] != 3'd2)) begin
              // Had to add this case because Spike wants to report a
              // cmderr of 3 (exception) on Abstract Accesss Register
              // reads that set aarsize to 64 bits on a 32 bit
              // configuration. This also needs to be investigated.
              result = 1;
            end else begin
              case(last_abstract_reg)
                // Ignore fails in DMSTATUS when trying to read
                // Trigger Module registers, as this is a known
                // difference until Trigger Modules are implemented.
                16'h7a0: begin
                  result = 1;
                end
                16'h7a1: result = 1;
                16'h7a4: result = 1;
                default: result = 0;
              endcase
            end
          end

          default: result = 0;
        endcase
      end

      return result;
    endfunction

    // Primary workhorse task
    /* This function is responsible for feeding testvectors from a
     file across the JTAG interface. It has several features.
     - Checks for known exceptions to the assert statements.
     - Updates the state of the debugger, telling us if we're doing an
       abstract register read or simply reading a DM register.
     - Asserts that the expected output, obtained from using OpenOCD
       and Spike, matches the output that Wally gives.
     */
    task run_testvectors();
      logic exception;
      // Reset errors back to zero
      error_locations = {};
      this.getEndVector();
      foreach (testvectors[i]) begin
        if (i == endIndex - 1) begin
          this.reportErrors();
        end

        if (i > 0) begin
          last_addr = testvectors[i-1][40:34];
          if (last_addr == 7'h17) begin
            last_abstract_reg = testvectors[i-1][17:2];
            last_aarsize      = testvectors[i-1][24:22];
          end
        end

        this.dmireg.write(testvectors[i]);

        // Uncomment the following lines in order to see every
        // testvector in the log output.

        // $display("\n");
        // $display("\033[1mtestvector\033[0m[%0d]: \033[1m addr:\033[0m %2h, data: %8h, op: %2b", i, this.testvectors[i][40:34], this.testvectors[i][33:2], this.testvectors[i][1:0]);

        if (state == DATA0_READ | state == DATA1_READ | state == DMREG_READ | state == ABSTRACT_READ) begin
          exception = this.knownExceptions(this.expected_outputs[i], this.dmireg.result);
        end

        // Update State after using the previous state to determine exception value
        this.changeState(testvectors[i]);

        // Assert that the output should equal what Spike outputs.
        assert(this.dmireg.result == expected_outputs[i] | exception | i == 0) begin
          string green   = "\033[1;32m"; // Green text
          string normal  = "\033[0m";    // Reset to default
          exception = 0;

          // Uncomment the following lines to see all matching expected outputs.
          // $display("%sMATCHES%s", green, normal);
          // $display("  Expected[%0d] = \033[1m addr:\033[0m %2h, data: %8h, op: %2b", i, this.expected_outputs[i][40:34], this.expected_outputs[i][33:2], this.expected_outputs[i][1:0]);
          // $display("  Actual[%0d] =  addr: %2h, data: %8h, op: %2b", i, this.dmireg.result[40:34], this.dmireg.result[33:2], this.dmireg.result[1:0]);
        end else begin
          string red     = "\033[1;31m"; // Red text
          string normal  = "\033[0m";    // Reset to default
          $display("%sFAILED:%s Wally does not match Spike.", red, normal);
          // Report both the expected and actual results
          $display("  Expected[%0d] = \033[1m addr:\033[0m %2h, data: %8h, op: %2b", i, this.expected_outputs[i][40:34], this.expected_outputs[i][33:2], this.expected_outputs[i][1:0]);
          $display("  Actual[%0d] =  addr: %2h, data: %8h, op: %2b", i, this.dmireg.result[40:34], this.dmireg.result[33:2], this.dmireg.result[1:0]);
          error_locations.push_back(i);
        end
      end
    endtask

    function void getEndVector();
      logic [6:0] addr;
      logic [31:0] data;
      int          endVector;
      int          i;
      for (i = testvectors.size() - 1; i >= 0; i--) begin
        addr = testvectors[i][40:34];
        data = testvectors[i][33:2];
        if (data[30] & addr == 7'h10) begin
          endIndex = i;
          return;
        end
      end
    endfunction

    function void reportErrors();
      if (error_locations.size() > 0) begin
        $display("errors: %d", error_locations.size());
        $display("Number of errors: %d. The following testvector indices had errors.", error_locations.size());
        foreach (error_locations[i]) begin
          $display("%d", error_locations[i]);
        end
      end
    endfunction
  endclass

  // ----------------------------------------------------------------
  // THE TESTS
  // ----------------------------------------------------------------

  // Debug Commands
  initial begin
    JTAG_DR #(32) idcode = new();
    JTAG_DR #(32) dtmcs = new();
    DMI dmireg = new();
    Debugger debugger = new();

    fork : debugger_main
      begin
        forever begin
          @(negedge reset);
          disable fork;

          fork
            begin : debug_sequence
              debugger.get_testvectors(filename);
              debugger.initialize();
              debugger.run_testvectors();
            end
          join_none
        end
      end
    join_none
  end
endmodule

// typedef string stringarr[];
// No native split function in System Verilog. This function splits the lines
function automatic void split(string str, string delimiter, ref string result[$]);
  string temp = "";
  int strlen = str.len();
  result = '{};

  for (int i = 0; i <= strlen; i++) begin
    if (str[i] == delimiter[0] || (i == strlen && temp.len() != 0) || str[i] == "\n") begin
      result.push_back(temp);
      temp = "";
    end else begin
      temp = {temp, str[i]};
    end
  end

  if (temp.len() != 0)
    result.push_back(temp);
endfunction

function automatic logic isAbstractCommand(input logic [40:0] testvector);
  if ((testvector[40:34] == 7'h17) & (testvector[33:33-8+1] == 8'h0)) begin
    return 1'b1;
  end
  return 1'b0;
endfunction

function automatic logic [1:0] op_decode(string op_str, logic response);
  if (response) begin
    if (op_str == "+") begin
      return 2'b00;
    end else if (op_str == "b") begin
      return 2'b11;
    end else begin
      return 2'b01; // reserved
    end
  end else begin
    if (op_str == "r") begin
      return 2'b01;
    end else if (op_str == "w") begin
      return 2'b10;
    end else if (op_str == "-") begin
      return 2'b00;
    end else begin
      return 2'b11;
    end
  end
  return 2'b00;
endfunction
