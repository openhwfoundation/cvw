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
