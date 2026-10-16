///////////////////////////////////////////
// clmul.sv
//
// Written: Kevin Kim <kekim@hmc.edu> and Kip Macsai-Goren <kmacsaigoren@hmc.edu>
// Created: 1 February 2023
// Modified:
//
// Purpose: Carry-Less multiplication unit
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module clmul #(parameter WIDTH=32) (
  input  logic [WIDTH-1:0] X, Y,             // Operands
  output logic [WIDTH-1:0] ClmulResult);     // ZBS result

  logic [(WIDTH*WIDTH)-1:0] S;               // intermediary signals for carry-less multiply

  integer i,j;

  always_comb begin
    for (i=0;i<WIDTH;i++) begin : outer
      S[WIDTH*i] = X[0] & Y[i];
      for (j=1;j<=i;j++) begin : inner
        S[WIDTH*i+j] = (X[j] & Y[i-j]) ^ S[WIDTH*i+j-1];
      end
      ClmulResult[i] = S[WIDTH*i+j-1];
    end
  end
endmodule
