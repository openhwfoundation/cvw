///////////////////////////////////////////
// vregfile.sv
//
// Written: Rose Thompson Rose.Thompson@skyworksinc.com
// based on regfile.sv by David_Harris@hmc.edu, Sarah.Harris@unlv.edu
// Created: 2 September
// Modified: 17 November 2026 Georgia Tai ytai@g.hmc.edu
//
// Purpose: Banked vector register file with streaming reads
//
// Documentation: RISC-V System on Chip Design Vol 2
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University & Skyworks Solutions Inc.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

// Each bank holds one BLEN beat of all 32 registers.
// A read request enters bank 0 and moves one bank per cycle, so bank i handles the request issued i cycles ago
// and a register streams out one beat per cycle.
// One micro-op issues per cycle, so two requests should not collide in the same bank.
// Commit writes the whole register to all banks.
// *** direct bank access for vrgather / vcompress, sVRF read check for chaining

module vregfile #(parameter VLEN, BLEN, ORDERBITS) (
  input  logic                 clk, reset,
  input  logic                 VectorStallE,              // hold every stream
  // read request of a micro-op at dispatch
  input  logic [4:0]           Vs1D, Vs2D, VdD,           // registers to read
  input  logic                 OldVdD,                    // vd read fills the micro-op's sVRF entry
  input  logic [ORDERBITS-1:0] OrderD,                    // order tag of the micro-op
  // one beat per bank, bank i from the request issued i cycles ago
  output logic [BLEN-1:0]      VRD1 [VLEN/BLEN-1:0],
  output logic [BLEN-1:0]      VRD2 [VLEN/BLEN-1:0],
  output logic [BLEN-1:0]      VRD3 [VLEN/BLEN-1:0],      // vd, also the old vd beat to the sVRF
  output logic [VLEN/BLEN-1:0] OldVdValid,                // VRD3 of this bank fills an sVRF entry
  output logic [ORDERBITS-1:0] OldVdOrder [VLEN/BLEN-1:0],
  output logic [VLEN-1:0]      V0,                        // mask, on its own port
  // commit of the sVRF head entry
  input  logic                 VRegWriteW,
  input  logic [4:0]           VdW,
  input  logic [VLEN-1:0]      DataW,
  input  logic [VLEN/8-1:0]    ByteMaskW
);

  localparam BANKS   = VLEN/BLEN;
  localparam BYTES   = BLEN/8;
  localparam REQBITS = 16 + ORDERBITS;

  logic [REQBITS-1:0] Request [BANKS-1:0];               // {vs1, vs2, vd, old vd, order} at each bank

  genvar bank;

  assign Request[0] = {Vs1D, Vs2D, VdD, OldVdD, OrderD};

  for (bank = 0; bank < BANKS; bank++) begin : banks
    logic [BLEN-1:0]      Regs [31:0];
    logic [4:0]           Vs1, Vs2, Vd;
    logic [BLEN-1:0]      DataBankW;
    logic [BYTES-1:0]     ByteMaskBankW;

    // request moves to the next bank one cycle later
    if (bank > 0) flopenr #(REQBITS) requestreg(clk, reset, ~VectorStallE, Request[bank-1], Request[bank]);

    assign {Vs1, Vs2, Vd, OldVdValid[bank], OldVdOrder[bank]} = Request[bank];

    assign VRD1[bank] = Regs[Vs1];
    assign VRD2[bank] = Regs[Vs2];
    assign VRD3[bank] = Regs[Vd];
    assign V0[bank*BLEN +: BLEN] = Regs[0];

    assign DataBankW     = DataW[bank*BLEN +: BLEN];
    assign ByteMaskBankW = ByteMaskW[bank*BYTES +: BYTES];

    always_ff @(negedge clk)
      if (reset) for (int r = 0; r < 32; r++) Regs[r] <= '0;
      else if (VRegWriteW)
        for (int b = 0; b < BYTES; b++)
          if (ByteMaskBankW[b]) Regs[VdW][b*8 +: 8] <= DataBankW[b*8 +: 8];
  end

endmodule
