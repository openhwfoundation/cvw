///////////////////////////////////////////
// vfrec7lut.sv
//
// Written: nfotneos@g.hmc.edu 2026-09-18
//
// Purpose: vfrec7 reciprocal lookup table.
//          Input  = seven MSBs of normalized input fraction
//          Output = seven MSBs of normalized reciprocal fraction
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
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

module vfrec7lut (
  input  logic [6:0] LutIdx,
  output logic [6:0] LutOut
);

  logic [6:0] ROM [0:127];

  `ifdef VERILATOR
    // because Verilator doesn't automatically accept $WALLY from the shell
    import "DPI-C" function string getenvval(input string env_name);
  `endif

  initial begin
    `ifdef VERILATOR
      string WALLY_DIR = getenvval("WALLY");
      $readmemh({WALLY_DIR, "/src/vpu/vfrec7/vfrec7rom.txt"}, ROM);
    `else
      $readmemh({"$WALLY/src/vpu/vfrec7/vfrec7rom.txt"}, ROM);
    `endif
  end

  assign LutOut = ROM[LutIdx];

endmodule
