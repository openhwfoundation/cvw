///////////////////////////////////////////
// tlbcontrol.sv
//
// Written: David_Harris@hmc.edu 5 July 2021
// Modified:
//
// Purpose: Control signals for TLB
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
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

module tlbcontrol import cvw::*;  #(parameter cvw_t P, ITLB = 0) (
  input  logic [P.SVMODE_BITS-1:0] SATP_MODE,
  input  logic [P.XLEN-1:0]        VAdr,
  input  logic                     STATUS_MXR, STATUS_SUM, STATUS_MPRV,
  input  logic [1:0]               STATUS_MPP,
  input  logic                     ENVCFG_PBMTE,       // Page-based memory types enabled
  input  logic                     ENVCFG_ADUE,        // HPTW A/D Update enable
  input  logic [1:0]               EffectivePrivilegeModeW,   // Current privilege level of the processeor, accounting for mstatus.MPRV
  input  logic                     ReadAccess, WriteAccess,
  input  logic [3:0]               CMOpM,
  input  logic                     DisableTranslation,
  input  logic [11:0]              PTEAccessBits,
  input  logic                     CAMHit,
  input  logic                     Misaligned,
  input  logic                     NAPOT4,             // pte.ppn[3:0] = 1000, indicating 64 KiB continuous NAPOT region
  output logic                     TLBMiss,
  output logic                     TLBHit,
  output logic                     TLBPageFault,
  output logic                     UpdateDA,
  output logic                     SV39Mode,
  output logic                     SV48Mode,
  output logic                     Translate,
  output logic                     PTE_N,         // NAPOT page table entry
  output logic [1:0]               PBMemoryType   // PBMT field of PTE during TLB hit, or 00 otherwise
);

  // Sections of the page table entry
  logic [1:0]                     PTE_PBMT;
  logic                           PTE_RESERVED, PTE_D, PTE_A, PTE_U, PTE_X, PTE_W, PTE_R, PTE_V; // Useful PTE Control Bits
  logic                           UpperBitsUnequal;
  logic                           TLBAccess;
  logic                           ImproperPrivilege;
  logic                           BadPBMT, BadNAPOT, BadReserved;
  logic                           ReservedRW;
  logic                           InvalidAccess;
  logic                           PreUpdateDA, PrePageFault;

  // Grab the sv mode from SATP and determine whether translation should occur
  assign Translate = (SATP_MODE != P.NO_TRANSLATE[P.SVMODE_BITS-1:0]) & (EffectivePrivilegeModeW != P.M_MODE) & ~DisableTranslation;

  // Determine whether TLB is being used
  assign TLBAccess = ReadAccess | WriteAccess | (|CMOpM);

  // Check that upper bits are legal (all 0s or all 1s)
  vm64check #(P) vm64check(.SATP_MODE, .VAdr, .SV39Mode, .SV48Mode, .UpperBitsUnequal);

  // unswizzle useful PTE bits
  assign PTE_N = PTEAccessBits[11];
  assign PTE_PBMT = PTEAccessBits[10:9];
  assign PTE_RESERVED = PTEAccessBits[8];
  assign {PTE_D, PTE_A} = PTEAccessBits[7:6];
  assign {PTE_U, PTE_X, PTE_W, PTE_R, PTE_V} = PTEAccessBits[4:0];

  // Send PMA a 2-bit MemoryType that is PBMT during leaf page table accesses and 0 otherwise
  assign PBMemoryType = PTE_PBMT & {2{Translate & TLBHit & P.SVPBMT_SUPPORTED}};

  // check if reserved, N, or PBMT bits are malformed w in RV64
  assign BadPBMT = ((PTE_PBMT != 0) & ~(P.SVPBMT_SUPPORTED & ENVCFG_PBMTE)) | PTE_PBMT == 3; // PBMT must be zero if not supported; value of 3 is reserved
  assign BadNAPOT = PTE_N & (~P.SVNAPOT_SUPPORTED | ~NAPOT4);              // N must be be 0 if CVNAPOT is not supported or not 64 KiB contiguous region
  assign BadReserved = PTE_RESERVED;                                       // Reserved bits must be zero
  assign ReservedRW = PTE_W & ~PTE_R;                                      // page fault on reserved encoding with R=0, W=1 per Privileged Spec 10.3.1

  // Check whether the access is allowed, page faulting if not.
  if (ITLB == 1) begin : itlb // Instruction TLB fault checking
    // User mode may only execute user mode pages, and supervisor mode may
    // only execute non-user mode pages.
    assign ImproperPrivilege = ((EffectivePrivilegeModeW == P.U_MODE) & ~PTE_U) | ((EffectivePrivilegeModeW == P.S_MODE) & PTE_U);
    assign PreUpdateDA = ~PTE_A;
    assign InvalidAccess = ~PTE_X | ReservedRW;
 end else begin : dtlb // Data TLB fault checking
    logic InvalidRead, InvalidWrite;
    logic InvalidCBOM, InvalidCBOZ;

    // User mode may only load/store from user mode pages, and supervisor mode
    // may only access user mode pages when STATUS_SUM is low.
    assign ImproperPrivilege = ((EffectivePrivilegeModeW == P.U_MODE) & ~PTE_U) |
      ((EffectivePrivilegeModeW == P.S_MODE) & PTE_U & ~STATUS_SUM);
    // Check for read error. Reads are invalid when the page is not readable
    // (and executable pages are not readable) or when the page is neither
    // readable nor executable (and executable pages are readable).
    assign InvalidRead = ReadAccess & ~PTE_R & (~STATUS_MXR | ~PTE_X);
    // Check for write error. Writes are invalid when the page's write bit is 0.
    assign InvalidWrite = WriteAccess & ~PTE_W;
    assign InvalidCBOM = (|CMOpM[2:0]) & (~PTE_R & (~STATUS_MXR | ~PTE_X));
    assign InvalidCBOZ = CMOpM[3] & ~PTE_W;
    assign InvalidAccess = InvalidRead | InvalidWrite | InvalidCBOM | InvalidCBOZ | ReservedRW;
    assign PreUpdateDA = ~PTE_A | (WriteAccess | CMOpM[3]) & ~PTE_D;
  end

  // Determine whether to update DA bits.  With SVADU, it is done in hardware
  assign UpdateDA = P.SVADU_SUPPORTED & PreUpdateDA & Translate & TLBHit & ~TLBPageFault & ENVCFG_ADUE;

  // Determine whether page fault occurs
  assign PrePageFault = UpperBitsUnequal | Misaligned | ~PTE_V | ImproperPrivilege | (P.XLEN == 64 & (BadPBMT | BadNAPOT | BadReserved)) | (PreUpdateDA & (~P.SVADU_SUPPORTED | ~ENVCFG_ADUE));
  assign TLBPageFault = Translate & TLBHit & (PrePageFault | InvalidAccess);

  assign TLBHit = CAMHit & TLBAccess;
  assign TLBMiss = ~CAMHit & TLBAccess & Translate ;
endmodule
