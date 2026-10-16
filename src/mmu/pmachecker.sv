///////////////////////////////////////////
// pmachecker.sv
//
// Written: tfleming@hmc.edu & jtorrey@hmc.edu 20 April 2021
// Modified:
//
// Purpose: Examines all physical memory accesses and identifies attributes of
//          the memory region accessed.
//          Can report illegal accesses to the trap unit and cause a fault.
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

module pmachecker import cvw::*;  #(parameter cvw_t P) (
  input  logic [P.PA_BITS-1:0] PhysicalAddress,        // Physical address
  input  logic [1:0]           Size,                   // Access size (log2 bytes)
  input  logic [3:0]           CMOpM,                  // Cache management operation: 1 cbo.inval, 2 cbo.clean, 4 cbo.flush, 8 cbo.zero
  input  logic                 AtomicAccessM,          // Atomic access
  input  logic                 ExecuteAccessF,         // Execute access
  input  logic                 WriteAccessM,           // Write access
  input  logic                 ReadAccessM,            // Read access
  input  logic [1:0]           PBMemoryType,           // PBMT field of PTE during TLB hit, or 00 otherwise
  output logic                 Cacheable, Idempotent, SelTIM, // PMA attributes: cacheable, idempotent, tightly integrated memory
  output logic                 PMAInstrAccessFaultF,   // PMA instruction access fault
  output logic                 PMALoadAccessFaultM,    // PMA load access fault
  output logic                 PMAStoreAmoAccessFaultM // PMA store/AMO access fault
);

  logic                        PMAAccessFault;
  logic                        AccessRW, AccessRWXC, AccessRX;
  logic [12:0]                 SelRegions;
  logic                        AtomicAllowed;
  logic                        CacheableRegion, IdempotentRegion;

  // Determine what type of access is being made
  assign AccessRW  = ReadAccessM | WriteAccessM;
  assign AccessRWXC = ReadAccessM | WriteAccessM | ExecuteAccessF | (|CMOpM);
  assign AccessRX  = ReadAccessM | ExecuteAccessF;

  // Determine which region of physical memory (if any) is being accessed
  // SelRegions: 0 none, 1 DTIM, 2 IROM, 3 EXT_MEM, 4 BOOTROM, 5 UNCORE_RAM, 6 CLINT, 7 GPIO, 8 UART, 9 PLIC, 10 SDC, 11 SPI, 12 PWM
  adrdecs #(P) adrdecs(PhysicalAddress, AccessRW, AccessRX, AccessRWXC, Size, SelRegions);

  // Only non-core RAM/ROM memory regions are cacheable. PBMT can override cacheable; NC and IO are uncachable
  assign CacheableRegion = SelRegions[3] | SelRegions[4] | SelRegions[5];  // exclusion-tag: unused-cacheable
  assign Cacheable = (PBMemoryType == 2'b00) ? CacheableRegion : 1'b0;

  // Non-idempotent means access could have side effect and must not be done speculatively or redundantly
  // I/O is nonidempotent.  PBMT can override PMA; NC is idempotent and IO is non-idempotent
  assign IdempotentRegion = SelRegions[1] | SelRegions[2] | SelRegions[3] | SelRegions[4] | SelRegions[5];
  assign Idempotent = (PBMemoryType == 2'b00) ? IdempotentRegion : (PBMemoryType == 2'b01);

  // Atomic operations are only allowed on RAM
  assign AtomicAllowed = SelRegions[1] | SelRegions[3] | SelRegions[5]; // exclusion-tag: unused-atomic
  // Check if tightly integrated memories are selected
  assign SelTIM = SelRegions[1] | SelRegions[2]; // exclusion-tag: unused-tim

  // Detect access faults
  assign PMAAccessFault          = SelRegions[0] & AccessRWXC | AtomicAccessM & ~AtomicAllowed;
  assign PMAInstrAccessFaultF    = ExecuteAccessF & PMAAccessFault;
  assign PMALoadAccessFaultM     = ReadAccessM & ~WriteAccessM & PMAAccessFault;
  assign PMAStoreAmoAccessFaultM = (WriteAccessM | (|CMOpM))   & PMAAccessFault;
endmodule
