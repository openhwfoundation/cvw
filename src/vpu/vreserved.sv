///////////////////////////////////////////
// vreserved.sv
//
// Written: Georgia Tai ytai@g.hmc.edu
// Created: 28 September 2026
// Modified: 28 September 2026
//
// Purpose: reserved vector operands: element width, register group size and alignment,
//          segment size, and register group overlap
//
// Documentation: TODO: RISC-V System on Chip Design Volume 2
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

module vreserved import cvw::*;  #(parameter cvw_t P) (
  input  logic [2:0] SewD,                        // log2(SEW)
  input  logic [2:0] VlmulD,                      // vtype.vlmul, log2(LMUL) in two's complement
  input  logic [4:0] VdD, Vs2D, Vs1D,
  input  logic [2:0] VdEEWD, Vs2EEWD, Vs1EEWD,    // log2(EEW), 000 = EEW 1 (mask)
  input  logic       VdEnD, Vs2EnD, Vs1EnD,       // a vector register is used as an operand
  input  logic       VReductionD,                 // vd and vs1 are element 0 only
  input  logic       VScalarMoveD,                // the vector operand is element 0 only
  input  logic       VWholeRegD,                  // vd and vs2 are nf+1 registers
  input  logic [2:0] NfD,                         // nf field, or simm[2:0] of vmv<nr>r.v
  input  logic [5:0] VLSModeD,                    // load/store addressing modes, [0] segment
  input  logic       VmD,                         // 0 = masked by v0
  input  logic       VRegWriteD,                  // vd is written; otherwise vd is store data
  input  logic       VdNoOverlapD,                // vd may not overlap a source, nor v0 when masked
  output logic       IllegalVOperandD
);

  localparam logic [2:0] LOG_ELEN = 3'($clog2(P.ELEN));

  // Register group of each operand
  logic              VdSingleRegD, Vs2SingleRegD, Vs1SingleRegD;  // one register regardless of LMUL
  logic signed [3:0] VdEMULD, Vs2EMULD, Vs1EMULD;                 // log2(EMUL) = log2(LMUL) + log2(EEW) - log2(SEW)
  logic [1:0]        VdGroupSizeD, Vs2GroupSizeD, Vs1GroupSizeD;  // log2 of the registers in the group
  logic [1:0]        WholeRegSizeD;                               // log2(nf+1), nf is 0, 1, 3 or 7

  // vector mask (EEW 1) and vector scalar (element 0) operand are always one register
  assign VdSingleRegD  = (VdEEWD  == 3'b000) | VReductionD | VScalarMoveD;
  assign Vs2SingleRegD = (Vs2EEWD == 3'b000) | VScalarMoveD;
  assign Vs1SingleRegD = (Vs1EEWD == 3'b000) | VReductionD;

  assign VdEMULD  = $signed({VlmulD[2], VlmulD}) + $signed({1'b0, VdEEWD})  - $signed({1'b0, SewD});
  assign Vs2EMULD = $signed({VlmulD[2], VlmulD}) + $signed({1'b0, Vs2EEWD}) - $signed({1'b0, SewD});
  assign Vs1EMULD = $signed({VlmulD[2], VlmulD}) + $signed({1'b0, Vs1EEWD}) - $signed({1'b0, SewD});
  assign WholeRegSizeD = {NfD[1], ^NfD};

  // A fractional EMUL is one register
  assign VdGroupSizeD  = VWholeRegD ? WholeRegSizeD : (VdSingleRegD  | VdEMULD[3])  ? 2'd0 : VdEMULD[1:0];
  assign Vs2GroupSizeD = VWholeRegD ? WholeRegSizeD : (Vs2SingleRegD | Vs2EMULD[3]) ? 2'd0 : Vs2EMULD[1:0];
  assign Vs1GroupSizeD =                              (Vs1SingleRegD | Vs1EMULD[3]) ? 2'd0 : Vs1EMULD[1:0];


  // Width and group size
  logic       EMULReservedD, MisalignedD, SegReservedD;
  logic [6:0] SegRegsD;                              // registers of all nf+1 fields

  // EEW above ELEN, or EMUL outside 1/8 to 8 for a group that follows LMUL
  // TODO: check for fractional EMULs based on SEWMIN and ELEN
  assign EMULReservedD =
    VdEnD  & ((VdEEWD  > LOG_ELEN) | ~VdSingleRegD  & ~VWholeRegD & ((VdEMULD  > 4'sd3) | (VdEMULD  < -4'sd3))) |
    Vs2EnD & ((Vs2EEWD > LOG_ELEN) | ~Vs2SingleRegD & ~VWholeRegD & ((Vs2EMULD > 4'sd3) | (Vs2EMULD < -4'sd3))) |
    Vs1EnD & ((Vs1EEWD > LOG_ELEN) | ~Vs1SingleRegD &               ((Vs1EMULD > 4'sd3) | (Vs1EMULD < -4'sd3)));

  // Register number not a multiple of the group size
  assign MisalignedD = VdEnD  & |(VdD[2:0]  & ~(3'b111 << VdGroupSizeD)) |
                       Vs2EnD & |(Vs2D[2:0] & ~(3'b111 << Vs2GroupSizeD)) |
                       Vs1EnD & |(Vs1D[2:0] & ~(3'b111 << Vs1GroupSizeD));

  // Segment: the nf+1 fields span more than 8 registers or run past v31
  assign SegRegsD     = ({4'b0, NfD} + 7'd1) << VdGroupSizeD;
  assign SegReservedD = VLSModeD[0] & ((SegRegsD > 7'd8) | (({2'b0, VdD} + SegRegsD) > 7'd32));


  // Overlap checks
  logic       VdVs2OverlapD, VdVs1OverlapD, Vs2Vs1OverlapD;
  logic       VdV0OverlapD, Vs2V0OverlapD, Vs1V0OverlapD;           // the group holds v0
  logic [5:0] VdEndD, Vs2EndD, Vs1EndD;                             // first register past the group

  assign VdVs2OverlapD  = ~|((VdD  ^ Vs2D) & (5'b11111 << ((VdGroupSizeD  > Vs2GroupSizeD) ? VdGroupSizeD  : Vs2GroupSizeD)));
  assign VdVs1OverlapD  = ~|((VdD  ^ Vs1D) & (5'b11111 << ((VdGroupSizeD  > Vs1GroupSizeD) ? VdGroupSizeD  : Vs1GroupSizeD)));
  assign Vs2Vs1OverlapD = ~|((Vs2D ^ Vs1D) & (5'b11111 << ((Vs2GroupSizeD > Vs1GroupSizeD) ? Vs2GroupSizeD : Vs1GroupSizeD)));
  assign VdV0OverlapD   = ~|(VdD  & (5'b11111 << VdGroupSizeD));
  assign Vs2V0OverlapD  = ~|(Vs2D & (5'b11111 << Vs2GroupSizeD));
  assign Vs1V0OverlapD  = ~|(Vs1D & (5'b11111 << Vs1GroupSizeD));

  assign VdEndD  = {1'b0, VdD}  + (6'd1 << VdGroupSizeD);
  assign Vs2EndD = {1'b0, Vs2D} + (6'd1 << Vs2GroupSizeD);
  assign Vs1EndD = {1'b0, Vs1D} + (6'd1 << Vs1GroupSizeD);

  logic VdOverlapReservedD, SrcOverlapReservedD, IndexOverlapReservedD;

  // vd written as a vector (not a scalar vector) overlapping a source:
  //   no overlap allowed:  VdNoOverlapD ops
  //   vd narrower:         allowed only when vd starts at the source's first register
  //   vd wider:            allowed only from a source group with EMUL >= 1 that ends where vd ends
  //   masked:              vd may hold v0 only when vd is a mask
  assign VdOverlapReservedD = VRegWriteD & ~VReductionD & ~VScalarMoveD & (
    Vs2EnD & VdVs2OverlapD & (VdNoOverlapD |
      (VdEEWD < Vs2EEWD) & (VdD != Vs2D) |
      (VdEEWD > Vs2EEWD) & (Vs2SingleRegD | VWholeRegD | Vs2EMULD[3] | (Vs2EndD != VdEndD))) |
    Vs1EnD & VdVs1OverlapD & (VdNoOverlapD |
      (VdEEWD < Vs1EEWD) & (VdD != Vs1D) |
      (VdEEWD > Vs1EEWD) & (Vs1SingleRegD | Vs1EMULD[3] | (Vs1EndD != VdEndD))) |
    ~VmD & VdV0OverlapD & (VdNoOverlapD | (VdEEWD != 3'b000)));

  // A register read with two EEWs:
  //   vs2 and vs1 overlapping with different EEWs
  //   masked: vs2 or vs1 holding v0 as data, while v0 is read as the mask (EEW 1)
  //   store: the store data (vd field) overlapping the index with a different EEW, or holding v0 when masked
  assign SrcOverlapReservedD =
    Vs2EnD & Vs1EnD & Vs2Vs1OverlapD & (Vs2EEWD != Vs1EEWD) |
    ~VmD & Vs2EnD & Vs2V0OverlapD & (Vs2EEWD != 3'b000) |
    ~VmD & Vs1EnD & Vs1V0OverlapD & (Vs1EEWD != 3'b000) |
    ~VRegWriteD & VdEnD & (Vs2EnD & VdVs2OverlapD & (VdEEWD != Vs2EEWD) |
                           ~VmD & VdV0OverlapD & (VdEEWD != 3'b000));

  // Segment indexed load: vd across all nf+1 fields overlapping the index
  assign IndexOverlapReservedD = VLSModeD[0] & VRegWriteD & Vs2EnD &
    ({1'b0, VdD} < Vs2EndD) & ({2'b0, Vs2D} < ({2'b0, VdD} + SegRegsD));

  assign IllegalVOperandD = EMULReservedD | MisalignedD | SegReservedD |
                            VdOverlapReservedD | SrcOverlapReservedD | IndexOverlapReservedD;

endmodule
