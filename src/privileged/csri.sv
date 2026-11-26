///////////////////////////////////////////
// csri.sv
//
// Written:  David Harris David_Harris@hmc.edu 9 January 2021
// Modified: Ben Bracker, Rose Thompson, Kip Macsai-Goren, Harshini Srinath
//
// Purpose: Interrupt pending and enable CSRs.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module csri import cvw::*; #(parameter cvw_t P) (
  input  logic              clk, reset,
  input  logic              CSRMWriteM, CSRSWriteM,
  input  logic [P.XLEN-1:0] CSRWriteValM,
  input  logic [11:0]       CSRAdrM,
  input  logic              MExtInt, SExtInt, MTimerInt, STimerInt, MSwInt,
  input  logic [15:0]       HIP_MIP_REGW, // mip aliases for {SGEIP,VSEIP,VSTIP,VSSIP} from hip
  input  logic              WriteHIEM, WriteVSIEM,
  input  logic [15:0]       HIDELEG_REGW,
  input  logic [15:0]       MIDELEG_REGW,
  input  logic              MENVCFG_STCE,
  output logic [15:0]       HIE_REGW,
  output logic [15:0]       MIP_REGW, MIE_REGW,
  output logic [15:0]       MIP_REGW_writeable // only SEIP, STIP, SSIP are actually writeable; the rest are hardwired to 0
);

  logic [15:0]              MIP_WRITE_MASK, SIP_WRITE_MASK, MIE_WRITE_MASK, SIE_WRITE_MASK, HIE_WRITE_MASK, VSIE_WRITE_MASK;
  logic [15:0]              MIEWriteMaskM, MIEWriteValM;
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
  // SEIP, STIP, SSIP are writable in MIP if S mode exists
  // SSIP is writable in SIP if S mode exists
  if (P.S_SUPPORTED) begin:mask
    if (P.SSTC_SUPPORTED) begin
      assign MIP_WRITE_MASK = MENVCFG_STCE ? 16'h0202 : 16'h0222; // SEIP and SSIP are writable, but STIP is not writable when STIMECMP is implemented (see SSTC spec)
      assign STIP = MENVCFG_STCE ? STimerInt : MIP_REGW_writeable[5];
    end else begin
      assign MIP_WRITE_MASK = 16'h0222; // SEIP, STIP, SSIP are writeable in MIP (20210108-draft 3.1.9)
      assign STIP = MIP_REGW_writeable[5];
    end
    assign SIP_WRITE_MASK = 16'h0002 & MIDELEG_REGW; // SSIP is writeable in SIP (privileged 20210108-draft 4.1.3)
    assign MIE_WRITE_MASK = 16'h0AAA | HIE_WRITE_MASK; // MEIE, SEIE, MTIE, STIE, MSIE, SSIE, and the H-added enables
  end else begin : mask
    assign MIP_WRITE_MASK = 16'h0000;
    assign SIP_WRITE_MASK = 16'h0000;
    assign MIE_WRITE_MASK = 16'h0888; // MEIE, MTIE, MSIE
    assign STIP = '0;
  end
  assign SIE_WRITE_MASK = 16'h0222 & MIDELEG_REGW;
  always_ff @(posedge clk)
    if (reset)          MIP_REGW_writeable <= 16'b0;
    else if (WriteMIPM) MIP_REGW_writeable <= (CSRWriteValM[15:0] & MIP_WRITE_MASK);
    else if (WriteSIPM) MIP_REGW_writeable <= (CSRWriteValM[15:0] & SIP_WRITE_MASK) | (MIP_REGW_writeable & ~SIP_WRITE_MASK); // exclusion-tag: csri-write-sip

  // mie owns all implemented enable state.  sie, hie and vsie are masked views of it: each write
  // changes only the bits its mask allows.  Bits outside MIE_WRITE_MASK are never set, so a full mie
  // write is the same read-modify-write with the widest mask.
  assign HIE_WRITE_MASK  = P.H_SUPPORTED ? (16'h0444 | ((P.GEILEN > 0) ? 16'h1000 : 16'h0000)) : 16'h0000;
  assign VSIE_WRITE_MASK = HIDELEG_REGW; // vsie.{SEIE,STIE,SSIE} alias mie.{VSEIE,VSTIE,VSSIE} (bits 10/6/2) when delegated
  // The write enables decode distinct addresses, so at most one is set
  assign MIEWriteMaskM = ({16{WriteMIEM}}  & MIE_WRITE_MASK) | ({16{WriteSIEM}}  & SIE_WRITE_MASK) |
                         ({16{WriteHIEM}}  & HIE_WRITE_MASK) | ({16{WriteVSIEM}} & VSIE_WRITE_MASK);
  assign MIEWriteValM = WriteVSIEM ? {CSRWriteValM[14:0], 1'b0} : CSRWriteValM[15:0];
  flopenr #(16) MIEreg(clk, reset, WriteMIEM | WriteSIEM | WriteHIEM | WriteVSIEM, // exclusion-tag: csri-write-sie
                       (MIE_REGW & ~MIEWriteMaskM) | (MIEWriteValM & MIEWriteMaskM), MIE_REGW);

  assign HIE_REGW = MIE_REGW & HIE_WRITE_MASK;

  // H adds SGEIP (bit 12) and VSEIP/VSTIP/VSSIP (10/6/2) from csrh; HIP_MIP_REGW is zero without H.
  // Bit 13 is present for future LCOFI support and remains zero.
  assign MIP_REGW = {3'b0,      HIP_MIP_REGW[12],
                     MExtInt,   HIP_MIP_REGW[10], SExtInt | MIP_REGW_writeable[9], 1'b0,
                     MTimerInt, HIP_MIP_REGW[6],  STIP,                            1'b0,
                     MSwInt,    HIP_MIP_REGW[2],  MIP_REGW_writeable[1],           1'b0};
endmodule
