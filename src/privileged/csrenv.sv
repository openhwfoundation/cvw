///////////////////////////////////////////
// csrenv.sv
//
// Written: nchulani@hmc.edu 27 April 2026
// Purpose: Effective environment configuration controls
//          See RISC-V Privileged Mode Specification
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
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

module csrenv import cvw::*;  #(parameter cvw_t P) (
  input  logic [31:0]       InstrM,
  input  logic [1:0]        PrivilegeModeW,
  input  logic              VirtModeW,
  input  logic [63:0]       MENVCFG_REGW, HENVCFG_REGW,
  input  logic [P.XLEN-1:0] SENVCFG_REGW,
  output logic [3:0]        ENVCFG_CBE,
  output logic              ENVCFG_PBMTE,
  output logic              ENVCFG_ADUE,
  output logic              VirtualCMOInstrM
);

  logic UseHENVCFG, UseSENVCFG;
  assign UseHENVCFG = P.H_SUPPORTED & VirtModeW;                    // henvcfg constrains VS and VU
  assign UseSENVCFG = P.S_SUPPORTED & (PrivilegeModeW == P.U_MODE); // senvcfg constrains U and VU

  // Effective envcfg controls broadcast to IEU/MMU.  henvcfg's STCE/PBMTE/ADUE already read as zero
  // when menvcfg clears them (csrh), so they need no second AND with menvcfg here.
  assign ENVCFG_PBMTE = UseHENVCFG ? HENVCFG_REGW[62] : MENVCFG_REGW[62];
  assign ENVCFG_ADUE  = UseHENVCFG ? HENVCFG_REGW[61] : MENVCFG_REGW[61];
  assign ENVCFG_CBE   = (PrivilegeModeW == P.M_MODE) ? 4'b1111 :
                        MENVCFG_REGW[7:4] & (UseHENVCFG ? HENVCFG_REGW[7:4] : 4'b1111) &
                                            (UseSENVCFG ? SENVCFG_REGW[7:4] : 4'b1111);

  // A cbo.* that menvcfg allows but henvcfg/senvcfg blocks at V=1: the IEU flags it illegal, privdec makes it virtual.
  if (P.H_SUPPORTED) begin: envcfg_h
    logic CBOMenvcfgEnM;
    always_comb
      case (InstrM[31:20])
        12'd0:        CBOMenvcfgEnM = P.ZICBOM_SUPPORTED & (MENVCFG_REGW[5:4] != 2'b00); // cbo.inval: CBIE
        12'd1, 12'd2: CBOMenvcfgEnM = P.ZICBOM_SUPPORTED & MENVCFG_REGW[6];              // cbo.clean/flush: CBCFE
        12'd4:        CBOMenvcfgEnM = P.ZICBOZ_SUPPORTED & MENVCFG_REGW[7];              // cbo.zero: CBZE
        default:      CBOMenvcfgEnM = 1'b0;
      endcase
    assign VirtualCMOInstrM = VirtModeW & (InstrM[6:0] == 7'b0001111) & (InstrM[14:7] == 8'b010_00000) & CBOMenvcfgEnM;
  end else begin: envcfg_noh
    assign VirtualCMOInstrM = 1'b0;
  end
endmodule
