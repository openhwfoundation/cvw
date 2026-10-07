///////////////////////////////////////////
// tap_controller.sv
//
// Written: james.stine@okstate.edu, jacob.pease@okstate.edu 28 July 2025
// Modified:
//
// Purpose: IEEE 1149.1 tap controller
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-25 Harvey Mudd College & Oklahoma State University
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

module tap_controller
  (input  logic tck,
   input  logic trst,
   input  logic tms,
   input  logic tdi,
   output logic reset,
   output logic enable,
   output logic select,
   output logic ShiftIR,
   output logic CaptureIR,
   output logic ClockIR,
   output logic UpdateIR,
   output logic ShiftDR,
   output logic ClockDR,
   output logic UpdateDR);

   // -----------------------------------------------------------------------------
   // TAP Controller States (IEEE 1149.1 Table 6-3)
   // State[3] distinguishes between DR path (0) and IR path / special (1)
   //
   //   State Name     | Encoding | Binary  | State[3] | Path Type
   // -----------------+----------+---------+----------+------------------------
   //   Exit2DR        | 0x0      | 0000    |    0     | DR path
   //   Exit1DR        | 0x1      | 0001    |    0     | DR path
   //   ShiftDR        | 0x2      | 0010    |    0     | DR path
   //   PauseDR        | 0x3      | 0011    |    0     | DR path
   //   SelectIR       | 0x4      | 0100    |    0     | DR path -> IR select
   //   UpdateDR       | 0x5      | 0101    |    0     | DR path
   //   CaptureDR      | 0x6      | 0110    |    0     | DR path
   //   SelectDR       | 0x7      | 0111    |    0     | DR path
   //   Exit2IR        | 0x8      | 1000    |    1     | IR path
   //   Exit1IR        | 0x9      | 1001    |    1     | IR path
   //   ShiftIR        | 0xA      | 1010    |    1     | IR path
   //   PauseIR        | 0xB      | 1011    |    1     | IR path
   //   RunTestIdle    | 0xC      | 1100    |    1     | IR path
   //   UpdateIR       | 0xD      | 1101    |    1     | IR path
   //   CaptureIR      | 0xE      | 1110    |    1     | IR path
   //   TLReset        | 0xF      | 1111    |    1     | Special state
   // -----------------------------------------------------------------------------

    typedef enum logic [3:0] {
      EXIT2_DR         = 4'h0,
      EXIT1_DR         = 4'h1,
      SHIFT_DR         = 4'h2,
      PAUSE_DR         = 4'h3,
      SELECT_IR        = 4'h4,
      UPDATE_DR        = 4'h5,
      CAPTURE_DR       = 4'h6,
      SELECT_DR        = 4'h7,
      EXIT2_IR         = 4'h8,
      EXIT1_IR         = 4'h9,
      SHIFT_IR         = 4'hA,
      PAUSE_IR         = 4'hB,
      RUN_TEST_IDLE    = 4'hC,
      UPDATE_IR        = 4'hD,
      CAPTURE_IR       = 4'hE,
      TEST_LOGIC_RESET = 4'hF
   } statetype;

   statetype State, NextState;

   always @(posedge tck, posedge trst) begin
      if (trst) State <= TEST_LOGIC_RESET;
      else case (State)
             TEST_LOGIC_RESET : State <= tms ? TEST_LOGIC_RESET : RUN_TEST_IDLE;
             RUN_TEST_IDLE    : State <= tms ? SELECT_DR : RUN_TEST_IDLE;
             SELECT_DR        : State <= tms ? SELECT_IR : CAPTURE_DR;
             CAPTURE_DR       : State <= tms ? EXIT1_DR : SHIFT_DR;
             SHIFT_DR         : State <= tms ? EXIT1_DR : SHIFT_DR;
             EXIT1_DR         : State <= tms ? UPDATE_DR : PAUSE_DR;
             PAUSE_DR         : State <= tms ? EXIT2_DR : PAUSE_DR;
             EXIT2_DR         : State <= tms ? UPDATE_DR : SHIFT_DR;
             UPDATE_DR        : State <= tms ? SELECT_DR : RUN_TEST_IDLE;
             SELECT_IR        : State <= tms ? TEST_LOGIC_RESET : CAPTURE_IR;
             CAPTURE_IR       : State <= tms ? EXIT1_IR : SHIFT_IR;
             SHIFT_IR         : State <= tms ? EXIT1_IR : SHIFT_IR;
             EXIT1_IR         : State <= tms ? UPDATE_IR : PAUSE_IR;
             PAUSE_IR         : State <= tms ? EXIT2_IR : PAUSE_IR;
             EXIT2_IR         : State <= tms ? UPDATE_IR : SHIFT_IR;
             UPDATE_IR        : State <= tms ? SELECT_DR : RUN_TEST_IDLE;
             default          : State <= TEST_LOGIC_RESET;
           endcase
   end

   // The following assignments and flops are based completely on the
   // IEEE 1149.1-2001 spec.

   // Instruction Register and Test Data Register should be clocked
   // on their respective CAPTURE and SHIFT states
   assign ClockIR = (State == CAPTURE_IR) | (State == SHIFT_IR);
   assign ClockDR = (State == CAPTURE_DR) | (State == SHIFT_DR);

   assign UpdateIR = (State == UPDATE_IR);
   assign UpdateDR = (State == UPDATE_DR);

   // signal present in the IEEE 1149.1-2001 spec Figure 6-5 (may not be needed)
   assign select = State[3];

   always @(negedge tck, posedge trst)
     if (trst) begin
        CaptureIR <= 0;
        ShiftIR <= 0;
        ShiftDR <= 0;
        reset <= 0;
        enable <= 0;
     end else begin
        CaptureIR <= (State == CAPTURE_IR);
        ShiftIR <= (State == SHIFT_IR);
        ShiftDR <= (State == SHIFT_DR);
        reset <= ~(State == TEST_LOGIC_RESET);
        enable <= (State == SHIFT_IR) | (State == SHIFT_DR);
     end
endmodule
