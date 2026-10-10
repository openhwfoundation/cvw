///////////////////////////////////////////
// csri.sv
//
// Written:  David Harris David_Harris@hmc.edu 9 January 2021
// Modified: Ben Bracker bbracker@hmc.edu, Rose Thompson rose@rosethompson.net, Kip Macsai-Goren kmacsaigoren@hmc.edu, Harshini Srinath harshini.srinath@gmail.com
//
// Purpose: Interrupt pending and enable CSRs (mip/mie and sip/sie).
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

module csri import cvw::*;  #(parameter cvw_t P) (
  input  logic              clk, reset,
  input  logic              CSRMWriteM, CSRSWriteM,
  input  logic [P.XLEN-1:0] CSRWriteValM,
  input  logic [11:0]       CSRAdrM,
  input  logic              MExtInt, SExtInt, MTimerInt, STimerInt, MSwInt,
  input  logic [11:0]       MIDELEG_REGW,
  input  logic              ENVCFG_STCE,
  output logic [11:0]       MIP_REGW, MIE_REGW,
  output logic [11:0]       MIP_REGW_writeable // only SEIP, STIP, SSIP are actually writeable; the rest are hardwired to 0
);

  logic [11:0]              MIP_WRITE_MASK, SIP_WRITE_MASK, MIE_WRITE_MASK, SIE_WRITE_MASK;
  logic                     WriteMIPM, WriteMIEM, WriteSIPM, WriteSIEM;
  logic                     STIP;

  localparam MIE = 12'h304;
  localparam MIP = 12'h344;
  localparam SIE = 12'h104;
  localparam SIP = 12'h144;

  // Interrupt Write Enables
  assign WriteMIPM = CSRMWriteM & (CSRAdrM == MIP);
  assign WriteMIEM = CSRMWriteM & (CSRAdrM == MIE);
  assign WriteSIPM = CSRSWriteM & (CSRAdrM == SIP);
  assign WriteSIEM = CSRSWriteM & (CSRAdrM == SIE);

  // Interrupt Pending and Enable Registers
  // MEIP, MTIP, MSIP are read-only
  // SEIP, STIP, SSIP is writable in MIP if S mode exists
  // SSIP is writable in SIP if S mode exists
  if (P.S_SUPPORTED) begin : mask
    if (P.SSTC_SUPPORTED) begin
      assign MIP_WRITE_MASK = ENVCFG_STCE ? 12'h202 : 12'h222; // SEIP and SSIP are writable, but STIP is not writable when STIMECMP is implemented (see SSTC spec)
      assign STIP = ENVCFG_STCE ? STimerInt : MIP_REGW_writeable[5];
    end else begin
      assign MIP_WRITE_MASK = 12'h222; // SEIP, STIP, SSIP are writeable in MIP (20210108-draft 3.1.9)
      assign STIP = MIP_REGW_writeable[5];
    end
    assign SIP_WRITE_MASK = 12'h002 & MIDELEG_REGW; // SSIP is writeable in SIP (privileged 20210108-draft 4.1.3)
    assign MIE_WRITE_MASK = 12'hAAA;
    assign SIE_WRITE_MASK = 12'h222 & MIDELEG_REGW; // Delegated supervisor interrupts are writable in SIE
  end else begin : mask
    assign MIP_WRITE_MASK = 12'h000;
    assign SIP_WRITE_MASK = 12'h000;
    assign MIE_WRITE_MASK = 12'h888;
    assign SIE_WRITE_MASK = 12'h000;
    assign STIP = '0;
  end
  always_ff @(posedge clk)
    if (reset)          MIP_REGW_writeable <= 12'b0;
    else if (WriteMIPM) MIP_REGW_writeable <= (CSRWriteValM[11:0] & MIP_WRITE_MASK);
    else if (WriteSIPM) MIP_REGW_writeable <= (CSRWriteValM[11:0] & SIP_WRITE_MASK) | (MIP_REGW_writeable & ~SIP_WRITE_MASK);
  always_ff @(posedge clk)
    if (reset)          MIE_REGW <= 12'b0;
    else if (WriteMIEM) MIE_REGW <= (CSRWriteValM[11:0] & MIE_WRITE_MASK); // MIE controls M and S fields
    else if (WriteSIEM) MIE_REGW <= (CSRWriteValM[11:0] & SIE_WRITE_MASK) | (MIE_REGW & ~SIE_WRITE_MASK); // only S fields

  assign MIP_REGW = {MExtInt,   1'b0, SExtInt|MIP_REGW_writeable[9],  1'b0,
                     MTimerInt, 1'b0, STIP,                           1'b0,
                     MSwInt,    1'b0, MIP_REGW_writeable[1],          1'b0};
endmodule
