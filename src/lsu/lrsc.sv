///////////////////////////////////////////
// lrsc.sv
//
// Written: David_Harris@hmc.edu
// Created: 17 July 2021
// Modified: 18 January 2023
//
// Purpose: Load Reserved / Store Conditional unit
//          Track the reservation and squash the store if it fails
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

module lrsc import cvw::*;  #(parameter cvw_t P) (
  input  logic                 clk,
  input  logic                 reset,
  input  logic                 StallW,
  input  logic                 MemReadM,   // Memory read
  input  logic [1:0]           PreLSURWM,  // Memory operation from the HPTW or IEU [1]: read, [0]: write
  output logic [1:0]           LSURWM,     // Memory operation after potential squash of SC
  input  logic [1:0]           LSUAtomicM, // Atomic memory operation
  input  logic [P.PA_BITS-1:0] PAdrM,      // Physical memory address
  output logic                 SquashSCW   // Squash the store conditional by not allowing rf write
);

  // reservation set size is XLEN for Wally
  localparam RESERVATION_SET_SIZE_IN_BYTES = P.XLEN/8;
  localparam RESERVATION_SET_ADDRESS_BITS = $clog2(RESERVATION_SET_SIZE_IN_BYTES); // 2 for rv32, 3 for rv64

  // Handle atomic load reserved / store conditional
  logic [P.PA_BITS-1:RESERVATION_SET_ADDRESS_BITS]        ReservationPAdrW;
  logic                        ReservationValidM, ReservationValidW;
  logic                        lrM, scM, WriteAdrMatchM;
  logic                        SquashSCM;

  assign lrM = MemReadM & LSUAtomicM[0];
  assign scM = PreLSURWM[0] & LSUAtomicM[0];
  assign WriteAdrMatchM = PreLSURWM[0] & (PAdrM[P.PA_BITS-1:RESERVATION_SET_ADDRESS_BITS] == ReservationPAdrW) & ReservationValidW;
  assign SquashSCM = scM & ~WriteAdrMatchM;
  assign LSURWM = SquashSCM ? 2'b00 : PreLSURWM;
  always_comb begin // ReservationValidM (next value of valid reservation)
    if (lrM) ReservationValidM = 1'b1;  // set valid on load reserve
  // if we implement multiple harts invalidate reservation if another hart stores to this reservation.
    else if (scM) ReservationValidM = 1'b0; // clear valid on store to same address or any sc
    else ReservationValidM = ReservationValidW; // otherwise don't change valid
  end

  flopenr #(P.PA_BITS-RESERVATION_SET_ADDRESS_BITS) resadrreg(clk, reset, lrM & ~StallW, PAdrM[P.PA_BITS-1:RESERVATION_SET_ADDRESS_BITS], ReservationPAdrW); // could drop clear on this one but not valid
  flopenr #(1) resvldreg(clk, reset, ~StallW, ReservationValidM, ReservationValidW);
  flopenr #(1) squashreg(clk, reset, ~StallW, SquashSCM, SquashSCW);
endmodule
