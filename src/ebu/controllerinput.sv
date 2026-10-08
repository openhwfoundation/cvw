///////////////////////////////////////////
// controllerinput.sv
//
// Written: Rose Thompson rose@rosethompson.net
// Created:  August 31, 2022
// Modified: 18 January 2023
//
// Purpose: AHB multi controller interface to merge LSU and IFU controls.
//          See ARM_HIH0033A_AMBA_AHB-Lite_SPEC 1.0
//          Arbitrates requests from instruction and data streams
//          Connects core to peripherals and I/O pins on SOC
//          Bus width presently matches XLEN
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

module controllerinput #(
  parameter PA_BITS,
  parameter SAVE_ENABLED = 1           // 1: Save manager inputs if Save = 1, 0: Don't save inputs
)(
  input  logic                HCLK,
  input  logic                HRESETn,
  input  logic                Save,     // Two or more managers requesting (HTRANS != 00) at the same time.  Save the non-granted manager inputs
  input  logic                Restore,  // Restore a saved manager inputs when it is finally granted
  input  logic                Disable,  // Suppress HREADY to the non-granted manager
  output logic                Request,  // This manager is making a request
  // controller input
  input  logic [1:0]          HTRANSIn,  // Manager input. AHB transaction type, 00: IDLE, 10 NON_SEQ, 11 SEQ
  input  logic                HWRITEIn,  // Manager input. AHB 0: Read operation 1: Write operation
  input  logic [2:0]          HSIZEIn,   // Manager input. AHB transaction width
  input  logic [2:0]          HBURSTIn,  // Manager input. AHB burst length
  input  logic [PA_BITS-1:0]  HADDRIn,   // Manager input. AHB address
  output logic                HREADYOut, // Indicate to manager the peripheral is not busy and another manager does not have priority
  // controller output
  output logic [1:0]          HTRANSOut, // Arbitrated manager transaction. AHB transaction type, 00: IDLE, 10 NON_SEQ, 11 SEQ
  output logic                HWRITEOut, // Arbitrated manager transaction. AHB 0: Read operation 1: Write operation
  output logic [2:0]          HSIZEOut,  // Arbitrated manager transaction. AHB transaction width
  output logic [2:0]          HBURSTOut, // Arbitrated manager transaction. AHB burst length
  output logic [PA_BITS-1:0]  HADDROut,  // Arbitrated manager transaction. AHB address
  input  logic                HREADYIn   // Peripheral ready
);

  logic                       HWRITESave;
  logic [2:0]                 HSIZESave;
  logic [2:0]                 HBURSTSave;
  logic [1:0]                 HTRANSSave;
  logic [PA_BITS-1:0]         HADDRSave;

  if (SAVE_ENABLED) begin
    flopenr #(1+3+3+2+PA_BITS) SaveReg(HCLK, ~HRESETn, Save,
      {HWRITEIn, HSIZEIn, HBURSTIn, HTRANSIn, HADDRIn},
      {HWRITESave, HSIZESave, HBURSTSave, HTRANSSave, HADDRSave});
    mux2 #(1+3+3+2+PA_BITS) RestorMux({HWRITEIn, HSIZEIn, HBURSTIn, HTRANSIn, HADDRIn},
      {HWRITESave, HSIZESave, HBURSTSave, HTRANSSave, HADDRSave},
      Restore,
      {HWRITEOut, HSIZEOut, HBURSTOut, HTRANSOut, HADDROut});
  end else begin
    assign HWRITEOut = HWRITEIn;
    assign HSIZEOut = HSIZEIn;
    assign HBURSTOut = HBURSTIn;
    assign HTRANSOut = HTRANSIn;
    assign HADDROut = HADDRIn;
  end

  assign Request = HTRANSOut != 2'b00;
  assign HREADYOut = HREADYIn & ~Disable;

endmodule
