///////////////////////////////////////////
// rvvisynth.sv
//
// Written:  Rose Thompson rose@rosethompson.net 23 January 2024
// Modified:
//
// Purpose: Synthesizable RVVI tracer that compresses each retired instruction and its register and CSR updates into a packed record.
//
// Documentation:
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module rvvisynth import cvw::*; #(parameter cvw_t P,
                                  parameter integer MAX_CSRS = 5,
                                  parameter integer TOTAL_CSRS = 36)(
  input logic clk, reset,
  input logic                                     StallE, StallM, StallW, FlushE, FlushM, FlushW,
  // required
  input logic [P.XLEN-1:0]                        PCM,
  input logic                                     InstrValidM,
  input logic [31:0]                              InstrRawD,
  input logic [63:0]                              Mcycle, Minstret,
  input logic                                     TrapM,
  input logic [1:0]                               PrivilegeModeW,
  // registers gpr and fpr
  input logic                                     GPRWen, FPRWen,
  input logic [4:0]                               GPRAddr, FPRAddr,
  input logic [P.XLEN-1:0]                        GPRValue, FPRValue,
  input var logic [P.XLEN-1:0]                    CSRArray [TOTAL_CSRS-1:0],
  output logic valid,
  output logic [72+(5*P.XLEN) + MAX_CSRS*(P.XLEN+16)-1:0] rvvi
  );

  // pipeline controls

  // required
  logic [P.XLEN-1:0]                        PCW;
  logic                                     InstrValidW;
  logic [31:0]                              InstrRawE, InstrRawM, InstrRawW;
  logic                                     TrapW;

  // registers gpr and fpr
  logic [P.XLEN-1:0]                        XLENZeros;
  logic [TOTAL_CSRS-1:0]                    CSRArrayWen;
  logic [P.XLEN-1:0]                        CSRValue [MAX_CSRS-1:0];
  logic [TOTAL_CSRS-1:0]                    CSRWen [MAX_CSRS-1:0];
  logic [11:0]                              CSRAddr [MAX_CSRS-1:0];
  logic [MAX_CSRS-1:0]                      EnabledCSRs;
  logic [MAX_CSRS-1:0]                      CSRCountShort;
  logic [11:0]                              CSRCount;
  logic [56+3*P.XLEN-1:0]                   Required;
  logic [16+2*P.XLEN-1:0]                   Registers;
  logic [MAX_CSRS*(P.XLEN+16)-1:0]          CSRs;

  assign XLENZeros = '0;

  // start out easy and just populate Required
  // PC, inst, mcycle, minstret, trap, mode

  flopenrc #(1)      InstrValidMReg (clk, reset, FlushW, ~StallW, InstrValidM, InstrValidW);
  flopenrc #(P.XLEN) PCWReg (clk, reset, FlushW, ~StallW, PCM, PCW);
  flopenrc #(32)     InstrRawEReg (clk, reset, FlushE, ~StallE, InstrRawD, InstrRawE);
  flopenrc #(32)     InstrRawMReg (clk, reset, FlushM, ~StallM, InstrRawE, InstrRawM);
  flopenrc #(32)     InstrRawWReg (clk, reset, FlushW, ~StallW, InstrRawM, InstrRawW);
  flopenrc #(1)      TrapWReg (clk, reset, 1'b0, ~StallW, TrapM, TrapW);

  assign valid  = InstrValidW & ~StallW;
  assign Required = {4'b0, CSRCount, 3'b0, FPRWen, GPRWen, PrivilegeModeW, TrapW, Minstret, Mcycle, InstrRawW, PCW};
  assign Registers = {FPRWen, GPRWen} == 2'b11 ? {FPRValue, 3'b0, FPRAddr, GPRValue, 3'b0, GPRAddr} :
                     {FPRWen, GPRWen} == 2'b01 ? {XLENZeros, 8'b0, GPRValue, 3'b0, GPRAddr} :
                     {FPRWen, GPRWen} == 2'b10 ? {FPRValue, 3'b0, FPRAddr, XLENZeros, 8'b0} :
                     '0;

  /* verilator lint_off UNOPTFLAT */
  // For some reason verilator complains about CSRWenFilterMatrix being in a circular loop when it is not.

  // the CSRs are complex
  // 1. we need to get the CSR values
  // 2. we check if the CSR value changes by registering the value then XORing with the old value.
  // 3. Then use priorityaomux to collect CSR values and addresses for compating into the compressed rvvi format

  // step 2
  genvar                                   index;
  for (index = 0; index < TOTAL_CSRS; index = index + 1) begin
    regchangedetect #(P.XLEN) changedetect(clk, reset, CSRArray[index], CSRArrayWen[index]);
  end

  // step 3a
  logic [TOTAL_CSRS-1:0] CSRWenPriorityMatrix [MAX_CSRS-1:0];
  logic [TOTAL_CSRS-1:0] CSRWenFilterMatrix [MAX_CSRS-1:0];

  priorityaomux #(TOTAL_CSRS, P.XLEN) firstpriorityaomux(CSRArrayWen, CSRArray, CSRValue[0], CSRWenPriorityMatrix[0]);
  assign CSRWenFilterMatrix[0] = CSRArrayWen;

  for(index = 1; index < MAX_CSRS; index = index + 1) begin
    priorityaomux #(TOTAL_CSRS, P.XLEN) priorityaomux(CSRWenFilterMatrix[index], CSRArray, CSRValue[index], CSRWenPriorityMatrix[index]);
    assign CSRWenFilterMatrix[index] = CSRWenFilterMatrix[index-1] & ~CSRWenPriorityMatrix[index-1];
  end
  for(index = 0; index < MAX_CSRS; index = index + 1) begin
    // step 3b
    csrindextoaddr #(TOTAL_CSRS) csrindextoaddr(CSRWenPriorityMatrix[index], CSRAddr[index]);
    assign CSRs[(index+1) * (P.XLEN + 16)- 1: index * (P.XLEN + 16)] = {CSRValue[index], 4'b0, CSRAddr[index]};
    assign EnabledCSRs[index] = |CSRWenPriorityMatrix[index];
  end

  integer index2;
  always_comb begin
    CSRCountShort = '0;
    for(index2 = 0; index2 < MAX_CSRS; index2++) begin
      /* verilator lint_off WIDTHEXPAND */
      CSRCountShort += EnabledCSRs[index2];
      /* verilator lint_on WIDTHEXPAND */
    end
  end
  /* verilator lint_on UNOPTFLAT */

  assign CSRCount = {{{12-MAX_CSRS}{1'b0}}, CSRCountShort};
  assign rvvi = {CSRs, Registers, Required};

endmodule
