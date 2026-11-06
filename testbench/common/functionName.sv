///////////////////////////////////////////
// functionName.sv
//
// Written: Rose Thompson rose@rosethompson.net
//
// Purpose: decode name of function
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module functionName import cvw::*; #(parameter cvw_t P) (
  input logic reset,
  input logic clk,
  input string ProgramAddrMapFile,
  input string ProgramLabelMapFile
  );

  logic [P.XLEN-1:0] ProgramAddrMapMemory  [logic [P.XLEN-1:0]];
  string             ProgramLabelMapMemory [logic [P.XLEN-1:0]];
  string             FunctionName;


  logic [P.XLEN-1:0] PCF, PCD, PCE, PCM, FunctionAddr, PCM_temp, PCMOld;
  logic              StallD, StallE, StallM, FlushD, FlushE, FlushM;
  logic              InstrValidM;
  logic [P.XLEN-1:0] ProgramAddrIndex, ProgramAddrIndexQ;

  assign PCF = testbench.dut.core.ifu.PCF;
  assign StallD = testbench.dut.core.StallD;
  assign StallE = testbench.dut.core.StallE;
  assign StallM = testbench.dut.core.StallM;
  assign FlushD = testbench.dut.core.FlushD;
  assign FlushE = testbench.dut.core.FlushE;
  assign FlushM = testbench.dut.core.FlushM;
  assign InstrValidM = testbench.dut.core.InstrValidM;

  // copy from ifu
  // when the F and D stages are flushed we need to ensure the PCE is held so that the function name does not
  // erroneously change.
  // also need to hold the old value not an erroneously fetched PC.
  flopenr #(P.XLEN) PCDReg(clk, reset, ~StallD, FlushD ? PCE : PCF, PCD);
  flopenr #(P.XLEN) PCEReg(clk, reset, ~StallE, FlushD & FlushE ? PCF : FlushE ? PCE : PCD, PCE);
  flopenr #(P.XLEN) PCMReg(clk, reset, ~StallM, FlushD & FlushE & FlushM ? PCF : FlushE & FlushM ? PCE : FlushM ? PCM : PCE, PCM_temp);
  flopenr #(P.XLEN) PCMOldReg(clk, reset, InstrValidM, PCM_temp, PCMOld);
  assign PCM = InstrValidM ? PCM_temp : PCMOld;

  task automatic bin_search_min;
    input  logic [P.XLEN-1:0] pc;
    input  logic [P.XLEN-1:0] length;
    ref    logic [P.XLEN-1:0] array [logic [P.XLEN-1:0]];
    output logic [P.XLEN-1:0] minval;
    output logic [P.XLEN-1:0] mid;

    logic [P.XLEN-1:0] left, right;

    begin
      if ( pc == 0 ) begin
        // want to  keep the old value for mid and minval
        mid = 0;
        return;
      end
      left = 0;
      right = length;
      while (left <= right) begin
        mid = left + ((right - left) / 2);
        if (array[mid] == pc) begin
          minval = array[mid];
          return;
        end
        if (array[mid] < pc) begin
          left = mid + 1;
        end else if( array[mid] > pc) begin
          right = mid -1;
        end else begin
          //$display("Critical Error in FunctionName. PC, %x not found.", pc);
          return;
          //$stop();
        end
      end // while (left <= right)
      // if the element pc is now found, right and left will be equal at this point.
      // we need to check if pc is less than the array at left or greater.
      // if it is less than pc, then we select left as the index.
      // if it is greater we want 1 less than left.
      if (array[left] < pc) begin
        minval = array[left];
        mid = left;
        return;
      end else begin
        minval = array[left-1];
        mid = left - 1;
        return;
      end
    end
  endtask // bin_search_min

  integer ProgramAddrMapFP, ProgramLabelMapFP;
  logic [P.XLEN-1:0] ProgramAddrMapLineCount;
  logic [P.XLEN-1:0] ProgramLabelMapLineCount;
  logic [P.XLEN-1:0] ProgramAddrMapLine;
  string  ProgramLabelMapLine;
  integer status;


  // preload
  //  initial begin
  always @ (negedge reset) begin

    // cannot readmemh directly to a dynamic array. Sad times :(
    // Let's initialize a static array with FFFF_FFFF for all addresses.
    // Then we can readmemh and finally copy to the dynamic array.

    // clear out the old mapping between programs.
    ProgramAddrMapMemory.delete();
    ProgramLabelMapMemory.delete();

    // Unfortunately verilator version 5.011 readmemh does not support dynamic arrays
    //$readmemh(ProgramAddrMapFile, ProgramAddrMapMemory);
    // we need to count the number of lines in the file so we can set FunctionRadixLineCount.

    ProgramAddrMapLineCount = 0;
    ProgramAddrMapFP = $fopen(ProgramAddrMapFile, "r");

    // read line by line to count lines
    if (ProgramAddrMapFP != 0) begin
      while (! $feof(ProgramAddrMapFP)) begin
        status = $fscanf(ProgramAddrMapFP, "%h\n", ProgramAddrMapLine);
        ProgramAddrMapMemory[ProgramAddrMapLineCount] = ProgramAddrMapLine;
        ProgramAddrMapLineCount = ProgramAddrMapLineCount + 1;
      end
    end else begin
      $display("Cannot open file %s for reading.", ProgramAddrMapFile);
    end
    $fclose(ProgramAddrMapFP);

    // ProgramIndexFile maps the program name to the compile index.
    // The compile index is then used to inditify the application
    // in the custom radix.
    // Build an associative array to convert the name to an index.
    ProgramLabelMapLineCount = 0;
    ProgramLabelMapFP = $fopen(ProgramLabelMapFile, "r");

    if (ProgramLabelMapFP != 0) begin
      while (! $feof(ProgramLabelMapFP)) begin
        status = $fscanf(ProgramLabelMapFP, "%s\n", ProgramLabelMapLine);
        ProgramLabelMapMemory[ProgramLabelMapLineCount] = ProgramLabelMapLine;
        ProgramLabelMapLineCount = ProgramLabelMapLineCount + 1;
      end
    end else begin
      $display("Cannot open file %s for reading.", ProgramLabelMapFile);
    end
    $fclose(ProgramLabelMapFP);

  end

  always @(PCM) begin
    bin_search_min(PCM, ProgramAddrMapLineCount, ProgramAddrMapMemory, FunctionAddr, ProgramAddrIndex);
  end

  logic OrReducedAdr, AnyUnknown;
  assign OrReducedAdr = |ProgramAddrIndex;
  assign AnyUnknown = (OrReducedAdr === 1'bx) ? 1'b1 : 1'b0;
  initial ProgramAddrIndex = 0;

  always @(*) FunctionName = AnyUnknown ? "Unknown!" : ProgramLabelMapMemory[ProgramAddrIndex];

endmodule // function_radix
