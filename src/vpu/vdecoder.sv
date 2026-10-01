///////////////////////////////////////////
// vdecoder.sv
//
// Written: Rose Thompson rose.thompson@skyworksinc.com
// Created: 26 August 2026
// Modified: 26 August 2026
//
// Purpose: vector decoder module
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

/* verilator lint_off UNUSEDPARAM */
// *** this will be useful later. Remove the lint_off when ready
module vdecoder import cvw::*;  #(parameter cvw_t P) (
/* verilator lint_on UNUSEDPARAM */
  input  logic        clk, reset,
  // Decode stage control signals
  input  logic        StallVectorD, FlushVectorD,          // Stall, flush Decode stage
  input  logic [31:0] InstrD,             // lmul sequenced micro-op instruction in Decode stage

  // Decode stage outputs
  output logic [4:0] Vs1D, Vs2D,               // Vector Source 1 and 2
  output logic [4:0] VdD,                      // Vector Destination read (overwrite)
  output logic VMD,                            // 0 = mask enabled, 1 mask disabled
  output logic [5:0] Funct6D,
  output logic [2:0] Funct3D,
  output logic RegWriteD,
  output logic VRegWriteD,
  output logic [1:0] VALUSrcAD,
  output logic VALUSrcBD,
  output logic VALUResultSrcD,
  output logic IllegalVPUInstrD
);


`define VCTRLW 7

  logic [6:0] OpD;                             // Opcode in Decode stage
  logic OPIVVD, OPFVVD, OPMVVD, OPIVID;
  logic OPIVXD, OPFVFD, OPMVXD, VSETD;
  logic VLSFunctD;
  logic MewD;


  assign OpD = InstrD[6:0];
  assign Funct3D = InstrD[14:12];
  assign Funct6D = InstrD[31:26];
  assign Vs1D    = InstrD[19:15];
  assign Vs2D    = InstrD[24:20];
  assign VdD     = InstrD[11:7];
  assign OPIVVD = Funct3D == 3'b000;
  assign OPFVVD = Funct3D == 3'b001;
  assign OPMVVD = Funct3D == 3'b010;
  assign OPIVID = Funct3D == 3'b011;
  assign OPIVXD = Funct3D == 3'b100;
  assign OPFVFD = Funct3D == 3'b101;
  assign OPMVXD = Funct3D == 3'b110;
  assign VSETD  = Funct3D == 3'b111;
  assign VMD    = InstrD[25];
  assign MewD   = InstrD[28];

  assign VLSFunctD = (Funct3D == 3'b000) | (Funct3D == 3'b101) | (Funct3D == 3'b110) | (Funct3D == 3'b111) & ~MewD;

  logic [`VCTRLW-1:0] ControlsD;                // Main Instruction Decoder control signals // *** far from complete

  always_comb begin
    case(OpD)
      // RegWrite_VRegWrite_ALUSrc(A_B)_ALUResult_Illegal
      7'b0000111: if(VLSFunctD)
        ControlsD = `VCTRLW'b0_1_10_0_1_0; // unit-stride; vl // *** add the address modes later
      7'b0100111: if(VLSFunctD)
        ControlsD = `VCTRLW'b0_0_10_1_0_0; // unit-stride; vs
      7'b1010111: begin // vector data operation
        if(OPIVVD)
          ControlsD = `VCTRLW'b0_1_00_0_0_0;
        else if(OPFVVD)
          ControlsD = `VCTRLW'b0_1_00_0_0_0; // *** expand later writes either GPR or VRF
        else if(OPMVVD)
          ControlsD = `VCTRLW'b0_1_00_0_0_0; // *** expand later writes either GPR or VRF
        else if(OPIVID)
          ControlsD = `VCTRLW'b0_1_01_0_0_0;
        else if(OPIVXD)
          ControlsD = `VCTRLW'b0_1_10_0_0_0;
        else if(OPFVFD)
          ControlsD = `VCTRLW'b0_1_10_0_0_0;
        else if(OPMVXD)
          ControlsD = `VCTRLW'b0_1_10_0_0_0; // *** expand later writes either GPR or VRF
        else if(VSETD)
          ControlsD = `VCTRLW'b1_0_10_0_0_0; // *** incomplete
      end
      default:
        ControlsD = `VCTRLW'b0_0_00_0_0_1;
    endcase
  end

  assign {RegWriteD, VRegWriteD, VALUSrcAD, VALUSrcBD, VALUResultSrcD, IllegalVPUInstrD} = ControlsD;

endmodule
