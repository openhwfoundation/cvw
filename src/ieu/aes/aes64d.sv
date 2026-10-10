///////////////////////////////////////////
// aes64d.sv
//
// Written:  Ryan Swann ryan.swann@okstate.edu, James Stine james.stine@okstate.edu 20 February 2024
// Modified: David Harris David_Harris@hmc.edu
//
// Purpose: Inverse ShiftRows, SubBytes, and MixColumns for the RV64 aes64ds, aes64dsm, and aes64im instructions.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
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
