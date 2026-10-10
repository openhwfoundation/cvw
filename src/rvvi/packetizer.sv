///////////////////////////////////////////
// packetizer.sv
//
// Written:  Rose Thompson rose@rosethompson.net 21 May 2024
// Modified:
//
// Purpose: Packs compressed RVVI trace records into Ethernet frames sent as AXI4 write bursts.
//
// Documentation:
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2024-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module packetizer import cvw::*; #(parameter cvw_t P,
                                   parameter integer MAX_CSRS,
                                   parameter logic [31:0] RVVI_INIT_TIME_OUT = 32'd4,
                                   parameter logic [31:0] RVVI_PACKET_DELAY = 32'd2
)(
  input  logic [72+(5*P.XLEN) + MAX_CSRS*(P.XLEN+16)-1:0] rvvi,
  input  logic valid,
  input  logic m_axi_aclk, m_axi_aresetn,
  output logic RVVIStall,
  // axi 4 write address channel
  // axi 4 write data channel
  output logic [31:0]  RvviAxiWdata,
  output logic [3:0]   RvviAxiWstrb,
  output logic         RvviAxiWlast,
  output logic         RvviAxiWvalid,
  input  logic         RvviAxiWready
  );

  localparam NearTotalFrameLengthBits = 2*48+16+72+(5*P.XLEN) + MAX_CSRS*(P.XLEN+16);
  localparam WordPadLen = 32 - (NearTotalFrameLengthBits % 32);
  localparam TotalFrameLengthBits = NearTotalFrameLengthBits + WordPadLen;
  localparam TotalFrameLengthBytes = TotalFrameLengthBits / 8;

  logic [9:0]              WordCount;
  logic [11:0]             BytesInFrame;
  logic                    TransReady;
  logic                    BurstDone;
  logic                    WordCountReset;
  logic                    WordCountEnable;
  logic [47:0]             SrcMac, DstMac;
  logic [15:0]             EthType, Length;
  logic [TotalFrameLengthBits-1:0] TotalFrame;
  logic [31:0] TotalFrameWords [TotalFrameLengthBytes/4-1:0];
  logic [WordPadLen-1:0]     WordPad;

  logic [72+(5*P.XLEN) + MAX_CSRS*(P.XLEN+16)-1:0] rvviDelay;

  typedef enum logic [2:0] {STATE_RST, STATE_COUNT, STATE_RDY, STATE_WAIT, STATE_TRANS, STATE_TRANS_INSERT_DELAY} statetype;
(* mark_debug = "true" *)  statetype CurrState, NextState;

  logic [31:0]       RstCount;
(* mark_debug = "true" *)   logic [31:0]      FrameCount;
  logic              RstCountRst, RstCountEn, CountFlag, DelayFlag;


  always_ff @(posedge m_axi_aclk) begin
    if(~m_axi_aresetn) CurrState <= STATE_RST;
    else               CurrState <= NextState;
  end

  always_comb begin
    case(CurrState)
      STATE_RST: NextState = STATE_COUNT;
      STATE_COUNT: if (CountFlag) NextState = STATE_RDY;
                   else           NextState = STATE_COUNT;
      STATE_RDY: if (TransReady & valid) NextState = STATE_TRANS;
      else if(~TransReady & valid) NextState = STATE_WAIT;
      else                        NextState = STATE_RDY;
      STATE_WAIT: if(TransReady)  NextState = STATE_TRANS;
                  else            NextState = STATE_WAIT;
      STATE_TRANS: if(BurstDone & TransReady) NextState = STATE_TRANS_INSERT_DELAY;
                   else          NextState = STATE_TRANS;
      STATE_TRANS_INSERT_DELAY: if(DelayFlag) NextState = STATE_RDY;
                                else          NextState = STATE_TRANS_INSERT_DELAY;
      default: NextState = STATE_RDY;
    endcase
  end

  assign RVVIStall = CurrState != STATE_RDY;
  assign TransReady = RvviAxiWready;
  assign WordCountEnable = (CurrState == STATE_RDY & valid) | (CurrState == STATE_TRANS & TransReady);
  assign WordCountReset = CurrState == STATE_RDY;
  assign RstCountEn = CurrState == STATE_COUNT | CurrState == STATE_TRANS_INSERT_DELAY;
  assign RstCountRst = CurrState == STATE_RST | CurrState == STATE_TRANS;

  // have to count at least 250 ms after reset pulled to wait for the phy to actually be ready
  // at 20MHz 250 ms is 250e-3 / (1/20e6) = 5,000,000.
  counter #(32) rstcounter(m_axi_aclk, RstCountRst, RstCountEn, RstCount);
  assign CountFlag = RstCount == RVVI_INIT_TIME_OUT;
  assign DelayFlag = RstCount == RVVI_PACKET_DELAY;

  counter #(32) framecounter(m_axi_aclk, ~m_axi_aresetn, (RvviAxiWready & RvviAxiWlast), FrameCount);


  flopenr #(72+(5*P.XLEN) + MAX_CSRS*(P.XLEN+16)) rvvireg(m_axi_aclk, ~m_axi_aresetn, valid, rvvi, rvviDelay);


  counter #(10) WordCounter(m_axi_aclk, WordCountReset, WordCountEnable, WordCount);
  // *** BUG BytesInFrame will eventually depend on the length of the data stored into the ethernet frame
  // for now this will be exactly 608 bits (76 bytes, 19 words) + the ethernet frame overhead and 2-byte padding = 92-bytes
  assign BytesInFrame = 12'd2 + 12'd76 + 12'd6 + 12'd6 + 12'd2;
  assign BurstDone = WordCount == (BytesInFrame[11:2] - 1'b1);

  genvar index;
  for (index = 0; index < TotalFrameLengthBytes/4; index++) begin
    assign TotalFrameWords[index] = TotalFrame[(index*32)+32-1 : (index*32)];
  end

  assign Length = {4'b0, BytesInFrame};
  assign WordPad = '0;
  assign TotalFrame = {WordPad, rvviDelay, EthType, DstMac, SrcMac};

  // *** fix me later
  assign DstMac = 48'h8F54_0000_1654; // made something up
  assign SrcMac = 48'h4502_1111_6843;
  assign EthType = 16'h005c;

  assign RvviAxiWdata = TotalFrameWords[WordCount[4:0]];
  assign RvviAxiWstrb = '1;
  assign RvviAxiWlast = BurstDone & (CurrState == STATE_TRANS);
  assign RvviAxiWvalid = (CurrState == STATE_TRANS);

endmodule
