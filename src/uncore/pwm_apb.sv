///////////////////////////////////////////
// pwm_apb.sv
//
// Written: naichewa@gmail.com 4/29/2026
// Modified:
//
// Purpose: PWM module
//
// Documentation:
// Based on PWM design from SiFive FU540-C000 manual version 1.0
// https://pdos.csail.mit.edu/6.828/2025/readings/FU540-C000-v1.0.pdf
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
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

module pwm_apb import cvw::*; #(parameter cvw_t P) (
  input  logic                PCLK, PRESETn,
  input  logic                PSEL,
  input  logic [7:0]          PADDR,
  input  logic [P.XLEN-1:0]   PWDATA,
  input  logic [P.XLEN/8-1:0] PSTRB,
  input  logic                PWRITE,
  input  logic                PENABLE,
  output logic [P.XLEN-1:0]   PRDATA,
  output logic                PREADY,
  output logic [3:0]          PWMIntr,
  output logic [3:0]          PWMGPIO
);

  // register map
  localparam PWM_CFG        = 8'h00;
  localparam PWM_COUNT      = 8'h08;
  localparam PWM_S          = 8'h10;
  localparam PWM_CMP0       = 8'h20;
  localparam PWM_CMP1       = 8'h24;
  localparam PWM_CMP2       = 8'h28;
  localparam PWM_CMP3       = 8'h2C;

  // PWM control registers
  logic [16:0] PWMConfig; // scale, sticky, zerocmp, deglitch, enalways, enoneshot, center, gang (pending bits live in PWMCompareIP)
  logic [P.PWM_WIDTH+14:0] PWMCount;
  logic [P.PWM_WIDTH-1:0] PWMScaled;
  logic [P.PWM_WIDTH-1:0] PWMCompare0;
  logic [P.PWM_WIDTH-1:0] PWMCompare1;
  logic [P.PWM_WIDTH-1:0] PWMCompare2;
  logic [P.PWM_WIDTH-1:0] PWMCompare3;

  // Bus interface signals
  logic [7:0]  Entry;
  logic        Memwrite;
  logic [31:0] Din,  Dout;

  // PWMConfig signals
  logic [3:0] PWMScale;
  logic PWMSticky, PWMZeroCompare, PWMDeglitch;
  logic PWMEnAlways, PWMEnOneShot;
  logic [3:0] PWMCompareCenter;
  logic [3:0] PWMCompareGang;
  logic [3:0] PWMCompareIP; // pwmcmpXip: set by the comparators, read and written through pwmcfg[31:28]
  logic [3:0] PWMCompareIPNext;
  logic       PWMConfigWrite;

  // PWMCount signals
  logic Carryout;
  logic PWMCountEn;
  logic PWMCycleEnd;

  // Deglitch circuit signals
  logic PWMHoldIn;
  logic PWMHoldOut;
  logic [3:0] PWMDeglitchMux;

  // Combinational signal logic
  logic [P.PWM_WIDTH+14:0] PWMPrescale;
  logic [P.PWM_WIDTH+14:0] ScaleMask;
  logic [3:0] PWMComparator;
  logic [3:0] PWMDeglitchMuxSelect;
  logic PWMCountReset;
  logic [P.PWM_WIDTH-1:0] PWMCompareXNOR0;
  logic [P.PWM_WIDTH-1:0] PWMCompareXNOR1;
  logic [P.PWM_WIDTH-1:0] PWMCompareXNOR2;
  logic [P.PWM_WIDTH-1:0] PWMCompareXNOR3;

  // Register signal logic
  assign PWMScale = PWMConfig[3:0];
  assign PWMSticky = PWMConfig[4];
  assign PWMZeroCompare = PWMConfig[5];
  assign PWMDeglitch = PWMConfig[6];
  assign PWMEnAlways = PWMConfig[7];
  assign PWMEnOneShot = PWMConfig[8];
  assign PWMCompareCenter = PWMConfig[12:9];
  assign PWMCompareGang = PWMConfig[16:13];
  // carryout is the carry out of the high bit of the pwms incrementer (FU540 manual 14.8), so it is the
  // one clock on which the whole of pwmcount below pwms is also all ones, not the entire final scaled
  // tick.  Resetting on &pwms alone would cut that tick from pwmscale clocks down to one.
  assign ScaleMask = ({{(P.PWM_WIDTH+14){1'b0}}, 1'b1} << PWMScale) - 1; // the pwmscale low bits of pwmcount
  assign Carryout = &PWMScaled & ((PWMCount & ScaleMask) == ScaleMask);
  assign PWMCountEn = PWMEnAlways | PWMEnOneShot;
  // A PWM cycle ends when pwms reaches pwmcmp0 with pwmzerocmp set, or when pwms carries out.  The end of a
  // cycle resets the counter, finishes a one-shot, and releases the deglitch hold; Figure 6 of the FU540
  // manual ORs carryout with the pwmcmp0 match to drive the pwmcount reset, and 14.4 has the counter
  // "reset to zero at the end of every PWM cycle" either way.
  assign PWMCycleEnd = PWMCountEn & ((PWMComparator[0] & PWMZeroCompare) | Carryout);
  assign PWMCountReset = PWMCycleEnd;


  // Deglitch Circuit logic
  assign PWMHoldIn = (~PWMCycleEnd & PWMDeglitch) | PWMSticky;
  flop #(1) pwmholdreg(PCLK,
                       PWMHoldIn, PWMHoldOut);

  // Bus logic
  assign Entry = {PADDR[7:2],2'b00};  //  32-bit word-aligned accesses
  assign Memwrite = PWRITE & PENABLE & PSEL;  // Only write in access phase
  assign PWMConfigWrite = Memwrite & (Entry == PWM_CFG);
  assign PREADY = 1'b1;

  //Account for subword read/write circuitry
  assign Din = PWDATA[31:0];
  if (P.XLEN == 64) assign PRDATA = {Dout,  Dout};
  else              assign PRDATA =  Dout;

  // Register access
  always_ff@(posedge PCLK)
    if (~PRESETn) begin
      PWMConfig <= 17'b0;
      PWMCompare0 <= {P.PWM_WIDTH{1'b1}};
      PWMCompare1 <= {P.PWM_WIDTH{1'b1}};
      PWMCompare2 <= {P.PWM_WIDTH{1'b1}};
      PWMCompare3 <= {P.PWM_WIDTH{1'b1}};
    end else begin // writes
      /* verilator lint_off CASEINCOMPLETE */
      if (Memwrite)
        case(Entry) // flop to sample inputs
          PWM_CFG:   PWMConfig <= {Din[27:24], Din[19:16], Din[13:12], Din[10:8], Din[3:0]};
          PWM_CMP0:  PWMCompare0 <= Din[P.PWM_WIDTH-1:0];
          PWM_CMP1:  PWMCompare1 <= Din[P.PWM_WIDTH-1:0];
          PWM_CMP2:  PWMCompare2 <= Din[P.PWM_WIDTH-1:0];
          PWM_CMP3:  PWMCompare3 <= Din[P.PWM_WIDTH-1:0];
        endcase
      else if (PWMCycleEnd) PWMConfig[8] <= 1'b0; // pwmenoneshot clears itself at the end of the cycle
      /* verilator lint_on CASEINCOMPLETE */
      case(Entry) // Flop to sample inputs
        PWM_CFG:   Dout <= {PWMCompareIP, PWMConfig[16:13], 4'b0, PWMConfig[12:9], 2'b0, PWMConfig[8:7], 1'b0, PWMConfig[6:4], 4'b0, PWMConfig[3:0]};
        PWM_COUNT: Dout <= {{(17-P.PWM_WIDTH){1'b0}}, PWMCount};
        PWM_S:     Dout <= {{(32-P.PWM_WIDTH){1'b0}}, PWMScaled[P.PWM_WIDTH-1:0]};
        PWM_CMP0:  Dout <= {{(32-P.PWM_WIDTH){1'b0}}, PWMCompare0[P.PWM_WIDTH-1:0]};
        PWM_CMP1:  Dout <= {{(32-P.PWM_WIDTH){1'b0}}, PWMCompare1[P.PWM_WIDTH-1:0]};
        PWM_CMP2:  Dout <= {{(32-P.PWM_WIDTH){1'b0}}, PWMCompare2[P.PWM_WIDTH-1:0]};
        PWM_CMP3:  Dout <= {{(32-P.PWM_WIDTH){1'b0}}, PWMCompare3[P.PWM_WIDTH-1:0]};
        default:   Dout <= 32'b0;
      endcase
    end

  // PWMCount register and PWMScaled logic
  always_ff @(posedge PCLK)
    if (PWMCountReset | ~PRESETn) PWMCount <= '0;
    else if (Memwrite & (Entry == PWM_COUNT)) PWMCount <= Din[P.PWM_WIDTH+14:0];
    else if (Memwrite & (Entry == PWM_S)) PWMCount <= {15'b0, Din[P.PWM_WIDTH-1:0]} << PWMScale; // widen before shifting
    else if (PWMCountEn) PWMCount <= PWMCount + 1;
  assign PWMPrescale = PWMCount >> PWMScale;
  assign PWMScaled = PWMPrescale[P.PWM_WIDTH-1:0];

  //PWM comparators
  assign PWMDeglitchMuxSelect[0] = PWMScaled[P.PWM_WIDTH-1] & PWMCompareCenter[0];
  assign PWMCompareXNOR0[P.PWM_WIDTH-1:0] = PWMDeglitchMuxSelect[0] ? ~PWMScaled : PWMScaled;
  assign PWMComparator[0] = PWMCompareXNOR0[P.PWM_WIDTH-1:0] >= PWMCompare0;
  assign PWMDeglitchMux[0] = PWMDeglitchMuxSelect[0] ? PWMComparator[0] : (PWMComparator[0] | (PWMHoldOut & PWMCompareIP[0]));
  assign PWMGPIO[0] = PWMCompareIP[0] & ~(PWMCompareGang[0] & PWMCompareIP[1]);

  assign PWMDeglitchMuxSelect[1] = PWMScaled[P.PWM_WIDTH-1] & PWMCompareCenter[1];
  assign PWMCompareXNOR1[P.PWM_WIDTH-1:0] = PWMDeglitchMuxSelect[1] ? ~PWMScaled : PWMScaled;
  assign PWMComparator[1] = PWMCompareXNOR1[P.PWM_WIDTH-1:0] >= PWMCompare1;
  assign PWMDeglitchMux[1] = PWMDeglitchMuxSelect[1] ? PWMComparator[1] : (PWMComparator[1] | (PWMHoldOut & PWMCompareIP[1]));
  assign PWMGPIO[1] = PWMCompareIP[1] & ~(PWMCompareGang[1] & PWMCompareIP[2]);

  assign PWMDeglitchMuxSelect[2] = PWMScaled[P.PWM_WIDTH-1] & PWMCompareCenter[2];
  assign PWMCompareXNOR2[P.PWM_WIDTH-1:0] = PWMDeglitchMuxSelect[2] ? ~PWMScaled : PWMScaled;
  assign PWMComparator[2] = PWMCompareXNOR2[P.PWM_WIDTH-1:0] >= PWMCompare2;
  assign PWMDeglitchMux[2] = PWMDeglitchMuxSelect[2] ? PWMComparator[2] : (PWMComparator[2] | (PWMHoldOut & PWMCompareIP[2]));
  assign PWMGPIO[2] = PWMCompareIP[2] & ~(PWMCompareGang[2] & PWMCompareIP[3]);

  assign PWMDeglitchMuxSelect[3] = PWMScaled[P.PWM_WIDTH-1] & PWMCompareCenter[3];
  assign PWMCompareXNOR3[P.PWM_WIDTH-1:0] = PWMDeglitchMuxSelect[3] ? ~PWMScaled : PWMScaled;
  assign PWMComparator[3] = PWMCompareXNOR3[P.PWM_WIDTH-1:0] >= PWMCompare3;
  assign PWMDeglitchMux[3] = PWMDeglitchMuxSelect[3] ? PWMComparator[3] : (PWMComparator[3] | (PWMHoldOut & PWMCompareIP[3]));
  assign PWMGPIO[3] = PWMCompareIP[3] & ~(PWMCompareGang[3] & PWMCompareIP[0]);

  // pwmcmpXip flops: a pwmcfg write sets them to the written value, otherwise the comparator and deglitch/sticky logic drives them
  assign PWMCompareIPNext = PWMConfigWrite ? Din[31:28] : PWMDeglitchMux;
  flopr #(4) pwmcompareipreg(PCLK, ~PRESETn, PWMCompareIPNext, PWMCompareIP);

  // Each comparator drives its own PLIC source, as in the FU540.  One ORed source would fire at the
  // pwms wrap even when the comparator of interest is low, for example a centered comparator while
  // another is set to all ones.
  assign PWMIntr = PWMCompareIP;

endmodule
