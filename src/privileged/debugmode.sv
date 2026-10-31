module debugmode import cvw::*;  #(parameter cvw_t P)(
  input  logic       clk, reset,
  input  logic       StallW,
  input  logic       InstrValidM, InstrValidE,
  input  logic       DebugHaltReq, DebugResumeReq,
  input  logic       DebugResetHaltReq,
  input  logic       DebugStep,
  input  logic       DebugEBreakM, DebugEBreakS, DebugEBreakU,
  input  logic       BreakpointFaultM,
  input  logic [1:0] PrivilegeModeW,
  // Confirm reset
  input  logic       DebugHaveResetAck,
  // Three conceptual bits of state
  output logic       DebugMode, DebugHalted, DebugRunning, DebugHaveReset,
  // CSRD Register Control
  output logic       NextHalt, NextResume, DebugEBreak,
  output logic [2:0] NextHaltCause,
  output logic       DebugUseDPC, DebugHaltFlush, DebugResumeFlush
);

  logic  HaltCondition;

  logic  ResetHaltReqCondition;
  logic  ResetHaltReqEnable;
  logic  ResetHaltReqValid;

  logic  BreakpointM;
  logic  BreakpointS;
  logic  BreakpointU;

  logic  Stepping;

  typedef enum logic {RUNNING, HALTED} dbg_state_e;
  dbg_state_e state, state_n;

  // ResumeAck state definitions
  typedef enum logic [1:0] {RESACKLOW, RESACKCLEAR, RESACKHIGH} resack_state_e;
  resack_state_e resack_state, next_resack_state;

  // Reset halt request signals. Conditions must be right for a reset halt request.
  assign ResetHaltReqCondition = DebugResetHaltReq & DebugHaveReset;
  assign ResetHaltReqValid = ResetHaltReqCondition & InstrValidE;
  assign ResetHaltReqEnable = ResetHaltReqCondition & NextHalt;

  assign BreakpointM = BreakpointFaultM & DebugEBreakM & PrivilegeModeW == P.M_MODE;
  assign BreakpointS = BreakpointFaultM & DebugEBreakS & PrivilegeModeW == P.S_MODE;
  assign BreakpointU = BreakpointFaultM & DebugEBreakU & PrivilegeModeW == P.U_MODE;
  assign DebugEBreak = BreakpointM | BreakpointS | BreakpointU;

  ////////////////////////////////////////////////////////////////////
  // Halt FSM
  ////////////////////////////////////////////////////////////////////

  always_ff @(posedge clk) begin
    if (reset) begin
      state <= RUNNING;
    end else if (DebugHaltReq | DebugResumeReq | Stepping | DebugEBreak | ResetHaltReqEnable) begin // Using the requests as enables
      state <= state_n;
    end else begin
      state <= state;
    end
  end

  // TODO: Add triggers to this list.
  assign HaltCondition = DebugHaltReq & InstrValidM & ~StallW |                  // Halt request
                         DebugEBreak & ~StallW |                                 // Ebreak
                         DebugStep & InstrValidM & ~DebugResumeFlush & ~StallW | // Stepping
                         ResetHaltReqValid;                                      // Reset Halt Request (needs ~StallW?)

  // Trying a simpler state machine logic
  always_comb begin
    case (state)
      RUNNING: state_n = HaltCondition ? HALTED : RUNNING;
      HALTED:  state_n = DebugResumeReq ? RUNNING : HALTED;
      default: state_n = RUNNING;
    endcase
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      Stepping <= 1'b0;
    end else if (DebugStep & DebugResumeReq) begin
      Stepping <= 1'b1;
    end else if (InstrValidM & ~StallW) begin
      // StallW must be low before we can reset Stepping. This
      // waits for anything stalling the pipeline to finish so that
      // the instruction in the Memory stage proceeds to the
      // Writeback.
      Stepping <= 1'b0;
    end
  end

  // Halted State Variables

  // Depending on whether appendix A.1 or appendix A.2 is implemented,
  // the pipeline is not necessarily halted when the hart is in Debug
  // Mode. Also, we must present the bits Halted, Running, and
  // HaveReset to the Debug Module. DebugHalted implies that the hart
  // is in DebugMode, but in Appendix A.2 the pipeline is still
  // moving and executing the park loop. This is where those
  // concerns should be separated.
  assign DebugHalted  = (state == HALTED);
  assign DebugRunning = (state == RUNNING);
  assign DebugMode = DebugHalted;

  // Flush before Halt while still running
  assign DebugHaltFlush = NextHalt;
  assign DebugUseDPC = DebugResumeFlush;

  // Flush after halt when running again.
  always_ff @(posedge clk) begin
    if (reset) begin
      DebugResumeFlush <= 0;
    end else begin
      DebugResumeFlush <= (state == HALTED) & (state_n == RUNNING);
    end
  end

  //
  assign NextHalt   = (state == RUNNING) & (state_n == HALTED);
  assign NextResume = (state == HALTED)  & (state_n == RUNNING);

  // -----------------------------------------------------------------------------
  // Halt cause: latch on entry into HALTED.
  // (This avoids combinational ambiguity and “wrong cause” when multiple signals
  //  overlap.)
  // -----------------------------------------------------------------------------

  // See Section 4.9 of Debug Specification 1.0 (Access: R)
  // 000: No cause - Reset
  // 001: ebreak
  // 010: trigger
  // 011: haltreg
  // 100: step
  // 101: resethaltreq
  // 110: group (no groups implemented)
  // 111: other (refer to extcause)// NextHaltCause logic.

  always_comb begin
    NextHaltCause = '0;
    if (ResetHaltReqEnable) begin
      NextHaltCause = 3'd5;
    end else if (DebugHaltReq) begin
      NextHaltCause = 3'd3;
    end else if (DebugEBreak) begin
      NextHaltCause = 3'd1;
    end else if (DebugStep & InstrValidM) begin
      NextHaltCause = 3'd4;
    end else begin
      NextHaltCause = '0;
    end
  end


  // -----------------------------------------------------------------------------
  // DebugHaveReset
  // -----------------------------------------------------------------------------

  always_ff @(posedge clk) begin
    if (reset) begin
      DebugHaveReset <= 1'b1;
    end else if (DebugHaveResetAck) begin
      DebugHaveReset <= 1'b0;
    end
  end

endmodule
