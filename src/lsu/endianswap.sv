///////////////////////////////////////////
// endianswap.sv
//
// Written:  David Harris David_Harris@hmc.edu 7 May 2022
// Modified:
//
// Purpose: Reverses the byte order of data for big-endian memory accesses.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2022-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module endianswap #(parameter LEN) (
  input  logic            BigEndianM,
  input  logic [LEN-1:0]  a,
  output logic [LEN-1:0]  y
);

  if(LEN == 128) begin
    always_comb
      if (BigEndianM) begin // swap endianness
        y[127:120] = a[7:0];
        y[119:112] = a[15:8];
        y[111:104] = a[23:16];
        y[103:96]  = a[31:24];
        y[95:88]   = a[39:32];
        y[87:80]   = a[47:40];
        y[79:72]   = a[55:48];
        y[71:64]   = a[63:56];
        y[63:56]   = a[71:64];
        y[55:48]   = a[79:72];
        y[47:40]   = a[87:80];
        y[39:32]   = a[95:88];
        y[31:24]   = a[103:96];
        y[23:16]   = a[111:104];
        y[15:8]    = a[119:112];
        y[7:0]     = a[127:120];
      end else y = a;
  end else if(LEN == 64) begin
    always_comb
      if (BigEndianM) begin // swap endianness
        y[63:56] = a[7:0];
        y[55:48] = a[15:8];
        y[47:40] = a[23:16];
        y[39:32] = a[31:24];
        y[31:24] = a[39:32];
        y[23:16] = a[47:40];
        y[15:8]  = a[55:48];
        y[7:0]   = a[63:56];
      end else y = a;
  end else begin
    always_comb
      if (BigEndianM) begin
        y[31:24] = a[7:0];
        y[23:16] = a[15:8];
        y[15:8]  = a[23:16];
        y[7:0]   = a[31:24];
      end else y = a;
  end
endmodule
