
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

module trigger import cvw::*; #(parameter cvw_t P) (
  input  logic [1:0]                     PrivilegeModeW,               // priv mode
  input  logic [P.XLEN-1:0]              SATP_REGW,                    // asid
  input  logic                           InstrValidNotFlushedM,
  input  logic                           TrapM, InterruptM, ExceptionM,
  input  logic [4:0]                     CauseM,
  input  logic                           CommittedF,
  input  logic [P.XLEN-1:0]              PCM, IEUAdrM, WriteDataM,     // mcontrol6 match values
  input  logic [31:0]                    InstrM, InstrOrigM,
  input  logic [P.LLEN-1:0]              ReadDataW,
  input  logic [2:0]                     Funct3M,                      // load/store size
  input  var logic [P.XLEN-1:0]          TDATA1_REGW[P.NUM_TRIGGERS],
  input  var logic [P.XLEN-1:0]          TDATA2_REGW[P.NUM_TRIGGERS],
  input  var logic [P.XLEN-1:0]          TDATA3_REGW[P.NUM_TRIGGERS],
  input  logic [P.XLEN-1:0]              TCONTROL_REGW,
  input  logic [P.XLEN-1:0]              SCONTEXT_REGW,
  input  logic [P.XLEN-1:0]              MCONTEXT_REGW,
  output logic [P.NUM_TRIGGERS-1:0]      MatchM, SetPendingM
);

  ///////////////////////////////////////////
  // Parameters
  ///////////////////////////////////////////

  // tdata1 types
  localparam MCONTROL6_TYPE = 4'b0110;
  localparam ICOUNT_TYPE    = 4'b0011;
  localparam ITRIGGER_TYPE  = 4'b0100;
  localparam ETRIGGER_TYPE  = 4'b0101;

  ///////////////////////////////////////////
  // Signals
  ///////////////////////////////////////////

  // privilege
  logic [P.NUM_TRIGGERS-1:0] MEnM, SEnM, UEnM;      // trigger enabled in M, S, U mode
  logic [P.NUM_TRIGGERS-1:0] PrivEnabledM;

  // context
  logic [P.NUM_TRIGGERS-1:0] mmatch, smatch, ContextMatchM;
  logic [P.ASID_BITS-1:0]    SATP_ASID;

  // mcontrol6
  logic [2:0]                size[P.NUM_TRIGGERS], sizeval[P.NUM_TRIGGERS];
  logic [3:0]                match[P.NUM_TRIGGERS];
  logic [P.XLEN-1:0]         matchval[P.NUM_TRIGGERS], napotmask[P.NUM_TRIGGERS];
  logic [P.XLEN-1:0]         datamask[P.NUM_TRIGGERS], cmpval[P.NUM_TRIGGERS], cmptdata2[P.NUM_TRIGGERS];
  logic [P.NUM_TRIGGERS-1:0] select, execute, store, load, chain, rawmatch, matchen, sizematch, valmatch;
  logic [P.NUM_TRIGGERS-1:0] matcheq, matchnapot, matchge, matchmasklow, matchmaskhigh;
  logic [P.NUM_TRIGGERS-1:0] mcontrol6match;

  // trigger match
  logic [P.NUM_TRIGGERS-1:0] TypeMatchM;
  logic [31:0]               CauseOneHotM;          // CauseM is 5 bits, so it selects only tdata2[31:0]

  ///////////////////////////////////////////
  // Privilege
  ///////////////////////////////////////////

  always_comb
    for (int i = 0; i < P.NUM_TRIGGERS; i++) begin
      // match field location depends on trigger type
      case (TDATA1_REGW[i][P.XLEN-1:P.XLEN-4])
        MCONTROL6_TYPE: begin
          MEnM[i]  = TDATA1_REGW[i][6];
          SEnM[i]  = TDATA1_REGW[i][4];
          UEnM[i]  = TDATA1_REGW[i][3];
        end
        ICOUNT_TYPE, ITRIGGER_TYPE, ETRIGGER_TYPE: begin
          MEnM[i]  = TDATA1_REGW[i][9];
          SEnM[i]  = TDATA1_REGW[i][7];
          UEnM[i]  = TDATA1_REGW[i][6];
        end
        default: begin // never match privilege
          MEnM[i] = 0; SEnM[i] = 0; UEnM[i] = 0;
        end
      endcase
      PrivEnabledM[i] = (PrivilegeModeW == P.M_MODE  & MEnM[i] & TCONTROL_REGW[3]) |
                        (PrivilegeModeW == P.S_MODE  & SEnM[i])   |
                        (PrivilegeModeW == P.U_MODE  & UEnM[i]);
    end

  ///////////////////////////////////////////
  // Context (tdata3)
  ///////////////////////////////////////////

  // mhselect legal values without H extension are 0 and 4
  // sselect and svalue are tied to 0 when S-mode is not supported
  assign SATP_ASID = SATP_REGW[P.ASID_BASE+P.ASID_BITS-1:P.ASID_BASE];
  if (P.XLEN == 32) begin
    always_comb
      for (int i = 0; i < P.NUM_TRIGGERS; i++) begin
        casez (TDATA3_REGW[i][25:23]) // tdata3.mhselect
          3'b000: mmatch[i] = 1; // ignore mhvalue
          3'b100: mmatch[i] = (MCONTEXT_REGW[5:0] == TDATA3_REGW[i][31:26]); // mcontext
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
  end else begin
    always_comb
      for (int i = 0; i < P.NUM_TRIGGERS; i++) begin
        casez (TDATA3_REGW[i][50:48]) // tdata3.mhselect
          3'b000: mmatch[i] = 1; // ignore mhvalue
          3'b100: mmatch[i] = (MCONTEXT_REGW[12:0] == TDATA3_REGW[i][63:51]); // mcontext
          default: mmatch[i] = 0; // reserved values don't match
        endcase
        if (P.S_SUPPORTED)
          case (TDATA3_REGW[i][1:0]) // tdata3.sselect
            2'b00: smatch[i] = 1; // ignore svalue
            2'b01: smatch[i] = ((SCONTEXT_REGW[7:0]   == TDATA3_REGW[i][9:2])   | TDATA3_REGW[i][36]) &
                                ((SCONTEXT_REGW[15:8]  == TDATA3_REGW[i][17:10]) | TDATA3_REGW[i][37]) &
                                ((SCONTEXT_REGW[23:16] == TDATA3_REGW[i][25:18]) | TDATA3_REGW[i][38]) &
                                ((SCONTEXT_REGW[31:24] == TDATA3_REGW[i][33:26]) | TDATA3_REGW[i][39]); // scontext
            2'b10: smatch[i] = (SATP_ASID == TDATA3_REGW[i][P.ASID_BITS+1:2]); // asid
            default: smatch[i] = 0; // reserved values don't match
          endcase
        else smatch[i] = 1;
        ContextMatchM[i] = mmatch[i] & smatch[i];
      end
  end

  ///////////////////////////////////////////
  // mcontrol6
  ///////////////////////////////////////////

  always_comb begin
    for (int i = 0; i < P.NUM_TRIGGERS; i++) begin
      // extract mcontrol6 fields
      size[i] = TDATA1_REGW[i][18:16];
      match[i] = TDATA1_REGW[i][10:7];
      select[i] = TDATA1_REGW[i][21];
      execute[i] = TDATA1_REGW[i][2];
      store[i] = TDATA1_REGW[i][1];
      load[i] = TDATA1_REGW[i][0];
      chain[i] = (TDATA1_REGW[i][P.XLEN-1:P.XLEN-4] == MCONTROL6_TYPE) & TDATA1_REGW[i][11]; // bit 11 is part of count in icount

      matchen[i] = execute[i] | store[i] | load[i];
      // Although the spec appears to allow multiple {execute,store,load} to be set
      // and match against any of them, this implementation only matches one per
      // trigger for the sake of hardware efficiency.

      casez ({select[i], execute[i], store[i], load[i]})
        4'b01??: matchval[i] = PCM;        // Execute Address
        4'b001?: matchval[i] = IEUAdrM;    // Store address
        4'b0001: matchval[i] = IEUAdrM;    // LoadAddress
        4'b11??: matchval[i] = {{(P.XLEN-32){1'b0}}, InstrOrigM}; // Instruction, as encoded (16 or 32 bits)
        4'b101?: matchval[i] = WriteDataM; // Store Data
        4'b1001: matchval[i] = ReadDataW[P.XLEN-1:0]; // Load Data; TODO only available in Writeback
        default: matchval[i] = '0; // no type selected
      endcase

      if (execute[i]) sizeval[i] = (InstrOrigM[1:0] != 2'b11) ? 3'd2 : 3'd3; // 16-bit compressed or 32-bit instruction
      else if (load[i] | store[i])
        case (Funct3M[1:0]) // TODO 6 for 128-bit FP quad accesses
          2'b00:   sizeval[i] = 3'd1; // 8 bits
          2'b01:   sizeval[i] = 3'd2; // 16 bits
          2'b10:   sizeval[i] = 3'd3; // 32 bits
          default: sizeval[i] = 3'd5; // 64 bits
        endcase
      else sizeval[i] = 3'b0;
      sizematch[i] = (size[i] == 0) | (size[i] == sizeval[i]); // size matches or "any" is selected

      // data compares only look at the bits the access uses; address compares use all XLEN bits
      if (select[i])
        case (sizeval[i])
          3'd1:    datamask[i] = {{(P.XLEN-8){1'b0}},  {8{1'b1}}};   // 8 bits
          3'd2:    datamask[i] = {{(P.XLEN-16){1'b0}}, {16{1'b1}}};  // 16 bits
          3'd3:    datamask[i] = {{(P.XLEN-32){1'b0}}, {32{1'b1}}};  // 32 bits
          default: datamask[i] = '1;                                 // 64 bits, or no access
        endcase
      else datamask[i] = '1;
      cmpval[i]    = matchval[i]    & datamask[i];
      cmptdata2[i] = TDATA2_REGW[i] & datamask[i];

      matcheq[i]       = (cmpval[i] == cmptdata2[i]);
      napotmask[i]     = ~(cmptdata2[i] ^ (cmptdata2[i] + 1)) | ({P.XLEN{1'b1}} << P.MCONTROL6_MASKMAX6); // bits above the lowest 0 are compared, range capped at 2^maskmax6
      matchnapot[i]    = ((cmpval[i] & napotmask[i]) == (cmptdata2[i] & napotmask[i]));
      matchge[i]       = (cmpval[i] >= cmptdata2[i]);
      matchmasklow[i]  = (cmpval[i][P.XLEN/2-1:0]      & TDATA2_REGW[i][P.XLEN-1:P.XLEN/2]) == TDATA2_REGW[i][P.XLEN/2-1:0];
      matchmaskhigh[i] = (cmpval[i][P.XLEN-1:P.XLEN/2] & TDATA2_REGW[i][P.XLEN-1:P.XLEN/2]) == TDATA2_REGW[i][P.XLEN/2-1:0];
      case (match[i]) // match field
        4'b0000: valmatch[i] = matcheq[i]; // equal
        4'b0001: valmatch[i] = matchnapot[i]; // napot
        4'b0010: valmatch[i] = matchge[i]; // ge
        4'b0011: valmatch[i] = ~matchge[i]; // lt
        4'b0100: valmatch[i] = matchmasklow[i]; // masklow
        4'b0101: valmatch[i] = matchmaskhigh[i]; // mask high
        4'b1000: valmatch[i] = ~matcheq[i]; // not equal
        4'b1001: valmatch[i] = ~matchnapot[i]; // not napot
        4'b1100: valmatch[i] = ~matchmasklow[i]; // not masklow
        4'b1101: valmatch[i] = ~matchmaskhigh[i]; // not maskhigh
        default: valmatch[i] = 0; // reserved
      endcase

      rawmatch[i] = matchen[i] & valmatch[i] & sizematch[i];
    end
  end
  // chains are at most 2 long, so trigger i is gated only by trigger i-1
  assign mcontrol6match = rawmatch & (~(chain << 1) | (rawmatch << 1));

  ///////////////////////////////////////////
  // Trigger match
  ///////////////////////////////////////////

  assign CauseOneHotM = 32'b1 << CauseM;

  always_comb
    for (int i = 0; i < P.NUM_TRIGGERS; i++) begin
      TypeMatchM[i] = 0;
      SetPendingM[i] = 0;
      // behavior depends on trigger type
      case (TDATA1_REGW[i][P.XLEN-1:P.XLEN-4])
        MCONTROL6_TYPE: begin
          // TODO add support for chain
          // TODO add support for hit
          TypeMatchM[i] = mcontrol6match[i];
        end
        ICOUNT_TYPE: begin
          // Icount decrements when instruction retires or traps
          TypeMatchM[i] = (InstrValidNotFlushedM | TrapM); // TODO make sure stalls are handled, probably with stall to register
        end
        ITRIGGER_TYPE: begin
          TypeMatchM[i] = InterruptM & |(TDATA2_REGW[i][31:0] & CauseOneHotM);
        end
        ETRIGGER_TYPE: begin
          TypeMatchM[i] = ExceptionM & ~CommittedF & |(TDATA2_REGW[i][31:0] & CauseOneHotM);
        end
        default: TypeMatchM[i] = 0;
      endcase
      // Match if the trigger condition is satisfied and the privilege mode is right
      MatchM[i] = TypeMatchM[i] & PrivEnabledM[i] & ContextMatchM[i];
      SetPendingM[i] = MatchM[i] & (TDATA1_REGW[i][23:10] == 14'b00000000000001) & (TDATA1_REGW[i][P.XLEN-1:P.XLEN-4] == ICOUNT_TYPE);
    end

endmodule
