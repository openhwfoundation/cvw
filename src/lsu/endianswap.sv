///////////////////////////////////////////
// endianswap.sv
//
// Written:  David Harris David_Harris@hmc.edu 7 May 2022
// Modified:
//
// Purpose: Big-endian byte swap.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2022-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module endianswap #(parameter LEN) (
  input  logic            BigEndianM,
  input  logic [LEN-1:0]  a,
  output logic [LEN-1:0]  y
);

  logic [LEN-1:0] Swapped; // a with its bytes in reverse order

  genvar i;
  for (i = 0; i < LEN/8; i++) begin : byteswap
    assign Swapped[8*i +: 8] = a[LEN-8-8*i +: 8];
  end

  assign y = BigEndianM ? Swapped : a;
endmodule
