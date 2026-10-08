///////////////////////////////////////////
// fli.sv
//
// Written: David_Harris@hmc.edu
// Modified: 1/16/2024
//
// Purpose: Floating-point float immediate
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
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

module fli import cvw::*;  #(parameter cvw_t P) (
  input  logic [4:0]        Rs1,           // Index of immediate to select
  input  logic [1:0]        Fmt,           // 00 = single, 01 = double, 10 = half, 11 = quad
  output logic [P.FLEN-1:0] Imm            // Immediate output
);

  logic [P.FLEN-1:0] HImmBox, SImmBox, DImmBox, QImmBox;

  // select constant for each immediate size supported

  ////////////////////////////
  // half
  ////////////////////////////

  if (P.ZFH_SUPPORTED) begin
    logic [15:0] HImm;
    always_comb begin
        case(Rs1)
            0:  HImm = 16'hBC00;
            1:  HImm = 16'h0400;
            2:  HImm = 16'h0100;
            3:  HImm = 16'h0200;
            4:  HImm = 16'h1C00;
            5:  HImm = 16'h2000;
            6:  HImm = 16'h2C00;
            7:  HImm = 16'h3000;
            8:  HImm = 16'h3400;
            9:  HImm = 16'h3500;
            10: HImm = 16'h3600;
            11: HImm = 16'h3700;
            12: HImm = 16'h3800;
            13: HImm = 16'h3900;
            14: HImm = 16'h3A00;
            15: HImm = 16'h3B00;
            16: HImm = 16'h3C00;
            17: HImm = 16'h3D00;
            18: HImm = 16'h3E00;
            19: HImm = 16'h3F00;
            20: HImm = 16'h4000;
            21: HImm = 16'h4100;
            22: HImm = 16'h4200;
            23: HImm = 16'h4400;
            24: HImm = 16'h4800;
            25: HImm = 16'h4C00;
            26: HImm = 16'h5800;
            27: HImm = 16'h5C00;
            28: HImm = 16'h7800;
            29: HImm = 16'h7C00;
            30: HImm = 16'h7C00;
            31: HImm = 16'h7E00;
        endcase
    end
    assign HImmBox = {{(P.FLEN-16){1'b1}}, HImm}; // NaN-box HImm
  end else assign HImmBox = '0;

  ////////////////////////////
  // single
  ////////////////////////////

    logic [31:0] SImm;
     always_comb begin
       case(Rs1)
            0:  SImm = 32'hBF800000;
            1:  SImm = 32'h00800000;
            2:  SImm = 32'h37800000;
            3:  SImm = 32'h38000000;
            4:  SImm = 32'h3B800000;
            5:  SImm = 32'h3C000000;
            6:  SImm = 32'h3D800000;
            7:  SImm = 32'h3E000000;
            8:  SImm = 32'h3E800000;
            9:  SImm = 32'h3EA00000;
            10: SImm = 32'h3EC00000;
            11: SImm = 32'h3EE00000;
            12: SImm = 32'h3F000000;
            13: SImm = 32'h3F200000;
            14: SImm = 32'h3F400000;
            15: SImm = 32'h3F600000;
            16: SImm = 32'h3F800000;
            17: SImm = 32'h3FA00000;
            18: SImm = 32'h3FC00000;
            19: SImm = 32'h3FE00000;
            20: SImm = 32'h40000000;
            21: SImm = 32'h40200000;
            22: SImm = 32'h40400000;
            23: SImm = 32'h40800000;
            24: SImm = 32'h41000000;
            25: SImm = 32'h41800000;
            26: SImm = 32'h43000000;
            27: SImm = 32'h43800000;
            28: SImm = 32'h47000000;
            29: SImm = 32'h47800000;
            30: SImm = 32'h7F800000;
            31: SImm = 32'h7FC00000;
        endcase
    end
    assign SImmBox = {{(P.FLEN-32){1'b1}}, SImm}; // NaN-box SImm

  ////////////////////////////
  // double
  ////////////////////////////

  if (P.D_SUPPORTED) begin
    logic [63:0] DImm;
    always_comb begin
        case(Rs1)
            0:  DImm = 64'hBFF0000000000000;
            1:  DImm = 64'h0010000000000000;
            2:  DImm = 64'h3EF0000000000000;
            3:  DImm = 64'h3F00000000000000;
            4:  DImm = 64'h3F70000000000000;
            5:  DImm = 64'h3F80000000000000;
            6:  DImm = 64'h3FB0000000000000;
            7:  DImm = 64'h3FC0000000000000;
            8:  DImm = 64'h3FD0000000000000;
            9:  DImm = 64'h3FD4000000000000;
            10: DImm = 64'h3FD8000000000000;
            11: DImm = 64'h3FDC000000000000;
            12: DImm = 64'h3FE0000000000000;
            13: DImm = 64'h3FE4000000000000;
            14: DImm = 64'h3FE8000000000000;
            15: DImm = 64'h3FEC000000000000;
            16: DImm = 64'h3FF0000000000000;
            17: DImm = 64'h3FF4000000000000;
            18: DImm = 64'h3FF8000000000000;
            19: DImm = 64'h3FFC000000000000;
            20: DImm = 64'h4000000000000000;
            21: DImm = 64'h4004000000000000;
            22: DImm = 64'h4008000000000000;
            23: DImm = 64'h4010000000000000;
            24: DImm = 64'h4020000000000000;
            25: DImm = 64'h4030000000000000;
            26: DImm = 64'h4060000000000000;
            27: DImm = 64'h4070000000000000;
            28: DImm = 64'h40E0000000000000;
            29: DImm = 64'h40F0000000000000;
            30: DImm = 64'h7FF0000000000000;
            31: DImm = 64'h7FF8000000000000;
        endcase
    end
    assign DImmBox = {{(P.FLEN-64){1'b1}}, DImm}; // NaN-box DImm
  end else assign DImmBox = '0;

    ////////////////////////////
  // double
  ////////////////////////////

  if (P.Q_SUPPORTED) begin
    logic [127:0] QImm;
    always_comb begin
        case(Rs1)
            0:  QImm = 128'hBFFF0000000000000000000000000000;
            1:  QImm = 128'h00010000000000000000000000000000;
            2:  QImm = 128'h3FEF0000000000000000000000000000;
            3:  QImm = 128'h3FF00000000000000000000000000000;
            4:  QImm = 128'h3FF70000000000000000000000000000;
            5:  QImm = 128'h3FF80000000000000000000000000000;
            6:  QImm = 128'h3FFB0000000000000000000000000000;
            7:  QImm = 128'h3FFC0000000000000000000000000000;
            8:  QImm = 128'h3FFD0000000000000000000000000000;
            9:  QImm = 128'h3FFD4000000000000000000000000000;
            10: QImm = 128'h3FFD8000000000000000000000000000;
            11: QImm = 128'h3FFDC000000000000000000000000000;
            12: QImm = 128'h3FFE0000000000000000000000000000;
            13: QImm = 128'h3FFE4000000000000000000000000000;
            14: QImm = 128'h3FFE8000000000000000000000000000;
            15: QImm = 128'h3FFEC000000000000000000000000000;
            16: QImm = 128'h3FFF0000000000000000000000000000;
            17: QImm = 128'h3FFF4000000000000000000000000000;
            18: QImm = 128'h3FFF8000000000000000000000000000;
            19: QImm = 128'h3FFFC000000000000000000000000000;
            20: QImm = 128'h40000000000000000000000000000000;
            21: QImm = 128'h40004000000000000000000000000000;
            22: QImm = 128'h40008000000000000000000000000000;
            23: QImm = 128'h40010000000000000000000000000000;
            24: QImm = 128'h40020000000000000000000000000000;
            25: QImm = 128'h40030000000000000000000000000000;
            26: QImm = 128'h40060000000000000000000000000000;
            27: QImm = 128'h40070000000000000000000000000000;
            28: QImm = 128'h400E0000000000000000000000000000;
            29: QImm = 128'h400F0000000000000000000000000000;
            30: QImm = 128'h7FFF0000000000000000000000000000;
            31: QImm = 128'h7FFF8000000000000000000000000000;
        endcase
    end
    assign QImmBox = QImm; // NaN-box QImm trivial because Q is longest format
  end else assign QImmBox = '0;

  mux4 #(P.FLEN) flimux(SImmBox, DImmBox, HImmBox, QImmBox, Fmt, Imm); // select immediate based on format

endmodule
