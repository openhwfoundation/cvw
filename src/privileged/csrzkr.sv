///////////////////////////////////////////
// csrzkr.sv
//
// Written: Sisi Wang siswang@hmc.edu 29 October 2026
// Modified:
//
// Purpose: Zkr Entropy Extension
//
// Documentation: RISC-V System on Chip Design
//
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


module csrzkr import cvw::*; #(parameter cvw_t P) (
  input  logic              clk, reset,
  input  logic [11:0]       CSRAdrM,            // CSR number in the instruction
  input  logic [1:0]        PrivilegeModeW,     // current privilege mode
  input  logic              CSRWriteM,          // 0 for read-only forms (csrr)
  input  logic              CSRUWriteM,         // instruction really completes this cycle
  input  logic              SSEED, USEED,       // mseccfg[9:8]: let S / U read seed
  input  logic              ESValid,            // source has a word
  input  logic [15:0]       ESBits,             // the word
  input  logic              ESBist, ESDead,     // source self-testing / broken
  output logic              ESReady,            // slot can take a word
  output logic [P.XLEN-1:0] CSRZReadValM,       // seed value; 0 for other CSRs
  output logic              IllegalCSRZAccessM  // 1 = not seed, or not allowed
);
  localparam logic [11:0] SEED = 12'h015;                                          // seed CSR number
  localparam logic [1:0]  BIST = 2'b00, WAIT = 2'b01, ES16 = 2'b10, DEAD = 2'b11;  // OPST values

  logic        AdrOK, ModeOK, LegalM, ConsumeM, Full;
  logic [15:0] Bits, Entropy;
  logic [1:0]  OPST;

  // Access checks
  assign AdrOK  = (CSRAdrM == SEED);
  assign ModeOK = (PrivilegeModeW == P.M_MODE) |                // M always
                  ((PrivilegeModeW == P.S_MODE) & SSEED) |      // S only if SSEED
                  ((PrivilegeModeW == P.U_MODE) & USEED);       // U only if USEED
  assign LegalM = AdrOK & ModeOK & CSRWriteM;                   // read-only forms trap
  assign IllegalCSRZAccessM = ~LegalM;

  // One-word slot: filled by the source, emptied by a completed read (wipe-on-read)
  assign ConsumeM = LegalM & CSRUWriteM;                        // CSRUWriteM is 1 if the CSR is writable and the instruction is valid and not flushed
  assign ESReady  = ~Full | ConsumeM;                           // empty, or emptied this cycle

  always_ff @(posedge clk)
    if (reset)                  begin Full <= 1'b0; Bits <= '0;     end
    else if (ESValid & ESReady) begin Full <= 1'b1; Bits <= ESBits; end   // fill
    else if (ConsumeM)          begin Full <= 1'b0; Bits <= '0;     end   // empty

  // Read value: {OPST, 14 zero bits, entropy}; entropy is 0 unless ES16
  assign OPST    = ESDead ? DEAD : ESBist ? BIST : Full ? ES16 : WAIT;
  assign Entropy = (OPST == ES16) ? Bits : '0;
  assign CSRZReadValM = AdrOK ? {{(P.XLEN-32){1'b0}}, OPST, 14'b0, Entropy} : '0;
endmodule
