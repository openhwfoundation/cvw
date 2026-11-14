///////////////////////////////////////////
// vlane.sv
//
// Written: eoinoconnell04@gmail.com
// Created: 30 October 2026
// Modified: 30 October 2026
//
// Purpose: vector integer execution unit lane. Currently just the valu adder.
//
// Documentation: RISC-V System on Chip Design Volume 2
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University & Skyworks Solutions Inc.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
////////////////////////////////////////////////////////////////////////////////////////////////

module vlane import cvw::*;  #(parameter cvw_t P) (
  input  logic              clk, reset,
  input  logic [P.ELEN-1:0] SrcA, SrcB,      // lane operands
  input  logic [2:0]        VALUSelectE,
  input  logic [1:0]        VLaneSelectE,    // 00 = valu, 01 = vmul, 10 = move, 11 = shift
  input  logic              VSubE,
  input  logic [1:0]        VSewE,
  input  logic [1:0]        VMulSelectE,     // 00 = vmul, 01 = vmulh, 10 = vwmul
  input  logic [1:0]        VShiftSelectE,   // 00 = sll, 10 = srl, 11 = sra
  output logic [P.ELEN-1:0] LaneResult       // lane result
);

  logic [P.ELEN-1:0] SumE, ProductE, ShiftE;

  valu #(P) valu(.A(SrcA), .B(SrcB), .VALUSelect(VALUSelectE), .VSub(VSubE), .VALUResult(SumE));

  // Currently only supports unsigned vmul and vmulhu
  // ***TODO: Figure out timing since vmul returns results in Memory stage instead of Execute
  vmul #(P) vmul(.clk, .reset, .A(SrcA), .B(SrcB), .Sew(VSewE), .MulSelect(VMulSelectE), .Product(ProductE));

  vshifter #(P) vshift(.Amt(SrcA[$clog2(P.ELEN)-1:0]), .B(SrcB), .Y(ShiftE), .Right(VShiftSelectE[1]), .SubArith(VShiftSelectE[0]));

  always_comb
    case (VLaneSelectE)
      2'b00:   LaneResult = SumE;
      2'b01:   LaneResult = ProductE;
      2'b10:   LaneResult = SrcA;     // move
      2'b11:   LaneResult = ShiftE;
      default: LaneResult = SumE;
    endcase

endmodule
