///////////////////////////////////////////
// aes64d.sv
//
// Written: ryan.swann@okstate.edu, james.stine@okstate.edu
// Created: 20 February 2024
//
// Purpose: aes64dsm and aes64ds instruction: RV64 middle and final round AES decryption
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
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

module aes64d(
   input  logic [63:0] rs1,
   input  logic [63:0] rs2,
   input  logic        finalround, aes64im,
   output logic [63:0] result
);

   logic [63:0]        ShiftRowsOut, SboxOut, MixcolsIn, MixcolsOut;

   // Apply inverse shiftrows to rs2 and rs1
   aesinvshiftrows64 srow({rs2, rs1}, ShiftRowsOut);

   // Apply full word inverse substitution to lower doubleord of shiftrow out
   aesinvsbox64 invsbox(ShiftRowsOut,  SboxOut);

   mux2 #(64) mixcolmux(SboxOut, rs1, aes64im, MixcolsIn);

   // Apply inverse MixColumns to sbox outputs
   aesinvmixcolumns32 invmw0(MixcolsIn[31:0], MixcolsOut[31:0]);
   aesinvmixcolumns32 invmw1(MixcolsIn[63:32], MixcolsOut[63:32]);

   // Final round skips mixcolumns.
   mux2 #(64) resultmux(MixcolsOut, SboxOut, finalround, result);
endmodule
