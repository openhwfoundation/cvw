///////////////////////////////////////////
// csrc.sv
//
// Written: David_Harris@hmc.edu 9 January 2021
// Modified:
//
// Purpose: Counter CSRs
//          See RISC-V Privileged Mode Specification 20190608 3.1.10-11
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
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

module csrc  import cvw::*;  #(parameter cvw_t P) (
  input  logic              clk, reset,
  input  logic              StallE, StallM,
  input  logic              FlushM,
  input  logic              InstrValidNotFlushedM, LoadStallD, StoreStallD,
  input  logic              CSRMWriteM, CSRWriteM,
  input  logic              BPDirWrongM,
  input  logic              BTAWrongM,
  input  logic              RASPredPCWrongM,
  input  logic              IClassWrongM,
  input  logic              BPWrongM,                                  // branch predictor is wrong
  input  logic [3:0]        IClassM,
  input  logic              DCacheMiss,
  input  logic              DCacheAccess,
  input  logic              ICacheMiss,
  input  logic              ICacheAccess,
  input  logic              ICacheStallF,
  input  logic              DCacheStallM,
  input  logic              sfencevmaM,
  input  logic              InterruptM,
  input  logic              ExceptionM,
  input  logic              InvalidateICacheM,
  input  logic              DivBusyE,                                  // integer divide busy
  input  logic              FDivBusyE,                                 // floating point divide busy
  input  logic [11:0]       CSRAdrM,
  input  logic [1:0]        PrivilegeModeW,
  input  logic [P.XLEN-1:0] CSRWriteValM,
  input  logic [31:0]       MCOUNTINHIBIT_REGW, MCOUNTEREN_REGW, SCOUNTEREN_REGW,
  input  logic [63:0]       MTIME_CLINT,
  output logic [P.XLEN-1:0] CSRCReadValM,
  output logic              IllegalCSRCAccessM
);

  localparam MHPMCOUNTERBASE  = 12'hB00;
  localparam MTIME            = 12'hB01;               // this is a memory-mapped register; no such CSR exists, and access should faul;
  localparam MHPMCOUNTERHBASE = 12'hB80;
  localparam MTIMEH           = 12'hB81;               // this is a memory-mapped register; no such CSR exists, and access should fault
  localparam MHPMEVENTBASE    = 12'h323;
  localparam MHPMEVENTLAST    = 12'h33F;
  // SystemVerilog has no zero-width array, so keep one unused element when no hpmevents exist
  localparam HPMEVENTTOP      = P.COUNTERS > 3 ? P.COUNTERS - 1 : 3;
  localparam HPMCOUNTERBASE   = 12'hC00;
  localparam HPMCOUNTERHBASE  = 12'hC80;
  localparam TIME             = 12'hC01;
  localparam TIMEH            = 12'hC81;

  logic [4:0]              CounterNumM;
  logic [P.XLEN-1:0]       HPMCOUNTER_REGW[P.COUNTERS-1:0];
  logic [P.XLEN-1:0]       HPMCOUNTERH_REGW[P.COUNTERS-1:0];
  logic [P.XLEN-1:0]       MHPMEVENT_REGW[HPMEVENTTOP:3];
  logic                    LoadStallE, LoadStallM;
  logic                    StoreStallE, StoreStallM;
  logic [P.COUNTERS-1:0]   WriteHPMCOUNTERM;
  logic [P.COUNTERS-1:0]   WriteHPMCOUNTERHM;
  logic [HPMEVENTTOP:3]    WriteMHPMEVENTM;
  logic [31:0]             CounterEvent; // keep all events here even if P.COUNTERS < 32
  logic [P.COUNTERS-1:0]   CounterInc;
  logic [63:0]             HPMCOUNTERPlusM[P.COUNTERS-1:0];
  logic [P.XLEN-1:0]       NextHPMCOUNTERHM[P.COUNTERS-1:0];
  logic [P.XLEN-1:0]       NextHPMCOUNTERM[P.COUNTERS-1:0];
  logic [P.XLEN-1:0]       NextMHPMEVENTM[HPMEVENTTOP:3];

  genvar                   i;

  // Interface signals
  flopenrc #(1) LoadStallEReg(.clk, .reset, .clear(1'b0), .en(~StallE), .d(LoadStallD), .q(LoadStallE));  // don't flush the load stall during a load stall.
  flopenrc #(1) LoadStallMReg(.clk, .reset, .clear(FlushM), .en(~StallM), .d(LoadStallE), .q(LoadStallM));

  flopenrc #(1) StoreStallEReg(.clk, .reset, .clear(1'b0), .en(~StallE), .d(StoreStallD), .q(StoreStallE));  // don't flush the load stall during a load stall.
  flopenrc #(1) StoreStallMReg(.clk, .reset, .clear(FlushM), .en(~StallM), .d(StoreStallE), .q(StoreStallM));

  // Determine when to increment each counter
  assign CounterEvent[0]    = 1'b1;                                                      // MCYCLE always increments
  assign CounterEvent[1]    = 1'b0;                                                      // Counter 1 doesn't exist
  assign CounterEvent[2]    = InstrValidNotFlushedM;                                     // MINSTRET instructions retired
  if (P.COUNTERS > 3) begin : cevent                                                   // User-defined counters
    // Ideally all events would be counted in the M stage, but the pipelining is costly. The counters may
    // count an event in a previous pipeline stage.
    assign CounterEvent[3]  = IClassM[0] & InstrValidNotFlushedM;                        // branch instruction
    assign CounterEvent[4]  = IClassM[1] & ~IClassM[2] & InstrValidNotFlushedM;          // jump and not return instructions
    assign CounterEvent[5]  = IClassM[2] & InstrValidNotFlushedM;                        // return instructions
    assign CounterEvent[6]  = BPWrongM & InstrValidNotFlushedM;                          // branch predictor wrong
    assign CounterEvent[7]  = BPDirWrongM & InstrValidNotFlushedM;                       // Branch predictor wrong direction
    assign CounterEvent[8]  = BTAWrongM & InstrValidNotFlushedM;                         // branch predictor wrong target
    assign CounterEvent[9]  = RASPredPCWrongM & InstrValidNotFlushedM;                   // return address stack wrong address
    assign CounterEvent[10] = IClassWrongM & InstrValidNotFlushedM;                      // instruction class predictor wrong
    assign CounterEvent[11] = LoadStallM;                                                // Load Stalls. don't want to suppress on flush as this only happens if flushed.
    assign CounterEvent[12] = StoreStallM;                                               // Store Stall
    assign CounterEvent[13] = DCacheAccess;                                              // data cache access
    assign CounterEvent[14] = DCacheMiss;                                                // data cache miss. Miss asserted 1 cycle at start of cache miss
    assign CounterEvent[15] = DCacheStallM;                                              // D$ miss cycles
    assign CounterEvent[16] = ICacheAccess;                                              // instruction cache access
    assign CounterEvent[17] = ICacheMiss;                                                // instruction cache miss. Miss asserted 1 cycle at start of cache miss
    assign CounterEvent[18] = ICacheStallF;                                              // I$ miss cycles
    assign CounterEvent[19] = CSRWriteM & InstrValidNotFlushedM;                         // CSR writes
    assign CounterEvent[20] = InvalidateICacheM & InstrValidNotFlushedM;                 // fence.i
    assign CounterEvent[21] = sfencevmaM & InstrValidNotFlushedM;                        // sfence.vma
    assign CounterEvent[22] = InterruptM;                                                // interrupt, InstrValidNotFlushedM will be low
    assign CounterEvent[23] = ExceptionM;                                                // exceptions, InstrValidNotFlushedM will be low
    // coverage off
    // DivBusyE will never be asserted high because the RV64GC configuration uses the FPU to do integer division
    assign CounterEvent[24] = DivBusyE | FDivBusyE;                                      // division cycles
    // coverage on
    assign CounterEvent[31:25] = '0; // eventually give these sources, including FP instructions, I$/D$ misses, branches and mispredictions
  end else begin : cevent
    assign CounterEvent[31:3] = '0;
  end

  // Counter update and write logic
  for (i = 0; i < P.COUNTERS; i = i+1) begin : cntr
      assign WriteHPMCOUNTERM[i] = CSRMWriteM & (CSRAdrM == MHPMCOUNTERBASE + i); // coverage tag: MTIME traps
      assign NextHPMCOUNTERM[i][P.XLEN-1:0] = WriteHPMCOUNTERM[i] ? CSRWriteValM : HPMCOUNTERPlusM[i][P.XLEN-1:0];
      if (i < 3) assign CounterInc[i] = CounterEvent[i] & ~MCOUNTINHIBIT_REGW[i]; // MCYCLE, CYCLE, and MINSTRET are always incremented if not inhibited
      else       assign CounterInc[i] = CounterEvent[i] & ~MCOUNTINHIBIT_REGW[i] & (MHPMEVENT_REGW[i] != 0); // user-defined counters are incremented only if the event is enabled
      always_ff @(posedge clk)
        if (reset) HPMCOUNTER_REGW[i][P.XLEN-1:0] <= '0;
        else       HPMCOUNTER_REGW[i][P.XLEN-1:0] <= NextHPMCOUNTERM[i];

      if (P.XLEN==32) begin // write high and low separately
        assign HPMCOUNTERPlusM[i] = {HPMCOUNTERH_REGW[i], HPMCOUNTER_REGW[i]} + {63'b0, CounterInc[i]};
        assign WriteHPMCOUNTERHM[i] = CSRMWriteM & (CSRAdrM == MHPMCOUNTERHBASE + i);
        assign NextHPMCOUNTERHM[i] = WriteHPMCOUNTERHM[i] ? CSRWriteValM : HPMCOUNTERPlusM[i][63:32];
        always_ff @(posedge clk)
            if (reset) HPMCOUNTERH_REGW[i][P.XLEN-1:0] <= '0;
            else       HPMCOUNTERH_REGW[i][P.XLEN-1:0] <= NextHPMCOUNTERHM[i];
      end else begin // XLEN=64; write entire register
          assign HPMCOUNTERPlusM[i] = HPMCOUNTER_REGW[i] + {63'b0, CounterInc[i]};
          assign HPMCOUNTERH_REGW[i] = '0; // disregard for RV64
      end
  end

  // hpmevent update and write logic
  if (P.COUNTERS > 3) begin : mhpmeventgen
    for (i = 3; i < P.COUNTERS; i = i+1) begin : mhpmevent
      assign WriteMHPMEVENTM[i] = CSRMWriteM & (CSRAdrM == MHPMEVENTBASE + i - 3);
      assign NextMHPMEVENTM[i] = WriteMHPMEVENTM[i] ? CSRWriteValM : MHPMEVENT_REGW[i];
      always_ff @(posedge clk)
        if (reset) MHPMEVENT_REGW[i] <= '0;
        else       MHPMEVENT_REGW[i] <= NextMHPMEVENTM[i];
    end
  end else begin : mhpmeventgen // no hpmevents exist; drive the placeholder element HPMEVENTTOP reserves
    assign WriteMHPMEVENTM = '0;
    assign NextMHPMEVENTM[3] = '0;
    assign MHPMEVENT_REGW[3] = '0;
  end

  // Read Counters, or cause exception if insufficient privilege in light of COUNTEREN flags
  assign CounterNumM = CSRAdrM[4:0]; // which counter to read?
  always_comb begin
    CSRCReadValM = '0; // default value
    IllegalCSRCAccessM = 1'b0;
    if (PrivilegeModeW == P.M_MODE & (CSRAdrM >= MHPMEVENTBASE & CSRAdrM <= MHPMEVENTLAST)) begin
        if (CSRAdrM < MHPMEVENTBASE+P.COUNTERS-3) CSRCReadValM = MHPMEVENT_REGW[CounterNumM];
        else CSRCReadValM ='0; // unused event selectors are read-only zero
      end
    else if (PrivilegeModeW == P.M_MODE |
      MCOUNTEREN_REGW[CounterNumM] & (!P.S_SUPPORTED | PrivilegeModeW == P.S_MODE | SCOUNTEREN_REGW[CounterNumM])) begin
        // The branch conditions below guarantee CounterNumM < P.COUNTERS before it indexes the
        // counter arrays, but Verilator sizes the index from the array bound, so it warns whenever
        // P.COUNTERS < 32.  This region also covers the MTIME_CLINT reads, which Verilator does not
        // realize happen only at one XLEN.
        /* verilator lint_off WIDTH */
        if (P.XLEN==64) begin // 64-bit counter reads
          // Veri lator doesn't realize this only occurs for XLEN=64
          if      (CSRAdrM == TIME & ~CSRWriteM)  CSRCReadValM = MTIME_CLINT; // TIME register is a shadow of the memory-mapped MTIME from the CLINT
          else if (CSRAdrM >= MHPMCOUNTERBASE & CSRAdrM < MHPMCOUNTERBASE+P.COUNTERS & CSRAdrM != MTIME)
                  CSRCReadValM = HPMCOUNTER_REGW[CounterNumM];
          else if (CSRAdrM >= MHPMCOUNTERBASE+P.COUNTERS & CSRAdrM < MHPMCOUNTERBASE+32)
                  CSRCReadValM = '0; // unused counters are read-only zero
          else if (CSRAdrM >= HPMCOUNTERBASE  & CSRAdrM  < HPMCOUNTERBASE+3 & ~CSRWriteM & P.ZICNTR_SUPPORTED)  // read-only
                  CSRCReadValM = HPMCOUNTER_REGW[CounterNumM];
          else if (CSRAdrM >= HPMCOUNTERBASE+3  & CSRAdrM  < HPMCOUNTERBASE+P.COUNTERS & ~CSRWriteM & P.ZIHPM_SUPPORTED)  // read-only
                  CSRCReadValM = HPMCOUNTER_REGW[CounterNumM];
          else if (CSRAdrM >= HPMCOUNTERBASE+P.COUNTERS  & CSRAdrM  < HPMCOUNTERBASE+32 & ~CSRWriteM & P.ZIHPM_SUPPORTED)  // read-only
                  CSRCReadValM = '0;
          else IllegalCSRCAccessM = 1'b1;  // requested CSR doesn't exist
        end else begin // 32-bit counter reads
          // Veril ator doesn't realize this only occurs for XLEN=32
          if      (CSRAdrM == TIME & ~CSRWriteM)  CSRCReadValM = MTIME_CLINT[31:0];// TIME register is a shadow of the memory-mapped MTIME from the CLINT
          else if (CSRAdrM == TIMEH & ~CSRWriteM) CSRCReadValM = MTIME_CLINT[63:32];
          else if (CSRAdrM >= MHPMCOUNTERBASE  & CSRAdrM < MHPMCOUNTERBASE+P.COUNTERS & CSRAdrM != MTIME)
                  CSRCReadValM = HPMCOUNTER_REGW[CounterNumM];
          else if (CSRAdrM >= MHPMCOUNTERBASE+P.COUNTERS & CSRAdrM < MHPMCOUNTERBASE+32)
                  CSRCReadValM = '0; // unused counters are read-only zero
          else if (CSRAdrM >= HPMCOUNTERBASE   & CSRAdrM < HPMCOUNTERBASE+3  & ~CSRWriteM & P.ZICNTR_SUPPORTED)    // read-only
                  CSRCReadValM = HPMCOUNTER_REGW[CounterNumM];
          else if (CSRAdrM >= HPMCOUNTERBASE+3   & CSRAdrM < HPMCOUNTERBASE+P.COUNTERS  & ~CSRWriteM & P.ZIHPM_SUPPORTED)    // read-only
                  CSRCReadValM = HPMCOUNTER_REGW[CounterNumM];
          else if (CSRAdrM >= HPMCOUNTERBASE+P.COUNTERS   & CSRAdrM < HPMCOUNTERBASE+32  & ~CSRWriteM & P.ZIHPM_SUPPORTED)    // read-only
                  CSRCReadValM = '0; // unused counters are read-only zero
          else if (CSRAdrM >= MHPMCOUNTERHBASE & CSRAdrM < MHPMCOUNTERHBASE+P.COUNTERS & CSRAdrM != MTIMEH)
                  CSRCReadValM = HPMCOUNTERH_REGW[CounterNumM];
          else if (CSRAdrM >= MHPMCOUNTERHBASE+P.COUNTERS & CSRAdrM < MHPMCOUNTERHBASE+32)
                  CSRCReadValM = '0; // unused counters are read-only zero
          else if (CSRAdrM >= HPMCOUNTERHBASE   & CSRAdrM < HPMCOUNTERHBASE+3  & ~CSRWriteM & P.ZICNTR_SUPPORTED)   // read-only
                  CSRCReadValM = HPMCOUNTERH_REGW[CounterNumM];
          else if (CSRAdrM >= HPMCOUNTERHBASE+3 & CSRAdrM < HPMCOUNTERHBASE+P.COUNTERS & ~CSRWriteM & P.ZIHPM_SUPPORTED)   // read-only
                  CSRCReadValM = HPMCOUNTERH_REGW[CounterNumM];
          else if (CSRAdrM >= HPMCOUNTERHBASE+P.COUNTERS & CSRAdrM < HPMCOUNTERHBASE+32 & ~CSRWriteM & P.ZIHPM_SUPPORTED)   // read-only
                  CSRCReadValM = '0;
          else    IllegalCSRCAccessM = 1'b1; // requested CSR doesn't exist
        end
        /* verilator lint_on WIDTH */
      end
    else IllegalCSRCAccessM = 1'b1; // no privileges for this csr
  end
endmodule
