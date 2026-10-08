///////////////////////////////////////////
// spi_controller.sv
//
// Written: Jacob Pease jacobpease@protonmail.com
// Created: October 28th, 2024
//
// Purpose: Controller logic for SPI
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
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

module spi_controller (
  input logic        PCLK,
  input logic        PRESETn,

  // Start Transmission
  input logic        TransmitStart,
  input logic        TransmitRegLoaded,
  input logic        ResetSCLKenable,

  // Registers
  input logic [11:0] SckDiv,
  input logic [1:0]  SckMode,
  input logic [1:0]  CSMode,
  input logic [15:0] Delay0,
  input logic [15:0] Delay1,
  input logic [3:0]  FrameLength,

  // Is the Transmit FIFO Empty?
  input logic        TransmitFIFOEmpty,

  // Control signals
  output logic       SCLKenable,
  output logic       ShiftEdge,
  output logic       SampleEdge,
  output logic       EndOfFrame,
  output logic       Transmitting,
  output logic       InactiveState,
  output logic       SPICLK
);

  // CSMode Stuff
  localparam         HOLDMODE = 2'b10;
  localparam         AUTOMODE = 2'b00;
  localparam         OFFMODE = 2'b11;

  // FSM States
  typedef enum       logic [2:0] {INACTIVE, CSSCK, TRANSMIT, SCKCS, HOLD, INTERCS, INTERXFR} statetype;
  statetype CurrState, NextState;

  // SCLKenable stuff
  logic [11:0]       DivCounter;
  logic              SCK;

  // Shift and Sample Edges
  logic EdgePulse;
  logic ShiftEdgePulse;
  logic SampleEdgePulse;
  logic EndOfFramePulse;
  logic InvertClock;

  // Frame stuff
  logic [3:0] BitNum;
  logic       LastBit;

  // Transmit Stuff
  logic       ContinueTransmit;
  logic       EndTransmission;
  // logic       TransmitRegLoaded; // TODO: Could be replaced by TransmitRegLoaded?
  logic       NextEndDelay;
  logic       CurrentEndDelay;

  // Delay Stuff
  logic [7:0] cssck;
  logic [7:0] sckcs;
  logic [7:0] intercs;
  logic [7:0] interxfr;
  logic       Phase;

  logic       HasCSSCK;
  logic       HasSCKCS;
  logic       HasINTERCS;
  logic       HasINTERXFR;

  logic       EndOfCSSCK;
  logic       EndOfSCKCS;
  logic       EndOfINTERCS;
  logic       EndOfINTERXFR;
  logic       EndOfDelay;

  logic [7:0] DelayCounter;

  logic       DelayState;

  // Convenient Delay Reg Names
  assign cssck = Delay0[7:0];
  assign sckcs = Delay0[15:8];
  assign intercs = Delay1[7:0];
  assign interxfr = Delay1[15:8];

  // Do we have delay for anything?
  assign HasCSSCK = cssck > 8'b0;
  assign HasSCKCS = sckcs > 8'b0;
  assign HasINTERCS = intercs > 8'b0;
  assign HasINTERXFR = interxfr > 8'b0;

  // Have we hit full delay for any of the delays?
  assign EndOfCSSCK = (DelayCounter == cssck) & (CurrState == CSSCK);
  assign EndOfSCKCS = (DelayCounter == sckcs) & (CurrState == SCKCS);
  assign EndOfINTERCS = (DelayCounter == intercs) & (CurrState == INTERCS);
  assign EndOfINTERXFR = (DelayCounter == interxfr) & (CurrState == INTERXFR);

  assign EndOfDelay = EndOfCSSCK | EndOfSCKCS | EndOfINTERCS | EndOfINTERXFR;

  // Clock Signal Stuff -----------------------------------------------
  // SPI enable generation, where SCLK = PCLK/(2*(SckDiv + 1))
  // Asserts SCLKenable at the rising and falling edge of SCLK by counting from 0 to SckDiv
  // Active at 2x SCLK frequency to account for implicit half cycle delays and actions on both clock edges depending on phase
  assign SCLKenable = DivCounter == SckDiv;

  assign ContinueTransmit = ~TransmitFIFOEmpty & EndOfFrame;
  assign EndTransmission = TransmitFIFOEmpty & EndOfFrame;
  assign Phase = SckMode[0];

  always_ff @(posedge PCLK) begin
    if (~PRESETn) begin
      DivCounter <= 12'b0;
      SPICLK <= SckMode[1];
      SCK <= 0;
      BitNum <= 4'h0;
      DelayCounter <= 0;
    end else begin
      // SCK logic for delay times
      if (TransmitStart & ~DelayState) begin
        SCK <= 0;
      end else if (SCLKenable) begin
        SCK <= ~SCK;
      end

      // Counter for all four delay types
      if (DelayState & SCK & SCLKenable) begin
        DelayCounter <= DelayCounter + 8'd1;
      end else if ((SCLKenable & EndOfDelay) | Transmitting) begin
        DelayCounter <= 8'd0;
      end

      // SPICLK Logic
      // We only want to trigger the clock during Transmission.
      // If Phase == 1, then we want to trigger as soon as NextState == TRANSMIT
      // Otherwise, only trigger the clock when the CurrState is TRANSMIT.
      // We never want to trigger the clock if the NextState is NOT TRANSMIT
      if (TransmitStart & ~DelayState) begin
        SPICLK <= SckMode[1];
        end else if (SCLKenable) begin
        SPICLK <= (NextState == TRANSMIT) & (~Phase & Transmitting | Phase) ? ~SPICLK : SckMode[1];
      end

      // Reset divider
      if (SCLKenable | (TransmitStart & ~DelayState) | ResetSCLKenable) begin
        DivCounter <= 12'b0;
      end else begin
        DivCounter <= DivCounter + 12'd1;
      end

      // Increment BitNum
      if (ShiftEdge & Transmitting) begin
        BitNum <= BitNum + 4'd1;
      end else if (EndOfFrame) begin
        BitNum <= 4'b0;
      end
    end
  end

  // The very last bit in a frame of any length.
  assign LastBit = (BitNum == FrameLength - 4'b1);

  // Any SCLKenable pulse aligns with leading or trailing edge during
  // Transmission. We can use this signal as the basis for ShiftEdge
  // and SampleEdge.
  assign EdgePulse = SCLKenable & Transmitting;

  // Possible pulses for all edge types. Combined with SPICLK to get
  // edges for different phase and polarity modes.
  assign ShiftEdgePulse = EdgePulse & ~LastBit;
  assign SampleEdgePulse = EdgePulse & (NextState == TRANSMIT);
  assign EndOfFramePulse = EdgePulse & LastBit;

  // Delay ShiftEdge and SampleEdge by a half PCLK period
  // Aligned EXACTLY ON THE MIDDLE of the leading and trailing edges.
  // Sweeeeeeeeeet...
  assign InvertClock = ^SckMode;
  always_ff @(negedge PCLK) begin
    if (~PRESETn | TransmitStart) begin
      ShiftEdge <= 0;
      SampleEdge <= 0;
      EndOfFrame <= 0;
    end else begin
      ShiftEdge <= (InvertClock ^ SPICLK) & ShiftEdgePulse;
      SampleEdge <= (InvertClock ^ ~SPICLK) & SampleEdgePulse;
      EndOfFrame <= (InvertClock ^ SPICLK) & EndOfFramePulse;
    end
  end

  always_ff @(posedge PCLK) begin
    if (~PRESETn) begin
      CurrState <= INACTIVE;
    end else if (SCLKenable) begin
      CurrState <= NextState;
    end
  end

  always_comb begin
    case (CurrState)
      INACTIVE: if (TransmitRegLoaded) begin
                  if (~HasCSSCK) NextState = TRANSMIT;
                  else NextState = CSSCK;
                end else begin
                  NextState = INACTIVE;
                end
      CSSCK: if (EndOfCSSCK) NextState = TRANSMIT;
             else NextState = CSSCK;
      TRANSMIT: begin // TRANSMIT case --------------------------------
        case(CSMode)
          AUTOMODE: begin
            if (EndTransmission & ~HasSCKCS) NextState = INACTIVE;
            else if (EndOfFrame & HasSCKCS) NextState = SCKCS;
            else if (EndOfFrame & ~HasSCKCS) NextState = INTERCS;
            else NextState = TRANSMIT;
          end
          HOLDMODE: begin
            if (EndOfFrame & HasINTERXFR) NextState = INTERXFR;
            else if (EndTransmission) NextState = HOLD;
            else NextState = TRANSMIT;
          end
          OFFMODE: begin
            if (EndOfFrame & HasINTERXFR) NextState = INTERXFR;
            else if (EndTransmission) NextState = HOLD;
            else NextState = TRANSMIT;
          end
          default: NextState = TRANSMIT;
        endcase
      end
      SCKCS: begin // SCKCS case --------------------------------------
        if (EndOfSCKCS) begin
          NextState = INTERCS;
        end else begin
          NextState = SCKCS;
        end
      end
      HOLD: begin // HOLD mode case -----------------------------------
        if (CSMode == AUTOMODE) begin
          NextState = INACTIVE;
        end else if (TransmitRegLoaded) begin // If FIFO is written to, start again.
          NextState = TRANSMIT;
        end else NextState = HOLD;
      end
      INTERCS: begin // INTERCS case ----------------------------------
        if (EndOfINTERCS) begin
          if (TransmitRegLoaded) begin
            if (HasCSSCK) NextState = CSSCK;
            else NextState = TRANSMIT;
          end else NextState = INACTIVE;
        end else begin
          NextState = INTERCS;
        end
      end
      INTERXFR: begin // INTERXFR case --------------------------------
        if (EndOfINTERXFR) begin
          if (TransmitRegLoaded)  NextState = TRANSMIT;
          else NextState = HOLD;
        end else begin
          NextState = INTERXFR;
        end
      end
      default: begin
        NextState = INACTIVE;
      end
    endcase
  end

  assign Transmitting = CurrState == TRANSMIT;
  assign DelayState = (CurrState == CSSCK | CurrState == SCKCS | CurrState == INTERCS | CurrState == INTERXFR);
  assign InactiveState = CurrState == INACTIVE | CurrState == INTERCS;

endmodule
