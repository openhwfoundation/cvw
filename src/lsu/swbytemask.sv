///////////////////////////////////////////
// swbytemask.sv
//
// Written: David_Harris@hmc.edu
// Created: 9 January 2021
// Modified: 18 January 2023
//
// Purpose: On-chip RAM, external to core
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

module swbytemask #(parameter WORDLEN, EXTEND = 0)(
  input logic  [2:0]                   Size,
  input logic  [$clog2(WORDLEN/8)-1:0] Adr,
  output logic [WORDLEN/8-1:0]         ByteMask,
  output logic [WORDLEN/8-1:0]         ByteMaskExtended
);

  if(EXTEND) begin
    logic [WORDLEN*2/8-1:0]              ExtendedByteMask;
    // 'd2 means 2, but stops Design Compiler from complaining about signed to unsigned conversion
    assign ExtendedByteMask = (('d2**('d2**Size))-'d1) << Adr;
    assign ByteMask = ExtendedByteMask[WORDLEN/8-1:0];
    assign ByteMaskExtended = ExtendedByteMask[WORDLEN*2/8-1:WORDLEN/8];
  end else begin
    assign ByteMask = (('d2**('d2**Size))-'d1) << Adr;
    assign ByteMaskExtended = '0;
  end

/* Equivalent to the following

  if(WORDLEN == 64) begin
    always_comb begin
      case(Size[1:0])
        2'b00: begin ByteMask = 8'b00000000; ByteMask[Adr[2:0]] = 1'b1; end // sb
        2'b01: case (Adr[2:1])
                  2'b00: ByteMask = 8'b0000_0011;
                  2'b01: ByteMask = 8'b0000_1100;
                  2'b10: ByteMask = 8'b0011_0000;
                  2'b11: ByteMask = 8'b1100_0000;
                endcase
        2'b10: if (Adr[2]) ByteMask = 8'b11110000;
               else        ByteMask = 8'b00001111;
        2'b11: ByteMask = 8'b1111_1111;
      endcase
    end
  end else begin
    always_comb begin
      case(Size[1:0])
        2'b00: begin ByteMask = 4'b0000; ByteMask[Adr[1:0]] = 1'b1; end // sb
        2'b01: if (Adr[1]) ByteMask = 4'b1100;
               else        ByteMask = 4'b0011;
        2'b10: ByteMask = 4'b1111;
        default: ByteMask =  4'b1111;
      endcase
    end
  end
*/
endmodule
