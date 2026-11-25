///////////////////////////////////////////
// clmul.sv
//
// Written:  Kevin Kim kekim@hmc.edu, Kip Macsai-Goren kmacsaigoren@hmc.edu 1 February 2023
// Modified: David Harris 24 November 2026: Karatsuba on the full sub-products
//
// Purpose: Carry-less multiplier: low WIDTH bits of the carry-less product X*Y.
//          Split X and Y into halves: low(X*Y) = full(Xl*Yl) ^ ((low(Xh*Yl) ^ low(Xl*Yh)) << WIDTH/2).
//          The full product uses Karatsuba (clmulfull), which needs 3/4 of the AND gates of schoolbook.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2023-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module clmul #(parameter WIDTH=32) (
  input  logic [WIDTH-1:0] X, Y,             // Operands
  output logic [WIDTH-1:0] ClmulResult);     // Carry-less multiply result

  localparam THRESH = 8;                     // schoolbook at or below this width

  if (WIDTH <= THRESH) begin : school
    always_comb begin
      ClmulResult = '0;
      for (int i = 0; i < WIDTH; i++)
        for (int j = 0; j <= i; j++) ClmulResult[i] = ClmulResult[i] ^ (X[j] & Y[i-j]);
    end
  end else begin : split
    localparam H = WIDTH/2;
    logic [2*H-2:0] LL;                      // full product of low halves
    logic [H-1:0]   HL, LH;                  // low halves of cross products
    clmulfull #(H, THRESH) fll(X[H-1:0], Y[H-1:0], LL);
    clmul     #(H)         lhl(X[WIDTH-1:H], Y[H-1:0], HL);
    clmul     #(H)         llh(X[H-1:0], Y[WIDTH-1:H], LH);
    assign ClmulResult = {1'b0, LL} ^ {HL ^ LH, {H{1'b0}}};
  end
endmodule
