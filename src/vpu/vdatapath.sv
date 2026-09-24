///////////////////////////////////////////
// vdatapath.sv
//
// Written: Rose Thompson rose.thompson@skyworksinc.com
// Created: 2 September 2026
// Modified: 2 September 2026
//
// Purpose: vector datapath module
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

module vdatapath import cvw::*;  #(parameter cvw_t P) (
  input  logic                 clk,
  input  logic                 reset,
  // Hazards
  input  logic                 StallD, StallE, StallM, StallW,      // stall signals (from HZU)
  input  logic                 FlushD, FlushE, FlushM, FlushW,      // flush signals (from HZU)
  // flow control
  input  logic [P.VPU_MAX_EU-1:0] ControllerValidD,
  output logic [P.VPU_MAX_EU-1:0] ExecutionUnitReadyD,
  // control input
  input  logic [4:0] Vs1FinalD, Vs2FinalD,               // Vector Source 1 and 2
  input  logic [4:0] VdFinalD,                      // Vector Destination read (overwrite)
  input  logic VmD,                            // 0 = mask enabled, 1 mask disabled
  input  logic [5:0] Funct6D,
  input  logic [2:0] Funct3D,
  input  logic VWriteIntD,
  input  logic VRegWriteD,
  input  logic [1:0] VALUSrcAD,
  input  logic VALUSrcBD,
  input  logic VALUResultD,
  input  logic IllegalVPUInstrD,
  // from/to the scalar core
  input  logic [P.XLEN-1:0]    ForwardedSrcAE, ForwardedSrcBE,     // Integer/FP input for convert, move (from IEU)
  output logic [P.VPU_LSU_BLEN-1:0]    VWriteDataM [P.VPU_LSU_EU-1:0],          // Data to be written to memory (to LSU)
  output logic [P.XLEN-1:0]            VEUAdrM     [P.VPU_LSU_EU-1:0],          // Data to be written to memory (to LSU)
  input  logic [P.VPU_LSU_BLEN-1:0]    VReadDataM [P.VPU_LSU_EU-1:0], // Read data (from LSU)
  output logic [P.XLEN-1:0]            VIEUFPResultW                            // Int or FP result for X or F regs.
  //
);

  logic [P.VLEN-1:0] SrcAD, SrcBD, SrcCD;
  logic [P.VLEN-1:0] v0D;
  logic [P.VLEN-1:0] VResultFinalW;


  logic            VdFinalweW;
  logic [4:0]      VdFinalW;

  vregfile #(P.VLEN) vregfile(clk, reset, VdFinalweW, Vs1FinalD, Vs2FinalD, VdFinalD, VdFinalW,
                              VResultFinalW, SrcAD, SrcBD, SrcCD, v0D);


  // *** remove all of this when ready
  genvar i;
  for(i = 0; i < P.VPU_LSU_LANES; i++) begin
      assign VWriteDataM[i] = '0;
      assign VEUAdrM[i] = '0;
  end

  assign ExecutionUnitReadyD = '1;
  assign VIEUFPResultW = '0;
  assign VdFinalweW = '0;
  assign VdFinalW = '0;
  assign VResultFinalW = '0;

endmodule
