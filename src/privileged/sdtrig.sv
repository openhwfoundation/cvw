
///////////////////////////////////////////
// sdtrig.sv
//
// Written: David_Harris@hmc.edu 14 March 2026 & Pclark@hmc.edu 10 Nov 2026
// Modified:
//
// Purpose: Sdtrig debug trigger extension
//          Wrapper connecting the CSRs (csrt) to the trigger match logic (trigger)
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

module sdtrig  import cvw::*;  #(parameter cvw_t P) (
  input  logic              clk, reset,
  input  logic              CSRSWriteM, CSRMWriteM,       // CSR write
  input  logic [11:0]       CSRAdrM,                      // CSR address
  input  logic [P.XLEN-1:0] CSRWriteValM,                 // CSR data val
  input  logic [1:0]        PrivilegeModeW,               // priv mode
  input  logic [P.XLEN-1:0] SATP_REGW,                    // asid
  input  logic              InstrValidNotFlushedM,
  input  logic              TrapM, InterruptM, ExceptionM,
  input  logic              StallW, mretM,
  input  logic [1:0]        NextPrivilegeModeM,
  input  logic [4:0]        CauseM,
  input  logic              CommittedF,
  input  logic [P.XLEN-1:0] PCM, IEUAdrM, WriteDataM,  // mcontrol6 match values
  input  logic [31:0]       InstrM, InstrOrigM,
  input  logic [P.LLEN-1:0] ReadDataW,
  input  logic [2:0]        Funct3M,                   // load/store size
  output logic [P.XLEN-1:0] CSRTReadValM,
  output logic              IllegalCSRTAccessM
);

  logic [P.XLEN-1:0]         TDATA1_REGW[P.NUM_TRIGGERS];
  logic [P.XLEN-1:0]         TDATA2_REGW[P.NUM_TRIGGERS];
  logic [P.XLEN-1:0]         TDATA3_REGW[P.NUM_TRIGGERS];
  logic [P.XLEN-1:0]         TCONTROL_REGW;
  logic [P.XLEN-1:0]         SCONTEXT_REGW;
  logic [P.XLEN-1:0]         MCONTEXT_REGW;
  logic [P.NUM_TRIGGERS-1:0] MatchM, SetPendingM;

  csrt #(P) csrt(.clk, .reset, .CSRSWriteM, .CSRMWriteM, .CSRAdrM, .CSRWriteValM,
    .TrapM, .StallW, .mretM, .NextPrivilegeModeM, .MatchM, .SetPendingM,
    .CSRTReadValM, .IllegalCSRTAccessM,
    .TDATA1_REGW, .TDATA2_REGW, .TDATA3_REGW, .TCONTROL_REGW, .SCONTEXT_REGW, .MCONTEXT_REGW);

  trigger #(P) trigger(.PrivilegeModeW, .SATP_REGW, .InstrValidNotFlushedM,
    .TrapM, .InterruptM, .ExceptionM, .CauseM, .CommittedF,
    .PCM, .IEUAdrM, .WriteDataM, .InstrM, .InstrOrigM, .ReadDataW, .Funct3M,
    .TDATA1_REGW, .TDATA2_REGW, .TDATA3_REGW, .TCONTROL_REGW, .SCONTEXT_REGW, .MCONTEXT_REGW,
    .MatchM, .SetPendingM);

endmodule
