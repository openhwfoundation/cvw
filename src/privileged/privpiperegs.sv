///////////////////////////////////////////
// privpiperegs.sv
//
// Written: David_Harris@hmc.edu 12 May 2022
// Modified:
//
// Purpose: Pipeline registers for early exceptions
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

module privpiperegs (
  input  logic         clk, reset,                          // Clock and reset
  input  logic         StallD, StallE, StallM,              // Stall Decode, Execute, Memory stages
  input  logic         FlushD, FlushE, FlushM,              // Flush Decode, Execute, Memory stages
  input  logic         InstrPageFaultF, InstrAccessFaultF,  // Instruction page and access faults in Fetch stage
  input  logic         HPTWInstrAccessFaultF,               // HPTW access fault during instruction page table walk, in Fetch stage
  input  logic         HPTWInstrPageFaultF,                 // HPTW page fault during instruction page table walk, in Fetch stage
  input  logic         IllegalIEUFPUInstrD,                 // Illegal integer or FP instruction in Decode stage
  output logic         InstrPageFaultM, InstrAccessFaultM,  // Instruction page and access faults in Memory stage
  output logic         IllegalIEUFPUInstrM,                 // Illegal integer or FP instruction in Memory stage
  output logic         HPTWInstrAccessFaultM,               // HPTW access fault during instruction page table walk, in Memory stage
  output logic         HPTWInstrPageFaultM                  // HPTW page fault during instruction page table walk, in Memory stage
);

  // Delayed fault signals
  logic                InstrPageFaultD, InstrAccessFaultD, HPTWInstrAccessFaultD, HPTWInstrPageFaultD;
  logic                InstrPageFaultE, InstrAccessFaultE, HPTWInstrAccessFaultE, HPTWInstrPageFaultE;
  logic                IllegalIEUFPUInstrE;

  // pipeline fault signals
  flopenrc #(4) faultregD(clk, reset, FlushD, ~StallD,
                  {InstrPageFaultF, InstrAccessFaultF, HPTWInstrAccessFaultF, HPTWInstrPageFaultF},
                  {InstrPageFaultD, InstrAccessFaultD, HPTWInstrAccessFaultD, HPTWInstrPageFaultD});
  flopenrc #(5) faultregE(clk, reset, FlushE, ~StallE,
                  {IllegalIEUFPUInstrD, InstrPageFaultD, InstrAccessFaultD, HPTWInstrAccessFaultD, HPTWInstrPageFaultD},
                  {IllegalIEUFPUInstrE, InstrPageFaultE, InstrAccessFaultE, HPTWInstrAccessFaultE, HPTWInstrPageFaultE});
  flopenrc #(5) faultregM(clk, reset, FlushM, ~StallM,
                  {IllegalIEUFPUInstrE, InstrPageFaultE, InstrAccessFaultE, HPTWInstrAccessFaultE, HPTWInstrPageFaultE},
                  {IllegalIEUFPUInstrM, InstrPageFaultM, InstrAccessFaultM, HPTWInstrAccessFaultM, HPTWInstrPageFaultM});
endmodule
