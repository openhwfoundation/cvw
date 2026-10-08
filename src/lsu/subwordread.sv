///////////////////////////////////////////
// subwordread.sv
//
// Written: David_Harris@hmc.edu
// Created: 9 January 2021
// Modified: 18 January 2023
//
// Purpose: Extract subwords and sign extend for reads
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

module subwordread import cvw::*;  #(parameter cvw_t P) (
   input logic [P.LLEN-1:0]  ReadDataWordMuxM,
   input logic [3:0]         PAdrM,
   input logic [2:0]         Funct3M,
   input logic               FpLoadStoreM,
   input logic               BigEndianM,
   output logic [P.LLEN-1:0] ReadDataM
);

  localparam ADRBITS = $clog2(P.LLEN)-3;

  logic [ADRBITS-1:0]       PAdrSwapM;
  logic [7:0]               ByteM;
  logic [15:0]              HalfwordM;
  logic [31:0]              WordM;
  logic [63:0]              DblWordM;
  logic [P.LLEN-1:0]        DblWordExtM;

  // invert lsbs of address to select appropriate subword for big endian
  if (P.BIGENDIAN_SUPPORTED) assign PAdrSwapM = PAdrM[ADRBITS-1:0] ^ {ADRBITS{BigEndianM}};
  else                       assign PAdrSwapM = PAdrM[ADRBITS-1:0];

  // Use indexed part select to imply muxes to select each size of subword
  if (P.LLEN == 128) mux2 #(64) dblmux(ReadDataWordMuxM[63:0], ReadDataWordMuxM[127:64], PAdrSwapM[3], DblWordM);
  else if (P.LLEN == 64) assign DblWordM = ReadDataWordMuxM;
  else assign DblWordM = '0; // unused for RV32F
  if (P.LLEN >= 64) mux2 #(32) wordmux(DblWordM[31:0], DblWordM[63:32], PAdrSwapM[2], WordM);
  else assign WordM = ReadDataWordMuxM;
  mux2 #(16) halfwordmux(WordM[15:0], WordM[31:16], PAdrSwapM[1], HalfwordM);
  mux2 #(8)  bytemux(HalfwordM[7:0], HalfwordM[15:8], PAdrSwapM[0], ByteM);

  // ld/fld sign extension/NaN boxing, in a generate so RV32 does not elaborate a negative replication
  if (P.LLEN >= 64) assign DblWordExtM = {{P.LLEN-64{DblWordM[63]|FpLoadStoreM}}, DblWordM[63:0]};
  else              assign DblWordExtM = ReadDataWordMuxM; // shouldn't happen

  // sign extension/ NaN boxing
  always_comb
    case(Funct3M)
      3'b000:  ReadDataM = {{(P.LLEN-8){ByteM[7]}}, ByteM};                                                     // lb
      3'b001:  ReadDataM = {{P.LLEN-16{HalfwordM[15]|FpLoadStoreM}}, HalfwordM[15:0]};                          // lh/flh
      3'b010:  ReadDataM = {{P.LLEN-32{WordM[31]|FpLoadStoreM}}, WordM[31:0]};                                  // lw/flw
      3'b011:  ReadDataM = DblWordExtM;                                                                         // ld/fld
      3'b100:  if (P.LLEN == 128) ReadDataM = FpLoadStoreM ? ReadDataWordMuxM : {{P.LLEN-8{1'b0}}, ByteM[7:0]}; // lbu/flq
               else ReadDataM = {{P.LLEN-8{1'b0}}, ByteM[7:0]};                                                 // lbu
      3'b101:  ReadDataM = {{P.LLEN-16{1'b0}}, HalfwordM[15:0]};                                                // lhu
      3'b110:  ReadDataM = {{P.LLEN-32{1'b0}}, WordM[31:0]};                                                    // lwu
      default: ReadDataM = ReadDataWordMuxM;                                                                    // Shouldn't happen
    endcase
endmodule
