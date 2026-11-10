
///////////////////////////////////////////
// sdtrig.sv
//
// Written: David_Harris@hmc.edu 14 March 2026
// Modified:
//
// Purpose: Sdtrig debug trigger extension
//          Includes both CSRs and trigger logic
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
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

module sdtrig  import cvw::*;  #(parameter cvw_t P) (
  input  logic              clk, reset,
  input  logic              CSRSWriteM, CSRMWriteM,
  input  logic [11:0]       CSRAdrM,
  input  logic [P.XLEN-1:0] CSRWriteValM,
  input  logic [1:0]        PrivilegeModeW,
  output logic [P.XLEN-1:0] CSRTReadValM,
  output logic              IllegalCSRTAccessM
);

  // constants
  localparam VERSION = 8'b1;
  localparam LOG_NUM_TRIGGERS = (P.NUM_TRIGGERS > 1) ? $clog2(P.NUM_TRIGGERS) : 1;
  localparam MASKMAX6 = P.XLEN-1;

  // Sdtrig CSRs
  localparam SCONTEXT  = 12'h5A8;
  // hcontext (0x6A8) requires the H extension, which Wally lacks; accesses are illegal
  localparam MCONTEXT  = 12'h7A8;
  // mscontext (0x7AA) is deprecated and not supported; accesses are illegal
  localparam TSELECT   = 12'h7A0;
  localparam TDATA1    = 12'h7A1;
  localparam TDATA2    = 12'h7A2;
  localparam TDATA3    = 12'h7A3;
  localparam TINFO     = 12'h7A4;
  localparam TCONTROL  = 12'h7A5;

  // trigger types
  localparam ICOUNT_TYPE    = 4'b0011;
  localparam ITRIGGER_TYPE  = 4'b0100;
  localparam ETRIGGER_TYPE  = 4'b0101;
  localparam MCONTROL6_TYPE = 4'b0110;
  localparam DISABLED_TYPE  = 4'b1111;

  // Masks control which fields of TDATA1 are readable for each trigger type
  // mcontrol6 hardwires uncertain and uncertainen to 0
  // itrigger hardwires nmi to 0
  // action is masked to 0
  localparam COUNT_ONES     = P.ICOUNT_HARDWIRED_1 ? 14'b00000000000001 : 14'b00000000000000;
  localparam ICOUNT_ONES    = {3'b000, COUNT_ONES, 10'b0000000000}; // which ones must stay ones

  localparam COUNT_MASK     = P.ICOUNT_HARDWIRED_1 ? 14'b00000000000001 : 14'b11111111111111;
  localparam ICOUNT_MASK    = {{(P.XLEN-32){1'b0}}, P.H_SUPPORTED, P.H_SUPPORTED, 1'b1, COUNT_MASK, 2'b11, P.S_SUPPORTED, P.U_SUPPORTED, 6'b000000};
  localparam ITRIGGER_MASK  = {1'b1, {(P.XLEN-19){1'b0}}, P.H_SUPPORTED, P.H_SUPPORTED, 3'b010, P.S_SUPPORTED, P.U_SUPPORTED, 6'b000000};
  localparam ETRIGGER_MASK  = {1'b1, {(P.XLEN-19){1'b0}}, P.H_SUPPORTED, P.H_SUPPORTED, 3'b010, P.S_SUPPORTED, P.U_SUPPORTED, 6'b000000};
  localparam MCONTROL6_MASK = {{(P.XLEN-32){1'b0}}, 2'b01, P.H_SUPPORTED, P.H_SUPPORTED, 18'b110011100001111110, P.S_SUPPORTED, P.U_SUPPORTED, 3'b111};
  localparam DISABLED_MASK  = {(P.XLEN-5){1'b0}};

  // Trigger Module Registers
  // Trigger data regs are replicated for each trigger
  logic [LOG_NUM_TRIGGERS-1:0] TSELECT_REGW;
  logic [P.XLEN-1:0] TDATA1_REGW[P.NUM_TRIGGERS];
  logic [P.XLEN-1:0] TDATA2_REGW[P.NUM_TRIGGERS];
  logic [P.XLEN-1:0] TDATA3_REGW[P.NUM_TRIGGERS];
  logic [1:0] TCONTROL_REGW; // inflate from fewer bits
  logic [31:0] SCONTEXT_REGW;
  logic [13:0] MCONTEXT_REGW;

  // internal signals
  logic [15:0] TINFO_INFO;
  logic [P.XLEN-1:0] TINFOval; // read-only
  logic [P.XLEN-1:0] TCONTROLval;

  // CSR Write Logic
  logic                    WriteTSELECTM;
  logic                    WriteTDATA1M, WriteTDATA2M, WriteTDATA3M;
  logic                    WriteTCONTROLM;
  logic                    WriteSCONTEXTM, WriteMCONTEXTM;

  logic [P.XLEN-1:0]       TDATA1WriteValLegalizedM[P.NUM_TRIGGERS];
  logic [P.XLEN-1:0]       TDATA2WriteValM, TDATA3WriteValM;
  logic [1:0]              TCONTROLWriteValM;

  logic                    CSRDWriteM;
  logic [P.NUM_TRIGGERS-1:0] MatchM, SetPendingM;

  assign CSRDWriteM  = 1'b0; // debug mode not supported
  assign MatchM      = '0;   // *** driven by trigger match logic
  assign SetPendingM = '0;   // *** driven by icount logic

  assign WriteTSELECTM    = CSRMWriteM & (CSRAdrM == TSELECT) & (CSRWriteValM < P.XLEN'(P.NUM_TRIGGERS)); // out-of-range writes ignored
  assign WriteTDATA1M     = CSRMWriteM & (CSRAdrM == TDATA1);
  assign WriteTDATA2M     = CSRMWriteM & (CSRAdrM == TDATA2);
  assign WriteTDATA3M     = CSRMWriteM & (CSRAdrM == TDATA3);
  assign WriteTCONTROLM   = CSRMWriteM & (CSRAdrM == TCONTROL);
  assign WriteSCONTEXTM   = CSRSWriteM & (CSRAdrM == SCONTEXT);
  assign WriteMCONTEXTM   = CSRMWriteM & (CSRAdrM == MCONTEXT);

  genvar t;


  // TSELECT
  flopenr #(LOG_NUM_TRIGGERS) TSELECTreg(clk, reset, WriteTSELECTM, CSRWriteValM[LOG_NUM_TRIGGERS-1:0], TSELECT_REGW);

  // TDATA1 has many fields handled specially per trigger type
  for (t=0; t < P.NUM_TRIGGERS; t++) begin
    logic [3:0]        TDATA1WriteTypeM, TDATA1WriteLegalizedTypeM;
    logic              TDATA1WriteLegalizedDmodeM;
    logic [P.XLEN-6:0] TDATA1WriteMaskM, TDATA1WriteOnesM;
    always_comb begin
      // Legalize Type: unsupported types become disabled
      TDATA1WriteTypeM = CSRWriteValM[P.XLEN-1:P.XLEN-4];
      case (TDATA1WriteTypeM)
        ICOUNT_TYPE:    TDATA1WriteLegalizedTypeM = P.ICOUNT_SUPPORTED    ? ICOUNT_TYPE    : DISABLED_TYPE;
        ITRIGGER_TYPE:  TDATA1WriteLegalizedTypeM = P.ITRIGGER_SUPPORTED  ? ITRIGGER_TYPE  : DISABLED_TYPE;
        ETRIGGER_TYPE:  TDATA1WriteLegalizedTypeM = P.ETRIGGER_SUPPORTED  ? ETRIGGER_TYPE  : DISABLED_TYPE;
        MCONTROL6_TYPE: TDATA1WriteLegalizedTypeM = P.MCONTROL6_SUPPORTED ? MCONTROL6_TYPE : DISABLED_TYPE;
        default:        TDATA1WriteLegalizedTypeM = DISABLED_TYPE;
      endcase
      // Dmode is preserved except by debug mode writes
      TDATA1WriteLegalizedDmodeM = CSRDWriteM ? CSRWriteValM[P.XLEN-5] : TDATA1_REGW[t][P.XLEN-5];
      // Mask data based on type
      case (TDATA1WriteLegalizedTypeM)
        ICOUNT_TYPE:    TDATA1WriteMaskM = ICOUNT_MASK;
        ITRIGGER_TYPE:  TDATA1WriteMaskM = ITRIGGER_MASK; // accomodate hit field
        ETRIGGER_TYPE:  TDATA1WriteMaskM = ETRIGGER_MASK; // accomodate hit field
        MCONTROL6_TYPE: TDATA1WriteMaskM = MCONTROL6_MASK;
        default:        TDATA1WriteMaskM = DISABLED_MASK;
      endcase
      // some fields can be hardwired to 1 (e.g. count)
      case (TDATA1WriteLegalizedTypeM)
        ICOUNT_TYPE:    TDATA1WriteOnesM = {{(P.XLEN-32){1'b0}}, ICOUNT_ONES};
        default:        TDATA1WriteOnesM = '0;
      endcase
      TDATA1WriteValLegalizedM[t] = {TDATA1WriteLegalizedTypeM, TDATA1WriteLegalizedDmodeM, CSRWriteValM[P.XLEN-6:0] & TDATA1WriteMaskM | TDATA1WriteOnesM};
    end
    always_ff @(posedge clk) begin
      if (reset) TDATA1_REGW[t] <= {4'b1111, {(P.XLEN-4){1'b0}}}; // reset to disabled state
      else if (WriteTDATA1M & (TSELECT_REGW == t)) TDATA1_REGW[t] <= TDATA1WriteValLegalizedM[t]; // tdata1 write
      else begin
        // hardware updates to tdata1
        case (TDATA1_REGW[t][P.XLEN-1:P.XLEN-4]) // type is in top 4 bits of tdata1
          ICOUNT_TYPE: begin
            // decrement count unless already at 0 or hardwired to 1
            if (~P.ICOUNT_HARDWIRED_1 & MatchM[t] & TDATA1_REGW[t][23:10] != 0) begin
              TDATA1_REGW[t][23:10] <= TDATA1_REGW[t][23:10]-1;
            end
            if (TDATA1_REGW[t][8] & MatchM[t]) begin // fire when pending
              TDATA1_REGW[t][8] <= 0; // clear
              // *** do stuff to fire
            end
            else if (SetPendingM[t]) TDATA1_REGW[t][8] <= 1; // set pending
          end
          ITRIGGER_TYPE: begin
            if (MatchM[t]) TDATA1_REGW[t][P.XLEN-6] <= 1; // set hit bit on match
          end
          ETRIGGER_TYPE: begin
            if (MatchM[t]) TDATA1_REGW[t][P.XLEN-6] <= 1; // set hit bit on match
          end
          MCONTROL6_TYPE: begin
            if (MatchM[t]) TDATA1_REGW[t][22] <= 1; // hit0; {hit1,hit0}=01 fired before instruction // TODO Have hit bit match timing
          end
          default: ; // disabled: no hardware updates
        endcase
      end
    end
  end

  // tdata2 write
  always_comb begin
    TDATA2WriteValM = CSRWriteValM; // default: write full value
    // for mcontrol6 when match=napot, tdata2 is WARL, if bits maskmax6-1:0 are written with 1s then bit masmax6-1 will be set to 0.
    if ((TDATA1_REGW[TSELECT_REGW][P.XLEN-1:P.XLEN-4] == MCONTROL6_TYPE) & (TDATA1_REGW[TSELECT_REGW][9:7] == 3'b001) & (CSRWriteValM[MASKMAX6-1:0] == '1))
        TDATA2WriteValM[MASKMAX6-1] = 1'b0; // clear the bit at the top of the mask
  end
  for (t=0; t < P.NUM_TRIGGERS; t++) begin
    flopenr #(P.XLEN) TDATA2reg(clk, reset, WriteTDATA2M & (TSELECT_REGW == t), TDATA2WriteValM, TDATA2_REGW[t]);
  end

  // tdata3 write
  if (P.XLEN == 32) assign TDATA3WriteValM = {CSRWriteValM[31:23], 3'b0, CSRWriteValM[19:0]};
  else              assign TDATA3WriteValM = {CSRWriteValM[63:48], 8'b0, CSRWriteValM[39:36], 2'b0, CSRWriteValM[33:0]};
  for (t=0; t < P.NUM_TRIGGERS; t++) begin
    // tdata3 has some fields hardwired to 0; form depends on XLEN
    flopenr #(P.XLEN) TDATA3reg(clk, reset, WriteTDATA3M & (TSELECT_REGW == t), TDATA3WriteValM, TDATA3_REGW[t]);
  end

  assign TCONTROLWriteValM = {CSRWriteValM[7], CSRWriteValM[3]};
  flopenr #(2) TCONTROLreg(clk, reset, WriteTCONTROLM, TCONTROLWriteValM, TCONTROL_REGW);

  // context registers
  if (P.CONTEXT_SUPPORTED) begin
    flopenr #(14) MCONTEXTreg(clk, reset, WriteMCONTEXTM, CSRWriteValM[13:0], MCONTEXT_REGW);
    if (P.S_SUPPORTED)
      flopenr #(32) SCONTEXTreg(clk, reset, WriteSCONTEXTM, CSRWriteValM[31:0], SCONTEXT_REGW);
    else assign SCONTEXT_REGW = '0;
  end
  else begin
    assign SCONTEXT_REGW = '0;
    assign MCONTEXT_REGW = '0;
  end

  // CSR Read Logic
  // tselect always holds an existing trigger, so tinfo never reads the nonexistent value 1
  assign TINFO_INFO = {9'b00000000, P.MCONTROL6_SUPPORTED, P.ETRIGGER_SUPPORTED, P.ITRIGGER_SUPPORTED, P.ICOUNT_SUPPORTED, 3'b000};
  assign TINFOval = {{(P.XLEN-32){1'b0}}, VERSION, 8'b0, TINFO_INFO};
  // inflate 2 bits of TCONTROL state to XLEN-sized register.
  assign TCONTROLval = {{(P.XLEN-8){1'b0}}, TCONTROL_REGW[1], 3'b0, TCONTROL_REGW[0], 3'b0};

  always_comb begin:csrr
    CSRTReadValM = '0;
    IllegalCSRTAccessM = 1'b0;
    case (CSRAdrM)
      SCONTEXT:  if (P.CONTEXT_SUPPORTED & P.S_SUPPORTED) CSRTReadValM = {{(P.XLEN-32){1'b0}}, SCONTEXT_REGW};
                 else IllegalCSRTAccessM = 1'b1;
      MCONTEXT:  if (P.CONTEXT_SUPPORTED) CSRTReadValM = {{(P.XLEN-14){1'b0}}, MCONTEXT_REGW};
                 else IllegalCSRTAccessM = 1'b1;
      TINFO:     CSRTReadValM = TINFOval;
      TCONTROL:  CSRTReadValM = TCONTROLval;
      TSELECT:   CSRTReadValM = {{(P.XLEN-LOG_NUM_TRIGGERS){1'b0}}, TSELECT_REGW};
      TDATA1:    CSRTReadValM = TDATA1_REGW[TSELECT_REGW];
      TDATA2:    CSRTReadValM = TDATA2_REGW[TSELECT_REGW];
      TDATA3:    CSRTReadValM = TDATA3_REGW[TSELECT_REGW];
      default:   IllegalCSRTAccessM = 1'b1;
    endcase
  end





endmodule
