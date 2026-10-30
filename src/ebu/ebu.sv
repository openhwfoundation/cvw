///////////////////////////////////////////
// ebu.sv
//
// Written:  Rose Thompson rose@rosethompson.net 29 August 2022
// Modified: David Harris
//
// Purpose: External bus unit: arbitrates the IFU and LSU onto one AHB-Lite bus.
//          See ARM IHI0033A AMBA AHB-Lite Specification 1.0. Bus width presently matches XLEN.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2022-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module ebu import cvw::*; #(parameter cvw_t P) (
  input  logic                 clk, reset,
  // Signals from IFU
  input  logic [1:0]           IFUHTRANS,     // IFU AHB transfer type
  input  logic [2:0]           IFUHSIZE,      // IFU AHB transfer size
  input  logic [2:0]           IFUHBURST,     // IFU AHB burst type
  input  logic [P.PA_BITS-1:0] IFUHADDR,      // IFU AHB address
  output logic                 IFUHREADY,     // AHB ready to IFU, gated by possible non-grant
  // Signals from LSU
  input  logic [1:0]           LSUHTRANS,     // LSU AHB transfer type
  input  logic                 LSUHWRITE,     // LSU AHB write (1) or read (0)
  input  logic [2:0]           LSUHSIZE,      // LSU AHB transfer size
  input  logic [2:0]           LSUHBURST,     // LSU AHB burst type
  input  logic [P.PA_BITS-1:0] LSUHADDR,      // LSU AHB address
  input  logic [P.XLEN-1:0]    LSUHWDATA,     // LSU AHB write data
  input  logic [P.XLEN/8-1:0]  LSUHWSTRB,     // LSU AHB byte write enables
  output logic                 LSUHREADY,     // AHB ready to LSU; gated while the IFU owns the bus

  // AHB-Lite external signals
  output logic                 HCLK, HRESETn, // AHB clock and reset (active low)
  input  logic                 HREADY,        // AHB ready
  input  logic                 HRESP,         // AHB peripheral response. 0: OK 1: Error.  Presently ignored.
  output logic [P.PA_BITS-1:0] HADDR,         // AHB address
  output logic [P.AHBW-1:0]    HWDATA,        // AHB write data
  output logic [P.XLEN/8-1:0]  HWSTRB,        // AHB byte write enables
  output logic                 HWRITE,        // AHB write (1) or read (0)
  output logic [2:0]           HSIZE,         // AHB transfer size
  output logic [2:0]           HBURST,        // AHB burst type
  output logic [3:0]           HPROT,         // AHB protection.  Wally does not use
  output logic [1:0]           HTRANS,        // AHB transfer type: 00 IDLE, 10 NONSEQ, 11 SEQ
  output logic                 HMASTLOCK      // AHB master lock.  Wally does not use
);

  logic                       LSUDisable;
  logic                       LSUSelect;
  logic                       IFUSave;
  logic                       IFURestore;
  logic                       IFUDisable;
  logic                       IFUSelect;

  logic [P.PA_BITS-1:0]       IFUHADDROut;
  logic [1:0]                 IFUHTRANSOut;
  logic [2:0]                 IFUHBURSTOut;
  logic [2:0]                 IFUHSIZEOut;
  logic                       IFUHWRITEOut;

  logic [P.PA_BITS-1:0]       LSUHADDROut;
  logic [1:0]                 LSUHTRANSOut;
  logic [2:0]                 LSUHBURSTOut;
  logic [2:0]                 LSUHSIZEOut;
  logic                       LSUHWRITEOut;

  logic                       IFUReq;
  logic                       LSUReq;

  assign HCLK = clk;
  assign HRESETn = ~reset;

  // if two requests come in at once pick one to select and save the other's Address phase
  // inputs.  Arbitration scheme is LSU always goes first.

  ////////////////////////////////////////////////////////////////////////////////////////////////////
  // input stages and muxing for IFU and LSU
  ////////////////////////////////////////////////////////////////////////////////////////////////////

  controllerinput #(P.PA_BITS) IFUInput(.HCLK, .HRESETn, .Save(IFUSave), .Restore(IFURestore), .Disable(IFUDisable),
    .Request(IFUReq),
    .HWRITEIn(1'b0), .HSIZEIn(IFUHSIZE), .HBURSTIn(IFUHBURST), .HTRANSIn(IFUHTRANS), .HADDRIn(IFUHADDR),
    .HWRITEOut(IFUHWRITEOut), .HSIZEOut(IFUHSIZEOut), .HBURSTOut(IFUHBURSTOut), .HREADYOut(IFUHREADY),
    .HTRANSOut(IFUHTRANSOut), .HADDROut(IFUHADDROut), .HREADYIn(HREADY));

  // LSU always has priority so there should never be a need to save and restore the address phase inputs.
  controllerinput #(P.PA_BITS, 0) LSUInput(.HCLK, .HRESETn, .Save(1'b0), .Restore(1'b0), .Disable(LSUDisable),
    .Request(LSUReq),
    .HWRITEIn(LSUHWRITE), .HSIZEIn(LSUHSIZE), .HBURSTIn(LSUHBURST), .HTRANSIn(LSUHTRANS), .HADDRIn(LSUHADDR), .HREADYOut(LSUHREADY),
    .HWRITEOut(LSUHWRITEOut), .HSIZEOut(LSUHSIZEOut), .HBURSTOut(LSUHBURSTOut),
    .HTRANSOut(LSUHTRANSOut), .HADDROut(LSUHADDROut), .HREADYIn(HREADY));

  // output mux
  assign HADDR = LSUSelect ? LSUHADDROut : IFUSelect ? IFUHADDROut : '0;
  assign HSIZE = LSUSelect ? LSUHSIZEOut : IFUSelect ? IFUHSIZEOut : '0;
  assign HBURST = LSUSelect ? LSUHBURSTOut : IFUSelect ? IFUHBURSTOut : '0; // If doing memory accesses, use LSUburst, else use Instruction burst.
  assign HTRANS = LSUSelect ? LSUHTRANSOut : IFUSelect ? IFUHTRANSOut : '0; // SEQ if not first read or write, NONSEQ if first read or write, IDLE otherwise
  assign HWRITE = LSUSelect ? LSUHWRITEOut : '0;
  assign HPROT = {3'b001, LSUSelect}; // treat as privileged access of either Opcode fetch or Data access
  assign HMASTLOCK = 1'b0; // no locking supported

  // data phase muxing.  This would be a mux if IFU wrote data.
  assign HWDATA = LSUHWDATA;
  assign HWSTRB = LSUHWSTRB;
  // HRDATA is sent to all controllers at the core level.

  ebufsmarb ebufsmarb(.HCLK, .HRESETn, .HBURST, .HREADY, .LSUReq, .IFUReq, .IFUSave,
    .IFURestore, .IFUDisable, .IFUSelect, .LSUDisable, .LSUSelect);

endmodule
