///////////////////////////////////////////
// satCounter2.sv
//
// Written: Rose Thomposn
// Email: rose@rosethompson.net
// Created: February 13, 2021
// Modified:
//
// Purpose: 2 bit starting counter
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module satCounter2
  (input logic        BrDir,
   input logic [1:0]  OldState,
   output logic [1:0] NewState
   );

  always_comb begin
    case(OldState)
      2'b00: begin
 if(BrDir) NewState = 2'b01;
 else NewState = 2'b00;
      end
      2'b01: begin
 if(BrDir) NewState = 2'b10;
 else NewState = 2'b00;
      end
      2'b10: begin
 if(BrDir) NewState = 2'b11;
 else NewState = 2'b01;
      end
      2'b11: begin
 if(BrDir) NewState = 2'b11;
 else NewState = 2'b10;
      end
    endcase
  end

endmodule
