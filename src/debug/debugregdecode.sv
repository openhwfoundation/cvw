///////////////////////////////////////////
// debugregdecode.sv
//
// Written: Jacob Pease jacobpease@protonmail.com,
//          James E. Stine james.stine@okstate.edu
// Created: October 23rd, 2026
// Modified:
//
// Purpose: Decodes an abstract command regno into CSR, GPR, or FPR access.
//          Shared by the debug APB requester and completer.
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

module debugregdecode import cvw::*; #(parameter cvw_t P) (
  input  logic [15:0] RegNO,
  output logic        CSRAccess, GPRAccess, FPRAccess
);
  assign CSRAccess = (RegNO[15:12] == 4'h0);                          // 0x0000-0x0fff
  assign GPRAccess = (RegNO[15:4]  == 12'h100) |                      // 0x1000-0x100f
                     (~P.E_SUPPORTED & (RegNO[15:4] == 12'h101));     // 0x1010-0x101f
  assign FPRAccess = P.F_SUPPORTED & (RegNO[15:5] == 11'h081);        // 0x1020-0x103f
endmodule
