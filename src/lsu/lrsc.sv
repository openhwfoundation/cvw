///////////////////////////////////////////
// lrsc.sv
//
// Written:  David Harris David_Harris@hmc.edu 17 July 2021
// Modified: Rose Thompson rose@rosethompson.net
//
// Purpose: Tracks load-reserved reservations and suppresses failing store-conditionals.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
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
