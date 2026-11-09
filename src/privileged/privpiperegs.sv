///////////////////////////////////////////
// privpiperegs.sv
//
// Written:  David Harris David_Harris@hmc.edu 12 May 2022
// Modified: Rose Thompson
//
// Purpose: Pipeline registers for early exceptions.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2022-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module privpiperegs (
  input  logic         clk, reset,
  input  logic         StallD, StallE, StallM,
  input  logic         FlushD, FlushE, FlushM,
  input  logic         InstrPageFaultF, InstrAccessFaultF,  // instruction faults
  input  logic         HPTWInstrAccessFaultF,               // hptw access fault during instruction page fetch
  input  logic         HPTWInstrPageFaultF,                 // hptw page fault during instruction page fetch
  input  logic         IllegalIEUFPUVPUInstrD,              // illegal IEU instruction decoded
  output logic         InstrPageFaultM, InstrAccessFaultM,  // delayed instruction faults
  output logic         IllegalIEUFPUVPUInstrM,              // delayed illegal IEU instruction
  output logic         HPTWInstrAccessFaultM,               // hptw access fault during instruction page fetch
  output logic         HPTWInstrPageFaultM                  // hptw page fault during instruction page fetch
);

  // Delayed fault signals
  logic                InstrPageFaultD, InstrAccessFaultD, HPTWInstrAccessFaultD, HPTWInstrPageFaultD;
  logic                InstrPageFaultE, InstrAccessFaultE, HPTWInstrAccessFaultE, HPTWInstrPageFaultE;
  logic                IllegalIEUFPUVPUInstrE;

  // pipeline fault signals
  flopenrc #(4) faultregD(clk, reset, FlushD, ~StallD,
                  {InstrPageFaultF, InstrAccessFaultF, HPTWInstrAccessFaultF, HPTWInstrPageFaultF},
                  {InstrPageFaultD, InstrAccessFaultD, HPTWInstrAccessFaultD, HPTWInstrPageFaultD});
  flopenrc #(5) faultregE(clk, reset, FlushE, ~StallE,
                  {IllegalIEUFPUVPUInstrD, InstrPageFaultD, InstrAccessFaultD, HPTWInstrAccessFaultD, HPTWInstrPageFaultD},
                  {IllegalIEUFPUVPUInstrE, InstrPageFaultE, InstrAccessFaultE, HPTWInstrAccessFaultE, HPTWInstrPageFaultE});
  flopenrc #(5) faultregM(clk, reset, FlushM, ~StallM,
                  {IllegalIEUFPUVPUInstrE, InstrPageFaultE, InstrAccessFaultE, HPTWInstrAccessFaultE, HPTWInstrPageFaultE},
                  {IllegalIEUFPUVPUInstrM, InstrPageFaultM, InstrAccessFaultM, HPTWInstrAccessFaultM, HPTWInstrPageFaultM});
endmodule
