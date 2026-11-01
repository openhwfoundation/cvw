///////////////////////////////////////////
// wallypipelinedsocwrapper.sv
//
// Written: Rose Thompson rose@rosethompson.net 16 June 2023
// Modified:
//
// Purpose: A wrapper to set parameters.  Vivado cannot set the top level parameters because it only supports verilog,
//          not system verilog.
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
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

//`include "BranchPredictorType.vh"
`include "config.vh"

import cvw::*;

module wallypipelinedsocwrapper (
  input  logic                clk,
  input  logic                reset_ext,        // external asynchronous reset pin
  output logic                reset,            // reset synchronized to clk to prevent races on release
  // AHB Interface
  input  logic [64-1:0]     HRDATAEXT,
  input  logic                HREADYEXT, HRESPEXT,
  output logic                HSELEXT,
  output logic                HSELEXTSDC,
  // outputs to external memory, shared with uncore memory
  output logic                HCLK, HRESETn,
  output logic [55:0]         HADDR,
  output logic [64-1:0]       HWDATA,
  output logic [64/8-1:0]     HWSTRB,
  output logic                HWRITE,
  output logic [2:0]          HSIZE,
  output logic [2:0]          HBURST,
  output logic [3:0]          HPROT,
  output logic [1:0]          HTRANS,
  output logic                HMASTLOCK,
  output logic                HREADY,
  // I/O Interface
  input  logic                TIMECLK,          // optional for CLINT MTIME counter
  input  logic [31:0]         GPIOIN,           // inputs from GPIO
  output logic [31:0]         GPIOOUT,          // output values for GPIO
  output logic [31:0]         GPIOEN,           // output enables for GPIO
  input  logic                UARTSin,          // UART serial data input
  output logic                UARTSout,         // UART serial data output
  input logic                 SDCIntr
);
  `include "parameter-defs.vh"

  wallypipelinedsoc  #(P) wallypipelinedsoc(.clk, .reset_ext, .reset, .HRDATAEXT,.HREADYEXT, .HRESPEXT, .HSELEXT,
    .HSELEXTSDC, .HCLK, .HRESETn, .HADDR, .HWDATA, .HWSTRB, .HWRITE, .HSIZE, .HBURST, .HPROT,
    .HTRANS, .HMASTLOCK, .HREADY, .TIMECLK(1'b0), .GPIOIN, .GPIOOUT, .GPIOEN,
    .UARTSin, .UARTSout, .SDCIntr);

endmodule
