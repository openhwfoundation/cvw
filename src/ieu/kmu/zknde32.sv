///////////////////////////////////////////
// zknde32.sv
//
// Written:  Kelvin Tran kelvin.tran@okstate.edu, James Stine james.stine@okstate.edu 27 November 2023
// Modified: David Harris David_Harris@hmc.edu
//
// Purpose: RV32 Zkne/Zknd unit for the aes32esi, aes32esmi, aes32dsi, and aes32dsmi instructions.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2023-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module zknde32 import cvw::*; #(parameter cvw_t P) (
   input  logic [31:0] A, B,
   input  logic [1:0]  bs,
   input  logic [3:0]  round,
   input  logic [3:0]  ZKNSelect,
   output logic [31:0] ZKNDEResult
);

    logic [4:0]     shamt;
    logic [7:0]     SboxIn;
    logic [31:0]    ZKNEResult, ZKNDResult, rotin, rotout;

    // Initial shamt and Sbox input selection steps shared between encrypt and decrypt
    assign shamt = {bs, 3'b0};          // shamt = bs * 8 (convert bytes to bits)
    assign SboxIn = B[shamt +: 8];               // select byte bs of rs2

    // Handle logic specific to encrypt or decrypt
    if (P.ZKND_SUPPORTED) aes32d aes32d(.SboxIn, .finalround(ZKNSelect[2]), .result(ZKNDResult));
    if (P.ZKNE_SUPPORTED) aes32e aes32e(.SboxIn, .finalround(ZKNSelect[2]), .result(ZKNEResult));

    // Mux result if both decrypt and encrypt are supported; otherwise, choose the only result
    if (P.ZKND_SUPPORTED & P.ZKNE_SUPPORTED)
        mux2 #(32) zknmux(ZKNDResult, ZKNEResult, ZKNSelect[0], rotin);
    else if (P.ZKND_SUPPORTED)
        assign rotin = ZKNDResult;
    else
        assign rotin = ZKNEResult;

    // final rotate and XOR steps shared between encrypt and decrypt
    mux4 #(32) mrotmux(rotin, {rotin[23:0], rotin[31:24]},
                       {rotin[15:0], rotin[31:16]}, {rotin[7:0], rotin[31:8]},  bs, rotout); // Rotate the mixcolumns output left by shamt (bs * 8)
    assign ZKNDEResult = A ^ rotout;               // xor with running value (A = rs1)
endmodule
