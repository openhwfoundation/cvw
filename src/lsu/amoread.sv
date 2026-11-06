///////////////////////////////////////////
// amoread.sv
//
// Written:  David Harris David_Harris@hmc.edu 30 October 2026
// Modified:
//
// Purpose: Select an AMO operand without general load formatting
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module amoread import cvw::*; #(parameter cvw_t P, parameter bit ZABHA_SUPPORTED = 0) (
  input  logic [P.LLEN-1:0] ReadDataWordM, // Data already byte-swapped for big endian
  input  logic [3:0]        PAdrM,
  input  logic              BigEndianM,
  input  logic [1:0]        SizeM,         // log2(operand size in bytes)
  output logic [P.XLEN-1:0] AMOReadDataM
);

  localparam ADRBITS = $clog2(P.LLEN/8);
  logic [ADRBITS-1:0] LaneAdrM;
  logic [7:0] ByteM;
  logic [15:0] HalfwordM;
  logic [31:0] WordM;
  logic [63:0] DblWordM;

  // Match subwordread's lane convention after the LSU endian swap.
  if (P.BIGENDIAN_SUPPORTED) assign LaneAdrM = PAdrM[ADRBITS-1:0] ^ {ADRBITS{BigEndianM}};
  else                       assign LaneAdrM = PAdrM[ADRBITS-1:0];

  // Select each width directly from the input, independently of other widths.
  if (ZABHA_SUPPORTED) begin
    assign ByteM     = ReadDataWordM[8*LaneAdrM +: 8];
    assign HalfwordM = ReadDataWordM[16*LaneAdrM[ADRBITS-1:1] +: 16];
  end else begin
    assign ByteM     = '0;
    assign HalfwordM = '0;
  end

  if (P.LLEN == 32) assign WordM = ReadDataWordM;
  else              assign WordM = ReadDataWordM[32*LaneAdrM[ADRBITS-1:2] +: 32];

  if (P.XLEN == 64) begin
    if (P.LLEN == 64) assign DblWordM = ReadDataWordM;
    else              assign DblWordM = ReadDataWordM[64*LaneAdrM[ADRBITS-1:3] +: 64];
  end else assign DblWordM = '0;

  // Distributed AND-OR mux: gate each operand by its width decode, then OR the results.
  // Unsupported widths produce zero.
  assign AMOReadDataM =
    ({P.XLEN{SizeM == 2'b00}} & P.XLEN'(ByteM)) |
    ({P.XLEN{SizeM == 2'b01}} & P.XLEN'(HalfwordM)) |
    ({P.XLEN{SizeM == 2'b10}} & P.XLEN'(WordM)) |
    ({P.XLEN{SizeM == 2'b11}} & P.XLEN'(DblWordM));
endmodule
