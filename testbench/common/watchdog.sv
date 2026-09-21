///////////////////////////////////////////
// watchdog.sv
//
// Written: Rose Thompson rose@rosethompson.net
// Modified: 14 June 2023
//
// Purpose: Detects if the processor is stuck and halts the simulation
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
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

module watchdog #(parameter XLEN, WatchDogTimerThreshold, SameTrapPCThreshold = 100)
  (input clk,
   input reset,
   string TEST
   );

  // check for hang up.
  logic [XLEN-1:0]      PCM, PCW, OldPCW;
  integer               WatchDogTimerCount;
  logic                 WatchDogTimeOut;

  flopenr #(XLEN) PCMReg(clk, reset, ~dut.core.ifu.StallM, dut.core.ifu.PCE, PCM); // duplicate PCM register because it is not in ifu for all configurations
  flopenr #(XLEN) PCWReg(clk, reset, ~dut.core.ieu.dp.StallW, PCM, PCW);

  always_ff @(posedge clk) begin
    OldPCW <= PCW;
    if(OldPCW == PCW) WatchDogTimerCount = WatchDogTimerCount + 1'b1;
    else WatchDogTimerCount = 0;
  end

  // Detect a recursive trap livelock.  When a faulting instruction's handler re-raises a fault at
  // that same instruction (e.g. an S-mode handler that reads mcause, an M-mode CSR, so every pass
  // takes an illegal-instruction trap) the core never wedges at one PC: the handler prologue
  // retires instructions and the PC visits several addresses each pass.  So neither the stuck-PCW
  // check above nor a minstret-frozen check would ever fire.  The invariant that *does* hold is
  // that the trapping PC is identical every time.  Count consecutive traps that capture the same
  // PCM; if the same instruction traps SameTrapPCThreshold times in a row, the core is livelocked.
  logic [XLEN-1:0]      LastTrapPC;
  integer               SameTrapPCCount;
  logic                 TrapMD, TrapEvent;
  logic                 SameTrapPCTimeOut;

  assign TrapEvent = dut.core.TrapM & ~TrapMD; // one pulse per trap, even if M stalls while trapping

  always_ff @(posedge clk) begin
    if (reset) begin
      TrapMD          <= 1'b0;
      LastTrapPC      <= '0;
      SameTrapPCCount <= 0;
    end else begin
      TrapMD <= dut.core.TrapM;
      if (TrapEvent) begin
        if (PCM == LastTrapPC) SameTrapPCCount <= SameTrapPCCount + 1;
        else                   SameTrapPCCount <= 0;
        LastTrapPC <= PCM;
      end
    end
  end

  always_comb begin
    WatchDogTimeOut = WatchDogTimerCount >= WatchDogTimerThreshold;
    SameTrapPCTimeOut = SameTrapPCCount >= SameTrapPCThreshold;
    if(WatchDogTimeOut | SameTrapPCTimeOut) begin
      if (TEST == "buildroot" & WatchDogTimeOut) $display("Watch Dog Time Out triggered.  This is a normal termination for a full buildroot boot.  Check sim/<simulator>/logs/buildroot_uart.log to check if the boot printed the login prompt.");
      else if (WatchDogTimeOut) $display("FAILURE: Watch Dog Time Out triggered. PCW stuck at %x for more than %d cycles", PCW, WatchDogTimerCount);
      else $display("FAILURE: Watch Dog Time Out triggered. Instruction at PC %x trapped %d times in a row; the core is livelocked in a recursive trap", LastTrapPC, SameTrapPCCount);
      `ifdef QUESTA
        $stop;  // if this is changed to $finish for Questa, wally-batch.do does not go to the next step to run coverage, and wally.do terminates without allowing GUI debug
      `else
        $finish;
      `endif
    end
  end

endmodule
