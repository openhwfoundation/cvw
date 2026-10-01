///////////////////////////////////////////
// vconfig.sv
//
// Written: ytai@g.hmc.edu 2026-09-08
//
// Purpose: Execute the RVV configuration instructions vsetvli / vsetivli / vsetvl.
//
// Documentation: TODO: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

// TODO: vset is currently not in the decode stage, udpates will be needed to implement vset instruction fusion
// We would need to decide whether to only forward the imm type of also forward the rs2 type of vtype
module vconfig import cvw::*;  #(parameter cvw_t P) (
  input  logic              clk, reset,
  input  logic              StallM, FlushM,
  // Decoded fields
  input  logic              VsetE,              // instruction is vsetvli / vsetivli / vsetvl
  input  logic              VsetvlE,            // vsetvl: vtype from rs2
  input  logic              VsetivliE,          // vsetivli: AVL is the uimm5 in the rs1 field
  input  logic [4:0]        Rs1E, RdE,          // rs1 and rd fields, which select the AVL
  input  logic [10:0]       VTYPEImmE,          // zero-extended vtype immediate for vsetvli/vsetivli
  // Forwarded scalar sources
  input  logic [P.XLEN-1:0] ForwardedSrcAE,     // rs1: AVL for vsetvli/vsetvl
  input  logic [P.XLEN-1:0] ForwardedSrcBE,     // rs2: full vtype for vsetvl
  // Current committed vl (for keep-vl)
  input  logic [P.XLEN-1:0] VL_REGW,
  // M-stage outputs (drive csrv commit + mstatus.VS dirty; NewVLM is also the rd result)
  output logic              WriteVLVTYPEM,
  output logic [P.XLEN-1:0] NewVLM,
  output logic [7:0]        NewVTYPEM,
  output logic              NewVILLM
);

  // vtype field extraction
  logic [2:0] VsewE, VlmulE;
  logic       VtaE, VmaE;
  logic [7:0] VTYPESrcE;                     // vtype selected between imm and rs2
  logic       VTYPEReservedE;                // are any reserved vtype bits set

  assign VTYPESrcE      = VsetvlE ? ForwardedSrcBE[7:0] : VTYPEImmE[7:0];
  assign VTYPEReservedE = VsetvlE ? (|ForwardedSrcBE[P.XLEN-1:8]) : (|VTYPEImmE[10:8]);

  assign VlmulE = VTYPESrcE[2:0];
  assign VsewE  = VTYPESrcE[5:3];
  assign VtaE   = VTYPESrcE[6];
  assign VmaE   = VTYPESrcE[7];

  // VLMAX = LMUL * VLEN / SEW
  localparam signed [7:0] LOG_VLEN    = 8'($clog2(P.VLEN));
  localparam signed [7:0] LOG_ELEN    = 8'($clog2(P.ELEN));
  localparam signed [7:0] LOG_SEW_MIN = 8'd3;                    // SEW_MIN = 8 bits, TODO: make SEW_MIN a parameter

  logic signed [7:0] LmulLog2E, SewLog2E, VlmaxLog2E;
  logic              VlmulReservedE, VsewReservedE, VlmaxUnsupportedE;

  assign LmulLog2E  = {{5{VlmulE[2]}}, VlmulE};
  assign SewLog2E   = LOG_SEW_MIN + {5'b0, VsewE};
  assign VlmaxLog2E = LOG_VLEN + LmulLog2E - SewLog2E;

  assign VlmulReservedE    = (VlmulE == 3'b100) | (LmulLog2E < LOG_SEW_MIN - LOG_ELEN);    // reserved: vlmul = 100, LMUL < SEW_MIN/ELEN;
  assign VsewReservedE     = VsewE[2] | (SewLog2E > LOG_ELEN);                             // reserved: vsew = 1xx, SEW > ELEN
  assign VlmaxUnsupportedE = VlmaxLog2E[7];                                                // unsupported: VLMAX < 1 (exponent negative)

  logic [P.XLEN-1:0] VlmaxE;
  assign VlmaxE = VlmaxUnsupportedE ? '0 : {{(P.XLEN-1){1'b0}}, 1'b1} << VlmaxLog2E[$clog2(P.XLEN)-1:0];

  // vill check
  logic NewVILLE;
  assign NewVILLE = VlmulReservedE | VsewReservedE | VlmaxUnsupportedE | VTYPEReservedE;

  // AVL selection
  logic [P.XLEN-1:0] AVLE;
  always_comb begin
    if      (VsetivliE)  AVLE = {{(P.XLEN-5){1'b0}}, Rs1E};
    else if (Rs1E != 5'd0) AVLE = ForwardedSrcAE;
    else if (RdE  != 5'd0) AVLE = VlmaxE;
    else                   AVLE = VL_REGW;
  end

  // new vl
  logic [P.XLEN-1:0] NewVLE;
  assign NewVLE = NewVILLE ? '0 : (AVLE < VlmaxE) ? AVLE : VlmaxE;

  // When vill is set, remaining bits of vtype should be zero
  logic [7:0] NewVTYPEE;
  assign NewVTYPEE = NewVILLE ? 8'b0 : {VmaE, VtaE, VsewE, VlmulE};

  logic WriteVLVTYPEE;
  assign WriteVLVTYPEE = VsetE;

  flopenrc #(1)        WriteVLVTYPEMReg (clk, reset, FlushM, ~StallM, WriteVLVTYPEE, WriteVLVTYPEM);
  flopenrc #(P.XLEN)   NewVLMReg        (clk, reset, FlushM, ~StallM, NewVLE,        NewVLM);
  flopenrc #(8)        NewVTYPEMReg     (clk, reset, FlushM, ~StallM, NewVTYPEE,     NewVTYPEM);
  flopenrc #(1)        NewVILLMReg      (clk, reset, FlushM, ~StallM, NewVILLE,      NewVILLM);

endmodule
