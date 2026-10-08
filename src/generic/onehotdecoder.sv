///////////////////////////////////////////
// onehotdecoder.sv
//
// Written: rose@rosethompson.net July 09, 2021
// Modified:
//
// Purpose: Bin to one hot decoder. Power of 2 only.
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

module onehotdecoder #(parameter WIDTH = 2) (
  input  logic [WIDTH-1:0]    bin,
  output logic [2**WIDTH-1:0] decoded
);

  always_comb begin
    decoded = '0;
    decoded[bin] = 1'b1;
  end

endmodule
