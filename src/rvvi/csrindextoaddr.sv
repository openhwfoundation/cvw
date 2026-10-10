///////////////////////////////////////////
// csrindextoaddr.sv
//
// Written: Rose Thompson rose@rosethompson.net
// Created: 24 January 2024
// Modified: 24 January 2024
//
// Purpose: Converts the rvvi CSR index into the CSR address
//
// Documentation:
//
// A component of the CORE-V-WALLY configurable RISC-V project.
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

module csrindextoaddr #(parameter TOTAL_CSRS = 36) (
  input  logic [TOTAL_CSRS-1:0] CSRWen,   // One-hot CSR write enables
  output logic [11:0]           CSRAddr); // CSR address

  // Address of CSRArray[i] as assigned in testbench/common/rvvitbwrapper.sv and the FPGA top levels
  localparam logic [11:0] CSR_ADDR [36] = '{
    12'h300, //  0 mstatus
    12'h310, //  1 mstatush
    12'h305, //  2 mtvec
    12'h341, //  3 mepc
    12'h306, //  4 mcounteren
    12'h320, //  5 mcountinhibit
    12'h302, //  6 medeleg
    12'h303, //  7 mideleg
    12'h344, //  8 mip
    12'h304, //  9 mie
    12'h301, // 10 misa
    12'h30A, // 11 menvcfg
    12'hF14, // 12 mhartid
    12'h340, // 13 mscratch
    12'h342, // 14 mcause
    12'h343, // 15 mtval
    12'hF11, // 16 mvendorid
    12'hF12, // 17 marchid
    12'hF13, // 18 mimpid
    12'hF15, // 19 mconfigptr
    12'h34A, // 20 mtinst
    12'h100, // 21 sstatus
    12'h104, // 22 sie
    12'h105, // 23 stvec
    12'h141, // 24 sepc
    12'h106, // 25 scounteren
    12'h10A, // 26 senvcfg
    12'h180, // 27 satp
    12'h140, // 28 sscratch
    12'h143, // 29 stval
    12'h142, // 30 scause
    12'h144, // 31 sip
    12'h14D, // 32 stimecmp
    12'h001, // 33 fflags
    12'h002, // 34 frm
    12'h003  // 35 fcsr
  };

  // CSRWen is one-hot: bit i selects CSRArray[i].  Return the address of that CSR (0 if none).
  always_comb begin
    CSRAddr = 12'h000;
    for (int i = 0; i < TOTAL_CSRS; i++)
      if (CSRWen == (TOTAL_CSRS'(1) << i)) CSRAddr = CSR_ADDR[i];
  end
endmodule
