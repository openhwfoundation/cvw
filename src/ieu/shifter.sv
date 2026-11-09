///////////////////////////////////////////
// shifter.sv
//
// Written:  David Harris David_Harris@hmc.edu, Sarah Harris Sarah.Harris@unlv.edu, Kevin Kim kekim@hmc.edu 9 January 2021
// Modified:
//
// Purpose: Shifter and rotator.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module shifter import cvw::*; #(parameter cvw_t P) (
  input  logic [P.XLEN-1:0]     A,                             // shift Source
  input  logic [P.LOG_XLEN-1:0] Amt,                           // Shift amount
  input  logic                  Right, Rotate, W64, SubArith,  // Shift right, rotate, W64-type operation, arithmetic shift
  output logic [P.XLEN-1:0]     Y);                            // Shifted result

  logic [2*P.XLEN-2:0]          Z, ZShift;                     // Input to funnel shifter, shifted amount before truncated to 32 or 64 bits
  logic [P.LOG_XLEN-1:0]        TruncAmt, Offset;              // Shift amount adjusted for RV64, right-shift amount
  logic                         Sign;                          // Sign bit for sign extension

  assign Sign = A[P.XLEN-1] & SubArith;  // sign bit for sign extension
  if (P.XLEN == 32) begin // rv32
    if (P.ZBB_SUPPORTED | P.ZBKB_SUPPORTED) begin : rotfunnel32 // rv32 shifter with rotates
      always_comb  // funnel mux
        case ({Right, Rotate})
          2'b00:        Z = {A[31:0], 31'b0};
          2'b10:        Z = {{31{Sign}}, A[31:0]};
          2'b01, 2'b11: Z = {A[30:0], A[31:0]}; // rotates (a left rotate is a right rotate by -TruncAmt)
        endcase
    end else begin : norotfunnel32 // rv32 shifter without rotates
      always_comb  // funnel mux
        if (Right)  Z = {{31{Sign}}, A[31:0]};
        else        Z = {A[31:0], 31'b0};
    end
    assign TruncAmt = Amt; // shift amount
  end else begin // rv64
    logic [P.XLEN-1:0]         A64;
    // W-type shifts use A[31:0]: zero-extended for logical (sel 00) or sign-extended for arithmetic (sel 01); others use A (sel 1x)
    mux3 #(64) extendmux({{32{1'b0}}, A[31:0]}, {{32{A[31]}}, A[31:0]}, A, {~W64, SubArith}, A64); // bottom 32 bits are always A[31:0], so effectively a 32-bit upper mux
    if (P.ZBB_SUPPORTED | P.ZBKB_SUPPORTED) begin : rotfunnel64 // rv64 shifter with rotates
      // shifter source select mux: shifts and rotates share one source so they share the funnel mux inputs
      logic [P.XLEN-1:0]   Src;                           // shift and rotate source
      mux2 #(P.XLEN) rotmux(A64, {A[31:0], A[31:0]}, W64 & Rotate, Src); // W64 rotations
      always_comb  // funnel mux
        case ({Right, Rotate})
          2'b00:        Z = {Src[63:0], {63'b0}};
          2'b10:        Z = {{63{Sign}}, Src[63:0]};
          2'b01, 2'b11: Z = {Src[62:0], Src[63:0]}; // rotates (a left rotate is a right rotate by -TruncAmt)
        endcase
    end else begin : norotfunnel64 // rv64 shifter without rotates
      always_comb  // funnel mux
        if (Right)  Z = {{63{Sign}}, A64[63:0]};
        else        Z = {A64[63:0], {63'b0}};
    end
    assign TruncAmt = W64 ? {1'b0, Amt[4:0]} : Amt; // 32- or 64-bit shift
  end

  // Funnel shifts right by TruncAmt for right shifts and rotates, by XLEN-1-TruncAmt (~TruncAmt) for left shifts,
  // or by XLEN-TruncAmt (-TruncAmt) for left rotates
  if (P.ZBB_SUPPORTED | P.ZBKB_SUPPORTED) assign Offset = Right ? TruncAmt : Rotate ? -TruncAmt : ~TruncAmt;
  else                                    assign Offset = Right ? TruncAmt : ~TruncAmt;

  // Funnel operation: shift right by each power of 2, largest first.  Only ZShift[XLEN-1:0] is used, so synthesis
  // drops the bits that each step moves out of reach; Z >> Offset synthesizes to a larger full-width shifter.
  always_comb begin
    ZShift = Z;
    for (int i = P.LOG_XLEN-1; i >= 0; i--)
      if (Offset[i]) ZShift = ZShift >> 2**i;
  end
  assign Y = ZShift[P.XLEN-1:0];
endmodule
