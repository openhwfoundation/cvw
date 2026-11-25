
///////////////////////////////////////////
// csrt.sv
//
// Written: David_Harris@hmc.edu 14 March 2026 & Pclark@hmc.edu 10 Nov 2026
// Modified:
//
// Purpose: Sdtrig CSRs: tselect, tdata1-3, tinfo, tcontrol, scontext, mcontext
//          Register writes with WARL legalization, hardware updates, and reads
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2026 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module csrt import cvw::*; #(parameter cvw_t P) (
  input  logic                           clk, reset,
  input  logic                           CSRSWriteM, CSRMWriteM,       // CSR write
  input  logic [11:0]                    CSRAdrM,                      // CSR address
  input  logic [P.XLEN-1:0]              CSRWriteValM,                 // CSR data val
  input  logic                           TrapM, StallW, mretM,
  input  logic [1:0]                     NextPrivilegeModeM,
  input  logic [P.NUM_TRIGGERS-1:0]      MatchM, SetPendingM,         // from trigger match logic
  output logic [P.XLEN-1:0]              CSRTReadValM,
  output logic                           IllegalCSRTAccessM,
  output var logic [P.XLEN-1:0]          TDATA1_REGW[P.NUM_TRIGGERS],
  output var logic [P.XLEN-1:0]          TDATA2_REGW[P.NUM_TRIGGERS],
  output var logic [P.XLEN-1:0]          TDATA3_REGW[P.NUM_TRIGGERS],
  output logic [P.XLEN-1:0]              TCONTROL_REGW,
  output logic [P.XLEN-1:0]              SCONTEXT_REGW,
  output logic [P.XLEN-1:0]              MCONTEXT_REGW
);

  ///////////////////////////////////////////
  // Parameters
  ///////////////////////////////////////////

  // CSR addresses
  localparam TSELECT   = 12'h7A0;
  localparam TDATA1    = 12'h7A1;
  localparam TDATA2    = 12'h7A2;
  localparam TDATA3    = 12'h7A3;
  localparam TINFO     = 12'h7A4;
  localparam TCONTROL  = 12'h7A5;
  // localparam HCONTEXT  = 12'h6A8; // requires the H extension, which Wally lacks; accesses are illegal
  localparam SCONTEXT  = 12'h5A8;
  localparam MCONTEXT  = 12'h7A8;
  // localparam MSCONTEXT = 12'h7AA; // is deprecated and not supported; accesses are illegal

  // tselect
  localparam NUM_TRIGGERS_XLEN = {{(P.XLEN-32){1'b0}}, P.NUM_TRIGGERS}; // tselect writes at or above this are ignored
  localparam TSELECT_LEN = $clog2(P.NUM_TRIGGERS > 1 ? P.NUM_TRIGGERS : 2);

  // tdata1 types
  localparam MCONTROL6_TYPE = 4'b0110;
  localparam ICOUNT_TYPE    = 4'b0011;
  localparam ITRIGGER_TYPE  = 4'b0100;
  localparam ETRIGGER_TYPE  = 4'b0101;
  localparam DISABLED_TYPE  = 4'b1111;

  // tdata1 write masks
  // mcontrol6 hardwires uncertain and uncertainen to 0
  // itrigger hardwires nmi to 0
  // action is masked to 0
  localparam MCONTROL6_MASK = {{(P.XLEN-32){1'b0}}, 2'b01, 2'b00, 11'b11001110000, (P.MAX_CHAIN_LENGTH > 1), 6'b111110, P.S_SUPPORTED, P.U_SUPPORTED, 3'b111};
  localparam COUNT_MASK     = P.ICOUNT_COUNT_HARDWIRED_1 ? 14'b00000000000001 : 14'b11111111111111;
  localparam ICOUNT_MASK    = {{(P.XLEN-32){1'b0}}, 2'b00, 1'b1, COUNT_MASK, 2'b11, P.S_SUPPORTED, P.U_SUPPORTED, 6'b000000};
  localparam COUNT_ONES     = P.ICOUNT_COUNT_HARDWIRED_1 ? 14'b00000000000001 : 14'b00000000000000;
  localparam ICOUNT_ONES    = {3'b000, COUNT_ONES, 10'b0000000000}; // which ones must stay ones
  localparam ITRIGGER_MASK  = {1'b1, {(P.XLEN-19){1'b0}}, 2'b00, 3'b010, P.S_SUPPORTED, P.U_SUPPORTED, 6'b000000};
  localparam ETRIGGER_MASK  = {1'b1, {(P.XLEN-19){1'b0}}, 2'b00, 3'b010, P.S_SUPPORTED, P.U_SUPPORTED, 6'b000000};
  localparam DISABLED_MASK  = {(P.XLEN-5){1'b0}};

  // tdata3: textra32 bits 22:20 and textra64 bits 47:40 and 35:34 are 0
  localparam logic [31:0] TEXTRA32_MASK = {{6{1'b1}},  3'b111, 3'b000, 2'b11,           {16{1'b1}}, 2'b11};
  localparam logic [63:0] TEXTRA64_MASK = {{13{1'b1}}, 3'b111, 8'b0,   4'b1111, 2'b00,  {32{1'b1}}, 2'b11};
  localparam logic [P.XLEN-1:0] TDATA3_MASK = (P.XLEN == 32) ? {{(P.XLEN-32){1'b0}}, TEXTRA32_MASK} : TEXTRA64_MASK[P.XLEN-1:0];
  localparam MHSELECT_LSB = (P.XLEN == 32) ? 23 : 48;

  // tcontrol: mpte and mte
  localparam TCONTROL_MASK = {{(P.XLEN-8){1'b0}}, 1'b1, 3'b000, 1'b1, 3'b000};

  // scontext and mcontext: the low DBG_*CONTEXT_WIDTH bits
  localparam SCONTEXT_MASK = {{(P.XLEN-P.DBG_SCONTEXT_WIDTH){1'b0}}, {P.DBG_SCONTEXT_WIDTH{1'b1}}};
  localparam MCONTEXT_MASK = {{(P.XLEN-P.DBG_HCONTEXT_WIDTH){1'b0}}, {P.DBG_HCONTEXT_WIDTH{1'b1}}};

  ///////////////////////////////////////////
  // Signals
  ///////////////////////////////////////////

  logic                      WriteTSELECTM, WriteTDATA1M, WriteTDATA2M, WriteTDATA3M;
  logic                      WriteTCONTROLM, WriteSCONTEXTM, WriteMCONTEXTM;

  // tselect
  logic [P.XLEN-1:0]         TSELECT_REGW;
  logic [TSELECT_LEN-1:0]    TSelM;                 // index of the selected trigger

  // tdata1
  logic [P.NUM_TRIGGERS-1:0] ChainedM;              // trigger i is mcontrol6 with chain = 1
  logic [P.XLEN-1:0]         TDATA1WriteValLegalizedM[P.NUM_TRIGGERS];

  // tdata2
  logic [P.XLEN-1:0]         TDATA2WriteValM;

  // tdata3
  logic [P.XLEN-1:0]         TDATA3WriteMaskM, TDATA3WriteValLegalizedM;
  logic                      TDATA3MhselectLegalM, TDATA3SselectLegalM;

  // tinfo
  logic [5:0]                TSELECTIndex;          // per-trigger *_SUPPORTED_TRIGGERS masks are 64 bits
  logic [15:0]               TINFO_INFO;
  logic [P.XLEN-1:0]         TINFOval;              // read-only

  // tcontrol
  logic                      MTrapM;

  genvar t;

  ///////////////////////////////////////////
  // Write enables
  ///////////////////////////////////////////

  assign WriteTSELECTM  = CSRMWriteM & (CSRAdrM == TSELECT) & (CSRWriteValM < NUM_TRIGGERS_XLEN); // out-of-range writes ignored
  assign WriteTDATA1M   = CSRMWriteM & (CSRAdrM == TDATA1);
  assign WriteTDATA2M   = CSRMWriteM & (CSRAdrM == TDATA2);
  assign WriteTDATA3M   = CSRMWriteM & (CSRAdrM == TDATA3);
  assign WriteTCONTROLM = CSRMWriteM & (CSRAdrM == TCONTROL);
  assign WriteSCONTEXTM = CSRSWriteM & (CSRAdrM == SCONTEXT);
  assign WriteMCONTEXTM = CSRMWriteM & (CSRAdrM == MCONTEXT);

  ///////////////////////////////////////////
  // tselect
  ///////////////////////////////////////////

  flopenr #(P.XLEN) TSELECTreg(clk, reset, WriteTSELECTM, CSRWriteValM, TSELECT_REGW);
  assign TSelM = TSELECT_REGW[TSELECT_LEN-1:0]; // writes above NUM_TRIGGERS-1 are ignored

  ///////////////////////////////////////////
  // tdata1
  ///////////////////////////////////////////

  // mcontrol6 chain bits, used to limit chain length
  always_comb
    for (int i = 0; i < P.NUM_TRIGGERS; i++)
      ChainedM[i] = (TDATA1_REGW[i][P.XLEN-1:P.XLEN-4] == MCONTROL6_TYPE) & TDATA1_REGW[i][11];

  for (t=0; t < P.NUM_TRIGGERS; t++) begin
    logic [3:0]        TDATA1WriteTypeM, TDATA1WriteLegalizedTypeM;
    logic              TDATA1WriteLegalizedDmodeM;
    logic [P.XLEN-6:0] TDATA1WriteMaskM, TDATA1WriteOnesM, TDATA1MControl6MaskM, TDATA1WriteLegalizedDataM;
    logic              TDATA1MatchLegalM, TDATA1SizeLegalM, TDATA1ChainLegalM;
    logic              PrevChainedM, NextChainedM;

    // Legalize chain writes: chains are at most 2 triggers, so t can't chain
    // if t-1 already chains into it or t+1 already chains onward
    if (t > 0)                assign PrevChainedM = ChainedM[t-1];
    else                      assign PrevChainedM = 1'b0;
    if (t < P.NUM_TRIGGERS-1) assign NextChainedM = ChainedM[t+1];
    else                      assign NextChainedM = 1'b0;
    assign TDATA1ChainLegalM = ~PrevChainedM & ~NextChainedM;

    // write legalization
    always_comb begin
      // Legalize Type: unsupported types become disabled
      TDATA1WriteTypeM = CSRWriteValM[P.XLEN-1:P.XLEN-4];
      case (TDATA1WriteTypeM)
        MCONTROL6_TYPE: TDATA1WriteLegalizedTypeM = P.MCONTROL6_SUPPORTED_TRIGGERS[t] ? MCONTROL6_TYPE : DISABLED_TYPE;
        ICOUNT_TYPE:    TDATA1WriteLegalizedTypeM = P.ICOUNT_SUPPORTED_TRIGGERS[t]    ? ICOUNT_TYPE    : DISABLED_TYPE;
        ITRIGGER_TYPE:  TDATA1WriteLegalizedTypeM = P.ITRIGGER_SUPPORTED_TRIGGERS[t]  ? ITRIGGER_TYPE  : DISABLED_TYPE;
        ETRIGGER_TYPE:  TDATA1WriteLegalizedTypeM = P.ETRIGGER_SUPPORTED_TRIGGERS[t]  ? ETRIGGER_TYPE  : DISABLED_TYPE;
        default:        TDATA1WriteLegalizedTypeM = DISABLED_TYPE;
      endcase
      // dmode is 0: debug mode not supported
      TDATA1WriteLegalizedDmodeM = 1'b0;

      // Legalize mcontrol6 WARL fields: an unsupported value masks its field to 0
      case (CSRWriteValM[10:7]) // match: 6, 7, 10, 11, 14, 15 are reserved
        4'd0, 4'd1, 4'd2, 4'd3, 4'd4, 4'd5, 4'd8, 4'd9, 4'd12, 4'd13: TDATA1MatchLegalM = 1'b1;
        default: TDATA1MatchLegalM = 1'b0;
      endcase
      case (CSRWriteValM[18:16]) // size: only access sizes Wally can make
        3'd0, 3'd1, 3'd2, 3'd3: TDATA1SizeLegalM = 1'b1;       // any, 8, 16, 32 bits
        3'd5:                   TDATA1SizeLegalM = (P.XLEN == 64) | P.D_SUPPORTED; // 64 bits
        3'd6:                   TDATA1SizeLegalM = P.Q_SUPPORTED; // 128 bits
        default:                TDATA1SizeLegalM = 1'b0;       // 48-bit instructions, reserved
      endcase
      TDATA1MControl6MaskM = MCONTROL6_MASK;
      if (~TDATA1MatchLegalM) TDATA1MControl6MaskM[10:7]  = '0;
      if (~TDATA1SizeLegalM)  TDATA1MControl6MaskM[18:16] = '0;
      if (t == P.NUM_TRIGGERS-1) TDATA1MControl6MaskM[11] = 1'b0; // last trigger has nothing to chain to
      if (~TDATA1ChainLegalM) TDATA1MControl6MaskM[11] = 1'b0;    // chain would be too long

      // Mask data based on type
      case (TDATA1WriteLegalizedTypeM)
        MCONTROL6_TYPE: TDATA1WriteMaskM = TDATA1MControl6MaskM;
        ICOUNT_TYPE:    TDATA1WriteMaskM = ICOUNT_MASK;
        ITRIGGER_TYPE:  TDATA1WriteMaskM = ITRIGGER_MASK; // accomodate hit field
        ETRIGGER_TYPE:  TDATA1WriteMaskM = ETRIGGER_MASK; // accomodate hit field
        default:        TDATA1WriteMaskM = DISABLED_MASK;
      endcase

      // Some fields can be hardwired to 1 (e.g. count)
      case (TDATA1WriteLegalizedTypeM)
        ICOUNT_TYPE:    TDATA1WriteOnesM = {{(P.XLEN-32){1'b0}}, ICOUNT_ONES};
        default:        TDATA1WriteOnesM = '0;
      endcase
      TDATA1WriteLegalizedDataM = CSRWriteValM[P.XLEN-6:0] & TDATA1WriteMaskM | TDATA1WriteOnesM;
      TDATA1WriteValLegalizedM[t] = {TDATA1WriteLegalizedTypeM, TDATA1WriteLegalizedDmodeM, TDATA1WriteLegalizedDataM};
    end

    // register with hardware updates
    always_ff @(posedge clk) begin
      if (reset) TDATA1_REGW[t] <= {4'b1111, {(P.XLEN-4){1'b0}}}; // reset to disabled state
      else if (WriteTDATA1M & (TSELECT_REGW == t)) TDATA1_REGW[t] <= TDATA1WriteValLegalizedM[t]; // tdata1 write
      else begin
        case (TDATA1_REGW[t][P.XLEN-1:P.XLEN-4]) // type is in top 4 bits of tdata1
          MCONTROL6_TYPE: begin
            if (MatchM[t]) TDATA1_REGW[t][22] <= 1; // hit0; {hit1,hit0}=01 fired before instruction // TODO Have hit bit match timing
          end
          ICOUNT_TYPE: begin
            // decrement count unless already at 0 or hardwired to 1
            if (~P.ICOUNT_COUNT_HARDWIRED_1 & MatchM[t] & TDATA1_REGW[t][23:10] != 0) begin
              TDATA1_REGW[t][23:10] <= TDATA1_REGW[t][23:10]-1;
            end
            if (TDATA1_REGW[t][8] & MatchM[t]) begin // fire when pending
              TDATA1_REGW[t][8] <= 0; // clear pending
              // TODO do stuff to fire
            end
            else if (SetPendingM[t]) TDATA1_REGW[t][8] <= 1; // set pending
          end
          ITRIGGER_TYPE: begin
            if (MatchM[t]) TDATA1_REGW[t][P.XLEN-6] <= 1; // set hit bit on match
          end
          ETRIGGER_TYPE: begin
            if (MatchM[t]) TDATA1_REGW[t][P.XLEN-6] <= 1; // set hit bit on match
          end
          default: ; // disabled: no hardware updates
        endcase
      end
    end
  end

  ///////////////////////////////////////////
  // tdata2
  ///////////////////////////////////////////

  always_comb begin
    TDATA2WriteValM = CSRWriteValM; // default: write full value
    // for mcontrol6 when match=napot, tdata2 is WARL, if bits maskmax6-1:0 are written with 1s then bit masmax6-1 will be set to 0.
    if ((TDATA1_REGW[TSelM][P.XLEN-1:P.XLEN-4] == MCONTROL6_TYPE) & (TDATA1_REGW[TSelM][10:7] == 4'b0001) & (CSRWriteValM[P.MCONTROL6_MASKMAX6-1:0] == '1))
        TDATA2WriteValM[P.MCONTROL6_MASKMAX6-1] = 1'b0; // clear the bit at the top of the mask
  end
  for (t=0; t < P.NUM_TRIGGERS; t++) begin
    flopenr #(P.XLEN) TDATA2reg(clk, reset, WriteTDATA2M & (TSELECT_REGW == t), TDATA2WriteValM, TDATA2_REGW[t]);
  end

  ///////////////////////////////////////////
  // tdata3
  ///////////////////////////////////////////

  // Legalize WARL fields: an unsupported value masks its field to 0
  always_comb begin
    case (CSRWriteValM[MHSELECT_LSB +: 3]) // mhselect: without H only 0 (ignore) and 4 (mcontext) are legal
      3'd0, 3'd4: TDATA3MhselectLegalM = 1'b1;
      default:    TDATA3MhselectLegalM = 1'b0;
    endcase
    case (CSRWriteValM[1:0]) // sselect: scontext and asid need S mode; 3 is reserved
      2'd0:       TDATA3SselectLegalM = 1'b1;
      2'd1, 2'd2: TDATA3SselectLegalM = P.S_SUPPORTED;
      default:    TDATA3SselectLegalM = 1'b0;
    endcase
    TDATA3WriteMaskM = TDATA3_MASK; // hardwired zeros
    if (~TDATA3MhselectLegalM) TDATA3WriteMaskM[MHSELECT_LSB+2:MHSELECT_LSB] = '0;
    if (~TDATA3SselectLegalM)  TDATA3WriteMaskM[1:0] = '0;
  end
  assign TDATA3WriteValLegalizedM = CSRWriteValM & TDATA3WriteMaskM;
  for (t=0; t < P.NUM_TRIGGERS; t++) begin
    flopenr #(P.XLEN) TDATA3reg(clk, reset, WriteTDATA3M & (TSELECT_REGW == t), TDATA3WriteValLegalizedM, TDATA3_REGW[t]);
  end

  ///////////////////////////////////////////
  // tcontrol
  ///////////////////////////////////////////

  // mte gates M-mode triggers; a trap into M saves it to mpte, mret restores it // TODO gate behind reentrancy option
  // only mpte (bit 7) and mte (bit 3) are writable
  assign MTrapM = TrapM & ~StallW & (NextPrivilegeModeM == P.M_MODE);
  always_ff @(posedge clk)
    if (reset)                    TCONTROL_REGW <= '0;
    else if (WriteTCONTROLM)      TCONTROL_REGW <= CSRWriteValM & TCONTROL_MASK;
    else if (MTrapM) begin
      TCONTROL_REGW[7] <= TCONTROL_REGW[3]; // mpte <= mte
      TCONTROL_REGW[3] <= 1'b0;             // mte <= 0
    end else if (mretM & ~StallW) TCONTROL_REGW[3] <= TCONTROL_REGW[7]; // mte <= mpte

  ///////////////////////////////////////////
  // scontext, mcontext
  ///////////////////////////////////////////

  if (P.S_SUPPORTED) begin
    flopenr #(P.XLEN) SCONTEXTreg(clk, reset, WriteSCONTEXTM, CSRWriteValM & SCONTEXT_MASK, SCONTEXT_REGW);
  end else assign SCONTEXT_REGW = '0;
  flopenr #(P.XLEN) MCONTEXTreg(clk, reset, WriteMCONTEXTM, CSRWriteValM & MCONTEXT_MASK, MCONTEXT_REGW);

  ///////////////////////////////////////////
  // Read
  ///////////////////////////////////////////

  // tinfo: tselect always holds an existing trigger, so tinfo never reads the nonexistent value 1
  assign TSELECTIndex = 6'(TSELECT_REGW);
  assign TINFO_INFO = {9'b00000000, P.MCONTROL6_SUPPORTED_TRIGGERS[TSELECTIndex], P.ETRIGGER_SUPPORTED_TRIGGERS[TSELECTIndex],
                       P.ITRIGGER_SUPPORTED_TRIGGERS[TSELECTIndex], P.ICOUNT_SUPPORTED_TRIGGERS[TSELECTIndex], 3'b000};
  assign TINFOval = {{(P.XLEN-32){1'b0}}, 8'd1, 8'b0, TINFO_INFO}; // version 1: Sdtrig 1.0

  always_comb begin
    CSRTReadValM = '0;
    IllegalCSRTAccessM = 1'b0;
    case (CSRAdrM)
      TSELECT:   CSRTReadValM = TSELECT_REGW;
      TDATA1:    CSRTReadValM = TDATA1_REGW[TSelM];
      TDATA2:    CSRTReadValM = TDATA2_REGW[TSelM];
      TDATA3:    CSRTReadValM = TDATA3_REGW[TSelM];
      TINFO:     CSRTReadValM = TINFOval;
      TCONTROL:  CSRTReadValM = TCONTROL_REGW;
      SCONTEXT:  if (P.S_SUPPORTED) CSRTReadValM = SCONTEXT_REGW;
                 else IllegalCSRTAccessM = 1'b1;
      MCONTEXT:  CSRTReadValM = MCONTEXT_REGW;
      default:   IllegalCSRTAccessM = 1'b1;
    endcase
  end

endmodule
