///////////////////////////////////////////
// swbytemask.sv
//
// Written:  David Harris David_Harris@hmc.edu 9 January 2021
// Modified: Rose Thompson
//
// Purpose: Store byte mask.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module swbytemask #(parameter WORDLEN, EXTEND = 0) (
  input  logic [2:0]                   Size,            // Access size (log2 bytes)
  input  logic [$clog2(WORDLEN/8)-1:0] Adr,             // Byte address within the word
  output logic [WORDLEN/8-1:0]         ByteMask,        // Byte write enables
  output logic [WORDLEN/8-1:0]         ByteMaskExtended // Byte write enables for the next word of a misaligned access
);

  if (EXTEND) begin
    logic [WORDLEN*2/8-1:0]              ExtendedByteMask;
    // 2^(2^Size) - 1 has one bit set per byte accessed; shift it to the byte address.
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
