///////////////////////////////////////////
// aes64e.sv
//
// Written:  Ryan Swann ryan.swann@okstate.edu, James Stine james.stine@okstate.edu 20 February 2024
// Modified: David Harris David_Harris@hmc.edu
//
// Purpose: ShiftRows, SubBytes, and MixColumns for the RV64 aes64es and aes64esm encryption instructions.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module aes64e(
    input  logic [63:0] rs1,
    input  logic [63:0] rs2,
    input  logic        finalround,
    input  logic [31:0] Sbox0Out,
    output logic [31:0] SboxEIn,
    output logic [63:0] result
);

    logic [63:0]  ShiftRowsOut, SboxOut, MixcolsOut;

    // AES shiftrow unit
    aesshiftrows64 srow({rs2,rs1}, ShiftRowsOut);

    // Apply substitution box to 2 lower words
    // Use the shared sbox in zknde64.sv for the first sbox
    assign SboxEIn = ShiftRowsOut[31:0];
    assign SboxOut[31:0] = Sbox0Out;

    aessbox32 sbox1(ShiftRowsOut[63:32], SboxOut[63:32]); // instantiate second sbox

    // Apply MixColumns operations
    aesmixcolumns32 mw0(SboxOut[31:0],  MixcolsOut[31:0]);
    aesmixcolumns32 mw1(SboxOut[63:32], MixcolsOut[63:32]);

    // Skip mixcolumns on last round
    mux2 #(64) resultmux(MixcolsOut, SboxOut, finalround, result);
endmodule
