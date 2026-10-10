///////////////////////////////////////////
// riscvassertions_wally.sv
//
// A component of the Wally configurable RISC-V project.
// Assertions specific to wally microarchitecture
//
// Created June 12 2025 by James Kaden Cassidy jacassidy@hmc.edu
//
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
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

module riscvassertions_wally import cvw::*; #(parameter cvw_t P);
  initial begin
    assert (P.PMP_G > 0 | P.XLEN == 32 | P.PMP_ENTRIES == 0) else $fatal(1, "RV64 requires PMP_G at least 1 to avoid checking for 8-byte accesses to 4-byte region");
    assert ((P.PMP_G >= $clog2(P.DCACHE_LINELENINBITS/8)-2) | !P.ZICCLSM_SUPPORTED | P.PMP_ENTRIES == 0) else $fatal(1, "Systems that support misaligned data with PMP must have grain size of at least one cache line so accesses that span grains will also cause spills");
    assert ((P.PMP_G >= $clog2(P.ICACHE_LINELENINBITS/8)-2) | !P.ZCA_SUPPORTED | (P.PMP_ENTRIES == 0) | !P.ICACHE_SUPPORTED) else $fatal(1, "Systems that support compressed instructions with PMP must have grain size of at least one cache line so fetches that span grains will also cause spills");
    assert (P.PMP_G < P.PA_BITS-2 | P.PMP_ENTRIES == 0) else $fatal(1, "PMP granularity must be less than the number of physical address bits");
    assert (P.IDIV_BITSPERCYCLE == 1 | P.IDIV_BITSPERCYCLE==2 | P.IDIV_BITSPERCYCLE==4) else $fatal(1, "Illegal number of divider bits/cycle: IDIV_BITSPERCYCLE must be 1, 2, or 4");
    assert (P.DCACHE_SUPPORTED | !P.F_SUPPORTED | P.FLEN <= P.XLEN) else $fatal(1, "Data cache required to support FLEN > XLEN because AHB/DTIM bus width is XLEN");
    assert (P.DCACHE_WAYSIZEINBYTES <= 4096 | (!P.DCACHE_SUPPORTED) | P.VIRTMEM_SUPPORTED == 0) else $fatal(1, "DCACHE_WAYSIZEINBYTES cannot exceed 4 KiB when caches and virtual memory is enabled (to prevent aliasing)");
    assert (P.DCACHE_LINELENINBITS >= 128 | (!P.DCACHE_SUPPORTED)) else $fatal(1, "DCACHE_LINELENINBITS must be at least 128 when caches are enabled");
    assert (P.DCACHE_LINELENINBITS < P.DCACHE_WAYSIZEINBYTES*8) else $fatal(1, "DCACHE_LINELENINBITS must be smaller than way size");
    assert (P.ICACHE_WAYSIZEINBYTES <= 4096 | (!P.ICACHE_SUPPORTED) | P.VIRTMEM_SUPPORTED == 0) else $fatal(1, "ICACHE_WAYSIZEINBYTES cannot exceed 4 KiB when caches and virtual memory is enabled (to prevent aliasing)");
    assert (P.ICACHE_LINELENINBITS >= 32 | (!P.ICACHE_SUPPORTED)) else $fatal(1, "ICACHE_LINELENINBITS must be at least 32 when caches are enabled");
    assert (P.ICACHE_LINELENINBITS < P.ICACHE_WAYSIZEINBYTES*8) else $fatal(1, "ICACHE_LINELENINBITS must be smaller than way size");
    assert (2**$clog2(P.DCACHE_LINELENINBITS) == P.DCACHE_LINELENINBITS | (!P.DCACHE_SUPPORTED)) else $fatal(1, "DCACHE_LINELENINBITS must be a power of 2");
    assert (2**$clog2(P.DCACHE_WAYSIZEINBYTES) == P.DCACHE_WAYSIZEINBYTES | (!P.DCACHE_SUPPORTED)) else $fatal(1, "DCACHE_WAYSIZEINBYTES must be a power of 2");
    assert (2**$clog2(P.ICACHE_LINELENINBITS) == P.ICACHE_LINELENINBITS | (!P.ICACHE_SUPPORTED)) else $fatal(1, "ICACHE_LINELENINBITS must be a power of 2");
    assert (2**$clog2(P.ICACHE_WAYSIZEINBYTES) == P.ICACHE_WAYSIZEINBYTES | (!P.ICACHE_SUPPORTED)) else $fatal(1, "ICACHE_WAYSIZEINBYTES must be a power of 2");
    assert (2**$clog2(P.ITLB_ENTRIES) == P.ITLB_ENTRIES | P.VIRTMEM_SUPPORTED==0) else $fatal(1, "ITLB_ENTRIES must be a power of 2");
    assert (2**$clog2(P.DTLB_ENTRIES) == P.DTLB_ENTRIES | P.VIRTMEM_SUPPORTED==0) else $fatal(1, "DTLB_ENTRIES must be a power of 2");
    assert (P.UNCORE_RAM_RANGE >= 64'h07FFFFFF) else $warning("Some regression tests will fail if UNCORE_RAM_RANGE is less than 64'h07FFFFFF");
    assert (P.VIRTMEM_SUPPORTED == 0 | (P.DTIM_SUPPORTED == 0 & P.IROM_SUPPORTED == 0)) else $fatal(1, "Can't simultaneously have virtual memory and DTIM_SUPPORTED/IROM_SUPPORTED because local memories don't translate addresses");
    assert (P.DCACHE_SUPPORTED | P.VIRTMEM_SUPPORTED ==0) else $fatal(1, "Virtual memory needs dcache");
    assert (P.ICACHE_SUPPORTED | P.VIRTMEM_SUPPORTED ==0) else $fatal(1, "Virtual memory needs icache");
    assert ((P.DCACHE_SUPPORTED == 0 & P.ICACHE_SUPPORTED == 0) | P.BUS_SUPPORTED) else $fatal(1, "Dcache and Icache requires DBUS_SUPPORTED.");
    assert (P.DCACHE_LINELENINBITS <= P.XLEN*16 | (!P.DCACHE_SUPPORTED)) else $fatal(1, "DCACHE_LINELENINBITS must not exceed 16 words because max AHB burst size is 16");
    assert (P.DCACHE_LINELENINBITS % 4 == 0) else $fatal(1, "DCACHE_LINELENINBITS must hold 4, 8, or 16 words");
    assert (P.DCACHE_SUPPORTED | (P.ZAAMO_SUPPORTED == 0 & P.ZALRSC_SUPPORTED == 0)) else $fatal(1, "Atomic extension (ZAAMO/ZALRSC) requires cache on Wally.");
    assert (P.IDIV_ON_FPU == 0 | P.F_SUPPORTED) else $fatal(1, "IDIV on FPU needs F_SUPPORTED");
    assert ((P.ZICBOM_SUPPORTED == 0) | (P.DCACHE_SUPPORTED == 1)) else $fatal(1, "ZICBOM requires DCACHE_SUPPORTED");
    assert ((P.ZICBOZ_SUPPORTED == 0) | (P.DCACHE_SUPPORTED == 1)) else $fatal(1, "ZICBOZ requires DCACHE_SUPPORTED");
    assert ((P.ZICBOZ_SUPPORTED == 0) | (P.DTIM_SUPPORTED == 0)) else $fatal(1, "ZICBOZ incompatible with DTIM");
    assert ((P.LLEN == P.XLEN) | (P.DCACHE_SUPPORTED & P.DTIM_SUPPORTED == 0)) else $fatal(1, "LLEN > XLEN (D on RV32 or Q on RV64) requires data cache");
    assert ((P.ZICCLSM_SUPPORTED == 0) | (P.DCACHE_SUPPORTED == 1)) else $fatal(1, "ZICCLSM requires DCACHE_SUPPORTED");
    assert ((P.ZAMA16B_SUPPORTED == 0) | (P.DCACHE_LINELENINBITS >= 128)) else $fatal(1, "ZAMA16B requires a cache line of at least 128 bits so a 16 byte granule never spans two lines");
  end

endmodule
