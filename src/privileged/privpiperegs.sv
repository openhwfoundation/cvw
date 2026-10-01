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

module privpiperegs (
  input  logic         clk, reset,
  input  logic         StallD, StallE, StallM,
  input  logic         FlushD, FlushE, FlushM,
  input  logic         InstrPageFaultF, InstrAccessFaultF,  // instruction faults
  input  logic         HPTWInstrAccessFaultF,               // hptw fault during instruction page fetch
  input  logic         HPTWInstrPageFaultF,                 // hptw fault during instruction page fetch
  input  logic         IllegalIEUFPUVPUInstrD,                 // illegal IEU instruction decoded
  output logic         InstrPageFaultM, InstrAccessFaultM,  // delayed instruction faults
  output logic         IllegalIEUFPUVPUInstrM,                 // delayed illegal IEU instruction
  output logic         HPTWInstrAccessFaultM,               // hptw fault during instruction page fetch
  output logic         HPTWInstrPageFaultM                  // hptw fault during instruction page fetch
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
