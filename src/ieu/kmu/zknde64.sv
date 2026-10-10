///////////////////////////////////////////
// zknde64.sv
//
// Written:  Kelvin Tran kelvin.tran@okstate.edu, James Stine james.stine@okstate.edu 27 November 2023
// Modified: David Harris David_Harris@hmc.edu
//
// Purpose: RV64 Zkne/Zknd unit for AES encryption, decryption, and key schedule instructions.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2023-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module zknde64 import cvw::*; #(parameter cvw_t P) (
   input  logic [63:0] A, B,
   input  logic [3:0]  round,
   input  logic [3:0]  ZKNSelect,
   output logic [63:0] ZKNDEResult
);

    logic [63:0]         aes64dRes, aes64eRes, aes64ks1iRes, aes64ks2Res;
    logic [31:0]         SboxEIn, SboxKIn, Sbox0In, Sbox0Out;

    if (P.ZKND_SUPPORTED) // ZKND supports aes64ds, aes64dsm, aes64im
        aes64d    aes64d(.rs1(A), .rs2(B), .finalround(ZKNSelect[2]), .aes64im(ZKNSelect[3]), .result(aes64dRes)); // decode AES
    else assign aes64dRes = '0;
    if (P.ZKNE_SUPPORTED) begin // ZKNE supports aes64es, aes64esm
        aes64e    aes64e(.rs1(A), .rs2(B), .finalround(ZKNSelect[2]), .Sbox0Out, .SboxEIn, .result(aes64eRes));
        mux2 #(32) sboxmux(SboxEIn, SboxKIn, ZKNSelect[1], Sbox0In);
    end else begin
        assign aes64eRes = '0;
        assign Sbox0In = SboxKIn;
    end

    // One S Box is always needed for aes64ks1i and is also needed for aes64e if that is supported.  Put it at the top level to allow sharing
    aessbox32 sbox(Sbox0In, Sbox0Out);                       // Substitute bytes of value obtained for tmp2 using Rijndael sbox

    // Both ZKND and ZKNE support aes64ks1i and aes64ks2 instructions
    aes64ks1i aes64ks1i(.round, .rs1(A[63:32]), .Sbox0Out, .SboxKIn, .result(aes64ks1iRes));
    aes64ks2  aes64ks2(.rs2(B), .rs1(A[63:32]), .result(aes64ks2Res));

    // Choose among decrypt, encrypt, key schedule 1, key schedule 2 results
    mux4 #(64) zkndmux(aes64dRes, aes64eRes, aes64ks1iRes, aes64ks2Res, ZKNSelect[1:0], ZKNDEResult);
endmodule
