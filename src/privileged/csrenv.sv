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

  // Effective envcfg controls broadcast to IEU/MMU. Machine envcfg gates all
  // lower modes; henvcfg additionally gates VS/VU behavior when V=1.
  assign ENVCFG_PBMTE = (P.H_SUPPORTED & VirtModeW) ? (HENVCFG_REGW[62] & MENVCFG_REGW[62]) : MENVCFG_REGW[62];
  assign ENVCFG_ADUE  = (P.H_SUPPORTED & VirtModeW) ? (HENVCFG_REGW[61] & MENVCFG_REGW[61]) : MENVCFG_REGW[61];

  if (P.H_SUPPORTED) begin: envcfg_h
    logic [3:0] MENVCFG_CBEM, HENVCFG_CBEM, SENVCFG_CBEM;
    logic [3:0] HSENVCFG_CBEM, VSENVCFG_CBEM, UENVCFG_CBEM, VUENVCFG_CBEM;
    logic       CBOInvalInstrM, CBOCleanInstrM, CBOFlushInstrM, CBOZeroInstrM;
    logic       MENVCFG_CBIEM, HENVCFG_CBIEM, SENVCFG_CBIEM;
    logic       MENVCFG_CBCFEM, HENVCFG_CBCFEM, SENVCFG_CBCFEM;
    logic       MENVCFG_CBZEM, HENVCFG_CBZEM, SENVCFG_CBZEM;
    logic       VirtualVSENVFaultM, VirtualVUENVFaultM;

    assign MENVCFG_CBEM  = MENVCFG_REGW[7:4];
    assign HENVCFG_CBEM  = HENVCFG_REGW[7:4];
    assign SENVCFG_CBEM  = SENVCFG_REGW[7:4];
    assign HSENVCFG_CBEM = MENVCFG_CBEM;
    assign VSENVCFG_CBEM = MENVCFG_CBEM & HENVCFG_CBEM;
    assign UENVCFG_CBEM  = MENVCFG_CBEM & SENVCFG_CBEM;
    assign VUENVCFG_CBEM = MENVCFG_CBEM & HENVCFG_CBEM & SENVCFG_CBEM;

    assign ENVCFG_CBE = (PrivilegeModeW == P.M_MODE) ? 4'b1111 :
                        (PrivilegeModeW == P.S_MODE | !P.S_SUPPORTED) ? (VirtModeW ? VSENVCFG_CBEM : HSENVCFG_CBEM) :
                                                                         (VirtModeW ? VUENVCFG_CBEM : UENVCFG_CBEM);

    assign CBOInvalInstrM = P.ZICBOM_SUPPORTED & (InstrM[6:0] == 7'b0001111) & (InstrM[14:12] == 3'b010) &
                            (InstrM[11:7] == 5'b00000) & (InstrM[31:20] == 12'd0);
    assign CBOCleanInstrM = P.ZICBOM_SUPPORTED & (InstrM[6:0] == 7'b0001111) & (InstrM[14:12] == 3'b010) &
                            (InstrM[11:7] == 5'b00000) & (InstrM[31:20] == 12'd1);
    assign CBOFlushInstrM = P.ZICBOM_SUPPORTED & (InstrM[6:0] == 7'b0001111) & (InstrM[14:12] == 3'b010) &
                            (InstrM[11:7] == 5'b00000) & (InstrM[31:20] == 12'd2);
    assign CBOZeroInstrM  = P.ZICBOZ_SUPPORTED & (InstrM[6:0] == 7'b0001111) & (InstrM[14:12] == 3'b010) &
                            (InstrM[11:7] == 5'b00000) & (InstrM[31:20] == 12'd4);

    assign MENVCFG_CBIEM  = MENVCFG_REGW[5:4] != 2'b00;
    assign HENVCFG_CBIEM  = HENVCFG_REGW[5:4] != 2'b00;
    assign SENVCFG_CBIEM  = SENVCFG_REGW[5:4] != 2'b00;
    assign MENVCFG_CBCFEM = MENVCFG_REGW[6];
    assign HENVCFG_CBCFEM = HENVCFG_REGW[6];
    assign SENVCFG_CBCFEM = SENVCFG_REGW[6];
    assign MENVCFG_CBZEM  = MENVCFG_REGW[7];
    assign HENVCFG_CBZEM  = HENVCFG_REGW[7];
    assign SENVCFG_CBZEM  = SENVCFG_REGW[7];

    // H-spec henvcfg CBIE/CBCFE/CBZE rules make HS-qualified CBOs virtual-instruction
    // traps in VS/VU when henvcfg or senvcfg blocks execution; menvcfg blocks stay illegal.
    assign VirtualVSENVFaultM = (CBOInvalInstrM & MENVCFG_CBIEM & ~HENVCFG_CBIEM) |
                                ((CBOCleanInstrM | CBOFlushInstrM) & MENVCFG_CBCFEM & ~HENVCFG_CBCFEM) |
                                (CBOZeroInstrM & MENVCFG_CBZEM & ~HENVCFG_CBZEM);
    assign VirtualVUENVFaultM = (CBOInvalInstrM & MENVCFG_CBIEM & (~HENVCFG_CBIEM | ~SENVCFG_CBIEM)) |
                                ((CBOCleanInstrM | CBOFlushInstrM) & MENVCFG_CBCFEM & (~HENVCFG_CBCFEM | ~SENVCFG_CBCFEM)) |
                                (CBOZeroInstrM & MENVCFG_CBZEM & (~HENVCFG_CBZEM | ~SENVCFG_CBZEM));
    assign VirtualCMOInstrM = VirtModeW & (((PrivilegeModeW == P.S_MODE) & VirtualVSENVFaultM) |
                                           ((PrivilegeModeW == P.U_MODE) & VirtualVUENVFaultM));
  end else begin: envcfg_noh
    assign ENVCFG_CBE = (PrivilegeModeW == P.M_MODE) ? 4'b1111 :
                        (PrivilegeModeW == P.S_MODE | !P.S_SUPPORTED) ? MENVCFG_REGW[7:4] :
                                                                         (MENVCFG_REGW[7:4] & SENVCFG_REGW[7:4]);
    assign VirtualCMOInstrM = 1'b0;
  end
endmodule
