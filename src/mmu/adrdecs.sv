///////////////////////////////////////////
// adrdecs.sv
//
// Written: David_Harris@hmc.edu 22 June 2021
// Modified:
//
// Purpose: All the address decoders for peripherals
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

  // verilator lint_off UNOPTFLAT

module adrdecs import cvw::*; #(parameter cvw_t P) (
  input  logic [P.PA_BITS-1:0] PhysicalAddress,                // Physical address
  input  logic                 AccessRW, AccessRX, AccessRWXC, // Access types: read or write; read or execute; any including cache management
  input  logic [1:0]           Size,                           // Access size (log2 bytes)
  output logic [12:0]          SelRegions                      // One-hot PMA region select
);

  // SizeMask bit i permits 2^i-byte accesses
  localparam logic [3:0]       SIZE_B             = 4'b0001; // byte only
  localparam logic [3:0]       SIZE_W             = 4'b0100; // word only
  localparam logic [3:0]       SIZE_WD            = 4'b1100; // word or doubleword
  localparam logic [3:0]       SIZE_BHW           = 4'b0111; // byte, halfword, or word
  localparam logic [3:0]       SIZE_BHWD          = 4'b1111; // byte, halfword, word, or doubleword
  localparam logic [3:0]       SUPPORTED_SIZE     = (P.LLEN == 32 ? SIZE_BHW : SIZE_BHWD);
  localparam logic [3:0]       SUPPORTED_BUS_SIZE = SUPPORTED_SIZE & (P.AHBW >= 64 ? SIZE_BHWD : SIZE_BHW);
  // Determine which region of physical memory (if any) is being accessed
  // GPIO, PLIC, SPI, and PWM are word-only; UART is byte-only
  adrdec #(P.PA_BITS) dtimdec(PhysicalAddress, P.DTIM_BASE[P.PA_BITS-1:0], P.DTIM_RANGE[P.PA_BITS-1:0], P.DTIM_SUPPORTED, AccessRW, Size, SUPPORTED_SIZE, SelRegions[REGION_DTIM]);
  adrdec #(P.PA_BITS) iromdec(PhysicalAddress, P.IROM_BASE[P.PA_BITS-1:0], P.IROM_RANGE[P.PA_BITS-1:0], P.IROM_SUPPORTED, AccessRX, Size, SUPPORTED_SIZE, SelRegions[REGION_IROM]);
  adrdec #(P.PA_BITS) ddr4dec(PhysicalAddress, P.EXT_MEM_BASE[P.PA_BITS-1:0], P.EXT_MEM_RANGE[P.PA_BITS-1:0], P.EXT_MEM_SUPPORTED, AccessRWXC, Size, SUPPORTED_SIZE, SelRegions[REGION_EXT_MEM]);
  adrdec #(P.PA_BITS) bootromdec(PhysicalAddress, P.BOOTROM_BASE[P.PA_BITS-1:0], P.BOOTROM_RANGE[P.PA_BITS-1:0], P.BOOTROM_SUPPORTED, AccessRX, Size, SUPPORTED_SIZE, SelRegions[REGION_BOOTROM]);
  adrdec #(P.PA_BITS) uncoreramdec(PhysicalAddress, P.UNCORE_RAM_BASE[P.PA_BITS-1:0], P.UNCORE_RAM_RANGE[P.PA_BITS-1:0], P.UNCORE_RAM_SUPPORTED, AccessRWXC, Size, SUPPORTED_SIZE, SelRegions[REGION_UNCORE_RAM]);
  adrdec #(P.PA_BITS) clintdec(PhysicalAddress, P.CLINT_BASE[P.PA_BITS-1:0], P.CLINT_RANGE[P.PA_BITS-1:0], P.CLINT_SUPPORTED, AccessRW, Size, SUPPORTED_BUS_SIZE, SelRegions[REGION_CLINT]);
  adrdec #(P.PA_BITS) gpiodec(PhysicalAddress, P.GPIO_BASE[P.PA_BITS-1:0], P.GPIO_RANGE[P.PA_BITS-1:0], P.GPIO_SUPPORTED, AccessRW, Size, SIZE_W, SelRegions[REGION_GPIO]);
  adrdec #(P.PA_BITS) uartdec(PhysicalAddress, P.UART_BASE[P.PA_BITS-1:0], P.UART_RANGE[P.PA_BITS-1:0], P.UART_SUPPORTED, AccessRW, Size, SIZE_B, SelRegions[REGION_UART]);
  adrdec #(P.PA_BITS) plicdec(PhysicalAddress, P.PLIC_BASE[P.PA_BITS-1:0], P.PLIC_RANGE[P.PA_BITS-1:0], P.PLIC_SUPPORTED, AccessRW, Size, SIZE_W, SelRegions[REGION_PLIC]);
  adrdec #(P.PA_BITS) sdcdec(PhysicalAddress, P.SDC_BASE[P.PA_BITS-1:0], P.SDC_RANGE[P.PA_BITS-1:0], P.SDC_SUPPORTED, AccessRW, Size, SUPPORTED_BUS_SIZE & SIZE_WD, SelRegions[REGION_SDC]);
  adrdec #(P.PA_BITS) spidec(PhysicalAddress, P.SPI_BASE[P.PA_BITS-1:0], P.SPI_RANGE[P.PA_BITS-1:0], P.SPI_SUPPORTED, AccessRW, Size, SIZE_W, SelRegions[REGION_SPI]);
  adrdec #(P.PA_BITS) pwmdec(PhysicalAddress, P.PWM_BASE[P.PA_BITS-1:0], P.PWM_RANGE[P.PA_BITS-1:0], P.PWM_SUPPORTED, AccessRW, Size, SIZE_W, SelRegions[REGION_PWM]);

  assign SelRegions[REGION_NONE] = ~|(SelRegions[REGION_PWM:REGION_DTIM]); // none of the regions are selected
endmodule

  // verilator lint_on UNOPTFLAT
