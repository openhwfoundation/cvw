///////////////////////////////////////////
// fhazard.sv
//
// Written: me@KatherineParry.com 19 May 2021
// Modified:
//
// Purpose: Determine forwarding, stalls and flushes for the FPU
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module fhazard(
  input  logic [4:0]  Adr1D, Adr2D, Adr3D,                // read data addresses
  input  logic [4:0]  Adr1E, Adr2E, Adr3E,                // read data addresses
  input  logic        FRegWriteE, FRegWriteM, FRegWriteW, // is the fp register being written to
  input  logic [4:0]  RdE, RdM, RdW,                      // the address being written to
  input  logic [1:0]  FResSelM,                           // the result being selected
  input  logic        XEnD, YEnD, ZEnD,                   // are the inputs needed
  output logic        FPUStallD,                          // stall the decode stage
  output logic [1:0]  ForwardXE, ForwardYE, ForwardZE     // select a forwarded value
);

  logic MatchDE; // is a value needed in decode stage being worked on in execute stage

  // Decode-stage instruction source depends on result from execute stage instruction
  assign MatchDE = ((Adr1D == RdE) & XEnD) | ((Adr2D == RdE) & YEnD) | ((Adr3D == RdE) & ZEnD);
  assign FPUStallD = MatchDE & FRegWriteE;

  always_comb begin
    // set defaults
    ForwardXE = 2'b00; // choose FRD1E
    ForwardYE = 2'b00; // choose FRD2E
    ForwardZE = 2'b00; // choose FRD3E

    // if the needed value is in the memory stage - input 1
    if ((Adr1E == RdM) & FRegWriteM) begin
      // if the result will be FResM (can be taken from the memory stage)
      if(FResSelM == 2'b00) ForwardXE = 2'b10; // choose FResM
      // if the needed value is in the writeback stage
    end else if ((Adr1E == RdW) & FRegWriteW) ForwardXE = 2'b01; // choose FResult64W

    // if the needed value is in the memory stage - input 2
    if ((Adr2E == RdM) & FRegWriteM) begin
      // if the result will be FResM (can be taken from the memory stage)
      if(FResSelM == 2'b00) ForwardYE = 2'b10; // choose FResM
      // if the needed value is in the writeback stage
    end else if ((Adr2E == RdW) & FRegWriteW) ForwardYE = 2'b01; // choose FResult64W

    // if the needed value is in the memory stage - input 3
    if ((Adr3E == RdM) & FRegWriteM) begin
      // if the result will be FResM (can be taken from the memory stage)
      if(FResSelM == 2'b00) ForwardZE = 2'b10; // choose FResM
      // if the needed value is in the writeback stage
    end else if ((Adr3E == RdW) & FRegWriteW) ForwardZE = 2'b01; // choose FResult64W
  end
endmodule
