///////////////////////////////////////////
// clmulfull.sv
//
// Written:  David Harris 24 November 2026
// Modified:
//
// Purpose: Full (2N-1)-bit carry-less product, Karatsuba recursion down to THRESH bits:
//          X*Y = Z0 ^ ((Z0 ^ Z1 ^ Z2) << N/2) ^ (Z2 << N), Z0 = Xl*Yl, Z2 = Xh*Yh, Z1 = (Xl^Xh)*(Yl^Yh).
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

module clmulfull #(parameter N=16, parameter THRESH=8) (
  input  logic [N-1:0]   X, Y,               // Operands
  output logic [2*N-2:0] Z);                 // Full carry-less product

  if (N <= THRESH) begin : school
    always_comb begin
      Z = '0;
      for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) Z[i+j] = Z[i+j] ^ (X[i] & Y[j]);
    end
  end else begin : karatsuba
    localparam H = N/2;
    logic [2*H-2:0] Z0, Z1, Z2, ZM;
    clmulfull #(H, THRESH) f0(X[H-1:0], Y[H-1:0], Z0);
    clmulfull #(H, THRESH) f2(X[N-1:H], Y[N-1:H], Z2);
    clmulfull #(H, THRESH) f1(X[H-1:0] ^ X[N-1:H], Y[H-1:0] ^ Y[N-1:H], Z1);
    assign ZM = Z0 ^ Z1 ^ Z2;
    assign Z = (2*N-1)'(Z0) ^ ((2*N-1)'(ZM) << H) ^ ((2*N-1)'(Z2) << 2*H);
  end
endmodule
