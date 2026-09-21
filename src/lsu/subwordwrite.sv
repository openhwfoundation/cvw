///////////////////////////////////////////
// subwordwrite.sv
//
// Written: David_Harris@hmc.edu
// Created: 9 January 2021
// Modified: 18 January 2023
//
// Purpose: Masking and muxing for subword writes
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

module subwordwrite #(parameter LLEN) (
  input logic  [2:0]        LSUFunct3M,
  input logic  [LLEN-1:0]   IMAFWriteDataM,
  output logic [LLEN-1:0]   LittleEndianWriteDataM
);

  // Replicate data for subword writes

  if (LLEN == 128) begin : sww
    always_comb
      case(LSUFunct3M[2:0])
        3'b000:  LittleEndianWriteDataM = {16{IMAFWriteDataM[7:0]}}; // sb
        3'b001:  LittleEndianWriteDataM = {8{IMAFWriteDataM[15:0]}}; // sh
        3'b010:  LittleEndianWriteDataM = {4{IMAFWriteDataM[31:0]}}; // sw
        3'b011:  LittleEndianWriteDataM = {2{IMAFWriteDataM[63:0]}}; // sd
        default: LittleEndianWriteDataM = IMAFWriteDataM;            // sq
      endcase
  end else if (LLEN == 64) begin : sww
    always_comb
      case(LSUFunct3M[1:0])
        2'b00:  LittleEndianWriteDataM = {8{IMAFWriteDataM[7:0]}};   // sb
        2'b01:  LittleEndianWriteDataM = {4{IMAFWriteDataM[15:0]}};  // sh
        2'b10:  LittleEndianWriteDataM = {2{IMAFWriteDataM[31:0]}};  // sw
        2'b11:  LittleEndianWriteDataM = IMAFWriteDataM;             // sd
      endcase
  end else begin : sww // 32-bit
    always_comb
      case(LSUFunct3M[1:0])
        2'b00:   LittleEndianWriteDataM = {4{IMAFWriteDataM[7:0]}};  // sb
        2'b01:   LittleEndianWriteDataM = {2{IMAFWriteDataM[15:0]}}; // sh
        2'b10:   LittleEndianWriteDataM = IMAFWriteDataM;            // sw
        default: LittleEndianWriteDataM = IMAFWriteDataM;            // shouldn't happen
      endcase
  end
endmodule
