///////////////////////////////////////////
// ahbapbbridge.sv
//
// Written: David_Harris@hmc.edu & Nic Lucio 7 June 2022
//
// Purpose: AHB to APB bridge
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

module ahbapbbridge import cvw::*;  #(parameter cvw_t P,
                                      parameter PERIPHS = 2) (
  input  logic                 HCLK, HRESETn,
  input  logic [PERIPHS-1:0]   HSEL,
  input  logic [P.PA_BITS-1:0] HADDR,
  input  logic [P.XLEN-1:0]    HWDATA,
  input  logic [P.XLEN/8-1:0]  HWSTRB,
  input  logic                 HWRITE,
  input  logic [1:0]           HTRANS,
  input  logic                 HREADY,
//  input  logic [3:0]        HPROT, // not used
  output logic [P.XLEN-1:0]    HRDATA,
  output logic                 HRESP, HREADYOUT,
  output logic                 PCLK, PRESETn,
  output logic [PERIPHS-1:0]   PSEL,
  output logic                 PWRITE,
  output logic                 PENABLE,
  output logic [31:0]          PADDR,
  output logic [P.XLEN-1:0]    PWDATA,
//  output logic [2:0]        PPROT, // not used
  output logic [P.XLEN/8-1:0]  PSTRB,
//  output logic              PWAKEUP // not used
  input  logic [PERIPHS-1:0]   PREADY,
  input  var   [PERIPHS-1:0][P.XLEN-1:0] PRDATA
);

  logic                       initTrans, initTransSel, initTransSelD;
  logic                       nextPENABLE;
  logic                       PREADYOUT;

  // convert AHB to APB signals
  assign PCLK    = HCLK;
  assign PRESETn = HRESETn;

  // identify start of a transaction
  assign initTrans    = HTRANS[1] & HREADY;  // start a transaction when the bus is ready and an active transaction is requested
  assign initTransSel = initTrans & |HSEL; // capture data and address if any of the peripherals are selected

  // delay AHB Address phase signals to align with AHB Data phase because APB expects them at the same time
  flopen  #(32) addrreg(HCLK, HREADY, HADDR[31:0], PADDR);
  flopenr #(1) writereg(HCLK, ~HRESETn, HREADY, HWRITE, PWRITE);
  flopenr #(PERIPHS) selreg(HCLK, ~HRESETn, HREADY, HSEL & {PERIPHS{initTrans}}, PSEL);
  // PPROT[2:0] = {Data/InstrB, Secure, Privileged};
  // assign PPROT = {~HPROT[0], 1'b0, HPROT[1]};  // protection not presently used
  // assign PWAKEUP = 1'b1; // not used

  // AHB Data phase signal doesn't need delay.  Note that they are guaranteed to remain stable until READY is asserted
  assign PWDATA = HWDATA;
  assign PSTRB  = HWSTRB;

  // enable logic: goes high a cycle after initTrans, then back low on cycle after desired PREADY is asserted
  // cycle1: AHB puts HADDR, HWRITE, HSEL on bus.  initTrans is 1, and these are captured
  // cycle2: AHB puts HWDATA on the bus.  This effectively extends the setup phase
  // cycle3: bridge raises PENABLE.  Peripheral typically responds with PREADY.
  //         Read occurs by end of cycle.  Write occurs at end of cycle.
  flopr #(1) inittransreg(HCLK, ~HRESETn, initTransSel, initTransSelD);
  assign nextPENABLE = PENABLE ? ~HREADY : initTransSelD;
  flopr #(1) enablereg(HCLK, ~HRESETn, nextPENABLE, PENABLE);

  // result and ready multiplexer
  int i;
  always_comb begin
    // default: no peripheral selected: read 0, indicate ready during access phase so bus doesn't hang
    HRDATA = '0;
    PREADYOUT = 1'b1;
    for (i=0; i<PERIPHS; i++)  begin
      if (PSEL[i]) begin // highest numbered peripheral has priority, but multiple PSEL should never be asserted
          HRDATA = PRDATA[i];
          PREADYOUT = PREADY[i];
      end
    end
  end
assign HREADYOUT = PREADYOUT & ~initTransSelD; // don't raise HREADYOUT before access phase

  // resp logic
  assign HRESP = 1'b0; // bridge never indicates errors
endmodule
