///////////////////////////////////////////
// plic_apb.sv
//
// Written: bbracker@hmc.edu 18 January 2021
// Modified:
//
// Purpose: Platform-Level Interrupt Controller
//   Based on RISC-V spec (https://github.com/riscv/riscv-plic-spec/blob/master/riscv-plic.adoc)
//   With clarifications from ROA's existing implementation (https://roalogic.github.io/plic/docs/AHB-Lite_PLIC_Datasheet.pdf)
//   Supports only 1 target core and only a global threshold.
//   This PLIC implementation serves as both the PLIC Gateways and PLIC Core.
//   It assumes interrupt sources are level-triggered wires.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
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

// number of interrupt sources
// does not include source 0, which does not connect to anything according to spec
// up to 63 sources supported; in the future, allow up to 1023 sources

`define C 2
// number of contexts
// hardcoded to 2 contexts for now; later upgrade to arbitrary (up to 15872) contexts

module plic_apb import cvw::*;  #(parameter cvw_t P) (
  input  logic                PCLK, PRESETn,
  input  logic                PSEL,
  input  logic [27:0]         PADDR,
  input  logic [P.XLEN-1:0]   PWDATA,
  input  logic [P.XLEN/8-1:0] PSTRB,
  input  logic                PWRITE,
  input  logic                PENABLE,
  output logic [P.XLEN-1:0]   PRDATA,
  output logic                PREADY,
  input  logic                UARTIntr,GPIOIntr, SPIIntr, SDCIntr,
  output logic                MExtInt, SExtInt
);

  // register map
  localparam PLIC_INTPRIORITY0   = 24'h000000;
  localparam PLIC_INTPENDING0    = 24'h001000;
  localparam PLIC_INTPENDING1    = 24'h001004;
  localparam PLIC_INTEN00        = 24'h002000;
  localparam PLIC_INTEN01        = 24'h002004;
  localparam PLIC_INTEN10        = 24'h002080;
  localparam PLIC_INTEN11        = 24'h002084;
  localparam PLIC_THRESHOLD0     = 24'h200000;
  localparam PLIC_CLAIMCOMPLETE0 = 24'h200004;
  localparam PLIC_THRESHOLD1     = 24'h201000;
  localparam PLIC_CLAIMCOMPLETE1 = 24'h201004;

  logic                       memwrite, memread;
  logic [23:0]                entry;
  logic [31:0]                Din, Dout;

  // context-independent signals
  logic [P.PLIC_NUM_SRC:1]               requests;
  logic [P.PLIC_NUM_SRC:1][2:0]          intPriority;
  logic [P.PLIC_NUM_SRC:1]               intInProgress, intPending, nextIntPending;

  // context-dependent signals
  logic [`C-1:0][2:0]        intThreshold;
  logic [`C-1:0][P.PLIC_NUM_SRC:1]       intEn;
  logic [`C-1:0][5:0]        intClaim; // ID's are 6 bits if we stay within 63 sources
  logic [`C-1:0][7:1][P.PLIC_NUM_SRC:1]  irqMatrix;
  logic [`C-1:0][7:1]        priorities_with_irqs;
  logic [`C-1:0][7:1]        max_priority_with_irqs;
  logic [`C-1:0][P.PLIC_NUM_SRC:1]       irqs_at_max_priority;
  logic [`C-1:0][7:1]        threshMask;
  logic [P.PLIC_NUM_SRC-1:0] One;

  // hacks to handle gracefully PLIC_NUM_SRC being smaller than 32
  // Otherwise Questa and other simulators produce part-select out of bounds even
  // though sources >=32 are never used

  localparam PLIC_SRC_TOP = (P.PLIC_NUM_SRC >= 32) ? P.PLIC_NUM_SRC : 1;
  localparam PLIC_SRC_BOT = (P.PLIC_NUM_SRC >= 32) ? 32 : 1;
  localparam PLIC_SRC_DINTOP = (P.PLIC_NUM_SRC >= 32) ? P.PLIC_NUM_SRC -32 : 0;
  localparam PLIC_SRC_EXT = (P.PLIC_NUM_SRC >= 32) ? 63-P.PLIC_NUM_SRC : 31;

  // =======
  // AHB I/O
  // =======

  assign memwrite = PWRITE & PENABLE & PSEL;  // only write in access phase
  assign memread  = ~PWRITE & PSEL & ~PENABLE; // read once, in APB setup phase
  assign PREADY   = 1'b1;                     // PLIC never takes >1 cycle to respond
  assign entry    = {PADDR[23:2],2'b0};
  assign One[P.PLIC_NUM_SRC-1:1] = '0; assign One[0] = 1'b1; // Vivado does not like this as a single assignment.

  // account for subword read/write circuitry
  // -- Note PLIC registers are 32 bits no matter what; access them with LW SW.
  assign Din = PWDATA[31:0];
  if (P.XLEN == 64) assign PRDATA = {Dout, Dout};
  else              assign PRDATA = Dout;

  // ==================
  // Register Interface
  // ==================
  localparam PLIC_NUM_SRC_MIN_32 = P.PLIC_NUM_SRC < 32 ? P.PLIC_NUM_SRC : 31;

  always_ff @(posedge PCLK) begin
    // resetting
    if (~PRESETn) begin
      intPriority   <= '0;
      intEn         <= '0;
      intThreshold  <= '0;
      intInProgress <= '0;
    // writing
    end else begin
      if (memwrite)
        casez(entry)
          24'h0000??:          intPriority[entry[7:2]] <= Din[2:0];
          PLIC_INTEN00:        intEn[0][PLIC_NUM_SRC_MIN_32:1] <= Din[PLIC_NUM_SRC_MIN_32:1];
          PLIC_INTEN10:        intEn[1][PLIC_NUM_SRC_MIN_32:1] <= Din[PLIC_NUM_SRC_MIN_32:1];
          PLIC_INTEN01:        if (P.PLIC_NUM_SRC >= 32) intEn[0][PLIC_SRC_TOP:PLIC_SRC_BOT]         <= Din[PLIC_SRC_DINTOP:0];
          PLIC_INTEN11:        if (P.PLIC_NUM_SRC >= 32) intEn[1][PLIC_SRC_TOP:PLIC_SRC_BOT]         <= Din[PLIC_SRC_DINTOP:0];
          PLIC_THRESHOLD0:     intThreshold[0]         <= Din[2:0];
          PLIC_CLAIMCOMPLETE0:
            if (Din[5:0] != 6'd0)
              intInProgress <= intInProgress & ~(One << (Din[5:0]-1)); // lower "InProgress" to signify completion
          PLIC_THRESHOLD1:     intThreshold[1]         <= Din[2:0];
          PLIC_CLAIMCOMPLETE1:
            if (Din[5:0] != 6'd0)
              intInProgress <= intInProgress & ~(One << (Din[5:0]-1)); // lower "InProgress" to signify completion
        endcase

      // Read synchronously because a read can have side effect of changing intInProgress
      if (memread) begin
        casez(entry)
          PLIC_INTPRIORITY0: Dout <= 32'b0;  // there is no intPriority[0]
          24'h0000??:        Dout <= {29'b0,intPriority[entry[7:2]]};
          PLIC_INTPENDING0:  Dout <= {{(31-PLIC_NUM_SRC_MIN_32){1'b0}},intPending[PLIC_NUM_SRC_MIN_32:1],1'b0};
          PLIC_INTEN00:      Dout <= {{(31-PLIC_NUM_SRC_MIN_32){1'b0}},intEn[0][PLIC_NUM_SRC_MIN_32:1],1'b0};
          PLIC_INTPENDING1:  if (P.PLIC_NUM_SRC >= 32) Dout <= {{(PLIC_SRC_EXT){1'b0}},intPending[PLIC_SRC_TOP:PLIC_SRC_BOT]};
          PLIC_INTEN01:      if (P.PLIC_NUM_SRC >= 32) Dout <= {{(PLIC_SRC_EXT){1'b0}},intEn[0][PLIC_SRC_TOP:PLIC_SRC_BOT]};
          PLIC_INTEN10:      Dout <= {{(31-PLIC_NUM_SRC_MIN_32){1'b0}},intEn[1][PLIC_NUM_SRC_MIN_32:1],1'b0};
          PLIC_INTEN11:      if (P.PLIC_NUM_SRC >= 32) Dout <= {{(PLIC_SRC_EXT){1'b0}},intEn[1][PLIC_SRC_TOP:PLIC_SRC_BOT]};
          PLIC_THRESHOLD0:   Dout <= {29'b0,intThreshold[0]};
          PLIC_CLAIMCOMPLETE0: begin
            Dout <= {26'b0,intClaim[0]};
            if (intClaim[0] != 6'd0) // not an invalid request
              intInProgress <= intInProgress | (One << (intClaim[0]-1)); // claimed requests are currently in progress of being serviced until they are completed
          end
          PLIC_THRESHOLD1:   Dout <= {29'b0,intThreshold[1]};
          PLIC_CLAIMCOMPLETE1: begin
            Dout <= {26'b0,intClaim[1]};
            if (intClaim[1] != 6'd0) // not an invalid request
              intInProgress <= intInProgress | (One << (intClaim[1]-1));  // claimed requests are currently in progress of being serviced until they are completed
          end
          default:           Dout <= 32'h0; // invalid access
        endcase
      end else               Dout <= 32'h0;
   end
  end

  // connect sources to requests
  always_comb begin
    requests = {P.PLIC_NUM_SRC{1'b0}};
    if(P.PLIC_GPIO_ID != 0) requests[P.PLIC_GPIO_ID] = GPIOIntr;
    if(P.PLIC_UART_ID != 0) requests[P.PLIC_UART_ID] = UARTIntr;
    if(P.PLIC_SPI_ID != 0) requests[P.PLIC_SPI_ID] = SPIIntr;
    if(P.PLIC_SDC_ID !=0)   requests[P.PLIC_SDC_ID]  = SDCIntr;
  end

  // pending interrupt request
  assign nextIntPending = (intPending | requests) & ~intInProgress;
  flopr #(P.PLIC_NUM_SRC) intPendingFlop(PCLK,~PRESETn,nextIntPending,intPending);

  // context-dependent signals
  genvar ctx;
  for (ctx=0; ctx<`C; ctx++) begin
    // request matrix
    //   priority level (rows) X source ID (columns)
    //
    //   irqMatrix[ctx][pri][src] is high if source <src>
    //   has priority level <pri> and has an "active" interrupt request
    //   ("active" meaning it is enabled in context <ctx> and is pending)
    genvar src, pri;
    for (pri=1; pri<=7; pri++) begin
      for (src=1; src<=P.PLIC_NUM_SRC; src++) begin
        assign irqMatrix[ctx][pri][src] = (intPriority[src]==pri) & intPending[src] & intEn[ctx][src];
      end
    end

    // which priority levels have one or more active requests?
    assign priorities_with_irqs[ctx][7:1] = {
      |irqMatrix[ctx][7],
      |irqMatrix[ctx][6],
      |irqMatrix[ctx][5],
      |irqMatrix[ctx][4],
      |irqMatrix[ctx][3],
      |irqMatrix[ctx][2],
      |irqMatrix[ctx][1]
    };

    // get the highest priority level that has active requests
    assign max_priority_with_irqs[ctx][7:1] = {
      priorities_with_irqs[ctx][7],
      priorities_with_irqs[ctx][6] & ~|priorities_with_irqs[ctx][7],
      priorities_with_irqs[ctx][5] & ~|priorities_with_irqs[ctx][7:6],
      priorities_with_irqs[ctx][4] & ~|priorities_with_irqs[ctx][7:5],
      priorities_with_irqs[ctx][3] & ~|priorities_with_irqs[ctx][7:4],
      priorities_with_irqs[ctx][2] & ~|priorities_with_irqs[ctx][7:3],
      priorities_with_irqs[ctx][1] & ~|priorities_with_irqs[ctx][7:2]
    };

    // of the sources at the highest priority level that has active requests,
    // which sources have active requests?
    assign irqs_at_max_priority[ctx][P.PLIC_NUM_SRC:1] =
      ({P.PLIC_NUM_SRC{max_priority_with_irqs[ctx][7]}} & irqMatrix[ctx][7]) |
      ({P.PLIC_NUM_SRC{max_priority_with_irqs[ctx][6]}} & irqMatrix[ctx][6]) |
      ({P.PLIC_NUM_SRC{max_priority_with_irqs[ctx][5]}} & irqMatrix[ctx][5]) |
      ({P.PLIC_NUM_SRC{max_priority_with_irqs[ctx][4]}} & irqMatrix[ctx][4]) |
      ({P.PLIC_NUM_SRC{max_priority_with_irqs[ctx][3]}} & irqMatrix[ctx][3]) |
      ({P.PLIC_NUM_SRC{max_priority_with_irqs[ctx][2]}} & irqMatrix[ctx][2]) |
      ({P.PLIC_NUM_SRC{max_priority_with_irqs[ctx][1]}} & irqMatrix[ctx][1]);

    // of the sources at the highest priority level that has active requests,
    // choose the source with the lowest source ID to be the most urgent
    // and set intClaim to the source ID of the most urgent active request
    integer k;
    always_comb begin
      intClaim[ctx] = 6'b0;
      for (k=P.PLIC_NUM_SRC; k>0; k--) begin
        if (irqs_at_max_priority[ctx][k]) intClaim[ctx] = k[5:0];
      end
    end

    // create threshold mask
    always_comb begin
      threshMask[ctx][7] = (intThreshold[ctx] != 7);
      threshMask[ctx][6] = (intThreshold[ctx] != 6) & threshMask[ctx][7];
      threshMask[ctx][5] = (intThreshold[ctx] != 5) & threshMask[ctx][6];
      threshMask[ctx][4] = (intThreshold[ctx] != 4) & threshMask[ctx][5];
      threshMask[ctx][3] = (intThreshold[ctx] != 3) & threshMask[ctx][4];
      threshMask[ctx][2] = (intThreshold[ctx] != 2) & threshMask[ctx][3];
      threshMask[ctx][1] = (intThreshold[ctx] != 1) & threshMask[ctx][2];
    end
  end
  // is the max priority > threshold?
  // would it be any better to first priority encode maxPriority into binary and then ">" with threshold?
  assign MExtInt = |(threshMask[0] & priorities_with_irqs[0]);
  assign SExtInt = |(threshMask[1] & priorities_with_irqs[1]);
endmodule
