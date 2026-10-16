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

module fhazard(
  input  logic [4:0]  Adr1D, Adr2D, Adr3D,                // FP source register addresses in Decode stage
  input  logic [4:0]  Adr1E, Adr2E, Adr3E,                // FP source register addresses in Execute stage
  input  logic        FRegWriteE, FRegWriteM, FRegWriteW, // FP register write enable in Execute, Memory, Writeback stages
  input  logic [4:0]  RdE, RdM, RdW,                      // Destination register in Execute, Memory, Writeback stages
  input  logic [1:0]  FResSelM,                           // FPU result select in Memory stage
  input  logic        XEnD, YEnD, ZEnD,                   // X, Y, Z inputs used in Decode stage
  output logic        FPUStallD,                          // FPU stalls Decode stage
  output logic [1:0]  ForwardXE, ForwardYE, ForwardZE     // Forwarding select for X, Y, Z inputs
);

  logic MatchDE; // is a value needed in decode stage being worked on in execute stage

  // Decode-stage instruction source depends on result from execute stage instruction
  assign MatchDE = ((Adr1D == RdE) & XEnD) | ((Adr2D == RdE) & YEnD) | ((Adr3D == RdE) & ZEnD);
  assign FPUStallD = MatchDE & FRegWriteE;

  // Forwarding select for a source register in the Execute stage
  //   10: PreFpResM from the Memory stage, only if the result is already available there (FResSel = 00)
  //   01: FResultW from the Writeback stage
  //   00: register file (FRD1E, FRD2E, FRD3E)
  function automatic logic [1:0] ForwardSel(input logic [4:0] AdrE);
    if ((AdrE == RdM) & FRegWriteM)      ForwardSel = (FResSelM == 2'b00) ? 2'b10 : 2'b00;
    else if ((AdrE == RdW) & FRegWriteW) ForwardSel = 2'b01;
    else                                 ForwardSel = 2'b00;
  endfunction

  always_comb begin
    ForwardXE = ForwardSel(Adr1E);
    ForwardYE = ForwardSel(Adr2E);
    ForwardZE = ForwardSel(Adr3E);
  end
endmodule
