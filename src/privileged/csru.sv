///////////////////////////////////////////
// csru.sv
//
// Written: David_Harris@hmc.edu 9 January 2021
// Modified:
//
// Purpose: User-Mode Control and Status Registers for Floating Point
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

module csru import cvw::*;  #(parameter cvw_t P) (
  input  logic              clk, reset,
  input  logic              InstrValidNotFlushedM,
  input  logic              CSRUWriteM,
  input  logic [11:0]       CSRAdrM,
  input  logic [P.XLEN-1:0] CSRWriteValM,
  input  logic [1:0]        STATUS_FS,
  output logic [P.XLEN-1:0] CSRUReadValM,
  input  logic [4:0]        SetFflagsM,
  output logic [2:0]        FRM_REGW,
  output logic              WriteFRMM, SetOrWriteFFLAGSM,
  output logic              IllegalCSRUAccessM
);

  localparam FFLAGS = 12'h001;
  localparam FRM    = 12'h002;
  localparam FCSR   = 12'h003;

  logic [4:0]               FFLAGS_REGW;
  logic [2:0]               NextFRMM;
  logic [4:0]               NextFFLAGSM;
  logic                     WriteFFLAGSM;

  // Write enables
  // Explicitly checking STATUS_FS != 0 is redundant since the instruction traps otherwise,
  // causing CSRWriteM to go low, but it is left here for safety
  assign WriteFRMM    = CSRUWriteM & (STATUS_FS != 2'b00) & (CSRAdrM == FRM | CSRAdrM == FCSR);
  assign WriteFFLAGSM = CSRUWriteM & (STATUS_FS != 2'b00) & (CSRAdrM == FFLAGS | CSRAdrM == FCSR);

  // Write Values
  assign NextFRMM          = (CSRAdrM == FCSR) ? CSRWriteValM[7:5] : CSRWriteValM[2:0];
  assign NextFFLAGSM       = WriteFFLAGSM ? CSRWriteValM[4:0] : FFLAGS_REGW | SetFflagsM;
  assign SetOrWriteFFLAGSM = WriteFFLAGSM | (|SetFflagsM & InstrValidNotFlushedM);

  // CSRs
  flopenr #(3) FRMreg(clk, reset, WriteFRMM, NextFRMM, FRM_REGW);
  flopenr #(5) FFLAGSreg(clk, reset, SetOrWriteFFLAGSM, NextFFLAGSM, FFLAGS_REGW);

  // CSR Reads
  always_comb begin
    CSRUReadValM = '0;
    IllegalCSRUAccessM = 1'b0;
    if (STATUS_FS == 2'b00)  IllegalCSRUAccessM = 1'b1; // fpu disabled, trap
    else begin
      case (CSRAdrM)
        FFLAGS:    CSRUReadValM = {{(P.XLEN-5){1'b0}}, FFLAGS_REGW};
        FRM:       CSRUReadValM = {{(P.XLEN-3){1'b0}}, FRM_REGW};
        FCSR:      CSRUReadValM = {{(P.XLEN-8){1'b0}}, FRM_REGW, FFLAGS_REGW};
        default:   IllegalCSRUAccessM = 1'b1;
      endcase
    end
  end
endmodule
