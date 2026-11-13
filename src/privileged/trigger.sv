
///////////////////////////////////////////
// trigger.sv
//
// Written: David_Harris@hmc.edu 14 March 2026 & Pclark@hmc.edu 10 Nov 2026
// Modified:
//
// Purpose: Sdtrig trigger match logic: privilege, context, and per-type matches
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

module trigger import cvw::*; #(parameter cvw_t P,
    localparam TDATA3_LEN   = (P.XLEN == 32) ? 29 : 54,  // tdata3 without its hardwired zeros
    localparam SCONTEXT_LEN = (P.XLEN == 32) ? 16 : 32,
    localparam MCONTEXT_LEN = (P.XLEN == 32) ? 6 : 13) (
  input  logic [1:0]                     PrivilegeModeW,               // priv mode
  input  logic [P.XLEN-1:0]              SATP_REGW,                    // asid
  input  logic                           InstrValidNotFlushedM,
  input  logic                           TrapM, InterruptM, ExceptionM,
  input  logic [4:0]                     CauseM,
  input  logic                           CommittedF,
  input  var logic [P.XLEN-1:0]          TDATA1_REGW[P.NUM_TRIGGERS],
  input  var logic [P.XLEN-1:0]          TDATA2_REGW[P.NUM_TRIGGERS],
  input  var logic [TDATA3_LEN-1:0]      TDATA3_REGW[P.NUM_TRIGGERS], // hardwired zeros not stored
  input  logic [1:0]                     TCONTROL_REGW,               // {mpte, mte}
  input  logic [SCONTEXT_LEN-1:0]        SCONTEXT_REGW,
  input  logic [MCONTEXT_LEN-1:0]        MCONTEXT_REGW,
  output logic [P.NUM_TRIGGERS-1:0]      MatchM, SetPendingM
);

  // trigger types
  localparam ICOUNT_TYPE    = 4'b0011;
  localparam ITRIGGER_TYPE  = 4'b0100;
  localparam ETRIGGER_TYPE  = 4'b0101;
  localparam MCONTROL6_TYPE = 4'b0110;

  logic [P.NUM_TRIGGERS-1:0] MEnM, SEnM, UEnM; // trigger enabled in M, S, U mode
  logic [P.NUM_TRIGGERS-1:0] PrivEnabledM;
  // Privilege match
  always_comb
    for (int i = 0; i < P.NUM_TRIGGERS; i++) begin
      // match field location depends on trigger type
      case (TDATA1_REGW[i][P.XLEN-1:P.XLEN-4])
        ICOUNT_TYPE, ITRIGGER_TYPE, ETRIGGER_TYPE: begin
          MEnM[i]  = TDATA1_REGW[i][9];
          SEnM[i]  = TDATA1_REGW[i][7];
          UEnM[i]  = TDATA1_REGW[i][6];
        end
        MCONTROL6_TYPE: begin
          MEnM[i]  = TDATA1_REGW[i][6];
          SEnM[i]  = TDATA1_REGW[i][4];
          UEnM[i]  = TDATA1_REGW[i][3];
        end
        default: begin // never match privilege
          MEnM[i] = 0; SEnM[i] = 0; UEnM[i] = 0;
        end
      endcase
      PrivEnabledM[i] = (PrivilegeModeW == P.M_MODE  & MEnM[i] & TCONTROL_REGW[0]) |
                        (PrivilegeModeW == P.S_MODE  & SEnM[i])   |
                        (PrivilegeModeW == P.U_MODE  & UEnM[i]);
    end

  // tdata3 context matches
  // mhselect legal values without H extension are 0 and 4
  // sselect and svalue are tied to 0 when S-mode is not supported
  logic [P.NUM_TRIGGERS-1:0] mmatch, smatch, ContextMatchM;
  logic [P.ASID_BITS-1:0] SATP_ASID;
  assign SATP_ASID = SATP_REGW[P.ASID_BASE+P.ASID_BITS-1:P.ASID_BASE];
  if (P.XLEN == 32) begin : ctxmatch32
    always_comb
      for (int i = 0; i < P.NUM_TRIGGERS; i++) begin
        casez (TDATA3_REGW[i][22:20]) // tdata3.mhselect
          3'b000: mmatch[i] = 1; // ignore mhvalue
          3'b100: mmatch[i] = (MCONTEXT_REGW[5:0] == TDATA3_REGW[i][28:23]); // mcontext
          default: mmatch[i] = 0; // reserved values don't match
        endcase
        if (P.S_SUPPORTED)
          case (TDATA3_REGW[i][1:0]) // tdata3.sselect
            2'b00: smatch[i] = 1; // ignore svalue
            2'b01: smatch[i] = ((SCONTEXT_REGW[7:0]  == TDATA3_REGW[i][9:2])   | TDATA3_REGW[i][18]) &
                              ((SCONTEXT_REGW[15:8] == TDATA3_REGW[i][17:10]) | TDATA3_REGW[i][19]); // scontext
            2'b10: smatch[i] = (SATP_ASID == TDATA3_REGW[i][P.ASID_BITS+1:2]); // asid
            default: smatch[i] = 0; // reserved values don't match
          endcase
        else smatch[i] = 1;
        ContextMatchM[i] = mmatch[i] & smatch[i];
      end
  end else begin : ctxmatch64
    always_comb
      for (int i = 0; i < P.NUM_TRIGGERS; i++) begin
        casez (TDATA3_REGW[i][40:38]) // tdata3.mhselect
          3'b000: mmatch[i] = 1; // ignore mhvalue
          3'b100: mmatch[i] = (MCONTEXT_REGW[12:0] == TDATA3_REGW[i][53:41]); // mcontext
          default: mmatch[i] = 0; // reserved values don't match
        endcase
        if (P.S_SUPPORTED)
          case (TDATA3_REGW[i][1:0]) // tdata3.sselect
            2'b00: smatch[i] = 1; // ignore svalue
            2'b01: smatch[i] = ((SCONTEXT_REGW[7:0]   == TDATA3_REGW[i][9:2])   | TDATA3_REGW[i][34]) &
                                ((SCONTEXT_REGW[15:8]  == TDATA3_REGW[i][17:10]) | TDATA3_REGW[i][35]) &
                                ((SCONTEXT_REGW[23:16] == TDATA3_REGW[i][25:18]) | TDATA3_REGW[i][36]) &
                                ((SCONTEXT_REGW[31:24] == TDATA3_REGW[i][33:26]) | TDATA3_REGW[i][37]); // scontext
            2'b10: smatch[i] = (SATP_ASID == TDATA3_REGW[i][P.ASID_BITS+1:2]); // asid
            default: smatch[i] = 0; // reserved values don't match
          endcase
        else smatch[i] = 1;
        ContextMatchM[i] = mmatch[i] & smatch[i];
      end
  end


  // Trigger matches
  logic [P.NUM_TRIGGERS-1:0] TypeMatchM, mcontrol6match;
  always_comb
    for (int i = 0; i < P.NUM_TRIGGERS; i++) begin
      TypeMatchM[i] = 0;
      SetPendingM[i] = 0;
      // behavior depends on trigger type
      case (TDATA1_REGW[i][P.XLEN-1:P.XLEN-4])
        ICOUNT_TYPE: begin
          // Icount decrements when instruction retires or traps
          TypeMatchM[i] = (InstrValidNotFlushedM | TrapM); // *** make sure stalls are handled, probably with stall to register
        end
        ITRIGGER_TYPE: begin
          TypeMatchM[i] = (InterruptM & TDATA2_REGW[i][$clog2(P.XLEN)'(CauseM)]);
        end
        ETRIGGER_TYPE: begin
          TypeMatchM[i] = ExceptionM & ~CommittedF & TDATA2_REGW[i][$clog2(P.XLEN)'(CauseM)];
        end
        MCONTROL6_TYPE: begin
          // *** add support for chain
          // *** add support for hit
          TypeMatchM[i] = mcontrol6match[i];
        end
        default: TypeMatchM[i] = 0;
      endcase
      // Match if the trigger condition is satisfied and the privilege mode is right
      MatchM[i] = TypeMatchM[i] & PrivEnabledM[i] & ContextMatchM[i];
      SetPendingM[i] = MatchM[i] & (TDATA1_REGW[i][23:10] == 14'b00000000000001) & (TDATA1_REGW[i][P.XLEN-1:P.XLEN-4] == ICOUNT_TYPE);
    end

  // *** mcontrol6 address/data match, copied from sdtrig.work; not yet compilable, so commented out
  /*
  // mcontrol6-specific matching logic
  always_comb begin
    for (t=0; t<P.NUM_TRIGGERS; t++) begin
      // extract mcontrol6 fields
      size[t] = TDATA1_REGW[t][18:16];
      match[t] = TDATA1_REGW[t][10:7];
      select[t] = TDATA1_REGW[t][21];
      execute[t] = TDATA1_REGW[t][2];
      store[t] = TDATA1_REGW[t][1];
      load[t] = TDATA1_REGW[t][0];

      // Although the spec appears to allow multiple {execute,store,load} to be set
      // and match against any of them, this implementation only matches one per
      // trigger for the sake of hardware efficiency.
      matchen[t] = 1; // by default the matchval is meaningful
      // *** update all of these with the correct signal names
      // *** mask down to their size
      casez {select[t], execute[t], store[t], load[t]}
        4'b?000: matchval[t] = '0; matchen[t] = 0; // no type selected
        4'b01??: matchval[t] = InstrAdrM; // Execute Address
        4'b001?: matchval[t] = IEUAdrM;   // Store address
        4'b0001: matchval[t] = IEUAdrM;   // LoadAddress
        4'b11??: matchval[t] = InstrM;    // Instruction
        4'b101?: matchval[t] = IEUWriteDataM; // Store Data
        4'b1001: matchval[t] = IEUReadDataM; // Load Data
      endcase

      matcheq[t] = (matchval[t] == TDATA2_REGW[t]);
      matchnapot[t] = ***;
      matchge[t] = ($unsigned(matchval[t]) >= $unsigned(TDATA2_REGW[t]);
      matchmasklow[t] = (matchval[t][P.XLEN/2-1:0] & TDATA2_REG[P.XLEN-1:P.XLEN/2]) == TDATA2_REGW[P.XLEN/2-1:0];
      matchmaskhigh[t] = (matchval[t][P.XLEN-1:P.XLEN] & TDATA2_REG[P.XLEN-1:P.XLEN/2]) == TDATA2_REGW[P.XLEN/2-1:0];
      case (match[t]) // match field
        4'b0000: valmatch[t] = matcheq[t]; // equal
        4'b0001: valmatch[t] = matchnapot[t]; // napot
        4'b0010: valmatch[t] = matchge[t]; // ge
        4'b0011: valmatch[t] = ~matchge[t]; // lt
        4'b0100: valmatch[t] = matchmasklow[t]; // masklow
        4'b0101: valmatch[t] = matchmaskhigh[t]; // mask high
        4'b1000: valmatch[t] = ~matcheq[t]; // not equal
        4'b1001: valmatch[t] = ~matchnapot[t]; // not napot
        4'b1100: valmatch[t] = ~matchmasklow[t]; // not masklow
        4'b1101: valmatch[t] = ~matchmaskhigh[t]; // not maskhigh
        default: valmatch[t] = 0; // reserved
      endcase

      if (extcute[t]) sizeval[t] = *** ? 3'b3 : 3'b2;
      else if (load[t] | store[t]) sizeval[t] == ***; // *** 6 for 128, 5 for 64, 3 for 32, 2 for 16, 1 for 8]
      else sizeval[t] = 3'b0;
      sizematch[t] = (size[t] == 0) | (size[t] == sizeval[t]); // size matches or "any" is selected

      assign mcontrol6match[t] = matchen[t] & valmatch[t] & sizematch[t];
    end
  end
  */

endmodule
