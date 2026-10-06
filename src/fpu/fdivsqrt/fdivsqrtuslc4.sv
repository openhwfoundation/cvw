///////////////////////////////////////////
// fdivsqrtuslc4.sv
//
// Written: David_Harris@hmc.edu, me@KatherineParry.com, cturek@hmc.edu
// Modified:13 January 2022
//
// Purpose: Table-based Radix 4 Unified Quotient/Square Root Digit Selection
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

module fdivsqrtuslc4 (
  input  logic [2:0] Dmsbs,             // U0.3 fractional bits after implicit leading 1
  input  logic [4:0] Smsbs,             // U1.4 leading bits of square root approximation
  input  logic [7:0] WSmsbs, WCmsbs,    // Q4.4 redundant residual most significant bits
  input  logic       Sqrt, j0, j1,
  output logic [3:0] udigit             // {2, 1, -1, -2} digit is 0 if none are hot
);
  logic [7:0] PreWmsbs;                 // Q4.4 nonredundant residual msbs
  logic [6:0] Wmsbs;                    // Q4.3 truncated nonredundant residual
  logic [2:0] A;                        // U0.3 upper bits of D or Smsbs, discarding integer bit

  assign PreWmsbs = WCmsbs + WSmsbs;    // add redundant residual to find msbs
  assign Wmsbs = PreWmsbs[7:1];         // truncate least significant bit to Q4.3 to index table
  // D = 0001.xxx...
  // Dmsbs = |   |
  // W =      xxxx.xxx...
  // Wmsbs = |        |

  logic [3:0] USel4[1023:0];            // 1024-bit table indexed with 3 bits of A and 7 bits of Wmsbs

  // Prepopulate selection table; this is constant at compile time
  always_comb begin
    integer a, w, i, w2;
    for(a=0; a<8; a++)
      for(w=0; w<128; w++)begin
        i = a*128+w;
        w2 = w-128*(w>=64); // convert to two's complement
        case(a)
          0: if($signed(w2)>=$signed(12))      USel4[i] = 4'b1000;
            else if(w2>=4)   USel4[i] = 4'b0100;
            else if(w2>=-4)  USel4[i] = 4'b0000;
            else if(w2>=-13) USel4[i] = 4'b0010;
            else             USel4[i] = 4'b0001;
          1: if(w2>=14)      USel4[i] = 4'b1000;
            else if(w2>=4)   USel4[i] = 4'b0100;
            else if(w2>=-4)  USel4[i] = 4'b0000;
            else if(w2>=-14) USel4[i] = 4'b0010;
            else             USel4[i] = 4'b0001;
          2: if(w2>=16)      USel4[i] = 4'b1000;
            else if(w2>=4)   USel4[i] = 4'b0100;
            else if(w2>=-6)  USel4[i] = 4'b0000;
            else if(w2>=-16) USel4[i] = 4'b0010;
            else             USel4[i] = 4'b0001;
          3: if(w2>=16)      USel4[i] = 4'b1000;
            else if(w2>=4)   USel4[i] = 4'b0100;
            else if(w2>=-6)  USel4[i] = 4'b0000;
            else if(w2>=-17) USel4[i] = 4'b0010;
            else             USel4[i] = 4'b0001;
          4: if(w2>=18)      USel4[i] = 4'b1000;
            else if(w2>=6)   USel4[i] = 4'b0100;
            else if(w2>=-6)  USel4[i] = 4'b0000;
            else if(w2>=-18) USel4[i] = 4'b0010;
            else             USel4[i] = 4'b0001;
          5: if(w2>=20)      USel4[i] = 4'b1000;
            else if(w2>=6)   USel4[i] = 4'b0100;
            else if(w2>=-8)  USel4[i] = 4'b0000;
            else if(w2>=-20) USel4[i] = 4'b0010;
            else             USel4[i] = 4'b0001;
          6: if(w2>=20)      USel4[i] = 4'b1000;
            else if(w2>=8)   USel4[i] = 4'b0100;
            else if(w2>=-8)  USel4[i] = 4'b0000;
            else if(w2>=-22) USel4[i] = 4'b0010;
            else             USel4[i] = 4'b0001;
          7: if(w2>=24)      USel4[i] = 4'b1000;
            else if(w2>=8)   USel4[i] = 4'b0100;
            else if(w2>=-8)  USel4[i] = 4'b0000;
            else if(w2>=-22) USel4[i] = 4'b0010;
            else             USel4[i] = 4'b0001;
        endcase
      end
  end

  // Select A
  always_comb
    if (Sqrt) begin
      if (j1)                 A = 3'b101;     // on first sqrt iteration        A = .101
      else if (Smsbs[4] == 1) A = 3'b111;     // if S = 1.0000, use             A = .111
      else                    A = Smsbs[2:0]; // otherwise use                  A = 2S (in U0.3 format)
    end else                  A = Dmsbs;      // division                       A = D (IN U0.3 format, dropping leading 1)

  // Select quotient digit from lookup table based on A and W
  // On step j = 0 for square root, always select u_0 = 1
  assign udigit = (Sqrt & j0) ? 4'b0100 : USel4[{A,Wmsbs}];
endmodule
