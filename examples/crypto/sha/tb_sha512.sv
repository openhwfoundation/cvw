///////////////////////////////////////////
// tb_sha512.sv
//
// Written: james.stine@okstate.edu/emelia.kravchuk@okstate.edu
// Created: 16 October 2024
//
// Purpose: SHA-512 Module testbench
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-25 Harvey Mudd College & Oklahoma State University
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

`timescale 1ns/1ps
module stimulus;

   parameter MSG_SIZE = 72; // Go Wally!

   logic [MSG_SIZE-1:0] message;
   logic [511:0] hashed;

   logic     clk;
   logic [31:0]  errors;
   logic [31:0]  vectornum;
   logic [511:0]  result;
   logic [7:0]   op;
   // Size of [583:0] is size of vector in file:  72 + 512 = 584 bits
   logic [583:0] testvectors[511:0];

   integer   handle3;
   integer   desc3;
   integer   i;
   integer       j;

   top #(MSG_SIZE, 1024) dut (message, hashed);

   // 1 ns clock
   initial
     begin
    clk = 1'b1;
    forever #5 clk = ~clk;
     end

   initial
     begin
        handle3 = $fopen("sha512.out");
        $readmemh("sha512.tv", testvectors);
        vectornum = 0;
        errors = 0;
        desc3 = handle3;
     end


   // apply test vectors on rising edge of clk
   always @(posedge clk)
     begin
        #1; {message, result} = testvectors[vectornum];
     end

   // check results on falling edge of clk
  always @(negedge clk)
    begin
       if (result != hashed)
            errors = errors + 1;
        $fdisplay(desc3, "%h %h || %h || %b",
                 message, hashed, result, (result == hashed));
       vectornum = vectornum + 1;
       if (testvectors[vectornum] === 584'bx)
         begin
            $display("%d tests completed with %d errors",
                     vectornum, errors);
            $finish;
         end
    end

endmodule // stimulus
