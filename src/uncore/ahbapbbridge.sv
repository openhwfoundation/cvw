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

module ahbapbbridge import cvw::*; #(parameter cvw_t P,
                                     parameter PERIPHS = 2) (
  input  logic                 HCLK, HRESETn,    // AHB clock and reset (active low)
  input  logic [PERIPHS-1:0]   HSEL,             // AHB subordinate select
  input  logic [P.PA_BITS-1:0] HADDR,            // AHB address
  input  logic [P.XLEN-1:0]    HWDATA,           // AHB write data
  input  logic [P.XLEN/8-1:0]  HWSTRB,           // AHB byte write enables
  input  logic                 HWRITE,           // AHB write (1) or read (0)
  input  logic [1:0]           HTRANS,           // AHB transfer type: 00 IDLE, 10 NONSEQ, 11 SEQ
  input  logic                 HREADY,           // AHB ready
//  input  logic [3:0]        HPROT, // not used
  output logic [P.XLEN-1:0]    HRDATA,           // AHB read data
  output logic                 HRESP, HREADYOUT, // AHB response and ready from subordinate
  output logic                 PCLK, PRESETn,    // APB clock and reset (active low)
  output logic [PERIPHS-1:0]   PSEL,             // APB peripheral select
  output logic                 PWRITE,           // APB write (1) or read (0)
  output logic                 PENABLE,          // APB enable (access phase)
  output logic [31:0]          PADDR,            // APB address
  output logic [P.XLEN-1:0]    PWDATA,           // APB write data
//  output logic [2:0]        PPROT, // not used
  output logic [P.XLEN/8-1:0]  PSTRB,            // APB byte write strobes
//  output logic              PWAKEUP // not used
  input  logic [PERIPHS-1:0]   PREADY,           // APB ready
  input  var   [PERIPHS-1:0][P.XLEN-1:0] PRDATA  // APB read data
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
    for (i = 0; i < PERIPHS; i++) begin
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
